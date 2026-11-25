"""Pure parsing of Bambu Lab MQTT status reports (no I/O, no paho).

Reports arrive on `device/<serial>/report` as JSON. Status lives in a `print` object with
`"command": "push_status"`. A `pushall` request returns the full object; between those the
printer may send partial deltas (P1/A1 always do; X1 firmware mostly sends full objects but
not reliably, so we always deep-merge). `merge_report` folds each report into a persistent
state dict and `to_printer_data` turns that state into the protocol's `PrinterData`.

Field reference: https://github.com/Doridian/OpenBambuAPI/blob/main/mqtt.md
"""
from __future__ import annotations

import copy
from typing import Any

from ...protocol import AmsSlot, PrinterData, PrinterJob, PrinterTemps

# gcode_state -> protocol state. Anything unknown is treated as idle.
STATES = {
    "IDLE": "idle",
    "INIT": "idle",
    "OFFLINE": "offline",
    "PREPARE": "printing",   # heating / bed levelling before the first layer
    "SLICING": "printing",   # cloud slicing a job that is about to start
    "RUNNING": "printing",
    "PAUSE": "paused",
    "FINISH": "finished",
    "FAILED": "error",
}

SPEEDS = {1: "silent", 2: "standard", 3: "sport", 4: "ludicrous"}

# print_error value the printer reports when the user cancels a job (gcode_state FAILED).
# A cancel is not a fault, so it shows as idle rather than error.
PRINT_CANCELLED = 0x0300400C

TRAY_EXTERNAL = 254  # tray_now: external spool holder ("vt_tray")
TRAY_NONE = 255      # tray_now: nothing loaded

HMS_SEVERITY = {1: "fatal", 2: "serious", 3: "common", 4: "info"}
HMS_WIKI = "https://wiki.bambulab.com/en/x1/troubleshooting/hmscode/"


# ------------------------------------------------------------------ merge


def _is_id_list(v: Any) -> bool:
    return isinstance(v, list) and bool(v) and all(isinstance(x, dict) and "id" in x for x in v)


def _merge(old: Any, new: Any) -> Any:
    if isinstance(old, dict) and isinstance(new, dict):
        out = dict(old)
        for k, v in new.items():
            out[k] = _merge(old.get(k), v)
        return out
    if _is_id_list(new) and (old is None or _is_id_list(old) or old == []):
        return _merge_by_id(old or [], new)
    return copy.deepcopy(new)


def _merge_by_id(old: list[dict], new: list[dict]) -> list[dict]:
    """Merge lists of {"id": ...} objects (AMS units, trays) element-wise by id.

    An element that carries *only* its id means "this slot is now empty" (that is how
    the printer reports an unloaded AMS tray), so it replaces the old element instead of
    merging into it — otherwise a removed spool's type/colour would linger forever."""
    out = [dict(x) for x in old]
    index = {str(x["id"]): i for i, x in enumerate(out)}
    for item in new:
        key = str(item["id"])
        if key in index:
            i = index[key]
            out[i] = copy.deepcopy(item) if len(item) == 1 else _merge(out[i], item)
        else:
            index[key] = len(out)
            out.append(copy.deepcopy(item))
    return out


def merge_report(state: dict, msg: dict) -> dict:
    """Return a new state with the report's `print` status deep-merged in.

    Messages without a `print` status object (version info, command acks such as
    `gcode_line` results, `system` replies) leave the state unchanged. `state` is not
    mutated."""
    p = msg.get("print") if isinstance(msg, dict) else None
    if not isinstance(p, dict):
        return state
    cmd = p.get("command")
    if cmd not in (None, "push_status"):
        return state
    return _merge(state, p)


# ------------------------------------------------------------------ conversion helpers


def _num(v: Any) -> float | None:
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    return f


def _int(v: Any) -> int | None:
    f = _num(v)
    return int(f) if f is not None else None


def _temp(v: Any) -> float | None:
    f = _num(v)
    return round(f, 1) if f is not None else None


def tray_color(v: Any) -> str | None:
    """"RRGGBBAA" (or "RRGGBB") hex -> "#RRGGBB". Fully transparent / invalid -> None."""
    if not isinstance(v, str):
        return None
    s = v.strip().lstrip("#")
    if len(s) not in (6, 8):
        return None
    try:
        int(s, 16)
    except ValueError:
        return None
    if len(s) == 8 and s[6:].upper() == "00":
        return None  # "00000000" is what the printer sends for an empty tray
    return "#" + s[:6].upper()


def speed_name(v: Any) -> str | None:
    return SPEEDS.get(_int(v) or 0)


def map_state(gcode_state: Any, print_error: int = 0) -> str:
    s = str(gcode_state or "").upper()
    state = STATES.get(s, "idle")
    if state == "error" and print_error == PRINT_CANCELLED:
        return "idle"
    return state


def hms_code(entry: dict) -> str | None:
    """{"attr": int, "code": int} -> "AAAA_AAAA_CCCC_CCCC" (the Bambu wiki's format)."""
    attr, code = _int(entry.get("attr")), _int(entry.get("code"))
    if attr is None or code is None:
        return None
    return f"{attr >> 16:04X}_{attr & 0xFFFF:04X}_{code >> 16:04X}_{code & 0xFFFF:04X}"


