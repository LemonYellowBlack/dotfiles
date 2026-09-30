#!/usr/bin/env bash
# termtest.sh: the program half of the neowall terminal-mode test. neowall
# runs it in a hidden terminal (see termtest.vibe), and termtest.glsl reads
# what it prints. Nothing it prints is meant to be read by you: the top row
# is a strip of data cells, each carrying three exact bytes as its
# background colour, and the shader turns those into pictures.
#
#   cell 0  heartbeat: (beat, 78, 87). 78 and 87 spell "NW", a marker that
#           says this script is the one running. beat changes every 0.4 s,
#           because neowall stops drawing 0.7 s after the terminal's last
#           change
#   cell 1  a fixed test pattern, (12, 200, 7): if the shader reads exactly
#           that, colours arrive exact
#   cell 2  the last click: background (column & 255, row & 255, the two's
#           high bits), foreground (count, button, 0). The count runs 1..255
#           and round again, so 0 means "no click yet"
#   cell 3  the scene: (0 or 1, 0, 0)
#   cell 4  (hue, clears, 0): the ripple colour, and a count that asks the
#           shader to calm the water
#
# What it listens for. neowall sends clicks as xterm mouse reports, once
# this script turns mouse reporting on:
#   left click or drag   a ripple in that cell
#   right click          switch scene
#   middle click         calm the water
#   scroll wheel         change the ripple colour
#   keys, once you've clicked the wallpaper: 1 and 2 pick a scene, r rain

set -u

# Errors go to a log, not the screen: this terminal is what the shader
# reads, so a stray error message would be painted into the data cells.
exec 2>>"${XDG_RUNTIME_DIR:-/tmp}/neowall-termtest.log"

ESC=$'\033'

# neowall sizes the terminal to fit the screen: 160 x 45 with 48 px cells
read -r ROWS COLS < <(stty size 2>/dev/null || echo "45 160")

# Raw: every byte arrives as it's typed, and nothing is echoed back into the
# grid. Then: the alternate screen, no cursor, no autowrap (writing the last
# column would otherwise scroll everything up a row), and mouse reports for
# clicks and drags (1002), in the SGR format (1006): ESC [ < b ; x ; y M.
stty raw -echo
printf '%s' "${ESC}[?1049h${ESC}[?25l${ESC}[?7l${ESC}[?1002h${ESC}[?1006h${ESC}[0m${ESC}[2J"
cleanup() { printf '%s' "${ESC}[?1006l${ESC}[?1002l${ESC}[?7h${ESC}[?25h${ESC}[?1049l"; stty sane; }
trap cleanup EXIT
trap 'exit 0' HUP TERM INT

# cell COL ROW  R G B  [FR FG FB]: one data cell (columns and rows from 0),
# its background (R, G, B) and optionally its foreground (FR, FG, FB). It
# prints a space: a space still stores both colours.
cell() {
    local fg=""
    (( $# >= 8 )) && fg="${ESC}[38;2;$6;$7;$8m"
    printf '%s' "${ESC}[$(( $2 + 1 ));$(( $1 + 1 ))H${ESC}[0m${fg}${ESC}[48;2;$3;$4;$5m ${ESC}[0m"
}

beat=0 scene=0 hue=0 clears=0 clicks=0 rain=0
last_x=- last_y=- last_b=-

# The lines you see in scene 2, the raw terminal
status() {
    printf '%s' "${ESC}[0m"
    printf '%s' "${ESC}[3;3H${ESC}[2Kneowall terminal test: grid ${COLS} x ${ROWS}, scene $(( scene + 1 )), hue $hue, rain $rain"
    printf '%s' "${ESC}[4;3H${ESC}[2Kclicks $clicks, the last in column $last_x, row $last_y (button $last_b)"
    printf '%s' "${ESC}[6;3H${ESC}[2Kleft click or drag: ripple   right click: scene   middle click: calm   wheel: colour"
    printf '%s' "${ESC}[7;3H${ESC}[2Kkeys, once you've clicked the wallpaper: 1 and 2 pick a scene, r rain"
}

# drop X Y B: tell the shader about a click (or a raindrop) in column X, row
# Y, made by button B
drop() {
    clicks=$(( clicks % 255 + 1 ))
    last_x=$1 last_y=$2 last_b=$3
    cell 2 0 $(( $1 & 255 )) $(( $2 & 255 )) $(( ($1 >> 8) | (($2 >> 8) << 4) )) "$clicks" "$3" 0
    status
}

set_scene() { scene=$1; cell 3 0 "$scene" 0 0; status; }
set_mode()  { cell 4 0 "$hue" "$clears" 0; status; }

# One mouse report: button, column, row (from 0), and M (pressed) or m (let go)
mouse() {
    [[ $4 == m ]] && return                           # let go: nothing to do
    case $1 in
        0|32) drop "$2" "$3" 0 ;;                     # left press, or a left drag (32 = moving)
        1)    clears=$(( (clears + 1) % 256 )); set_mode ;;
        2)    set_scene $(( 1 - scene )) ;;
        64)   hue=$(( (hue + 16) % 256 )); set_mode ;;    # wheel up
        65)   hue=$(( (hue + 240) % 256 )); set_mode ;;   # wheel down
    esac
}

# The heartbeat, every 0.4 s (and a raindrop with it, when it's raining).
# EPOCHREALTIME is the time in seconds with microseconds: with everything
# but its digits stripped, it's whole microseconds.
next_beat=0
beat_if_due() {
    local now=${EPOCHREALTIME//[!0-9]/}
    (( now < next_beat )) && return
    next_beat=$(( now + 400000 ))
    beat=$(( (beat + 1) % 256 ))
    cell 0 0 "$beat" 78 87
    (( rain )) && drop $(( RANDOM % COLS )) $(( 1 + RANDOM % (ROWS - 1) )) 3
}

cell 1 0 12 200 7
cell 2 0 0 0 0 0 0 0
set_scene 0
set_mode

while :; do
    beat_if_due
    # wait up to 0.1 s for a byte, then go round again to keep the beat
    IFS= read -rsn1 -t 0.1 ch || continue
    if [[ $ch == "$ESC" ]]; then
        IFS= read -rsn1 -t 0.05 ch || continue
        [[ $ch == "[" ]] || continue
        IFS= read -rsn1 -t 0.05 ch || continue
        [[ $ch == "<" ]] || continue                  # arrows and other keys' escapes: ignored
        seq=""
        while IFS= read -rsn1 -t 0.05 ch; do
            [[ $ch == [Mm] ]] && break
            seq+=$ch
        done
        # seq is "button;column;row", counting columns and rows from 1
        b=${seq%%;*} rest=${seq#*;}
        x=${rest%%;*} y=${rest#*;}
        [[ $b =~ ^[0-9]+$ && $x =~ ^[0-9]+$ && $y =~ ^[0-9]+$ && $ch == [Mm] ]] || continue
        mouse "$b" $(( x - 1 )) $(( y - 1 )) "$ch"
        continue
    fi
    # Anything else typed at the wallpaper is ignored: only these do something
    case $ch in
        1) set_scene 0 ;;
        2) set_scene 1 ;;
        r) rain=$(( 1 - rain )); status ;;
    esac
done
