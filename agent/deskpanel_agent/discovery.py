"""mDNS advertisement of _deskpanel._tcp. Re-registers when LAN addresses change."""
from __future__ import annotations

import asyncio
import logging
import socket

from zeroconf import IPVersion
from zeroconf.asyncio import AsyncServiceInfo, AsyncZeroconf

from . import PROTO_VERSION
from .pairing import lan_ipv4s

log = logging.getLogger(__name__)
SERVICE = "_deskpanel._tcp.local."


class Advertiser:
    def __init__(self, agent_id: str, port: int, tls: bool):
        self.agent_id, self.port, self.tls = agent_id, port, tls
        self._zc: AsyncZeroconf | None = None
        self._info: AsyncServiceInfo | None = None
        self._ips: list[str] = []
        self._task: asyncio.Task | None = None

    def _make_info(self, ips: list[str]) -> AsyncServiceInfo:
        host = socket.gethostname().removesuffix(".local")
        return AsyncServiceInfo(
            SERVICE,
            f"DeskPanel {host}-{self.agent_id}.{SERVICE}",
            addresses=[socket.inet_aton(ip) for ip in ips],
            port=self.port,
            properties={"id": self.agent_id, "proto": str(PROTO_VERSION), "tls": "1" if self.tls else "0",
                        "name": host},
            server=f"deskpanel-{self.agent_id}.local.",
        )

    async def start(self) -> None:
        self._zc = AsyncZeroconf(ip_version=IPVersion.V4Only)
        self._task = asyncio.create_task(self._loop())

    async def _loop(self) -> None:
        while True:
            ips = lan_ipv4s()
            if ips != self._ips:
                try:
                    if self._info:
                        await self._zc.async_unregister_service(self._info)
                        self._info = None
                    if ips:
                        self._info = self._make_info(ips)
                        await self._zc.async_register_service(self._info, allow_name_change=True)
                        log.info("mDNS: advertising %s on %s:%d", SERVICE, ",".join(ips), self.port)
                    self._ips = ips
                except Exception:  # noqa: BLE001
                    log.exception("mDNS registration failed; will retry")
            await asyncio.sleep(15)

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
        if self._zc:
            if self._info:
                await self._zc.async_unregister_service(self._info)
            await self._zc.async_close()
