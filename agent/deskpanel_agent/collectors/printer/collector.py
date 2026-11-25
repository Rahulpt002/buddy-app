"""`printer` topic: drives one PrinterBackend, decides online/offline, publishes on change
(at most once per `min_interval`), and handles `printer.refresh`."""
from __future__ import annotations

import asyncio
import logging
import time
from typing import Any, Callable

from ...config import BambuCfg
from ...hub import ActionError, Progress
from ...protocol import PrinterData
from ..base import BaseProvider
from .bambu import BambuBackend
from .base import PrinterBackend

log = logging.getLogger(__name__)

OFFLINE_AFTER = 60.0  # seconds without a report before the printer counts as offline


class PrinterCollector(BaseProvider):
    topics = ("printer",)

    def __init__(
        self,
        cfg: BambuCfg | None = None,
        *,
        backend: PrinterBackend | None = None,
        clock: Callable[[], float] = time.monotonic,
        offline_after: float = OFFLINE_AFTER,
        min_interval: float = 1.0,
    ) -> None:
        super().__init__()
        cfg = cfg or BambuCfg()
        self.name = cfg.name
        self.clock = clock
        self.backend = backend or BambuBackend(cfg, clock=clock)
        self.offline_after = offline_after
        self.min_interval = min_interval
        self.actions = {"printer.refresh": self.refresh}
        self._dirty = asyncio.Event()
        self._started_at: float | None = None
        self._last: Any = None

    @property
    def configured(self) -> bool:
        return not self.backend.missing_settings()

    # ---------------------------------------------------------------- lifecycle

    async def setup(self) -> None:
        if not self.configured:
            self.publish("printer", {"status": "unconfigured", "message": self.backend.setup_hint()})
            return
        self._started_at = self.clock()
        await self.backend.start(self._dirty.set)
        self.publish_if_changed()

    async def run(self) -> None:
        if not self.configured:
            return
        while True:
            try:
                # Wake on new data, or every second anyway so staleness is noticed.
                await asyncio.wait_for(self._dirty.wait(), timeout=1.0)
            except asyncio.TimeoutError:
                pass
            self._dirty.clear()
            self.publish_if_changed()
            await asyncio.sleep(self.min_interval)

    async def stop(self) -> None:
        await super().stop()
        try:
            await self.backend.stop()
        except Exception:  # noqa: BLE001
            log.exception("printer backend stop failed")

    # ---------------------------------------------------------------- snapshot

    def online(self) -> bool:
        b = self.backend
        return (b.connected and b.last_report_at is not None
                and self.clock() - b.last_report_at <= self.offline_after)

    def snapshot(self) -> PrinterData | dict:
        b = self.backend
        if not self.configured:
            return {"status": "unconfigured", "message": b.setup_hint()}
        data = b.snapshot()
        where = f" at {b.address}" if b.address else ""
        if data is None:  # nothing heard yet
            if b.error:
                return {"status": "error", "message": b.error}
            waited = self.clock() - (self._started_at if self._started_at is not None else self.clock())
            if waited < self.offline_after:
                return {"status": "starting", "message": f"Connecting to {self.name}{where}…"}
            return PrinterData(
                name=self.name, state="offline",
                message=f"Can't reach {self.name}{where}. Check it's powered on and on the same network.",
            )
        if self.online():
            return data
        # Keep the last known values, but show the printer as offline.
        data.state = "offline"
        if b.error:
            data.status = "error"
            data.message = b.error
        elif not b.connected:
            data.message = f"Lost connection to {self.name}{where}; reconnecting…"
        else:
            data.message = f"No status from {self.name} for over {int(self.offline_after)} s."
        return data

    def publish_if_changed(self) -> None:
        snap = self.snapshot()
        dump = snap.model_dump(mode="json") if isinstance(snap, PrinterData) else snap
        if dump != self._last:
            self._last = dump
            self.publish("printer", dump)

    # ---------------------------------------------------------------- actions

    async def refresh(self, params: dict, progress: Progress) -> dict:
        if not self.configured:
            raise ActionError("unconfigured", self.backend.setup_hint())
        await self.backend.refresh()
        return {}
