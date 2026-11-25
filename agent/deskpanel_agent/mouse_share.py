"""Laptop mouse on the phone (macOS): push the cursor past the edge the phone sits on and
it moves onto the phone; move back out of the phone's facing edge to get it back.

How:
- The phone app's arrangement screen (`mouse.displays`) places the phone like a small extra
  display touching one of the Mac's displays. It then sends `mouse.setup {on, rect, w, h}`:
  the phone's rectangle in global Mac points and its logical screen size. While on, and that
  phone is connected, a Quartz event tap watches mouse events.
- Where the phone touches (see mouse_edge.PhoneLayout) the Mac cursor is frozen and hidden, mouse events
  are swallowed, and `{"t":"ptr", ...}` frames go to that phone: enter / move / down / up /
  scroll / leave with 0..1 coordinates. The phone draws a cursor and turns them into taps,
  drags and scrolls inside DeskPanel.
- Back out of the phone's facing edge, Esc, or the phone disconnecting returns the cursor.

The event tap needs Accessibility permission for the app that runs the agent (Remote
Trackpad, or Terminal when run by hand). The keyboard always stays on the Mac.
"""
from __future__ import annotations

import asyncio
import ctypes
import logging
import sys
import threading
import time
from typing import Any

from .hub import ActionError, Client, current_client, dumps
from .mouse_edge import PhoneLayout, Rect

log = logging.getLogger(__name__)

NO_PERMISSION = ("macOS didn't allow DeskPanel to read the mouse. Open System Settings → Privacy & "
                 "Security → Accessibility and turn on the app that runs the agent (Remote Trackpad), "
                 "then restart it.")
ESC = 53
MOVE_HZ = 120


