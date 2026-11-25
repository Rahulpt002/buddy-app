"""Watches `adb devices` and keeps `adb reverse tcp:PORT tcp:PORT` applied for every
attached phone, so the app can reach the agent at 127.0.0.1 over the USB cable."""
from __future__ import annotations

import asyncio
import logging
import os
import shutil
from pathlib import Path

log = logging.getLogger(__name__)


def find_adb(configured: str | None = None) -> str | None:
    candidates = [configured, shutil.which("adb")]
    for env in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        if os.environ.get(env):
            candidates.append(str(Path(os.environ[env]) / "platform-tools" / "adb"))
    candidates.append(str(Path.home() / "Library/Android/sdk/platform-tools/adb"))
    for c in candidates:
        if c and Path(c).is_file() and os.access(c, os.X_OK):
            return c
    return None


async def _run(*args: str, timeout: float = 5.0) -> tuple[int, str]:
    proc = await asyncio.create_subprocess_exec(
        *args, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT
    )
    try:
        out, _ = await asyncio.wait_for(proc.communicate(), timeout)
    except asyncio.TimeoutError:
        proc.kill()
        return -1, "timeout"
    return proc.returncode or 0, out.decode(errors="replace")


def parse_devices(out: str) -> dict[str, str]:
    """`adb devices` output -> {serial: state}."""
    devs: dict[str, str] = {}
    for line in out.splitlines():
        if not line.strip() or line.startswith("*") or line.startswith("List of devices"):
            continue
        parts = line.split()
        if len(parts) >= 2:
            devs[parts[0]] = parts[1]
    return devs


def is_network_serial(serial: str) -> bool:
    """Wireless-debugging devices ("192.168.0.5:37000", "adb-XYZ._adb-tls-connect._tcp").
    They get no reverse: the app already reaches the agent directly over Wi-Fi, and a
    tunnel through adb-over-Wi-Fi would be slower and mislabelled as USB."""
    return ":" in serial or "._adb-tls-connect." in serial


class AdbReverse:
    def __init__(self, port: int, adb_path: str | None = None, interval: float = 3.0):
        self.port = port
        self.adb = find_adb(adb_path)
        self.interval = interval
        self.connected: set[str] = set()  # serials with an active reverse
        self._task: asyncio.Task | None = None
        self._warned: dict[str, str] = {}

    async def start(self) -> None:
        if not self.adb:
            log.info("adb not found; USB transport disabled (install Android platform-tools)")
            return
        log.info("USB: watching for phones with %s", self.adb)
        self._task = asyncio.create_task(self._loop())

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()

    async def _loop(self) -> None:
        spec = f"tcp:{self.port}"
        while True:
            try:
                rc, out = await _run(self.adb, "devices")
                devs = parse_devices(out) if rc == 0 else {}
                for serial, state in devs.items():
                    if is_network_serial(serial):
                        continue
                    if state != "device":
                        if self._warned.get(serial) != state:
                            hint = {"unauthorized": "accept the USB debugging prompt on the phone"}.get(state, "")
                            log.warning("USB: phone %s is %s %s", serial, state, hint)
                            self._warned[serial] = state
                        continue
                    self._warned.pop(serial, None)
                    rc, lst = await _run(self.adb, "-s", serial, "reverse", "--list")
                    if rc == 0 and f"{spec} {spec}" in lst:
                        if serial not in self.connected:
                            log.info("USB: reverse already active for %s", serial)
                            self.connected.add(serial)
                        continue
                    rc, msg = await _run(self.adb, "-s", serial, "reverse", spec, spec)
                    if rc == 0:
                        log.info("USB: phone %s connected (adb reverse %s)", serial, spec)
                        self.connected.add(serial)
                    else:
                        log.warning("USB: adb reverse failed for %s: %s", serial, msg.strip())
                for gone in self.connected - {s for s, st in devs.items() if st == "device"}:
                    log.info("USB: phone %s unplugged", gone)
                    self.connected.discard(gone)
            except Exception:  # noqa: BLE001
                log.exception("adb watcher error")
            await asyncio.sleep(self.interval)
