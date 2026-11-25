"""Bambu Lab printers over the local (LAN) MQTT broker every printer runs.

Connection: MQTT 3.1.1 over TLS to <host>:8883, username "bblp", password = the printer's
LAN access code. We subscribe to `device/<serial>/report` and, on every (re)connect, publish
a `pushall` to `device/<serial>/request` so a full status arrives straight away.

TLS verification is disabled on purpose: the printer's broker presents a certificate
signed by Bambu Lab's own private CA, issued for the printer's serial rather than its IP,
so neither the system trust store nor hostname checks can validate it. The link never
leaves the LAN and the access code is still required; this is the same trade-off Bambu
Studio, OrcaSlicer and Home Assistant's integration make.

paho-mqtt runs its own network thread (`loop_start`); its callbacks only hand work to the
asyncio loop via `call_soon_threadsafe`, so all state is touched on one thread.
"""
from __future__ import annotations

import asyncio
import json
import logging
import secrets
import ssl
import time
from typing import Any, Callable

from ...config import BambuCfg
from ...hub import ActionError
from ...protocol import PrinterData
from .bambu_parse import merge_report, model_from_serial, to_printer_data
from .base import PrinterBackend

__all__ = ["BambuBackend", "merge_report", "to_printer_data", "PUSHALL"]

log = logging.getLogger(__name__)

PORT = 8883
USERNAME = "bblp"
PUSHALL = {"pushing": {"sequence_id": "0", "command": "pushall"}}
# CONNACK codes meaning "credentials rejected": MQTT 3.1.1 (4, 5) and paho 2's
# MQTT 5-style ReasonCode equivalents (134 bad user name or password, 135 not authorized).
_AUTH_FAIL = {4, 5, 134, 135}


def _rc_value(rc: Any) -> int:
    v = getattr(rc, "value", rc)
    try:
        return int(v)
    except (TypeError, ValueError):
        return -1


def _rc_failed(rc: Any) -> bool:
    if hasattr(rc, "is_failure"):
        return bool(rc.is_failure)
    return _rc_value(rc) != 0


def paho_client(access_code: str) -> Any:
    """A configured paho-mqtt 2.x client (callback API v2). Imported lazily so the agent
    still starts — and reports a clear error — if the dependency is missing."""
    import paho.mqtt.client as mqtt
    from paho.mqtt.enums import CallbackAPIVersion

    client = mqtt.Client(
        callback_api_version=CallbackAPIVersion.VERSION2,
        client_id=f"deskpanel-{secrets.token_hex(4)}",  # unique: never kick Studio/Handy off
        protocol=mqtt.MQTTv311,
    )
    client.username_pw_set(USERNAME, access_code)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE  # see module docstring: self-signed, LAN-only
    client.tls_set_context(ctx)
    client.reconnect_delay_set(min_delay=1, max_delay=60)  # exponential backoff
    return client