def print_error_code(v: int) -> str:
    return f"{v >> 16:04X}_{v & 0xFFFF:04X}"


def error_text(state: dict) -> str | None:
    """A short human string from `print_error` and the HMS list, or None when healthy.

    Informational HMS entries (severity 4) are ignored; the most severe one is shown."""
    parts: list[str] = []
    pe = _int(state.get("print_error")) or 0
    if pe and pe != PRINT_CANCELLED:
        parts.append(f"Print error {print_error_code(pe)}")
    hms = [h for h in state.get("hms") or [] if isinstance(h, dict)]
    ranked = []
    for h in hms:
        code = hms_code(h)
        if code is None:
            continue
        sev = (_int(h.get("code")) or 0) >> 16
        if sev == 4:
            continue
        ranked.append((sev if sev in HMS_SEVERITY else 9, code))
    ranked.sort()
    if ranked:
        sev, code = ranked[0]
        label = HMS_SEVERITY.get(sev)
        txt = f"HMS {code}" + (f" ({label})" if label else "")
        if len(ranked) > 1:
            txt += f" +{len(ranked) - 1} more"
        parts.append(txt)
    return " · ".join(parts) or None


def model_from_serial(serial: str | None) -> str | None:
    """Bambu documents that X1 Carbon serial numbers start with "00M"."""
    if serial and serial.upper().startswith("00M"):
        return "X1C"
    return None


# ------------------------------------------------------------------ AMS


def _slot_index(ams_id: int, tray_id: int) -> int:
    # Standard AMS units hold 4 trays: global index = ams_id * 4 + tray_id (as tray_now).
    # Single-tray units (AMS HT) use ids >= 128 and are addressed by their own id.
    return ams_id if ams_id >= 128 else ams_id * 4 + tray_id


def _bits(v: Any) -> int | None:
    if v is None or v == "":
        return None
    try:
        return int(str(v), 16)
    except ValueError:
        return None


def _slot(slot: int, tray: dict, active: bool, present: bool = True) -> AmsSlot:
    ttype = tray.get("tray_type") or None
    if not present or not ttype:
        return AmsSlot(slot=slot, type=None, color=None, name=None, active=active)
    return AmsSlot(slot=slot, type=ttype, color=tray_color(tray.get("tray_color")),
                   name=tray.get("tray_sub_brands") or None, active=active)


def ams_slots(state: dict) -> list[AmsSlot]:
    ams = state.get("ams") if isinstance(state.get("ams"), dict) else {}
    now = _int(ams.get("tray_now"))
    unit_bits = _bits(ams.get("ams_exist_bits"))
    tray_bits = _bits(ams.get("tray_exist_bits"))
    slots: list[AmsSlot] = []
    for unit in ams.get("ams") or []:
        uid = _int(unit.get("id"))
        if uid is None:
            continue
        if unit_bits is not None and uid < 128 and not unit_bits >> uid & 1:
            continue  # unit no longer connected
        for tray in unit.get("tray") or []:
            tid = _int(tray.get("id"))
            if tid is None:
                continue
            idx = _slot_index(uid, tid)
            present = tray_bits is None or idx >= 128 or bool(tray_bits >> idx & 1)
            slots.append(_slot(idx, tray, active=(idx == now), present=present))
    slots.sort(key=lambda s: s.slot)
    # The external spool holder: shown when it's the one feeding, or when there's no AMS.
    vt = state.get("vt_tray")
    if isinstance(vt, dict) and (now == TRAY_EXTERNAL or (not slots and vt.get("tray_type"))):
        ext = _slot(TRAY_EXTERNAL, vt, active=(now == TRAY_EXTERNAL))
        if ext.name is None and ext.type:
            ext.name = "External spool"
        slots.append(ext)
    return slots


# ------------------------------------------------------------------ PrinterData


def to_printer_data(state: dict, name: str, model: str | None = None) -> PrinterData:
    pe = _int(state.get("print_error")) or 0
    st = map_state(state.get("gcode_state"), pe)
    err = error_text(state)
    job = None
    if st != "idle":
        total = _int(state.get("total_layer_num"))
        remaining = _int(state.get("mc_remaining_time"))
        if st == "finished":
            remaining = 0
        job = PrinterJob(
            name=state.get("subtask_name") or None,
            progress_pct=_num(state.get("mc_percent")) or 0.0,
            remaining_min=remaining,
            layer=_int(state.get("layer_num")),
            total_layers=total if total else None,
            speed=speed_name(state.get("spd_lvl")),
        )
    return PrinterData(
        kind="bambu",
        name=name,
        model=model,
        state=st,
        job=job,
        temps=PrinterTemps(
            nozzle=_temp(state.get("nozzle_temper")),
            nozzle_target=_temp(state.get("nozzle_target_temper")),
            bed=_temp(state.get("bed_temper")),
            bed_target=_temp(state.get("bed_target_temper")),
            chamber=_temp(state.get("chamber_temper")),
        ),
        ams=ams_slots(state),
        error=err,
    )
