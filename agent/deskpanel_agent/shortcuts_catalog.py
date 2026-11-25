"""Built-in shortcut tiles. Platform backends implement the behaviour; the phone only
ever sends one of these ids (or a custom id from config)."""
from __future__ import annotations

from .protocol import Tile

BUILTIN_TILES: list[Tile] = [
    Tile(id="mic.toggle", label="Mute mic", icon="mic", color="#E8A598"),
    Tile(id="sound.toggle", label="Mute sound", icon="speaker", color="#AEB6C2"),
    Tile(id="volume.down", label="Vol -", icon="vol_down", color="#AEB6C2"),
    Tile(id="volume.up", label="Vol +", icon="vol_up", color="#AEB6C2"),
    Tile(id="screenshot", label="Screenshot", icon="screenshot", color="#A8C5B5"),
    Tile(id="terminal", label="Terminal", icon="terminal", color="#AEB6C2"),
    Tile(id="downloads", label="Downloads", icon="folder", color="#D9C49A"),
    Tile(id="lock", label="Lock PC", icon="lock", color="#B9A6E0"),
]