class BambuBackend(PrinterBackend):
    kind = "bambu"

    def __init__(
        self,
        cfg: BambuCfg,
        *,
        clock: Callable[[], float] = time.monotonic,
        client_factory: Callable[[str], Any] | None = None,
    ) -> None:
        super().__init__()
        self.cfg = cfg
        self.clock = clock
        self.client_factory = client_factory or paho_client
        self.address = cfg.host or ""
        self.state: dict = {}
        self.client: Any = None
        self._loop: asyncio.AbstractEventLoop | None = None
        self._notify: Callable[[], None] = lambda: None
        serial = (cfg.serial or "").strip()
        self.report_topic = f"device/{serial}/report"
        self.request_topic = f"device/{serial}/request"

    # ---------------------------------------------------------------- config

    def missing_settings(self) -> list[str]:
        return [k for k in ("host", "serial", "access_code") if not (getattr(self.cfg, k) or "").strip()]

    def setup_hint(self) -> str:
        missing = ", ".join(f"bambu.{k}" for k in self.missing_settings())
        return (
            "Add your Bambu printer to ~/.deskpanel/config.toml under [bambu]: host (the "
            "printer's IP address), serial (its serial number) and access_code (the LAN "
            "access code). All three are on the printer's screen under Settings. "
            f"Missing: {missing}. Restart the agent afterwards."
        )

    # ---------------------------------------------------------------- lifecycle

    async def start(self, notify: Callable[[], None]) -> None:
        self._loop = asyncio.get_running_loop()
        self._notify = notify
        try:
            client = self.client_factory(self.cfg.access_code.strip())
        except ImportError:
            self.error = "The paho-mqtt package isn't installed in the agent's environment."
            log.error("bambu: %s", self.error)
            notify()
            return
        client.on_connect = self._on_connect
        client.on_disconnect = self._on_disconnect
        client.on_message = self._on_message
        client.on_connect_fail = self._on_connect_fail
        self.client = client
        client.connect_async(self.cfg.host.strip(), PORT, keepalive=60)
        client.loop_start()
        log.info("bambu: connecting to %s:%d", self.cfg.host, PORT)

    async def stop(self) -> None:
        c, self.client = self.client, None
        if c is None:
            return
        try:
            c.disconnect()
        finally:
            await asyncio.to_thread(c.loop_stop)
        self.connected = False

    async def refresh(self) -> None:
        if self.client is None or not self.connected:
            raise ActionError("failed", "The printer isn't connected right now.")
        info = self.client.publish(self.request_topic, json.dumps(PUSHALL))
        if _rc_value(getattr(info, "rc", 0)) != 0:
            raise ActionError("failed", "Couldn't send the refresh request to the printer.")

    def snapshot(self) -> PrinterData | None:
        if self.last_report_at is None:
            return None
        return to_printer_data(self.state, self.cfg.name, model_from_serial(self.cfg.serial))

    # ---------------------------------------------------------------- paho thread → loop

    def _post(self, fn: Callable, *args: Any) -> None:
        loop = self._loop
        if loop is not None and not loop.is_closed():
            loop.call_soon_threadsafe(fn, *args)

    def _on_connect(self, client, userdata, flags, reason_code, properties=None) -> None:
        if _rc_failed(reason_code):
            self._post(self._set_link, False, _rc_value(reason_code), str(reason_code))
            return
        client.subscribe(self.report_topic)
        client.publish(self.request_topic, json.dumps(PUSHALL))
        self._post(self._set_link, True, 0, "")

    def _on_disconnect(self, client, userdata, flags, reason_code, properties=None) -> None:
        self._post(self._set_link, False, None, str(reason_code))

    def _on_connect_fail(self, client, userdata) -> None:
        self._post(self._set_link, False, None, "connection failed")

    def _on_message(self, client, userdata, msg) -> None:
        self._post(self.handle_payload, msg.payload)

    # ---------------------------------------------------------------- loop side

    def _set_link(self, up: bool, rc: int | None, why: str) -> None:
        was = self.connected
        self.connected = up
        if up:
            self.error = None
            log.info("bambu: connected")
        elif rc in _AUTH_FAIL:
            self.error = ("The printer rejected the access code. Check bambu.access_code against "
                          "the code on the printer's screen; it changes whenever LAN Only Mode "
                          "is toggled.")
            log.warning("bambu: authentication failed (%s)", why)
        elif was:
            log.info("bambu: disconnected (%s); reconnecting", why)
        self._notify()

    def handle_payload(self, payload: bytes | str) -> None:
        try:
            msg = json.loads(payload)
        except (ValueError, UnicodeDecodeError):
            log.debug("bambu: ignoring non-JSON payload")
            return
        if not isinstance(msg, dict):
            return
        self.state = merge_report(self.state, msg)
        if isinstance(msg.get("print"), dict) and self.state:
            self.last_report_at = self.clock()
        self._notify()
