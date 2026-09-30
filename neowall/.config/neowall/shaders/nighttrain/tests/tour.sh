#!/usr/bin/env bash
# tour.sh: short synthetic runs past each kind of thing on line 0, rendered to
# out/tour/ at 960x540 (tiles found with tests/landkinds.py). Each run starts
# a fresh Buffer A at a chosen tile, so it shows exactly what's asked for.
set -euo pipefail
cd "$(dirname "$0")/.."
T=tools/bin/harness_term; R=tests/out/tour; O=out/tour; mkdir -p "$R" "$O"
cross=$(python3 -c "
M=0xFFFFFFFF
def pcg(x):
    h=(x*747796405+2891336453)&M; h=(((h>>((h>>28)+4))^h)*277803737)&M; return (h>>22)^h
print(int(300+424*(pcg(1026^0x51ED270B)>>8)/16777216.0))")
run() {   # name, frame times, harness options, synth options...
    local name=$1 times=$2 hopt=$3; shift 3
    python3 tests/synth_rec.py "$R/$name.rec" "$@" >/dev/null
    $T nighttrain.glsl -w 960 -h 540 -R "$R/$name.rec" -s "$times" -o "$O" -p "$name" -v 0 $hopt >/dev/null 2>&1
}
run turbines 3        "-c 0.9"  --tile 1016 --secs 4
run crossing 3        "-c 0.1"  --tile 1026 --offset $((cross - 60)) --secs 4
run sea      3        "-c 0.9"  --tile 1029 --offset 400 --secs 4
run lake     3        "-c 0.9"  --tile 1002 --offset 400 --secs 4
run tiletunnel 5,9,14 "-c 0.1"  --tile 1055 --offset 100 --secs 15
run asked    7,10,20  "-c 0.1"  --tile 1003 --secs 21 --at "1 tunnel 480 2"
run rain     34       "-c 0.9"  --tile 1003 --secs 35 --weather RAIN
run beads    50       "-c 0.1"  --tile 1003 --secs 51 --weather HEAVY --at "1 arrive 200 RAIN|STOP"
run dusk     3        "-H 18.9" --tile 1003 --secs 4
run day      3        "-H 12.5" --tile 1003 --secs 4
wipes=""; for i in $(seq 0 20); do wipes="$wipes --at \"$(python3 -c "print(20 + $i * 0.05)") wipe $((40 + i * 4)) 25\""; done
eval run wipe 22,60 "\"-c 0.1\"" --tile 1003 --secs 61 --weather HEAVY $wipes
echo "frames in $O"
