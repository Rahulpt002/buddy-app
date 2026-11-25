"""macOS menu-bar icon (pystray). The menu bar must own the main thread, so the agent's
asyncio server runs in a background thread and the two talk through `TrayState`."""
from __future__ import annotations

import subprocess
import threading
from dataclasses import dataclass, field

from .config import home_dir


@dataclass
class TrayState:
    clients: int = 0
    transport: str = ""
    quit: threading.Event = field(default_factory=threading.Event)


STATE = TrayState()


def _icon_image(connected: bool):
    from PIL import Image, ImageDraw

    # Template-style monitor glyph; green dot when a phone is connected.
    im = Image.new("RGBA", (44, 44), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((5, 7, 39, 31), radius=4, outline=(0, 0, 0, 255), width=3)
    d.line((22, 31, 22, 37), fill=(0, 0, 0, 255), width=3)
    d.line((14, 38, 30, 38), fill=(0, 0, 0, 255), width=3)
    if connected:
        d.ellipse((28, 0, 43, 15), fill=(46, 204, 113, 255))
    return im


def run_tray(on_quit) -> None:
    import pystray

    def status_text(_item) -> str:
        n = STATE.clients
        return "No phone connected" if n == 0 else f"Phone connected{f' ({n})' if n > 1 else ''}"

    def show_qr(_icon, _item) -> None:
        png = home_dir() / "pair.png"
        if png.exists():
            subprocess.run(["open", str(png)], check=False)

    def open_path(name: str):
        return lambda _i, _it: subprocess.run(["open", "-t" if name.endswith(".toml") else "-R",
                                               str(home_dir() / name)], check=False)

    def quit_(icon, _item) -> None:
        STATE.quit.set()
        on_quit()
        icon.stop()

    menu = pystray.Menu(
        pystray.MenuItem(status_text, None, enabled=False),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Show pairing QR code", show_qr),
        pystray.MenuItem("Edit settings (config.toml)", open_path("config.toml")),
        pystray.MenuItem("Show log in Finder", open_path("agent.log")),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Quit DeskPanel agent", quit_),
    )
    icon = pystray.Icon("deskpanel", _icon_image(False), "DeskPanel", menu)

    def on_main(fn) -> None:
        # AppKit crashes (SIGTRAP) if UI is touched off the main thread.
        try:
            from Foundation import NSOperationQueue

            NSOperationQueue.mainQueue().addOperationWithBlock_(fn)
        except Exception:  # noqa: BLE001 - non-macOS backends are thread-safe enough
            fn()

    def refresh() -> None:
        last = None
        while not STATE.quit.wait(2):
            now = STATE.clients > 0
            changed, last = now != last, now

            def apply(connected=now, changed=changed) -> None:
                if changed:
                    icon.icon = _icon_image(connected)
                icon.update_menu()

            on_main(apply)

    threading.Thread(target=refresh, daemon=True).start()
    icon.run()
