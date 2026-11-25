"""Laptop mouse on the phone: pure geometry, no macOS calls.

The phone is placed in the Mac's display arrangement like one more (small) display: a
rectangle in global Mac points touching the outside of a display edge (the phone app's
arrangement screen snaps it there). Pushing the cursor out of a display where the phone
touches moves it onto the phone, at the matching spot; moving it out of the phone where a
display touches brings it back, at the matching spot. Movement is continuous across the
seam because the phone rectangle is to scale: one Mac point = 1/scale phone pixels.

Coordinates: Mac global points (Quartz: origin top-left of the main display, y down).
Phone: logical pixels of the phone's screen, origin top-left.
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Rect:
    x: float
    y: float
    w: float
    h: float

    @property
    def x2(self) -> float:
        return self.x + self.w

    @property
    def y2(self) -> float:
        return self.y + self.h

    def contains(self, px: float, py: float) -> bool:
        return self.x <= px < self.x2 and self.y <= py < self.y2


class PhoneLayout:
    """Decides when the cursor crosses, and tracks the phone pointer while it's there."""

    def __init__(self, displays: list[Rect], phone: Rect, phone_w: float, phone_h: float,
                 resistance: float = 24.0):
        self.displays = displays
        self.phone = phone
        self.pw, self.ph = max(1.0, phone_w), max(1.0, phone_h)
        self.sx, self.sy = phone.w / self.pw, phone.h / self.ph  # Mac points per phone pixel
        self.resistance = resistance  # points of push into the phone before crossing
        self._push = 0.0
        self.px = self.py = 0.0

    def _display_at(self, x: float, y: float) -> Rect | None:
        return next((d for d in self.displays if d.contains(x, y)), None)

    # ------------------------------------------------------------------ on the Mac

    def should_cross(self, x: float, y: float, dx: float, dy: float) -> bool:
        """Feed every plain mouse move (no button held). True = hand the mouse to the phone."""
        d = self._display_at(x, y)
        probe = None
        if d is not None:
            if dx > 0 and x >= d.x2 - 1:
                probe, out = (d.x2 + .5, y), dx
            elif dx < 0 and x <= d.x:
                probe, out = (d.x - .5, y), -dx
            elif dy > 0 and y >= d.y2 - 1:
                probe, out = (x, d.y2 + .5), dy
            elif dy < 0 and y <= d.y:
                probe, out = (x, d.y - .5), -dy
        if probe is None or not self.phone.contains(*probe) or self._display_at(*probe) is not None:
            if d is None or not (x <= d.x or x >= d.x2 - 1 or y <= d.y or y >= d.y2 - 1):
                self._push = 0.0  # away from every edge: start counting again
            return False
        self._push += out
        if self._push < self.resistance:
            return False
        self._push = 0.0
        self.px = min(max((probe[0] - self.phone.x) / self.sx, 0.0), self.pw - 1)
        self.py = min(max((probe[1] - self.phone.y) / self.sy, 0.0), self.ph - 1)
        return True

    # ------------------------------------------------------------------ on the phone

    def move(self, dx: float, dy: float) -> tuple[str, float, float]:
        """Move the phone pointer by a Mac delta. Returns ("move", nx, ny) with 0..1 phone
        coordinates, or ("leave", mac_x, mac_y) when it went out where a display touches."""
        px, py = self.px + dx / self.sx, self.py + dy / self.sy
        if not (0 <= px < self.pw and 0 <= py < self.ph):
            gx, gy = self.phone.x + px * self.sx, self.phone.y + py * self.sy
            d = self._display_at(gx, gy)
            if d is not None:
                self.px, self.py = min(max(px, 0.0), self.pw - 1), min(max(py, 0.0), self.ph - 1)
                return ("leave", min(max(gx, d.x + 2), d.x2 - 3), min(max(gy, d.y + 2), d.y2 - 3))
        self.px = min(max(px, 0.0), self.pw - 1)
        self.py = min(max(py, 0.0), self.ph - 1)
        return ("move", self.px / self.pw, self.py / self.ph)

    def return_point(self) -> tuple[float, float]:
        """For Esc / disconnect: the nearest spot on a display touching the phone."""
        gx, gy = self.phone.x + self.px * self.sx, self.phone.y + self.py * self.sy
        best = None
        for d in self.displays:
            cx, cy = min(max(gx, d.x + 2), d.x2 - 3), min(max(gy, d.y + 2), d.y2 - 3)
            dist = (cx - gx) ** 2 + (cy - gy) ** 2
            if best is None or dist < best[0]:
                best = (dist, cx, cy)
        return (best[1], best[2]) if best else (gx, gy)

    def normalized(self) -> tuple[float, float]:
        return self.px / self.pw, self.py / self.ph
