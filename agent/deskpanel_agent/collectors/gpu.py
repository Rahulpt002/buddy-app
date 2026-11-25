"""GPU backends behind one interface. Apple Silicon (ioreg, no sudo), NVIDIA (NVML), none."""
from __future__ import annotations

import logging
import platform
import re
from dataclasses import dataclass

import psutil

from .base import run_cmd

log = logging.getLogger(__name__)


@dataclass
class GpuSample:
    available: bool
    pct: float | None = None
    temp_c: float | None = None
    model: str | None = None
    vram_used: int | None = None
    vram_total: int | None = None
    vram_label: str = "VRAM"


class GpuBackend:
    async def sample(self) -> GpuSample:
        return GpuSample(available=False)


class AppleGpu(GpuBackend):
    """Apple Silicon: IOAccelerator PerformanceStatistics. Memory is unified, so 'GPU MEM'
    is GPU-resident memory out of total RAM. Temperature needs private SMC APIs: not shown."""

    _util = re.compile(r'"Device Utilization %"=(\d+)')
    _mem = re.compile(r'"In use system memory"=(\d+)')
    _model = re.compile(r'"model" = "([^"]+)"')

    def __init__(self) -> None:
        self.model: str | None = None
        self.total = psutil.virtual_memory().total

    async def sample(self) -> GpuSample:
        rc, out = await run_cmd("ioreg", "-r", "-d", "1", "-w", "0", "-c", "IOAccelerator", timeout=3)
        if rc != 0:
            return GpuSample(available=False)
        u, m = self._util.search(out), self._mem.search(out)
        if self.model is None and (mm := self._model.search(out)):
            self.model = mm.group(1)
        return GpuSample(
            available=u is not None,
            pct=float(u.group(1)) if u else None,
            model=self.model,
            vram_used=int(m.group(1)) if m else None,
            vram_total=self.total,
            vram_label="GPU MEM",
        )


class NvmlGpu(GpuBackend):
    def __init__(self) -> None:
        import pynvml  # type: ignore

        pynvml.nvmlInit()
        self.nv = pynvml
        self.h = pynvml.nvmlDeviceGetHandleByIndex(0)
        name = pynvml.nvmlDeviceGetName(self.h)
        self.model = (name.decode() if isinstance(name, bytes) else name).replace("NVIDIA ", "")

    async def sample(self) -> GpuSample:
        nv = self.nv
        util = nv.nvmlDeviceGetUtilizationRates(self.h)
        mem = nv.nvmlDeviceGetMemoryInfo(self.h)
        temp = nv.nvmlDeviceGetTemperature(self.h, nv.NVML_TEMPERATURE_GPU)
        return GpuSample(True, float(util.gpu), float(temp), self.model, int(mem.used), int(mem.total))


def pick_gpu() -> GpuBackend:
    if platform.system() == "Darwin" and platform.machine() == "arm64":
        return AppleGpu()
    try:
        return NvmlGpu()
    except Exception:  # noqa: BLE001 - no NVIDIA / no pynvml
        log.info("No supported GPU backend; GPU shows N/A")
        return GpuBackend()
