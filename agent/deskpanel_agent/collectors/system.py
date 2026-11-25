"""`system` topic at 1 Hz: CPU, GPU, RAM, disk, throughput, 60 s history."""
from __future__ import annotations

import asyncio
import os
import platform
import time
from collections import deque

import psutil

from ..protocol import Cpu, Disk, Gpu, NetRate, Ram, SysHistory, SystemData
from .base import BaseProvider, run_cmd
from .gpu import GpuBackend, pick_gpu


def net_totals() -> tuple[int, int]:
    """(bytes_recv, bytes_sent) summed over non-loopback interfaces."""
    rx = tx = 0
    for name, c in psutil.net_io_counters(pernic=True).items():
        if name.startswith(("lo", "utun", "awdl", "llw", "bridge", "anpi", "ap")):
            continue
        rx += c.bytes_recv
        tx += c.bytes_sent
    return rx, tx


def data_disk() -> str:
    # On macOS "/" is the sealed read-only system volume; user data lives here.
    return "/System/Volumes/Data" if os.path.isdir("/System/Volumes/Data") else "/"


class SystemCollector(BaseProvider):
    topics = ("system",)

    def __init__(self, gpu: GpuBackend | None = None) -> None:
        super().__init__()
        self.gpu = gpu
        self.cpu_hist: deque[float] = deque(maxlen=60)
        self.gpu_hist: deque[float | None] = deque(maxlen=60)
        self.down_hist: deque[float] = deque(maxlen=60)
        self.up_hist: deque[float] = deque(maxlen=60)

    async def setup(self) -> None:
        self.gpu = self.gpu or pick_gpu()
        self.cpu_model = await self._cpu_model()
        self.cores = psutil.cpu_count(logical=False)
        self.threads = psutil.cpu_count(logical=True)
        psutil.cpu_percent(None)  # prime
        self._net = net_totals()
        self._t = time.monotonic()
        self._disk = psutil.disk_usage(data_disk()).percent
        self._disk_at = time.monotonic()

    async def _cpu_model(self) -> str:
        if platform.system() == "Darwin":
            rc, out = await run_cmd("sysctl", "-n", "machdep.cpu.brand_string")
            if rc == 0 and out.strip():
                return out.strip()
        return platform.processor() or platform.machine()

    async def run(self) -> None:
        while True:
            await asyncio.sleep(1)
            self.publish("system", await self.sample())

    async def sample(self) -> SystemData:
        now = time.monotonic()
        cpu = psutil.cpu_percent(None)
        vm = psutil.virtual_memory()
        rx, tx = net_totals()
        dt = max(now - self._t, 1e-3)
        down = max(0, rx - self._net[0]) / dt
        up = max(0, tx - self._net[1]) / dt
        self._net, self._t = (rx, tx), now
        if now - self._disk_at > 30:
            self._disk = psutil.disk_usage(data_disk()).percent
            self._disk_at = now
        g = await self.gpu.sample()
        self.cpu_hist.append(round(cpu, 1))
        self.gpu_hist.append(round(g.pct, 1) if g.pct is not None else None)
        self.down_hist.append(round(down))
        self.up_hist.append(round(up))
        return SystemData(
            cpu=Cpu(pct=round(cpu, 1), model=self.cpu_model, cores=self.cores, threads=self.threads),
            gpu=Gpu(available=g.available, pct=g.pct, temp_c=g.temp_c, model=g.model,
                    vram_used=g.vram_used, vram_total=g.vram_total, vram_label=g.vram_label),
            ram=Ram(used=vm.total - vm.available, total=vm.total),
            disk=Disk(pct=round(self._disk, 1)),
            net=NetRate(down_bps=down, up_bps=up),
            history=SysHistory(cpu=list(self.cpu_hist), gpu=list(self.gpu_hist),
                               down=list(self.down_hist), up=list(self.up_hist)),
        )
