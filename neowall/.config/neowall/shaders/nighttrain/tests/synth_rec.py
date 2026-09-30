#!/usr/bin/env python3
# synth_rec.py: writes a recording the way nighttrain.py would print it, but
# made up, without running anything: for testing the shader on a chosen
# stretch of line, in chosen weather, with commands at exact times.
#
#   python3 tests/synth_rec.py OUT.rec [--tile N] [--offset M] [--line L]
#       [--weather RAIN] [--secs S] [--night] [--at "T CMD ARGS" ...]
#
# Commands (T in seconds):
#   arrive METRES [MAIN[|SUB]] [idle]   announce a station METRES ahead
#   depart                              leave it
#   tunnel METRES LINE                  a tunnel ahead, changing to LINE inside
#   weather CLEAR|CLOUDY|RAIN|HEAVY     (as the program's WEATHER_LOOK)
#   wipe X Y                            a left press at a cell (a drag: several)
#   sleep / wake                        the "sleeping soon" flag; stop / restart the heartbeat
#   sync TILE OFFSET                    a resync
# The heartbeat changes every 0.4 s unless asleep.
import argparse, struct

LOOK = {"CLEAR": (0, 30, 30), "CLOUDY": (0, 70, 170), "RAIN": (120, 190, 225), "HEAVY": (230, 255, 250)}
ESC = "\x1b"

def cell(col, bg, fg):
    bg = [int(v) & 255 for v in bg]; fg = [int(v) & 255 for v in fg]
    return (f"{ESC}[1;{col + 1}H{ESC}[0m{ESC}[38;2;{fg[0]};{fg[1]};{fg[2]}m"
            f"{ESC}[48;2;{bg[0]};{bg[1]};{bg[2]}m {ESC}[0m")

def text(row, s):
    col = max(0, (24 - len(s)) // 2)
    return f"{ESC}[{row + 1};1H{ESC}[0m{ESC}[2K{ESC}[{row + 1};{col + 1}H{s}"

def bump(n):
    return n % 255 + 1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--tile", type=int, default=1000)
    ap.add_argument("--offset", type=int, default=0)
    ap.add_argument("--line", type=int, default=0)
    ap.add_argument("--weather", default="CLEAR")
    ap.add_argument("--wind", type=int, default=60)
    ap.add_argument("--secs", type=float, default=10.0)
    ap.add_argument("--night", action="store_true", help="force night")
    ap.add_argument("--at", action="append", default=[])
    a = ap.parse_args()

    st = dict(beat=0, arrive=0, depart=0, tunnel=0, wipe=0, sync=1, stop_in=0, kind=0, flags=2 if a.night else 0,
              line=a.line, weather=a.weather, asleep=False, tunnel_len=0)
    def beat():
        return cell(0, (st["beat"], 78, 84), (1, st["flags"], 0))
    def station():
        return cell(2, (st["arrive"], st["stop_in"] // 8, st["kind"]), (st["depart"], 0, 0))
    def env():
        r, c, cl = LOOK[st["weather"]]
        return cell(4, (r, c, a.wind), (cl, st["line"], 0))
    def sync(tile, off):
        return cell(1, (tile >> 16, tile >> 8, tile), (off >> 8, off, st["sync"]))

    chunks = []
    setup = (f"{ESC}[?1049h{ESC}[?25l{ESC}[?7l{ESC}[?1002h{ESC}[?1006h{ESC}[0m{ESC}[2J"
             + beat() + sync(a.tile, a.offset) + station() + cell(3, (0, 0, st["line"]), (0, 0, 0)) + env()
             + cell(5, (0, 0, 0), (0, 0, 0)) + f"{ESC}[5;1Hsynthetic recording (tests/synth_rec.py)")
    chunks.append((0.05, setup))
    events = []
    for spec in a.at:
        t, rest = spec.split(None, 1)
        events.append((float(t), rest.split(None)))
    events.sort(key=lambda e: e[0])
    t, ei = 0.45, 0
    while t < a.secs:
        out = ""
        while ei < len(events) and events[ei][0] <= t:
            _, w = events[ei]; ei += 1
            cmd = w[0]
            if cmd == "arrive":
                st["stop_in"] = int(w[1]); st["arrive"] = bump(st["arrive"])
                label = " ".join(x for x in w[2:] if x != "idle") or "STATION|"
                main_, _, sub = label.partition("|")
                st["kind"] = 1 if "idle" in w else 0
                out += text(1, main_) + text(2, sub) + station()
            elif cmd == "depart":
                st["depart"] = bump(st["depart"]); out += station()
            elif cmd == "tunnel":
                st["tunnel"] = bump(st["tunnel"]); st["line"] = int(w[2]) % 4
                out += cell(3, (st["tunnel"], int(w[1]) // 16, st["line"]), (0, 0, 0)) + env()
            elif cmd == "weather":
                st["weather"] = w[1]; out += env()
            elif cmd == "wipe":
                x, y = int(w[1]), int(w[2]); st["wipe"] = bump(st["wipe"])
                out += cell(5, (x & 255, y & 255, (x >> 8) | ((y >> 8) << 4)), (st["wipe"], 0, 0))
            elif cmd == "sleep":
                st["flags"] |= 1; out += beat()
            elif cmd == "asleep":
                st["asleep"] = True
            elif cmd == "wake":
                st["asleep"] = False; st["flags"] &= ~1; out += beat()
            elif cmd == "sync":
                st["sync"] = bump(st["sync"]); out += sync(int(w[1]), int(w[2]))
        if not st["asleep"]:
            st["beat"] = (st["beat"] + 1) & 255
            out += beat()
        if out:
            chunks.append((t, out))
        t = round(t + 0.1, 3) if any(e[0] > t and e[0] < t + 0.4 for e in events[ei:ei + 1]) else round(t + 0.4, 3)
    with open(a.out, "wb") as f:
        f.write(f"NTREC 1 160 45\n".encode())
        for t, s in chunks:
            b = s.encode()
            f.write(struct.pack("<dI", t, len(b)) + b)
    print(f"{a.out}: {len(chunks)} chunks over {a.secs} s")

main()
