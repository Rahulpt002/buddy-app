"""Printer backend interface. `PrinterCollector` drives one backend; Bambu is the first,
OctoPrint / Moonraker can be added later by implementing the same small surface."""
from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Callable

from ...protocol import PrinterData


class PrinterBackend(ABC):
    """A connection to one printer.

    Contract:
    - `start(notify)` begins connecting (non-blocking; the backend reconnects by itself)
      and calls `notify()` on the asyncio loop whenever its data or connection changed.
    - `connected` / `last_report_at` / `error` describe link health. `last_report_at` uses
      the same clock the collector was given (monotonic seconds), None before any report.
    - `snapshot()` is the last known printer data (None before the first report). The
      collector, not the backend, decides when that data is stale and shows it offline.
    """

    kind: str = "unknown"
    #: shown in "can't reach …" messages, e.g. the printer's IP
    address: str = ""

    def __init__(self) -> None:
        self.connected = False
        self.last_report_at: float | None = None
        self.error: str | None = None  # connection-level problem worth showing (bad credentials …)

    def missing_settings(self) -> list[str]:
        """Names of required settings that are not configured (empty when ready)."""
        return []

    def setup_hint(self) -> str:
        """Explains how to configure the backend; used with status "unconfigured"."""
        return "This printer isn't configured."

    @abstractmethod
    async def start(self, notify: Callable[[], None]) -> None: ...

    @abstractmethod
    async def stop(self) -> None: ...

    @abstractmethod
    async def refresh(self) -> None:
        """Ask the printer for a full status now. Raise hub.ActionError on failure."""

    @abstractmethod
    def snapshot(self) -> PrinterData | None: ...
