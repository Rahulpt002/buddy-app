"""CPU temperature on Apple Silicon Macs, without root.

The SoC's thermal sensors are HID "services" (usage page 0xFF00, usage 5) that any user
process can read through IOKit's IOHIDEventSystemClient: the same interface menu-bar
monitors use. The die sensors are named "PMU tdie<n>" (and "PMU2 tdie<n>" on chips with a
second PMU); the CPU temperature is their average. Intel Macs keep temperatures in the SMC
instead, which this doesn't read: `cpu_c()` returns None there (and on any failure).

The API is undocumented but has been stable since the M1; every call is guarded.
"""
from __future__ import annotations

import ctypes
import ctypes.util
import logging
import platform
from ctypes import c_bool, c_char_p, c_double, c_int32, c_int64, c_uint32, c_void_p

log = logging.getLogger(__name__)

_TEMPERATURE = 15  # kIOHIDEventTypeTemperature
_UTF8 = 0x08000100


def mean_die_temp(readings: list[tuple[str, float | None]]) -> float | None:
    """Average of the plausible "PMU… tdie…" readings (pure; testable)."""
    vals = [t for name, t in readings
            if t is not None and "tdie" in name and name.startswith("PMU") and 5 < t < 130]
    return round(sum(vals) / len(vals), 1) if vals else None


class MacTemps:
    def __init__(self) -> None:
        self._ok = platform.system() == "Darwin" and platform.machine() == "arm64"
        self._services: list[tuple[str, int]] = []  # (name, service pointer)
        self._keep: list = []  # CF objects that must stay alive
        if self._ok:
            try:
                self._open()
            except Exception:  # noqa: BLE001
                log.info("CPU temperature not available on this Mac", exc_info=True)
                self._ok = False

    def _open(self) -> None:
        iokit = ctypes.cdll.LoadLibrary(ctypes.util.find_library("IOKit"))
        cf = ctypes.cdll.LoadLibrary(ctypes.util.find_library("CoreFoundation"))
        for f, r, a in [
            (iokit.IOHIDEventSystemClientCreate, c_void_p, [c_void_p]),
            (iokit.IOHIDEventSystemClientSetMatching, c_int32, [c_void_p, c_void_p]),
            (iokit.IOHIDEventSystemClientCopyServices, c_void_p, [c_void_p]),
            (iokit.IOHIDServiceClientCopyProperty, c_void_p, [c_void_p, c_void_p]),
            (iokit.IOHIDServiceClientCopyEvent, c_void_p, [c_void_p, c_int64, c_int32, c_int64]),
            (iokit.IOHIDEventGetFloatValue, c_double, [c_void_p, c_int32]),
            (cf.CFArrayGetCount, c_int64, [c_void_p]),
            (cf.CFArrayGetValueAtIndex, c_void_p, [c_void_p, c_int64]),
            (cf.CFStringCreateWithCString, c_void_p, [c_void_p, c_char_p, c_uint32]),
            (cf.CFStringGetCString, c_bool, [c_void_p, c_char_p, c_int64, c_uint32]),
            (cf.CFNumberCreate, c_void_p, [c_void_p, c_int32, c_void_p]),
            (cf.CFDictionaryCreate, c_void_p, [c_void_p, c_void_p, c_void_p, c_int64, c_void_p, c_void_p]),
            (cf.CFRelease, None, [c_void_p]),
        ]:
            f.restype, f.argtypes = r, a
        self._iokit, self._cf = iokit, cf

        def s(txt: str) -> int:
            return cf.CFStringCreateWithCString(None, txt.encode(), _UTF8)

        def n(v: int) -> int:
            x = c_int32(v)
            return cf.CFNumberCreate(None, 3, ctypes.byref(x))  # kCFNumberSInt32Type

        keys = (c_void_p * 2)(s("PrimaryUsagePage"), s("PrimaryUsage"))
        vals = (c_void_p * 2)(n(0xFF00), n(5))
        kcb = c_void_p.in_dll(cf, "kCFTypeDictionaryKeyCallBacks")
        vcb = c_void_p.in_dll(cf, "kCFTypeDictionaryValueCallBacks")
        match = cf.CFDictionaryCreate(None, keys, vals, 2, ctypes.addressof(kcb), ctypes.addressof(vcb))
        client = iokit.IOHIDEventSystemClientCreate(None)
        if not client:
            raise OSError("no HID event system client")
        iokit.IOHIDEventSystemClientSetMatching(client, match)
        services = iokit.IOHIDEventSystemClientCopyServices(client)
        if not services:
            raise OSError("no thermal sensors")
        self._keep = [client, services, match]
        product, buf = s("Product"), ctypes.create_string_buffer(128)
        for i in range(cf.CFArrayGetCount(services)):
            svc = cf.CFArrayGetValueAtIndex(services, i)
            name = iokit.IOHIDServiceClientCopyProperty(svc, product)
            label = buf.value.decode() if name and cf.CFStringGetCString(name, buf, 128, _UTF8) else ""
            if name:
                cf.CFRelease(name)
            if label.startswith("PMU") and "tdie" in label:
                self._services.append((label, svc))
        if not self._services:
            raise OSError("no die sensors")
        log.info("CPU temperature: %d die sensors", len(self._services))

    def cpu_c(self) -> float | None:
        if not self._ok:
            return None
        try:
            readings = []
            for name, svc in self._services:
                ev = self._iokit.IOHIDServiceClientCopyEvent(svc, _TEMPERATURE, 0, 0)
                if not ev:
                    continue
                readings.append((name, self._iokit.IOHIDEventGetFloatValue(ev, _TEMPERATURE << 16)))
                self._cf.CFRelease(ev)
            return mean_die_temp(readings)
        except Exception:  # noqa: BLE001
            self._ok = False
            log.info("CPU temperature read failed; stopping", exc_info=True)
            return None
