#!/usr/bin/env python3
"""Print VRChat's earmuff hearing radius in meters (radius + falloff), or nothing if earmuffs are off.

Reads VRChat's PlayerPrefs from its Wine registry. Wine saves the registry
every ~30 s, so changes made in-game arrive with that delay.
"""
import re, struct, sys
from pathlib import Path

REG = Path.home() / ".local/share/Steam/steamapps/compatdata/438100/pfx/user.reg"


def pref(text, name):  # "VRC_EARMUFF_MODE_RADIUS_h123"=hex(4):00,..  (little-endian double) or =dword:1
    m = re.search(rf'^"{name}_h\d+"=(?:dword:(\w+)|hex\(4\):([\w,]+))$', text, re.M)
    if not m:
        return None
    dword, double = m.groups()
    return int(dword, 16) if dword else struct.unpack("<d", bytes.fromhex(double.replace(",", "")))[0]


text = REG.read_text(errors="replace")
if pref(text, "VRC_EARMUFF_MODE") == 1:
    print(round(pref(text, "VRC_EARMUFF_MODE_RADIUS") + (pref(text, "VRC_EARMUFF_MODE_FALLOFF") or 0), 2))
