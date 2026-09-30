#!/usr/bin/env bash
# build.sh: builds the offline test tools for neowall terminal-mode shaders.
#
#   NW=/path/to/neowall-src ./build.sh
#
# NW is a checkout of neowall 0.7.1's source. Without one, this clones it:
#   git clone https://github.com/1ay1/neowall "$NW" && git -C "$NW" checkout fd79109
#
# The tools (all land in ./bin):
#   binding_check SHADER   neowall's own parser plus its channel-binding guess,
#                          copied verbatim from shader_multipass.c. Prints what
#                          each pass would read. Buffer A must say ch0=Self.
#   cellcheck STREAM       feeds a byte stream through neowall's own terminal
#                          emulator (screen.c, vtparse.c) and prints what lands
#                          in the first header cells and the text rows.
#   harness_term SHADER    renders a terminal-mode shader offscreen through
#                          neowall's real preamble, with fake terminal textures
#                          and a scripted session (play() in it is termtest's),
#                          or -R: a recording from tests/drive_nt.py replayed
#                          through neowall's own emulator and glyph atlas.
#                          -w -h size, -s "t,t,..." frames to save, -o dir,
#                          -T timing; the header comment in it lists the rest.
#   drive.py PROGRAM DIR   (python, no build) runs a program in a 160x45 pty
#                          the way neowall does, sends it scripted mouse/key
#                          bytes, and saves what it prints after each step.
#
# nw_strings.h and nw_wrap.inc are copied from neowall 0.7.1 (MIT licence,
# Copyright (c) 2025 NeoWall Contributors): its shader preamble and its
# wrap_pass_source(). stub/ holds minimal stand-ins for neowall headers.
set -euo pipefail
cd "$(dirname "$0")"
NW=${NW:-$PWD/neowall-src}
if [[ ! -d $NW/src/shader ]]; then
    git clone https://github.com/1ay1/neowall "$NW"
    git -C "$NW" checkout fd79109
fi
# the heuristic's body, lines 785-939 of shader_multipass.c at 0.7.1: check
# the first line is where we think it is before trusting the cut
if ! sed -n 785p "$NW/src/shader/shader_multipass.c" | grep -q 'const char \*src = pass->source;'; then
    echo "shader_multipass.c isn't neowall 0.7.1's: find the channel heuristic's lines again" >&2
    exit 1
fi
sed -n 785,939p "$NW/src/shader/shader_multipass.c" > heuristic_body.inc
mkdir -p bin
gcc -O1 -w -Istub -I"$NW/src/shader" -o bin/binding_check binding_check.c "$NW/src/shader/multipass_parse.c"
gcc -O1 -w -I"$NW/include" -I"$NW/src/terminal" -o bin/cellcheck cellcheck.c \
    "$NW/src/terminal/screen.c" "$NW/src/terminal/vtparse.c"
# the harness links neowall's own terminal emulator and glyph atlas too, so a
# recorded session replays through exactly what neowall would run (-R)
gcc -O2 -w -Istub -I. -I"$NW/include" -I"$NW/src/shader" -I"$NW/src/terminal" $(pkg-config --cflags fontconfig) \
    -o bin/harness_term harness_term.c \
    "$NW/src/shader/multipass_parse.c" "$NW/src/shader/glsl_shadow.c" "$NW/src/shader/shadertoy_compat.c" \
    "$NW/src/terminal/screen.c" "$NW/src/terminal/vtparse.c" "$NW/src/terminal/glyph_atlas.c" \
    "$NW/src/terminal/glyph_synth.c" "$NW/src/terminal/cbdt.c" \
    -lEGL -lGL -lpng -lfontconfig -lm
echo "built: $(ls bin | tr '\n' ' ')"
