"""deskpanel-agent command line."""
from __future__ import annotations

import argparse
import asyncio
import logging
import signal
import subprocess
import sys

from . import __version__
from .config import home_dir, load_config
from .pairing import ensure_cert, load_identity, pair_uri, print_qr, save_qr_png

log = logging.getLogger("deskpanel")


def _show_pairing(port: int, tls: bool, open_png: bool) -> None:
    ident = load_identity()
    fp = ensure_cert(ident.agent_id)[2] if tls else None
    uri = pair_uri(ident, port, fp)
    print("\nScan this with the DeskPanel app (Settings → Pair with laptop):\n")
    print_qr(uri)
    png = save_qr_png(uri)
    print(f"QR image: {png}")
    if open_png and sys.platform == "darwin":
        subprocess.run(["open", str(png)], check=False)


async def _serve(args: argparse.Namespace, holder: dict | None = None) -> None:
    import uvicorn

    from .adb import AdbReverse
    from .discovery import Advertiser
    from .hub import Hub
    from .server import create_app

    cfg = load_config()
    port = args.port or cfg.server.port
    tls = cfg.server.tls and not args.no_tls
    ident = load_identity()
    cert = key = None
    if tls:
        cert, key, fp = ensure_cert(ident.agent_id)
        log.info("TLS on (cert sha256 %s…)", fp[:16])

    hub = Hub()
    if args.mock:
        from .mock import MockProvider

        hub.add_provider(MockProvider())
        log.info("MOCK MODE: emitting fake data for every topic")
    else:
        from .providers import build_providers

        for p in build_providers(cfg):
            hub.add_provider(p)
    await hub.start()

    app = create_app(hub, ident, tls)
    server = uvicorn.Server(uvicorn.Config(
        app, host=cfg.server.bind, port=port, log_level="warning",
        ssl_certfile=str(cert) if cert else None, ssl_keyfile=str(key) if key else None,
        ws_ping_interval=None,  # app-level ping/pong handles liveness
    ))
    server.install_signal_handlers = lambda: None  # we handle signals below

    extras = []
    if cfg.server.mdns:
        extras.append(Advertiser(ident.agent_id, port, tls))
    if cfg.server.adb_reverse:
        extras.append(AdbReverse(port, cfg.server.adb_path))
    for e in extras:
        try:
            await e.start()
        except Exception:  # noqa: BLE001
            log.exception("failed to start %s", type(e).__name__)

    if args.qr:
        _show_pairing(port, tls, open_png=False)
    log.info("DeskPanel agent %s listening on %s://%s:%d", __version__, "wss" if tls else "ws",
             cfg.server.bind, port)

    loop = asyncio.get_running_loop()
    if holder is not None:  # --tray: the menu bar (main thread) stops us through these
        holder.update(server=server, loop=loop)
    else:
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, lambda: setattr(server, "should_exit", True))
    if getattr(args, "tray", False) or getattr(args, "write_qr", False):
        # Keep the pairing image ready for "Show pairing QR code" (tray or a host app's menu).
        ident = load_identity()
        save_qr_png(pair_uri(ident, port, ensure_cert(ident.agent_id)[2] if tls else None))
    if getattr(args, "tray", False):
        from .tray import STATE

        async def count_clients() -> None:
            while True:
                STATE.clients = len(hub.clients)
                await asyncio.sleep(2)

        asyncio.create_task(count_clients())
    try:
        await server.serve()
    finally:
        for e in extras:
            await e.stop()
        await hub.stop()


def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser(prog="deskpanel-agent", description="DeskPanel laptop agent")
    ap.add_argument("--version", action="version", version=__version__)
    ap.add_argument("-v", "--verbose", action="store_true")
    sub = ap.add_subparsers(dest="cmd")

    run = sub.add_parser("run", help="run the agent (default)")
    for p in (ap, run):
        p.add_argument("--mock", action="store_true", help="emit fake data for every topic")
        p.add_argument("--port", type=int, default=None)
        p.add_argument("--no-tls", action="store_true", help="plain ws:// (debugging only)")
        p.add_argument("--qr", action="store_true", help="print the pairing QR on start")
        p.add_argument("--tray", action="store_true", help="show a menu-bar icon (macOS)")
        p.add_argument("--write-qr", action="store_true", help="keep ~/.deskpanel/pair.png current")

    ist = sub.add_parser("install-startup", help="start the agent at login, with a menu-bar icon")
    ist.add_argument("--no-tray", action="store_true", help="no menu-bar icon")
    sub.add_parser("uninstall-startup", help="stop starting the agent at login")
    isl = sub.add_parser("install-statusline", help="share Claude plan limits via Claude Code's statusLine")
    isl.add_argument("--yes", action="store_true", help="don't ask for confirmation")
    sub.add_parser("uninstall-statusline", help="remove the statusLine bridge (restores your previous one)")

    hl = sub.add_parser("hotspot-login", help="sign in to your Hotspot Monitor Server (for the Hotspot page)")
    hl.add_argument("--server", default=None, help="https:// address of the Server")

    pair = sub.add_parser("pair", help="show the pairing QR code")
    pair.add_argument("--reset", action="store_true", help="rotate the token (all phones must re-pair)")
    pair.add_argument("--open", action="store_true", help="open the QR image in Preview")

    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s", datefmt="%H:%M:%S")
    for noisy in ("httpx", "httpcore"):
        logging.getLogger(noisy).setLevel(logging.WARNING)

    if args.cmd == "install-startup":
        from .startup import install as install_startup

        raise SystemExit(install_startup(tray=not args.no_tray))
    if args.cmd == "uninstall-startup":
        from .startup import uninstall as uninstall_startup

        raise SystemExit(uninstall_startup())
    if args.cmd == "install-statusline":
        from .statusline_install import install

        raise SystemExit(install(args.yes))
    if args.cmd == "uninstall-statusline":
        from .statusline_install import uninstall

        raise SystemExit(uninstall())

    if args.cmd == "hotspot-login":
        from .hotspot_login import login

        raise SystemExit(login(args.server))

    if args.cmd == "pair":
        if args.reset:
            load_identity(reset_token=True)
            print("Token rotated. Previously paired phones must scan the new code.")
        cfg = load_config()
        _show_pairing(cfg.server.port, cfg.server.tls, args.open)
        print(f"\nConfig and pairing data live in {home_dir()}")
        return

    if args.tray:
        import threading

        from .tray import run_tray

        holder: dict = {}
        t = threading.Thread(target=lambda: asyncio.run(_serve(args, holder)), name="agent", daemon=True)
        t.start()

        def stop() -> None:
            srv, loop = holder.get("server"), holder.get("loop")
            if srv and loop:
                loop.call_soon_threadsafe(setattr, srv, "should_exit", True)

        run_tray(stop)  # blocks on the main thread until Quit
        t.join(timeout=8)
        return

    try:
        asyncio.run(_serve(args))
    except KeyboardInterrupt:
        pass