class MouseShare:
    """Provider: no topics, one action (`mouse.setup`)."""

    topics: tuple[str, ...] = ()

    def __init__(self) -> None:
        self.actions = {"mouse.setup": self._setup, "mouse.displays": self._list_displays}
        self.loop: asyncio.AbstractEventLoop | None = None
        self.client: Client | None = None
        self.rect = Rect(0, 0, 1, 1)
        self.size = (780.0, 360.0)
        self.logic: PhoneLayout | None = None
        self.remote = False
        self._tap = None
        self._runloop = None
        self._thread: threading.Thread | None = None
        self._displays_at = 0.0
        self._pending_move: tuple[float, float] | None = None
        self._flush_scheduled = False
        self._hides = 0  # CGDisplayHideCursor calls to undo (it counts)
        self._park: tuple[float, float] | None = None  # where the Mac cursor waits
        self._checked = 0.0

    # ------------------------------------------------------------------ provider API

    async def start(self, hub: Any) -> None:
        self.loop = asyncio.get_running_loop()

    async def stop(self) -> None:
        self._stop_tap()

    def on_demand(self, topic: str, wanted: bool) -> None:
        pass

    def on_client_gone(self, c: Client) -> None:
        if c is self.client:
            self.client = None
            self._stop_tap()

    async def _list_displays(self, params: dict, progress: Any) -> dict:
        """The Mac's display arrangement for the phone's arrangement screen: bounds in global
        points and physical size in mm (0 when the display doesn't report it)."""
        if sys.platform != "darwin":
            raise ActionError("unsupported", "Sharing the mouse only works with a Mac for now.")
        import Quartz as Q

        err, ids, n = Q.CGGetActiveDisplayList(16, None, None)
        out = []
        for d in (ids or [])[:n]:
            b, mm = Q.CGDisplayBounds(d), Q.CGDisplayScreenSize(d)
            out.append({"x": b.origin.x, "y": b.origin.y, "w": b.size.width, "h": b.size.height,
                        "mm_w": round(mm.width, 1), "mm_h": round(mm.height, 1),
                        "main": bool(Q.CGDisplayIsMain(d)), "builtin": bool(Q.CGDisplayIsBuiltin(d))})
        return {"displays": out}

    async def _setup(self, params: dict, progress: Any) -> dict:
        on = bool(params.get("on"))
        c = current_client.get()
        if not on:
            if c is self.client or self.client is None:
                self.client = None
                self._stop_tap()
            return {"active": False}
        try:
            w, h = float(params["w"]), float(params["h"])
            x, y, rw, rh = (float(v) for v in params["rect"])
        except (KeyError, TypeError, ValueError):
            raise ActionError("bad_request", "rect [x, y, w, h] and the phone's w, h are required") from None
        if w < 50 or h < 50 or rw < 20 or rh < 20:
            raise ActionError("bad_request", "phone size too small")
        if sys.platform != "darwin":
            raise ActionError("unsupported", "Sharing the mouse only works with a Mac for now.")
        self.client, self.rect, self.size = c, Rect(x, y, rw, rh), (w, h)
        self._build_logic()
        if self._tap is None and not self._start_tap():
            self.client = None
            raise ActionError("failed", NO_PERMISSION)
        log.info("mouse: phone at (%.0f, %.0f) %.0fx%.0f pt in the display arrangement", x, y, rw, rh)
        return {"active": True}

    # ------------------------------------------------------------------ geometry

    def _build_logic(self) -> None:
        self.logic = PhoneLayout(self._displays(), self.rect, *self.size)
        self._displays_at = time.monotonic()

    @staticmethod
    def _displays() -> list[Rect]:
        import Quartz as Q

        err, ids, n = Q.CGGetActiveDisplayList(16, None, None)
        out = []
        for d in (ids or [])[:n]:
            b = Q.CGDisplayBounds(d)
            out.append(Rect(b.origin.x, b.origin.y, b.size.width, b.size.height))
        return out or [Rect(0, 0, 1440, 900)]

    # ------------------------------------------------------------------ event tap

    def _start_tap(self) -> bool:
        import Quartz as Q

        types = (Q.kCGEventMouseMoved, Q.kCGEventLeftMouseDown, Q.kCGEventLeftMouseUp,
                 Q.kCGEventLeftMouseDragged, Q.kCGEventRightMouseDown, Q.kCGEventRightMouseUp,
                 Q.kCGEventRightMouseDragged, Q.kCGEventOtherMouseDown, Q.kCGEventOtherMouseUp,
                 Q.kCGEventOtherMouseDragged, Q.kCGEventScrollWheel, Q.kCGEventKeyDown)
        mask = 0
        for t in types:
            mask |= Q.CGEventMaskBit(t)
        self._cb = self._callback  # keep the bound method alive while the tap exists
        tap = Q.CGEventTapCreate(Q.kCGSessionEventTap, Q.kCGHeadInsertEventTap, Q.kCGEventTapOptionDefault,
                                 mask, self._cb, None)
        if tap is None:
            log.warning("mouse: no Accessibility permission for the event tap")
            return False
        self._tap = tap
        ready = threading.Event()

        def run() -> None:
            import CoreFoundation as CF

            src = CF.CFMachPortCreateRunLoopSource(None, tap, 0)
            self._runloop = CF.CFRunLoopGetCurrent()
            CF.CFRunLoopAddSource(self._runloop, src, CF.kCFRunLoopCommonModes)
            Q.CGEventTapEnable(tap, True)
            ready.set()
            CF.CFRunLoopRun()

        self._thread = threading.Thread(target=run, name="mouse-tap", daemon=True)
        self._thread.start()
        ready.wait(2)
        return True

    def _stop_tap(self) -> None:
        if self.remote:
            self._go_home()
        if self._tap is None:
            return
        import CoreFoundation as CF
        import Quartz as Q

        Q.CGEventTapEnable(self._tap, False)
        if self._runloop is not None:
            CF.CFRunLoopStop(self._runloop)
        self._tap = self._runloop = self._thread = None
        log.info("mouse: stopped")

    def _callback(self, proxy: Any, etype: int, event: Any, refcon: Any) -> Any:
        """Runs on the tap thread for every mouse event. Must be quick and must never raise:
        on any error the event goes through untouched."""
        import Quartz as Q

        try:
            if etype in (Q.kCGEventTapDisabledByTimeout, Q.kCGEventTapDisabledByUserInput):
                if self._tap is not None:
                    Q.CGEventTapEnable(self._tap, True)
                if self.remote:
                    self._keep_parked(None, force=True)
                return event
            logic = self.logic
            if logic is None or self.client is None:
                return event
            if not self.remote:
                # Only plain moves cross (never while dragging a window).
                if etype != Q.kCGEventMouseMoved:
                    return event
                if time.monotonic() - self._displays_at > 3:
                    self._build_logic()
                    logic = self.logic
                loc = Q.CGEventGetLocation(event)
                dx = Q.CGEventGetIntegerValueField(event, Q.kCGMouseEventDeltaX)
                dy = Q.CGEventGetIntegerValueField(event, Q.kCGMouseEventDeltaY)
                if logic.should_cross(loc.x, loc.y, dx, dy):
                    self._go_phone()
                    return None
                return event

            # The mouse is on the phone: swallow everything except the keyboard.
            if etype in (Q.kCGEventMouseMoved, Q.kCGEventLeftMouseDragged, Q.kCGEventRightMouseDragged,
                         Q.kCGEventOtherMouseDragged):
                dx = Q.CGEventGetIntegerValueField(event, Q.kCGMouseEventDeltaX)
                dy = Q.CGEventGetIntegerValueField(event, Q.kCGMouseEventDeltaY)
                kind, a, b = logic.move(dx, dy)
                if kind == "leave":
                    self._go_home((a, b))
                else:
                    self._keep_parked(Q.CGEventGetLocation(event))
                    self._queue_move(a, b)
            elif etype == Q.kCGEventLeftMouseDown:
                self._send("down")
            elif etype == Q.kCGEventLeftMouseUp:
                self._send("up")
            elif etype == Q.kCGEventScrollWheel:
                dy = Q.CGEventGetIntegerValueField(event, Q.kCGScrollWheelEventPointDeltaAxis1)
                if dy:
                    self._send("scroll", dy=-dy)  # Flutter: positive = content moves up
            elif etype == Q.kCGEventKeyDown:
                if Q.CGEventGetIntegerValueField(event, Q.kCGKeyboardEventKeycode) == ESC:
                    self._go_home()
                    return None
                return event
            return None  # right / other buttons: swallowed, nothing on the phone
        except Exception:  # noqa: BLE001
            log.exception("mouse: tap callback failed; giving the mouse back")
            try:
                self._go_home()
            except Exception:  # noqa: BLE001
                pass
            return event

    # ------------------------------------------------------------------ crossing

    def _go_phone(self) -> None:
        import Quartz as Q

        self.remote = True
        loc = Q.CGEventGetLocation(Q.CGEventCreate(None))
        self._park = (loc.x, loc.y)
        Q.CGAssociateMouseAndMouseCursorPosition(False)
        self._hide_cursor()
        x, y = self.logic.normalized()
        self._send("enter", x=x, y=y)

    def _go_home(self, at: tuple[float, float] | None = None) -> None:
        import Quartz as Q

        if not self.remote:
            return
        self.remote = False
        self._pending_move = None
        at = at or (self.logic.return_point() if self.logic else None)
        if at:
            Q.CGWarpMouseCursorPosition(Q.CGPointMake(*at))
        Q.CGAssociateMouseAndMouseCursorPosition(True)
        self._show_cursor()
        self._send("leave")

    # Hiding the cursor from a background process needs the (private, long-standing)
    # "SetsCursorInBackground" connection property. macOS can still show the cursor again
    # (another app sets its cursor, or switching apps undoes the freeze), so while the mouse
    # is on the phone every move re-checks: cursor back at the park spot, frozen, hidden.
    def _hide_cursor(self) -> None:
        import Quartz as Q

        try:
            _allow_background_cursor()
            err = Q.CGDisplayHideCursor(Q.CGMainDisplayID())
            if err:
                log.warning("mouse: couldn't hide the Mac cursor (%s)", err)
            else:
                self._hides += 1
        except Exception as e:  # noqa: BLE001
            log.warning("mouse: couldn't hide the Mac cursor (%s)", e)

    def _keep_parked(self, loc: Any, force: bool = False) -> None:
        import Quartz as Q

        park = self._park
        if park is not None and (loc is None or abs(loc.x - park[0]) > 1 or abs(loc.y - park[1]) > 1):
            Q.CGWarpMouseCursorPosition(Q.CGPointMake(*park))
            Q.CGAssociateMouseAndMouseCursorPosition(False)
        now = time.monotonic()
        if force or now - self._checked > .1:
            self._checked = now
            if Q.CGCursorIsVisible() and self._hides < 20:
                self._hide_cursor()

    def _show_cursor(self) -> None:
        import Quartz as Q

        # Undo every hide (the count is per process), then make sure it's really back.
        for _ in range(self._hides):
            Q.CGDisplayShowCursor(Q.CGMainDisplayID())
        self._hides = 0
        for _ in range(5):
            if Q.CGCursorIsVisible():
                break
            Q.CGDisplayShowCursor(Q.CGMainDisplayID())
        self._park = None

    # ------------------------------------------------------------------ frames (thread-safe)

    def _send(self, kind: str, **kw: float) -> None:
        if self.loop is None:
            return
        self.loop.call_soon_threadsafe(self._push, {"t": "ptr", "k": kind, **kw})

    def _queue_move(self, x: float, y: float) -> None:
        self._pending_move = (x, y)
        if not self._flush_scheduled and self.loop is not None:
            self._flush_scheduled = True
            self.loop.call_soon_threadsafe(lambda: self.loop.call_later(1 / MOVE_HZ, self._flush))

    def _flush(self) -> None:
        self._flush_scheduled = False
        m, self._pending_move = self._pending_move, None
        if m and self.remote:
            self._push({"t": "ptr", "k": "move", "x": round(m[0], 5), "y": round(m[1], 5)})

    def _push(self, frame: dict) -> None:
        c = self.client
        if c is not None and not c.closed:
            if frame["k"] in ("down", "up", "leave") and self._pending_move:
                self._flush()  # a click lands where the pointer was last shown
            c.push(dumps(frame))


_bg_done = False


def _allow_background_cursor() -> None:
    """Let this (background) process hide the cursor: the window server's private
    "SetsCursorInBackground" connection property, set with plain CoreFoundation objects."""
    global _bg_done
    if _bg_done:
        return
    cf = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    cg = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
    cf.CFStringCreateWithCString.restype = ctypes.c_void_p
    cf.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
    key = cf.CFStringCreateWithCString(None, b"SetsCursorInBackground", 0x08000100)  # UTF-8
    yes = ctypes.c_void_p.in_dll(cf, "kCFBooleanTrue")
    conn = cg._CGSDefaultConnection
    conn.restype = ctypes.c_int
    setp = cg.CGSSetConnectionProperty
    setp.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
    setp.restype = ctypes.c_int
    c = conn()
    err = setp(c, c, key, yes)
    if err:
        raise OSError(f"CGSSetConnectionProperty failed ({err})")
    _bg_done = True
