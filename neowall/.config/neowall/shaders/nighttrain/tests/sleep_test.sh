#!/usr/bin/env bash
# sleep_test.sh: a quiet spell and a wake-up, with short timings. After
# IDLE_AFTER the train halts ("KM n" / "HH:MM"), sets "sleeping soon", and
# its heartbeat stops. Two commits in a throwaway repo at ~24 s wake it:
# heartbeat, DEPART, then a "2 COMMITS" station after DEPART_CLEAR.
set -euo pipefail
cd "$(dirname "$0")/.."
G=$(mktemp -d /tmp/nt-git-XXXX); trap 'rm -rf "$G"' EXIT
mkdir -p "$G/proj/alpha"; git -C "$G/proj/alpha" init -q
c() { git -C "$G/proj/alpha" -c user.email=test@example.invalid -c user.name=test commit -q --allow-empty -m "$1"; }
c one
cat > "$G/sleep.txt" <<EOS
set IDLE_AFTER 6
set IDLE_MARGIN 0
set STOP_IN [96, 96]
set ARRIVE_SLACK 0
set DEPART_CLEAR 4
set DWELL 2
set GIT_ROOTS ["$G/proj"]
set GIT_EVERY 1
at 40 end
EOS
( sleep 24; c two; c three ) &
python3 tests/drive_nt.py nighttrain.py "$G/sleep.txt" tests/out/sleep.rec 2>&1 | grep -v '^temp dir'
wait
python3 tests/rec_cells.py tests/out/sleep.rec | grep -v 'H_BEAT'
