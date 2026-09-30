# Night train: implementation plan

## Status (2026-09-30): built

Implemented from this plan, all milestones: `nighttrain.py`,
`nighttrain.glsl`, `nighttrain.vibe`, and the offline test kit in `tests/`
(see `tests/README.md`) and `tools/` (the harness now replays recordings
through neowall's own emulator and glyph atlas, `-R`, and imitates the idle
gate, `-g`).

Checked offline:
- Program: the header protocol; the heartbeat (0.40 s gaps); stations from
  the test key, the inbox (sanitised: `rm -rf $HOME` arrives as `RM -RF
  HOME`) and git (`2 COMMITS`); a 20-line flood becomes one `20 EVENTS`;
  tunnels; wipes; the idle halt, sleep (no grid change for 7 s) and waking;
  restart continuity; and following the real Hyprland workspace.
- Shader: it stops exactly on the stop point, with the sign centred (the
  station's distance reads 0.0000), braking at 0.69 m/s². An early DEPART
  waits out the 8 s minimum dwell. There are renders of every kind of land,
  tunnels, rain moving and beaded, the mist with a wipe that fogs back over
  minutes, dusk and day, and the sleep fade.

Where it differs from the plan, and why:
- **Cost.** It measured 9.4 ms a frame at 4K on the UHD 630 (Buffer A 1.3,
  Image 8.1 p10), against the plan's 6 ms for the Image. That's level with
  orbit3d. The limit is texture reads (~0.7 ms each at 4K, measured); the
  shader's "What it costs" section has the details.
- **The per-column rows** carry flags and a packed pole position. D_ texels
  hold their positions as whole metres plus the rest: half floats step
  3-50 cm at those sizes. The glass's whole effect is worked out on its own
  grid (rows 190..369). Buffer A's layout comment in the shader is the
  reference.
- **The idle halt waits longer:** `(stopIn + 1000) / 12 + 10` s, not
  `stopIn / 12 + 10`, because the shader may move a stop past a tunnel or
  bridge. After a DEPART, the program waits `DEPART_CLEAR` = 60 s before
  the next ARRIVE, so the last station is out of sight before its sign
  text changes.
- **Git** runs `git rev-parse HEAD` as planned, one repo per tick, with
  `GIT_OPTIONAL_LOCKS=0`. Tests override settings through
  `NIGHTTRAIN_OVERRIDES` (JSON).
- **Lines** are ids 0 mixed, 1 coast, 2 hills, 3 plains. The land is
  8-tile regions of one biome each, then tile kinds weighted by biome.
- **Tunnel lamps are every 32 m** and **fence posts every 2 m**, not 24 m:
  both have to divide the poles' 64 m to stay put.
- **Not done:** the optional glass "refraction lite", the proportional
  sign font, real weather and more event sources. Clouds are only an
  overcast tint, not drifting bands.

Everything below is the plan as written.

---

Everything needed to build the night-train wallpaper, written 2026-09-29 at
the end of a long session, to be handed back to Claude after compaction.
Every design decision is made here, so implementation shouldn't need to
reopen any. Background on neowall's terminal mode, with the source-code
evidence behind every claim, is in `../termtest/terminal-mode.md`. The facts
that shape this plan are repeated in section 3.

## 0. Working agreement

- The user asked for this to be implemented. The implementing session may
  create and edit files in this folder (`nighttrain/`).
- Still **teach as you go**: explain what each piece does and why, in plain
  words, like the comments in `koi.glsl`.
- **Don't** change `~/.config/neowall/config.vibe` (the live wallpaper is koi),
  **don't** commit, and **ask before** stopping the user's neowall daemon. Live
  tests replace their wallpaper, so offer the commands (section 9) instead.
- **Ground rule:** the Kanagawa palette is used for its colours only. No
  Japanese or other Asian cultural motifs anywhere: no lanterns-as-motif,
  paper screens, calligraphy, pagoda-like buildings, or place names in any
  language. The scene is placeless: land, weather, light, and a train that
  could be anywhere.

## 1. Decisions

| question | decision (user can overrule) |
|---|---|
| landscape | one continuous line through changing country; the biome drifts every few km (forest, lakes, open plains, hills, coast). A **line** is a biome mix (mixed, coastal, hill, plains). Right-click changes line, through a tunnel |
| what makes a station | v1: (a) an **inbox** any script can write to, (b) **new git commits** in repos under `~/lyb`, (c) an **idle halt** after 20 min without an event. Later: Forgejo pushes (restricted ssh key), calendar, builds (via the inbox) |
| feel | calm. Stations only for events and idle. The rhythm comes from the land itself: towns, bridges, crossings and tunnels placed procedurally, with their density in SETTINGS |
| program language | Python 3 (3.14 installed), standard library only, one file, no build step. Go (1.27 installed) is a possible later port |
| time of day | follows the real day (`iSun`, `iTimeOfDay`, `iDate`): night is the signature, but dusk, dawn and an overcast day exist. A setting can force night |
| direction | the train moves right, so the scenery flows right to left |
| sign font | `term_font /usr/share/fonts/noto/NotoSansMono-Medium.ttf` (monospace, safe). Later upgrade: `/usr/share/fonts/TTF/MonaSansCondensed-*.ttf` with proportional layout |
| grid | `term_font_size 48`: 160 x 45 cells of 24 x 48 px, an exact fit on 3840 x 2160, so the shader's cell maths matches neowall's click mapping |
| covered screen | the program sleeps (stops the heartbeat) while the focused workspace has any window: the journey only moves while you can see it |
| weather | v1 synthetic: a slow, persisted weather process in the program (clear, cloudy, rain, heavy rain). Real weather is a possible v2 (note: a weather API learns your location) |

## 2. Architecture

```
nighttrain.py  (neowall's `terminal` command)
  reads:  mouse reports + keys on stdin, the inbox FIFO, git repos (polled),
          Hyprland's event socket, the clock
  owns:   the why and when: events queue, station schedule, idle and sleep,
          line, weather, the journey's approximate km (saved to state.json)
  writes: row 0 = header cells (protocol v1, section 4), rows 1-2 = sign
          text, rows 4+ = status text for debugging
      | neowall's pty -> iTermCells / iTermChange
      v
nighttrain.glsl  (term_shader)
  Buffer A owns the fine motion and the look's memory: the exact position
          (tile + offset), speed, braking to the exact stop point, tunnels,
          the condensation on the glass, per-column layer heights, and
          D-texels (per-frame constants) for the Image pass
  Image   draws sky, land layers, features, station and sign, the glass
          (rain, fog, reflection), then tonemap, gamma and dither
```

**Who owns what, and why.** The shader owns motion because it alone knows
exactly where the train is, every frame. The program never needs that. It
gives relative commands ("stop in 900 m", "tunnel now") and waits long
enough. The shader handles anything that arrives early (section 4). The
program owns everything that must persist or depends on the outside world.

## 3. neowall facts this depends on (all verified in 0.7.1)

- **Config** (`nighttrain.vibe`): `terminal "<cmd>"`, `term_shader <path>`,
  `term_font`, `term_font_size 48`, `term_cols 0`, `term_rows 0`, `vsync true`,
  `shader_fps 30`. `terminal` replaces `shader`. Use `~` paths (a relative path
  with `/` resolves against neowall's working directory).
- **Channel binding** (no sidecar in terminal mode): Buffer A's own `mainImage`
  must itself contain `texelFetch(iChannel0, ivec2(fragCoord), 0)`, and nothing
  after that read in that `mainImage` may contain `/256`, `/512`, `/1024` (with
  or without a space) or `*0.00` (within 60 characters of a use). Helpers above
  `mainImage` aren't scanned. Check it every time:
  `tools/bin/binding_check nighttrain.glsl` must print
  `Pass 0 (Buffer A): ch0=Self`.
- **Pass markers:** `// Buffer A: ...` directly above the first `mainImage`,
  `// Image: ...` directly above the second. No other pass name may appear
  on the 5 lines above either one.
- **Idle gate:** frames are drawn only within 700 ms of a grid change. So:
  - While awake, change the heartbeat cell every 0.4 s.
  - Stopping it is how the wallpaper sleeps (0% GPU, last frame stays).
  - Rewriting an identical value doesn't count.
  - The first frame after sleeping has `iTimeDelta` = 0.25 s: clamp `dt`.
- **Input:** `iMouse.zw` is always 0, so clicks exist only through the
  program.
  - The program enables `ESC[?1002h` (clicks and drags) and `ESC[?1006h`
    (SGR format).
  - Reports look like `ESC[<b;x;yM` (press) and `...m` (release), with x and
    y counted from 1.
  - Buttons: 0 left, 1 middle, 2 right; 32 + button while dragging; wheel
    64 and 65.
  - Hover isn't sent to the program. The shader sees it via `iMouse.xy`
    (screen px, y from the top).
  - Keys arrive only after the wallpaper is clicked.
- **Cells:** `iTermCells` (`usampler2D`, row 0 is the top row):
  - `.b` = fg `r<<24|g<<16|b<<8|0xFF`
  - `.a` = bg `r<<24|g<<16|b<<8|style`
  - `.r` = atlas x<<20 | y<<8 | flags (bit 0 glyph, bit 1 colour emoji)
  - `.g` = glyph w<<24 | h<<16 | (ox+128)<<8 | (oy+128)
  - Truecolour arrives exactly. A space keeps both colours. Never use reverse
    video (SGR 7), which swaps fg and bg.
  - `iTermChange` holds per-cell ms stamps, and `iTermFade.y` is "now" on the
    same clock.
  - `iTermInfo.zw` is the *supersampled* atlas cell size. For screen cells
    use `iResolution / iTermInfo.xy`.
- **Text:** the stdlib's `nwTermCell(cell, frac, cw, ch, cursor)` draws any
  cell anywhere. Texture units: atlas 5, cells 6, colour atlas 7, stamps 8.
- **stderr is the grid:** the program must send its stderr to a log file.
- **Reload:** `neowall reload` doesn't recompile a term_shader while the same
  command runs (`output.c:1293`). Restart neowall for shader edits. The
  offscreen harness is the fast loop.
- **Buffer A size:** don't assume 70% (the live log showed the optimizer
  line `Pass 0: unknown @ 75%`). In Buffer A use `iResolution`; in Image use
  `textureSize(iChannel0, 0)`. Keep every Buffer A region below row 1000
  and column 1000.
- **Half floats** (RGBA16F, round toward zero on this chip): integers are
  exact to 2048, fractions in [0,1) keep ~11 bits. Anything accumulating is
  kept in hi/lo parts (section 6).
- **Cost rules on the UHD 630 at 4K:**
  - ~10 instructions a pixel cost ~0.5 ms.
  - Each per-pixel `texelFetch` costs ~0.3 ms, so issue independent reads
    together.
  - Avoid per-pixel `sin`/`cos`/`pow`: use `sinCos()` from koi.glsl, and
    repeated squaring for powers.
  - Never dynamically index a local array per pixel (that alone cost 1.4 ms).
  - Gate per-pixel extras to the pixels that need them (ungated boxes cost
    1.8 ms).
  - Both passes must compile SIMD16.
- **Buffer A binding** is only to itself (ch0). The Image pass reads
  Buffer A on ch0.

## 4. Protocol v1: what the program prints, what the shader reads

The program reads the grid size at start (`os.get_terminal_size(0)`, fallback
160 x 45) and writes only cells whose value changed. The rules:
- Bytes go in the bg and fg colours.
- 16-bit values are split into a hi and a lo byte.
- A counter runs 1..255 and wraps to 1, so 0 means "none yet".
- The shader remembers the last count it saw: a different count is a new
  command, and that cell's stamp says when it came.

### Row 0: header cells

| cell | name | bg (r, g, b) | fg (r, g, b) |
|---|---|---|---|
| 0 | H_BEAT | (beat 0..255, 78, 84): 78, 84 = "NT", the marker | (protocol 1, flags, 0). flags bit 0: sleeping soon, so fade the motion out; bit 1: force night |
| 1 | H_SYNC | journey tile, 24 bits: (hi, mid, lo) | (offset metres hi byte, lo byte, sync count). Used when Buffer A is fresh, or when the sync count changes (a debug key) |
| 2 | H_STATION | (arrive count, stop-in metres / 8, kind: 0 event, 1 idle halt) | (depart count, 0, 0) |
| 3 | H_TUNNEL | (tunnel count, length / 16 m, line id to switch to at its middle) | (0, 0, 0) |
| 4 | H_ENV | (rain, condensation rate, wind), each 0..255 | (cloud 0..255, line id for a fresh start, 0) |
| 5 | H_WIPE | (x & 255, y & 255, (x >> 8) \| ((y >> 8) << 4)) | (count, button, 0) |

- **Rows 1 and 2** hold the sign's main line and sub line. The text is
  centred by the program in the first `SIGN_COLS` = 24 columns, printed in
  default colours: the shader only uses glyph coverage and recolours it. The
  program writes them in the same flush as the ARRIVE, and they stay until
  the next one.
- **Rows 4 and up** are status text. If the marker is missing, the shader
  shows the raw terminal (`nwTerm(uv)`) so errors are visible, as termtest
  does.

### Choreography

- **ARRIVE:**
  - The program writes the sign rows, then bumps the arrive count with
    `stop-in` metres. Always send 900..1400 m, which is more than the
    braking distance from top speed (34 m/s at 0.7 m/s² needs 826 m).
  - The shader sets `stopPoint = pos + stopIn`. If that lands in a
    tunnel, on a bridge, or within 200 m of either, it moves the stop
    forward to the first clear stretch.
- **DEPART:**
  - The program bumps the depart count once dwell is over: 25 s for event
    stations, or on wake for idle halts.
  - The shader ignores it until it has stopped *and* been stopped for
    `MIN_DWELL` (8 s). A DEPART that arrives early just waits.
- **Idle halt:**
  - After `IDLE_AFTER` (20 min) without an event, the program sends an
    ARRIVE of kind 1, with a sign that reads `KM 3412` and a sub line of
    `23:41`.
  - It then waits for the train to have stopped. It estimates this as
    `stopIn / 12 + 10` s, generous on purpose.
  - Then it sets the "sleeping soon" flag, waits `SLEEP_FADE` (3 s) while
    the shader eases the rain and blinking to rest, and stops the heartbeat.
- **Wake:**
  - A new event: the program restarts the heartbeat, clears the flag, and
    sends DEPART.
  - It then schedules the event's own station about 1 km later.
- **Covered:**
  - The focused workspace has windows. The program stops the heartbeat at
    once (no fade needed, nobody's looking) and pauses its own clocks.
  - When the workspace is uncovered, everything carries on.
- **Tunnel:**
  - Right-click (or key `t`): the program bumps the tunnel count with a
    length and the next line id.
  - The shader starts the tunnel 150 m ahead, and switches its landscape to
    the new line at the tunnel's middle, where nobody can see the change.
- **Wipe:**
  - Left press or left drag: the program forwards the cell to H_WIPE with a
    new count.
  - The shader clears condensation along the segment from the previous
    wipe point, if that came within 150 ms. Otherwise it clears a spot.

## 5. The program: `nighttrain.py`

One file. SETTINGS at the top, in the same commented style as the shaders.
Plain-language comments.

### Setup and teardown
- **Terminal modes:**
  - `tty.setraw(0)`
  - enter: `ESC[?1049h ESC[?25l ESC[?7l ESC[?1002h ESC[?1006h ESC[0m ESC[2J`
  - undo all of it on exit (`atexit`, plus handlers for SIGTERM, SIGHUP and
    SIGINT)
- **stderr** goes to `$XDG_RUNTIME_DIR/nighttrain/log`: make the directory
  with mode 0700, and set `sys.stderr` to the log file first thing.
- **Grid class:** keeps what every cell currently holds and queues only
  changes. `flush()` does a single `os.write` per tick.
  - Cells are written as `ESC[row;colH ESC[0m ESC[38;2;..m ESC[48;2;..m <space> ESC[0m`.
  - Text rows are written as plain text over default colours, erasing the
    row first.

### Main loop
- `selectors` over stdin, the inbox FIFO, and the Hyprland socket.
- The timeout is the time until the next scheduled action: the heartbeat
  every 0.4 s, collectors, the schedule, weather steps.

### Input (stdin)
- **Parse** SGR mouse reports.
- **Mouse:**
  - Left press, or motion with bit 32 set: H_WIPE.
  - Right press: tunnel and line change.
  - Middle: nothing.
  - Wheel: nothing yet.
- **Keys**, once the wallpaper has been clicked:
  - `s`: station now, with text `TEST|<time>`
  - `t`: tunnel
  - `r`: cycle the weather
  - `n`: toggle force night
  - `1`..`4`: pick a line
  - `k`: resync, for debugging
- **Ignore** every other byte. Never log keys.

### Event sources
- **Inbox:**
  - `os.mkfifo($XDG_RUNTIME_DIR/nighttrain/inbox, 0o600)`.
  - Open it `O_RDONLY|O_NONBLOCK`, and also keep one `O_WRONLY` fd open
    yourself, so the reader never sees EOF when writers come and go.
  - Line format: `MAIN[|SUB]`. Sanitize each part:
    - uppercase
    - keep only `A-Z 0-9 space . : / # - +`
    - collapse runs of spaces
    - cut to 24 characters
  - Rate limit: 1 queued event per 10 s. Keep at most 5 queued; past that,
    merge them into `N EVENTS`.
  - Anyone can then send a station:
    `echo "BUILD PASSED|radar" > $XDG_RUNTIME_DIR/nighttrain/inbox`
- **Git:**
  - At start and hourly, find repos: directories under `~/lyb`, up to
    depth 2, that contain `.git`.
  - Every 60 s, run `git -C <repo> rev-parse HEAD` (with a timeout) for each.
  - A change after the first scan becomes an event: `COMMIT|<repo name>`, or
    `3 COMMITS|<repo>` for several.
  - SETTINGS: a list of roots and exclude patterns.
- **Idle:** as in section 4.

### Visibility
- Connect to `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`.
- On any line starting `workspace`, `focusedmon`, `openwindow`,
  `closewindow`, `movewindow`, `changefloatingmode` or `fullscreen`, run
  `hyprctl -j activeworkspace`. Visible means `windows == 0`.
- No socket: assume visible.

### Program states
- **TRAVEL:** heartbeat on, km estimate advancing.
- **ARRIVING:** ARRIVE sent, waiting out the estimate.
- **DWELL:** stopped at an event station.
- **SLEEP_PENDING:** flag set, fading.
- **ASLEEP:** no heartbeat.
- **HIDDEN:** covered: no heartbeat, clocks paused. It overrides the others
  and restores them on uncover.

### Persistence
- File: `$XDG_STATE_HOME/nighttrain/state.json`, falling back to
  `~/.local/state`. It holds `{version, tile, offset, line, km, weather,
  last_event_at}`.
- Saved every 60 s and on exit.
- The km estimate advances at `V_NOMINAL` (25 m/s) while in TRAVEL, and
  nothing more. It's only for restart continuity and the idle halt's
  `KM` sign, so drift doesn't matter.
- On start, send H_SYNC with the saved tile and offset. The shader only
  uses it when its Buffer A is fresh, so a program restart doesn't make the
  train jump.

### Weather
- Every 10 min, a Markov step between CLEAR, CLOUDY, RAIN and HEAVY. Weights
  go in SETTINGS; the weather tends to persist.
- It sets H_ENV's rain, condensation rate (higher when raining) and cloud.

### Status rows
- Rows 4 and up show: state, queue, km, line, weather, visibility, and the
  last input kind (never its content).

### Env hygiene
- In the vibe, run it as
  `env -u SSH_AUTH_SOCK python3 ~/.config/neowall/shaders/nighttrain/nighttrain.py`.
  It needs no ssh and no network in v1.

## 6. The shader: `nighttrain.glsl`

Follow the house style (section 10). Everything tunable goes in SETTINGS.

### Units and the long-journey problem
- **Position:** world position is metres along the line, as
  `tile` (uint, 1024 m tiles) plus `offset` (0..1024).
  - A float32 can't hold a long journey smoothly: at 3.5 million m its step
    is 0.25 m, and foreground poles would jitter. So large numbers stay
    integers and floats stay small.
  - In Buffer A (half floats), position is `(tileHi, tileLo, offInt, offFrac)`:
    `tile = tileHi*2048 + tileLo` (up to 2^22 tiles, 4 million km),
    `offset = offInt + offFrac`. Every part is exactly representable.
  - Advance with `offFrac += v*dt`, carrying whole metres into `offInt`,
    1024 into `tileLo`, and 2048 into `tileHi`.
- **Speed:** `(vInt, vFrac)` the same way, since acceleration steps (~0.01
  m/s per frame) are finer than a half float holds near 30.
- **Layers:** each has a depth factor `k`, a power of two: FAR 1/256,
  HILLS 1/64, MID 1/16, NEAR 1/4, FORE 1. Each layer's coordinate is:

  ```
  L(xs) = tile * T + f,   T = 1024 * k           (an exact integer)
                          f = offset * k + xs * SPAN   (small float; xs in screen heights)
  ```

  For value noise with a lattice cell of `c` layer-metres (a power of two):

  ```
  A      = tile * T + uint(floor(f))                        (uint, exact)
  index  = A / c                                            (a shift)
  within = (float(A % c) + fract(f)) / c
  noise  = mix(hash(index), hash(index + 1), smooth(within))
  ```

  fBm octaves halve `c`. `hash` is a uint hash (PCG:
  `h = x*747796405u + 2891336453u; h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u; h = (h >> 22u) ^ h;`).
  With `tile < 2^22` nothing overflows before 4 million km.
- **Poles:** world-locked every 64 m, which divides 1024.
  - Current pole index: `tile*16 + offInt/64`.
  - Pole j's position relative to the train: `j*64 - mod(offset, 64)`, a
    small float.
- **Tile kinds:** one per tile, from `hash(tile ^ lineSeed)` and the line's
  weights: PLAIN, FOREST, LAKE, TOWN, HILLS, COAST, BRIDGE, TUNNEL, CROSSING.
  - The kind picks each layer's features and is blended across tile edges
    over 100 m.
  - A tunnel or bridge covers the middle half of its tile.
  - A crossing sits at a hashed spot in its tile.

### Buffer A layout (RGBA16F)

Row 0 holds the state texels. `S_` texels are memory; `D_` texels are worked
out each frame for the Image pass.

| texel | contents |
|---|---|
| S_MARK | (0, 0, 0, 0.75): the "remembered" marker, as in koi |
| S_POS | (tileHi, tileLo, offInt, offFrac) |
| S_VEL | (vInt, vFrac, mode, 0). mode: 0 cruise, 1 approach, 2 stopped |
| S_STOP | the stop point, in S_POS's form |
| S_SEEN | last counts seen: (arrive, depart, tunnel, wipe) |
| S_TUN0, S_TUN1 | the requested tunnel's start and end, S_POS form |
| S_LINE | (line id, pending line id, stopped-for s (hi), stopped-for (lo)) |
| S_FLAGS | (depart pending 0/1, sleep fade 0..1, last wipe x, last wipe y) |
| S_CLOCK | two wrapped phases, hi/lo each (koi's `accumulate`): blink, rain |
| S_METRICS | smoothed cpu, net (hi/lo, as in koi) |
| D_MOTION | (speed m/s, motion-blur px at 4K, in-tunnel 0..1, station x relative to the train in m, clamped to +-400) |
| D_POLE | (mod(offset,64), crossing x relative, bridge factor 0..1, portal x relative) |
| D_SKY | (day 0..1, dusk 0..1, stars 0..1, moon phase 0..1) |
| D_SKY2 | (moon screen x, y, cloud, flags bit 0 = sign lit) |
| D_ENV | (rain, rain motion factor (moving vs beading), condensation rate, reflection strength) |

Other regions:
- **Rows 2 and 3:** per-column data, `NCOL` = 960 texels each, 4 screen px a
  column at 4K. The Image pass samples them bilinearly.
  - row 2: (FAR height, HILLS height, MID height, NEAR height), in screen
    heights above the horizon
  - row 3: (tree canopy on MID, water level or no-water, town density,
    turbine x within column or none)
- **Rows 8..187:** condensation, 320 x 180. `.r` is fog amount 0..1:
  - it grows toward 1 at the H_ENV rate, over roughly 3 min
  - a wipe clears a capsule of radius 0.03 screen heights from the previous
    wipe point to the new one, so a drag leaves a clean stripe
  - it grows back from there

### Motion (Buffer A, per frame)
- `dt = min(iTimeDelta, 0.05)`.
- **Cruise speed:** `v_cruise = mix(18, 34, smoothstep(lo, hi, smoothed iCpuMax))`,
  with ranges in SETTINGS like koi's.
- **CRUISE:** ease `v` toward `v_cruise` at 0.3/s, with |a| ≤ `A_MAX` (0.4 m/s²).
- **New ARRIVE:** set S_STOP, then `mode = APPROACH`.
- **APPROACH:**
  - `s = stop - pos` (a small float from tile/offset differences).
  - `v_allowed = sqrt(2 * A_BRAKE * max(s, 0))`, with `A_BRAKE` = 0.7.
  - `v_target = min(v_cruise, v_allowed)`, eased with deceleration up to
    `1.2 * A_BRAKE`.
  - Integrate. If `pos` passes `stop`, or `s < 0.5` with `v < 0.3`: set
    `pos = stop` exactly, `v = 0`, `mode = STOPPED`.
- **STOPPED:**
  - Count stopped-for up.
  - Leave once a pending DEPART exists and stopped-for ≥ `MIN_DWELL`: switch
    to CRUISE and accelerate at `A_MAX`.
- **Tunnels:**
  - in-tunnel = pos is inside S_TUN0..S_TUN1, or inside a TUNNEL tile's
    middle half.
  - Past a requested tunnel's midpoint, set line = pending line.
- **Fresh** (no marker):
  - take position and line from H_SYNC and H_ENV, speed = cruise
  - mark every current count as seen, so old commands don't replay

### Image, back to front

The horizon sits at `HORIZON` (0.40 of the height). Colours are from
colors.glsl (copy the constants in; neowall has no `#include`).

1. **Sky.**
   - Night: sumiInk0 zenith to waveBlue1 horizon, with a dragonBlue haze
     near the moon.
   - Dusk and dawn: winterBlue to oniViolet to a thin surimiOrange and
     autumnYellow band at the horizon.
   - Overcast day: springViolet2 to dragonBlue.
2. **Stars.** fujiWhite, a hashed grid, twinkling from S_CLOCK, fading with
   day.
3. **Moon.** A fujiWhite disc with an oldWhite halo.
   - Phase from `iDate`, as days since 2000-01-06 18:14 UTC mod 29.530589.
     `iDate` is (year, month 0-11, day, seconds since midnight): check the
     month base once.
4. **Clouds.** Two soft noise bands drifting with the wind, not the train.
   - Night: sumiInk3, with edges lit dragonBlue by the moon.
   - Day: katanaGray.
5. **FAR ridges.** waveBlue1 by night, dragonBlue by day, hazed toward the
   sky colour.
6. **HILLS.** sumiInk4 by night, winterGreen by day.
   - **Wind turbines:** an ash-grey tower and three rotating blades. Only
     pixels in a column with a turbine evaluate blades.
   - **Hub lights:** autumnRed, all blinking together, 1 s on and 1 s off.
7. **MID.** Terrain plus tree canopy, sumiInk2 (a dark autumnGreen by day).
   - **Lakes and coast:** mirror the sky gradient and the FAR and HILLS
     silhouettes, from the column heights. Add a moon glitter path: a
     sparkle column under the moon's x.
   - **Towns** (TOWN tiles), all generic:
     - building boxes and gabled roofs, water towers
     - windows in carpYellow and autumnYellow, a few springBlue for
       screens; fewer are lit late at night
     - street lamps in roninYellow and surimiOrange, with glows
8. **NEAR.** The embankment and fences, sumiInk1.
   - **Level crossings:** two samuraiRed lights flashing alternately, and a
     waiting car's headlights (fujiWhite, warm).
   - **Bridge tiles:** the ground falls away to a river valley. MID water
     shows below.
9. **FORE.** Poles and wires, as near-black silhouettes.
   - **Wires:** two or three sag between pole tops as parabolas, which
     gives the train-window "rising and falling" wires.
   - **Bridge truss:** diagonals every 8 m.
   - **Motion blur:** box-filter each bar horizontally by
     `D_MOTION.blur`. The coverage is a trapezoid, done analytically.
10. **Tunnel.** Near-black walls, with lamps every 24 m as streaks (waveAqua2
    or oldWhite). The portal edge sweeps across at FORE speed.
11. **Station**, only when |station x| < 400 m (gated).
    - **Platform:** a slab along the bottom, up to 0.18 of the height, from
      stop-180 m to stop+30 m, at FORE scale. katanaGray and fujiGray, with
      a carpYellow edge line.
    - **Lamps:** posts every 25 m, casting roninYellow pools
      (`1/(d² + c)`).
    - **The sign:** a waveBlue1 panel with a fujiWhite border, on two posts,
      at world x = stop, so it's dead centre when stopped. It sits at 0.42
      to 0.58 of the height and is 0.55 wide.
    - **Sign text:**
      - The main line (row 1) fills the top 60% of the panel, the sub line
        (row 2) the bottom 30%. Both map across `SIGN_COLS` = 24 columns.
      - Get glyph coverage from a small local copy of the stdlib's atlas
        lookup, `glyphCoverage(cell, frac)`: read `.r`/`.g`, then 1-2
        bilinear taps of `iTermAtlas`. Compute it only for pixels inside
        the panel.
      - Draw the text in fujiWhite, lit a little by the lamps.
12. **Glass: rain.**
    - When moving: slanted streaks, at angle `atan(v / 5 m/s)` from
      vertical, scrolling with speed. Two hashed-grid layers, highlights in
      lightBlue and fujiWhite.
    - When stopped: beads and slow vertical trails, blended in by
      `D_ENV.y`.
    - Optional "refraction lite": inside big drops, re-evaluate only the sky
      and FAR/HILLS (cheap, from the column data) at a flipped offset.
13. **Glass: condensation.** Lifts blacks toward springViolet1 at fog×0.6,
    and widens light glows by (1 + 2·fog).
14. **Glass: interior reflection.** A dim boatYellow2 glow of a reading lamp
    at (0.15, 0.85), and the window's lower edge as a faint band.
    - Strength `D_ENV.w = base * (1 - outside brightness)`: strong in
      tunnels, faint by day.
    - An optional thin, dark window frame at the edges (SETTING, on).
15. **Out.** koi's tonemap with its knee, sqrt, and dither.

**Sleeping soon (flag):** the shader eases rain motion to beads and the
turbine blinking to steady-off over `SLEEP_FADE`, so the frozen frame looks
deliberate.

### Budget
- Image ≤ 6 ms p10 at 4K in the harness, with the live wallpaper running
  (koi's is 6.7).
- Buffer A ≤ 1.5 ms.
- Image reads per pixel: D_MOTION, D_POLE, D_SKY, D_ENV (issued together),
  plus 2 column texels and 1 condensation texel. Everything else only where
  gated.

## 7. Files

```
nighttrain/
  PLAN.md            this file
  nighttrain.glsl    the term_shader (Buffer A + Image)
  nighttrain.py      the program
  nighttrain.vibe    config to run it (how-to-run comments at the top, like termtest.vibe)
  tests/             drive scenarios, recordings, expected-cell checks
  out/               offline renders (add to a .gitignore)
  tools/             the offline tools (durable copies) + build.sh
```

`nighttrain.vibe`:
```
default {
  terminal "env -u SSH_AUTH_SOCK python3 ~/.config/neowall/shaders/nighttrain/nighttrain.py"
  term_shader ~/.config/neowall/shaders/nighttrain/nighttrain.glsl
  term_font /usr/share/fonts/noto/NotoSansMono-Medium.ttf
  term_font_size 48
  term_cols 0
  term_rows 0
  vsync true
  shader_fps 30
}
```

## 8. Milestones (build and verify in order)

**M0: tooling**
- Build the tools with `NW=<neowall-src> tools/build.sh`. It clones neowall
  at `fd79109` if no checkout is given. A checkout may still exist at
  `/tmp/claude-1000/-home-robbie/f5945148-4fc8-40dc-adf4-a8819d0f66b8/scratchpad/neowall-src`.
- Write `tests/drive_nt.py`. It generalizes `tools/drive.py`:
  - input: a scenario list of timed actions (wait, mouse, key, inbox line)
  - output: a recording of `(t, bytes)` chunks of the program's output
- Extend `harness_term.c` with **replay**: `-R file.rec`.
  - Feed the recorded bytes, at their times, into neowall's `screen.c` and
    `vtparse.c`.
  - Pack cells the way `term_render.c` does (fg/bg/attrs, change stamps).
    Try linking `glyph_atlas.c`, `glyph_synth.c`, `cbdt.c` and the vendored
    stb from `src/terminal/` for real glyphs, so sign text can be checked
    offline. If that's too tangled, pack with no glyphs and check text
    live.
- **Accept:** termtest's recorded session replays as it rendered before.

**M1: the moving landscape**
- Program: setup, heartbeat and marker, H_SYNC from state.json, status rows.
- Shader:
  - Buffer A: state row, hi/lo position, constant cruise, per-column heights
    for FAR, HILLS, MID and NEAR using the exact-integer lattice.
  - Image: sky (night and day), layers with haze, FORE poles and wires.
- **Accept:**
  - binding Self
  - smooth parallax in frames at 0, 5 and 10 s
  - no jitter with H_SYNC at tile 1,000,000: pole x must step evenly frame
    to frame
  - Image ≤ 4 ms p10 at 4K
  - both passes SIMD16

**M2: speed and stations**
- Cruise from metrics and motion blur.
- ARRIVE/DEPART with the exact stop, the platform, a blank sign, and
  MIN_DWELL.
- The idle halt, the sleep flag and heartbeat stop (program states), and the
  test keys `s` and `t`.
- **Accept** (scripted):
  - ARRIVE 1000 m stops the train with the sign centred within 2 px at 4K
  - an early DEPART waits
  - after sleep, no heartbeat change for 5 s

**M3: sign text and events**
- Glyph coverage on the sign (term_font set).
- The inbox with sanitizing, queue and rate limit.
- The git collector.
- The idle halt's `KM` sign.
- **Accept:**
  - `echo "BUILD PASSED|radar" > inbox` makes the next station show exactly
    that
  - unsafe characters are dropped
  - a flood of 20 lines becomes one `N EVENTS` station

**M4: richer land, and lines**
- Tile kinds and line mixes; towns, lakes with reflections and glitter,
  turbines, crossings, bridges; tunnels with lamps and reflection.
- Right-click makes a tunnel and changes the line at its middle.
- Stars, moon phase and clouds; day, dusk and dawn.
- **Accept:** a 10 min offline run shows every kind at least once, and no
  visible pop at a line change.

**M5: the glass**
- Rain, moving and stopped; condensation and wiping; interior reflection.
- The weather process, persisted.
- **Accept:** a drag leaves a clean stripe that fogs back over minutes;
  streak angle follows speed.

**M6: power and finish**
- Hyprland visibility sleep; restart continuity (killing the program must
  not make the train jump); env hygiene.
- Performance pass to budget; the "What it costs" comment section with
  measured numbers.
- A live test with the user.
- Ask before making it the default wallpaper.

## 9. How to test

- **Every change:**
  - `python3 -m py_compile nighttrain.py`
  - `tools/bin/binding_check nighttrain.glsl` must show `ch0=Self`
  - harness frames at chosen times (`-s 0,5,10 -o out`), then look at them
- **SIMD:**
  `MESA_SHADER_CACHE_DISABLE=true INTEL_DEBUG=fs tools/bin/harness_term nighttrain.glsl -w 640 -h 360 -n 2 2>&1 | grep -E '^SIMD(8|16|32) shader'`.
  Each pass must list SIMD16.
- **Timing:** `-w 3840 -h 2160 -T -n 180` prints p10.
  - With the live wallpaper running, compare p10s: koi's is 6.7 ms, and
    means come out ~1.6x high.
  - koi's own reference used the older harness at
    `/tmp/claude-1000/-home-robbie/75a7d156-cb1f-4e1e-be82-a9859c043cbb/scratchpad/h/harness_koi`
    (`HARNESS_BUFSCALE=0.7 harness_koi koi.glsl -w 3840 -h 2160 -T -n 300`),
    which may be gone after a reboot.
- **The program alone:** drive it in a pty with scenarios, then check the
  header cells and sign rows with `cellcheck`. Extend cellcheck to print
  cells 0-5 and rows 1-2.
- **Live** (the user runs it, or agrees to it):
  - `neowall kill`
  - `neowall -f -v -c ~/.config/neowall/shaders/nighttrain/nighttrain.vibe`
  - look for `Pass 0 (Buffer A): ch0=Self` and `Stats: .. FPS`
  - screenshots:
    - only of an empty workspace: poll `hyprctl -j activeworkspace` for
      `windows == 0`, then `grim -o eDP-1`
    - a 4K PNG takes a few seconds to encode
    - stop the watcher when done, and delete shots of anything but the
      wallpaper
  - to stop: Ctrl-C in that terminal, then `neowall` to bring koi back

## 10. House style (match koi.glsl and jelly.glsl)

- **Header comment:** what it is, what it reads, and what makes it feel
  alive. Then a `SETTINGS` block grouped by purpose, one plain-English
  comment per number. Then a line "Everything below is how it works".
- **Colours:** Kanagawa constants copied from `colors.glsl` with their hex
  in a comment. Linear lighting (`toLinear` = square, `sqrt` at the end),
  koi's `tonemap`, and the dither line.
- **Buffer A:** `state(i)`, `S_`/`D_` texel constants each with a comment, the
  0.75 marker, and hi/lo helpers (`coarse`, `accumulate`, and the carry
  logic for position).
- **Comments:** explain *why* in whole plain sentences, including the
  measurements that forced a design. End with a "What it costs" section.
- **Python:** the same tone, SETTINGS at the top, no dependencies.

## 11. Risks and fallbacks

- **Glyphs offline:** if linking the atlas code is too tangled, verify sign
  text live.
- **Buffer A size:** keep every region small and read sizes as section 3
  says.
- **Program timing estimates:** the shader defers early DEPARTs, and stops
  exactly wherever it is told, so estimates can be generous.
- **Hyprland socket missing:** neowall started outside Hyprland. The program
  then assumes visible, which is still correct, just not power-saving.
- **Two monitors:** each output runs its own copy of the program (untested).
  Use a lock on state.json. v1 targets eDP-1 only.
