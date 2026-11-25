"""SQLite persistence: daily network usage, speed-test history, small key/value state."""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
import threading
from pathlib import Path
from typing import Any

from .config import home_dir

_SCHEMA = """
CREATE TABLE IF NOT EXISTS net_usage (day TEXT PRIMARY KEY, rx INTEGER NOT NULL DEFAULT 0, tx INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS speedtests (at INTEGER PRIMARY KEY, down_bps REAL, up_bps REAL, ping_ms REAL);
CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT NOT NULL);
"""


class Store:
    """Tiny synchronous store; calls are fast (local SQLite) so they run inline."""

    def __init__(self, path: Path | None = None):
        self.path = path or home_dir() / "deskpanel.db"
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._db = sqlite3.connect(self.path, check_same_thread=False, isolation_level=None)
        self._db.execute("PRAGMA journal_mode=WAL")
        self._db.executescript(_SCHEMA)
        self._lock = threading.Lock()

    # ---------------------------------------------------------------- net usage

    def add_usage(self, rx: int, tx: int, day: dt.date | None = None) -> None:
        d = (day or dt.date.today()).isoformat()
        with self._lock:
            self._db.execute(
                "INSERT INTO net_usage(day, rx, tx) VALUES(?,?,?) "
                "ON CONFLICT(day) DO UPDATE SET rx = rx + excluded.rx, tx = tx + excluded.tx",
                (d, rx, tx),
            )

    def usage_day(self, day: dt.date | None = None) -> int:
        d = (day or dt.date.today()).isoformat()
        row = self._db.execute("SELECT rx + tx FROM net_usage WHERE day = ?", (d,)).fetchone()
        return int(row[0]) if row else 0

    def usage_month(self, day: dt.date | None = None) -> int:
        d = day or dt.date.today()
        row = self._db.execute(
            "SELECT COALESCE(SUM(rx + tx), 0) FROM net_usage WHERE day LIKE ?", (f"{d:%Y-%m}-%",)
        ).fetchone()
        return int(row[0])

    # ---------------------------------------------------------------- speed tests

    def add_speedtest(self, at_ms: int, down_bps: float, up_bps: float, ping_ms: float) -> None:
        with self._lock:
            self._db.execute("INSERT OR REPLACE INTO speedtests VALUES(?,?,?,?)", (at_ms, down_bps, up_bps, ping_ms))

    def last_speedtest(self) -> dict | None:
        row = self._db.execute(
            "SELECT at, down_bps, up_bps, ping_ms FROM speedtests ORDER BY at DESC LIMIT 1"
        ).fetchone()
        return None if row is None else {"at": row[0], "down_bps": row[1], "up_bps": row[2], "ping_ms": row[3]}

    # ---------------------------------------------------------------- kv

    def get(self, k: str, default: Any = None) -> Any:
        row = self._db.execute("SELECT v FROM kv WHERE k = ?", (k,)).fetchone()
        return default if row is None else json.loads(row[0])

    def set(self, k: str, v: Any) -> None:
        with self._lock:
            self._db.execute("INSERT OR REPLACE INTO kv VALUES(?,?)", (k, json.dumps(v)))

    def close(self) -> None:
        self._db.close()
