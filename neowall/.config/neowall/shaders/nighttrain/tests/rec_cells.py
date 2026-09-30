#!/usr/bin/env python3
# rec_cells.py: a recording's header-cell changes as a timeline, so the
# program's choreography can be checked by eye:
#   python3 tests/rec_cells.py out.rec [--beats]
# Each line: time, cell name, the bg and fg bytes. Heartbeats (cell 0 changing
# only its beat) are summed up rather than listed, unless --beats.
import re, struct, sys
NAMES = ["H_BEAT", "H_SYNC", "H_STATION", "H_TUNNEL", "H_ENV", "H_WIPE"]
CELL = re.compile(rb"\x1b\[1;(\d)H\x1b\[0m\x1b\[38;2;(\d+);(\d+);(\d+)m\x1b\[48;2;(\d+);(\d+);(\d+)m ")
TEXT = re.compile(rb"\x1b\[([23]);1H\x1b\[0m\x1b\[2K\x1b\[\d+;\d+H([^\x1b]*)")
data = open(sys.argv[1], "rb").read()
p = data.index(b"\n") + 1
last, beats, beat_times = {}, 0, []
while p + 12 <= len(data):
    t, n = struct.unpack("<dI", data[p:p + 12])
    chunk = data[p + 12:p + 12 + n]
    p += 12 + n
    for m in TEXT.finditer(chunk):
        print(f"{t:8.2f}  sign row {int(m[1]) - 1}: {m[2].decode()!r}")
    for m in CELL.finditer(chunk):
        c = int(m[1]) - 1
        fg, bg = tuple(map(int, m.groups()[1:4])), tuple(map(int, m.groups()[4:7]))
        if c == 0 and last.get(0) and last[0][1] == fg and "--beats" not in sys.argv:
            beats += 1; beat_times.append(t)
        else:
            print(f"{t:8.2f}  {NAMES[c]:9s} bg {bg}  fg {fg}")
        last[c] = (bg, fg)
if beat_times:
    gaps = [b - a for a, b in zip(beat_times, beat_times[1:])]
    print(f"heartbeats: {beats}, {beat_times[0]:.2f}..{beat_times[-1]:.2f} s"
          + (f", gaps {min(gaps):.2f}..{max(gaps):.2f} s" if gaps else ""))
