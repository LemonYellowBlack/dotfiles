# Testing the night train offline

Everything here runs without neowall or the live wallpaper. Build the tools
first (`NW=<neowall-src> tools/build.sh`; it clones neowall 0.7.1 if needed).

## The program (nighttrain.py)

- `python3 -m py_compile nighttrain.py`
- `python3 tests/drive_nt.py nighttrain.py tests/scenarios/basics.txt tests/out/basics.rec`
  runs it in a 160 x 45 pty the way neowall does, acts out the scenario
  (clicks, drags, keys, inbox lines; syntax at the top of drive_nt.py) and
  records what it prints. It prints the program's log at the end.
- `python3 tests/rec_cells.py tests/out/basics.rec` lists the header cells'
  changes over time (stations, tunnels, wipes, heartbeat gaps).
- `tools/bin/cellcheck tests/out/basics.rec 12.5` shows the grid at 12.5 s,
  through neowall's own terminal emulator.

Scenarios: `basics` (heartbeat, test key, inbox text, unsafe text, a flood,
a tunnel, a wipe), `station` (one station, start to finish), `restart` (run
twice with `--state DIR` to check the journey carries on), `hypr` (with
`--keep-hypr`: follows the real workspace). `tests/sleep_test.sh` checks a
quiet spell: the idle halt, sleep, and two git commits waking it.

## The shader (nighttrain.glsl)

- `tools/bin/binding_check nighttrain.glsl` must say `Pass 0 (Buffer A): ch0=Self`.
- `tools/bin/harness_term nighttrain.glsl -R tests/out/station.rec -s 40,100 -o out -w 1920 -h 1080`
  replays a recording through neowall's emulator and glyph atlas and saves
  frames. `-t 1,2,16` prints row-0 texels every frame (position, speed,
  station), `-q x:y,...` any texels at the end, `-g` imitates neowall's idle
  gate, `-H hour`, `-c cpu`, `-D y,m,d`. The header of harness_term.c lists
  the rest.
- `python3 tests/synth_rec.py OUT.rec --tile N --at "T CMD ..."` makes up a
  recording without the program: a chosen stretch of line (find one with
  `python3 tests/landkinds.py LINE FIRST COUNT`), weather, stations,
  tunnels, wipes, sleep, at exact times. `tests/tour.sh` renders one of each
  kind of thing to out/tour/.
- Timing: `tools/bin/harness_term nighttrain.glsl -w 3840 -h 2160 -R tests/out/basics.rec -T -n 200 -v 0`
  (compare p10s; the live wallpaper running at the same time inflates means).
- SIMD: `MESA_SHADER_CACHE_DISABLE=true INTEL_DEBUG=fs tools/bin/harness_term nighttrain.glsl -w 640 -h 360 -R tests/out/basics.rec -n 2 -v 0 2>&1 | grep 'shader:'`
  must list a SIMD16 for the drawing pass.
