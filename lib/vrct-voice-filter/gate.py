#!/usr/bin/env python3
"""Loudness gate for VRCT: s16le mono 16 kHz on stdin -> stdout.

VRChat quiets voices with distance, so "within radius" is approximated as
"louder than threshold". Quiet (far) audio is replaced with silence, so
VRCT's own energy threshold never fires on it. The threshold is re-read
from a state file every second, so radius changes apply live.
"""
import array, math, sys, time
from collections import deque

RATE = 16000
FRAME = RATE // 50           # 20 ms
HOLD_FRAMES = 20             # keep open 400 ms after speech drops below
PREROLL_FRAMES = 5           # 100 ms before opening, so word onsets survive
thr_file = sys.argv[1]
meter = len(sys.argv) > 2 and sys.argv[2] == "--meter"

def read_thr():
    try:
        return float(open(thr_file).read())
    except (OSError, ValueError):
        return 0.0

inp, out = sys.stdin.buffer, sys.stdout.buffer
silence = bytes(FRAME * 2)
pre = deque(maxlen=PREROLL_FRAMES)
thr, thr_at, hold = read_thr(), time.monotonic(), 0
peak, peak_at = 0.0, time.monotonic()
while True:
    buf = inp.read(FRAME * 2)
    if len(buf) < FRAME * 2:
        break
    a = array.array("h", buf)
    rms = math.sqrt(sum(x * x for x in a) / FRAME)
    now = time.monotonic()
    if meter:
        peak = max(peak, rms)
        if now - peak_at >= 0.25:
            bar = "#" * min(60, int(peak / 50))
            sys.stderr.write(f"\r{peak:7.0f} {bar:<60}")
            sys.stderr.flush()
            peak, peak_at = 0.0, now
        continue
    if now - thr_at >= 1:
        thr, thr_at = read_thr(), now
    if rms >= thr:
        if hold == 0:
            for f in pre:
                out.write(f)
            pre.clear()
        hold = HOLD_FRAMES
    if hold > 0:
        hold -= 1
        out.write(buf)
    else:
        pre.append(buf)
        out.write(silence)
    out.flush()
