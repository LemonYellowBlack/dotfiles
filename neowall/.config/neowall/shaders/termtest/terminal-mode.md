# neowall terminal mode: what it gives a wallpaper, and how to use it

Notes from one long session (2026-09-29), written so a fresh session can
pick the thread up without re-deriving anything. Everything marked
**verified** was read in neowall 0.7.1's source and/or run; anything else is
an idea or an open question, and says so.

## Where things stand

- `termtest/` (this folder) is a working prototype: `termtest.sh` is a
  program neowall runs in a hidden terminal, `termtest.glsl` is a two-pass
  shader that reads it, `termtest.vibe` a throwaway config that runs them.
  How to run it is at the top of `termtest.vibe`.
- **Verified live** (2026-09-29, on the XPS at 4K): neowall drew it
  continuously at ~59 fps with 0 errors (render engine ~44% busy); both
  lamps green (heartbeat arriving, test bytes exact); Buffer A remembers
  (ripples spread over many frames); clicks and drags reach the shader
  through the script. The user watched it and says it works. Not separately
  checked: the raw-terminal scene's text, and exact click placement (it
  looked right to the user).
- **Verified offline** before that: neowall's own parser + channel guess
  binds termtest's Buffer A to itself; the script's output, fed through
  neowall's own terminal emulator, puts exactly the intended bytes in every
  data cell; the shader renders the scripted session correctly; both passes
  compile SIMD16. Tools for all of this are listed at the end.
- Nothing is committed: `termtest/` is untracked in `~/dotfiles`.

## Direction chosen (2026-09-29): the night train

**Ground rule:** Kanagawa is used for its colours only. The user doesn't
want Japanese or other Asian cultural motifs: no shoji, washi, calligraphy,
lanterns-as-motif, raked gardens, haiku, and so on. The palette's colour
names are just labels. The scene below is deliberately placeless.

**The scene:** looking out of a train window at night, crossing an unnamed
countryside, from far to near:
- sky: a few stars, the real moon phase, drifting cloud
- far ridges, sliding slowest
- treelines and lakes (the moon's glitter path on the water), small towns
  as clusters of lit windows, wind turbines' slow red blink
- level crossings with flashing lights and a waiting car's headlights, a
  bridge's trusses flicking past
- poles and sagging wires whipping by in the foreground
- the glass itself: rain streaks that slant more the faster you go,
  condensation, and a faint reflection of the carriage's reading lamp,
  strongest in tunnels, when outside goes dark

**The program runs the journey** (it owns this, and saves it):
- The distance travelled, so the landscape carries on where it left off
  after a reboot. It's sent as a whole segment number plus an offset,
  because a float32 can't hold a long journey's position smoothly: another
  thing the CPU side does better.
- The route (coast, hills, plains...).
- The speed, from how busy the machine is.
- A small state machine: travelling, braking, stopped, departing, plus the
  odd tunnel.

**Events become stations.** The train brakes to a stop at a platform whose
sign shows the event in real type: "FORGEJO · 3 PUSHES", "BUILD PASSED",
"STANDUP 10:30". The braking is constant deceleration, worked out by the
program so the train stops exactly at the sign.

**Idle:** after a while with nothing happening, it waits at a quiet
station under one lamp, and the heartbeat stops. That's a still frame, so
0% GPU, until the next event pulls it out.

**Input:**
- drag to wipe condensation off the glass; it fogs back slowly (a field in
  Buffer A: shader-owned, since only the look changes)
- right-click to change line
- maybe the wheel to lean in closer to the glass

**New techniques:**
- **per-column precompute:** each layer's silhouette height is the same
  for every pixel in a screen column, so Buffer A works it out once per
  column (koi's "same for many pixels" rule again)
- **analytic motion blur:** horizontal only, scaled by speed and nearness;
  a pole becomes a soft smear
- **procedural slanted rain**
- **reflection strength** from outside versus inside brightness
- **braking curves**

**Build order:**
1. A still parallax scene, driven by a distance number from a tiny program.
2. Speed and motion blur.
3. Stations with sign text.
4. The glass: rain, condensation, reflection.
5. The idle policy.

## The idea in one paragraph

A plain neowall shader is a closed world: a function of time, a fixed menu
of machine metrics, the pointer's position, and its own last frame.
Terminal mode opens it up. `terminal "<command>"` runs a real program beside
the shader, and joins the two with a narrow pipe: whatever the program
prints lands in a grid of character cells, and the shader can read every
cell's colours exactly. Everything new follows from three facts:

1. the program can see and do anything a program can;
2. the pipe carries exact bytes, plus the exact time each cell last changed;
3. clicks and keys reach the wallpaper only through the program.

The shader stays the renderer. The program becomes the wallpaper's brain.

## What it adds over a plain shader

| | plain neowall shader | terminal mode adds |
|---|---|---|
| **input** | pointer position only: `iMouse.zw` is hard-wired to 0 (`render.c:1060`), so no shader ever sees a click | clicks (left, middle, right: press and release), scroll wheel, drags; keys once the wallpaper's been clicked. This is the only click path in 0.7.1 |
| **data** | the built-in metrics: cpu, ram, temps, net, disk, audio, battery, time, sun | anything a program can read: files, network, `ssh`, D-Bus, Hyprland's IPC, APIs, other programs' output |
| **events** | levels only (a metric's value now) | moments: a counter cell changes, and `iTermChange` says when, to the millisecond |
| **computation** | GPU, gather only: each pixel reads, none can write elsewhere | a CPU program: scatter, particles that deposit, search, sorting, rules, state machines, parsing |
| **memory** | Buffer A..D, wiped by any buffer resize; `state` keeps 4 texels | the program's own memory and disk. And since the shader re-reads the grid every frame, whatever the program holds survives a buffer wipe, a neowall restart, a reboot |
| **frame loop** | always on (and on this laptop never paused, see the occlusion bug in the neowall memory note) | the program decides: neowall only draws while the terminal changes, so the program can stop the wallpaper (0% GPU) and wake it |
| **text** | none (the stdlib's small bitmap font needs a sidecar channel) | real fonts: TrueType, fallbacks incl. CJK, colour emoji, drawn into an atlas the shader can sample anywhere |
| **composition** | none | Unix pipelines (`$SHELL -c`), existing TUIs as skeletons (`asciiquarium`, `cbonsai-git`) |

What it does **not** give, and the design has to work around:

- **A one-way street.** The program can tell the shader anything; the shader
  can tell the program nothing (there's no GPU readback). So the program has
  to know the layout of anything clickable, or leave the consequences of a
  click to the shader. See "who owns the world", below.
- Hover never reaches the program (only drags do). The shader sees hover
  through `iMouse.xy`.
- Click precision is one cell, and the grid's size is set by the one font
  size: small cells mean precise clicks and lots of data, but only if you
  don't also want to draw big text.
- A click takes a frame or two, plus the program's own time, to show up.
- It replaces `shader` mode on that output (one or the other), neowall
  reads no sidecar for it, and there's no `state` persistence. The heartbeat
  and the channel-binding rules below are musts.
- The program runs as you, with your whole environment (see Security).

## Verified facts (reference)

### Loading
- `terminal "<cmd>"` in `config.vibe` (mutually exclusive with `shader` and
  `path`). neowall runs it via `$SHELL -c` in a pty, with its own whole
  environment (minus `TERM`/`COLORTERM`; it sets `TERM=xterm-256color`, or
  `term_env`, and `COLORTERM=truecolor`). If it exits, it's restarted after
  0.5 s (the first 3 times), then 2 s, then 5 s. It dies with neowall
  (`PR_SET_PDEATHSIG`).
- `term_shader <path>`: an absolute or `~` path is used as is; a bare name is
  looked up in `~/.config/neowall/shaders/`; a relative path with a `/` is
  relative to neowall's working directory (so don't).
- The shader goes through the ordinary multipass parser: Buffer A..D and
  Image passes, found by the usual marker comments (and the usual trap:
  keep other pass names off the 5 lines above each `mainImage`). Every pass
  gets every uniform and every terminal texture.
- **No sidecar.** Channels come from a guess at the source text
  (`shader_multipass.c:776`). For a buffer pass it only reads that pass's own
  `mainImage` text, not the helpers above it:
  - channel 0 is bound to the pass's own last frame if its `mainImage` reads
    `iChannel0` itself, and nothing after that read looks like a noise
    lookup: `/256`, `/512`, `/1024` (with or without a space), or
    `*0.00...` within 60 characters of it;
  - if `iChannel0` never appears in that `mainImage`, it binds the noise
    texture. koi.glsl as it stands would get noise: its reads are all
    inside `state()`.
  - termtest's Buffer A `mainImage` opens with
    `texelFetch(iChannel0, ivec2(fragCoord), 0)`, which scores as self.
  - The Image pass gets ch0 = Buffer A, ch1..3 = B..D.
  - `neowall -f -v` logs the decision:
    `Pass 0 (Buffer A): ch0=Self` is the line to see.

### What the shader can read
- `iTermCells` (`usampler2D`, RGBA32UI, one texel per cell, row 0 = top):
  - `.r` = atlas x << 20 | atlas y << 8 | flags (bit 0: a glyph is drawn;
    bit 1: it's colour emoji)
  - `.g` = glyph w << 24 | h << 16 | (x offset + 128) << 8 | (y offset + 128)
  - `.b` = foreground red << 24 | green << 16 | blue << 8 | 0xFF
  - `.a` = background red << 24 | green << 16 | blue << 8 | style bits
    (bold 1, faint 2, italic 4, underline 8, blink 16, reverse 32,
    invisible 64, strike 128)
  - Truecolour (`ESC[38;2;r;g;bm`, `ESC[48;2;r;g;bm`) arrives exactly.
    Reverse video swaps fg and bg before packing, so data cells must never
    use it. A space still stores both colours.
  - **There's no character code.** The shader knows a glyph is there, and
    where its picture is in the atlas, not which character it is.
- `iTermChange` (`usampler2D`, R32UI): per cell, the terminal clock (ms since
  it started) when that cell's record last changed. Cells unchanged since
  the first frame read 0. `iTermFade.y` is "now" on the same clock, so
  `iTermFade.y - float(stamp)` is the age in ms.
- `iTermInfo` = (cols, rows, cell w, cell h). The cell size is the
  supersampled atlas size, not screen pixels: use `iResolution / cols,rows`.
- `iTermCursor` (x, y, visible), `iTermCursorPrev` (x, y, move time),
  `iTermAtlas`, `iTermColorAtlas`, `iTermAtlasSize`. The stdlib draws text
  with them: `nwTerm(uv)` (the whole grid, crisp), and `nwTermCell(cell,
  frac, cw, ch, cursor)` to draw any one cell anywhere.
- Texture units: atlas 5, cells 6, colour atlas 7, change stamps 8.

### Clicks and keys
- The pointer is converted to screen pixels (HiDPI-aware), then
  cell = pixel / cell size, clamped to the grid. A report is sent only if the
  program turned mouse reporting on: `ESC[?1000h` clicks, `?1002h` clicks and
  drags, `?1003h` accepted but hover isn't forwarded anyway; plus `?1006h`
  for the SGR format `ESC[<b;x;yM` (press) / `...m` (release), x and y from 1.
- Buttons: 0 left, 1 middle, 2 right; 32 + button for a drag; wheel 64 (up)
  and 65 (down), press only.
- `iMouse.xy` is always fed (screen pixels, y from the top), in every mode.
- Keys: only after the wallpaper's been clicked (on-demand focus, Wayland
  only). Everything but Ctrl-C, D, Z and \ reaches the program (those four are
  dropped unless `term_raw_input true`). The pty echoes typed keys into the
  grid unless the program turns echo off (`stty raw -echo`).

### The idle gate (the heartbeat)
- A terminal wallpaper is only redrawn while something's in flight: bytes
  arrived, or a cell changed or the cursor moved in the last 700 ms
  (`eventloop.c:1294`). It ignores `iTime` and buffers entirely. Once idle,
  the screen keeps its last frame.
- So continuous animation needs the program to change one cell at least
  every ~0.5 s. Rewriting the same value doesn't count. termtest's beat is
  0.4 s.
- The first frame after an idle spell sees a big `iTimeDelta` (neowall
  clamps it to 0.25 s): koi already uses exactly that to mean "someone came
  back".

### The grid
- Cell height = `term_font_size` (default 18, clamped 6..96), cell width =
  (height + 1) / 2, rounded down. Auto-fit (`term_cols 0`, `term_rows 0`)
  fills the screen: 3840 / width by 2160 / height. The largest allowed grid
  is 1024 x 512.
- Sizes that divide 3840 x 2160 exactly, so the shader's cells line up with
  neowall's click mapping: 16 -> 480x135, 20 -> 384x108, 24 -> 320x90,
  30 -> 256x72, 40 -> 192x54, 48 -> 160x45, 60 -> 128x36, 80 -> 96x27.
- Every time the grid changes, neowall repacks every cell on the CPU, diffs
  the rows, and uploads the changed band. That's cheap for termtest's
  160x45 at 2.5 changes a second. It's unmeasured for big grids at 60 Hz.

### The emulator, and other gotchas
- Supports autowrap off (`?7l`), cursor hide (`?25l`), the alternate screen
  (`?1049h`), mouse modes 1000/1002/1003 and SGR (1006), 256 colours and
  truecolour. Window titles (OSC 0/2) are stored. Palette, clipboard (OSC
  52) and hyperlink (OSC 8) commands are parsed and ignored. It answers
  cursor-position and device-attribute queries.
- The program's **stderr is the pty too**: an error message gets painted
  into the grid. Redirect it (termtest.sh: `exec 2>>"$XDG_RUNTIME_DIR/..."`).
- **Development loop:** with the same command already running,
  `output_set_terminal` returns early (`output.c:1293`). So `neowall reload`
  shouldn't pick up shader edits (read in the source, not tried). Restart
  neowall instead. Changing the command string, e.g. via
  `neowall set-terminal`, forces a rebuild (also untried). Iterate offscreen
  first (tools, below).
- Each output gets its own terminal, so two monitors would mean two copies
  of the program (untried). State files would want a lock.
- Buffer size, still open: the memory note says self-reading buffers are 70%
  of the screen, but the live log's optimizer line said
  `Pass 0: unknown @ 75%`, which is its default recommendation for
  unclassified passes. Whether that's the size actually used is unchecked.
  termtest reads the real size with `textureSize`, so it didn't matter;
  koi's layout guesses 70% (with a fallback check), so check before porting.

### Costs measured (4K, offscreen harness, koi running live alongside)
- termtest: Buffer A ~1 ms, Image 5.4 ms (p10). koi in the same conditions:
  Image 6.7 ms (p10). With the live wallpaper running, compare p10s; means
  come out ~1.6x high.
- Two lessons from getting termtest there from 8.1 ms:
  - Picking a colour from a 5-entry local array per pixel cost 1.4 ms.
  - Two smoothstep cell boxes computed on every pixel cost 1.8 ms.
  - So: work out per-frame constants once in a Buffer A texel, and gate
    per-pixel extras to the pixels that need them. Same rule as koi's
    "~10 instructions a pixel = 0.5 ms".

## Design patterns

### Who owns the world
The one-way street forces a choice for each piece of state:

- **Program-owned**: the world lives in the program, the grid is its render
  list, the shader interpolates and makes it beautiful.
  - Needed when a click's consequences must last (saved, counted, fed back
    into logic), when things must be clickable by identity ("that lantern"),
    or when the simulation is CPU-shaped.
- **Shader-owned**: the world lives in Buffer A, like koi. The program only
  forwards events and data, and the shader does its own hit tests. A click
  near a koi can startle it, because Buffer A knows where the koi are.
  - Right for big, continuous simulations (waves, fluids, particles) whose
    reactions are only visual.
- **Both**, split by timescale: slow, discrete, persistent state in the
  program; fast, continuous motion in the shader.
  - e.g. where each koi is headed, how hungry it is and whether it trusts
    you live in the program; its body, the ripples and the light live in
    Buffer A.

### A protocol for the cells
Design the grid like a wire format. termtest's is the seed:

- **Row 0 is a header.**
  - cell 0: a marker plus the heartbeat. The shader checks the marker
    before trusting anything, and falls back (termtest: shows the raw
    terminal) when it's missing.
  - Then a protocol version, the scene, parameters, and event slots.
- **Values:** bytes in background and foreground: 6 exact bytes a cell,
  plus style bits (never reverse video).
  - A 16-bit value takes two bytes, so one cell holds an entity: x, y and
    one more 16-bit field.
  - A 64-cell row holds 64 entities.
- **Events:** a counter, 1..255 with 0 for "none yet", plus the cell's
  change stamp.
  - Buffer A remembers the last count it saw. A different count is a new
    event, and the stamp says when it happened, so the shader can start
    its animation at the right moment.
- **Layout:** the other rows are maps (a material per cell, drawn in vim),
  entity tables, or real text for the shader to draw.
- **Cost:** only cells that change cost anything, so keep the heartbeat to
  one cell.

### When to draw
- Heartbeat only while there's something to show. Let the scene come to
  rest before stopping, since the last frame stays on screen. Stop when the
  wallpaper's covered or at night, and wake on an event.
- On waking, the first frame's big `iTimeDelta` is a free "you're back"
  signal.

### Persistence
- The program saves to `$XDG_STATE_HOME/...` and restores on start. The
  shader must cope with the marker being absent (the program restarting)
  and with fresh buffers (a resize), independently.

### Security (the program is a long-running process with your identity)
- **It inherits `SSH_AUTH_SOCK`**: a bug in anything that parses remote data
  could use your SSH agent. Run it as `env -u SSH_AUTH_SOCK ...` unless it
  needs ssh.
  - If it needs data from the ThinkCentre, a dedicated key with a forced
    `command=` in `authorized_keys` that can only print numbers is the
    least-privilege version.
- **Keep text away from the parser.** The emulator is hand-written C.
  - Send numbers, not attacker-influenced text such as log lines with
    usernames or URLs.
  - Sanitize anything you do print, and keep sensitive text off the grid,
    since it's one bug from being on screen.
- **Keyboard:** after a click, your typing goes to the program. Accept a
  small command set, ignore the rest, and never log keystrokes.
- **Sandboxing** is worth a look, e.g. `bwrap` with no network and a
  read-only home for programs that don't need either. It's not yet checked
  how that behaves under neowall's pty.

## Ideas

Each notes which new capability it leans on. In rough order of
payoff for effort:

1. **Power-aware koi** (frame loop + desktop events)
   - Run koi as a `term_shader`, with a tiny program that beats only while
     workspace 11 (or any empty workspace) is showing. It listens on
     Hyprland's event socket, `.socket2.sock` under
     `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/`, rather than
     polling.
   - Today koi keeps ~50% of the iGPU busy behind opaque terminals, because
     neowall never pauses on this HiDPI screen. This would take it to ~0,
     cool the package (which koi's heat input reads), and give back koi's
     "coming back" greeting.
   - First step: make koi's Buffer A `mainImage` read `iChannel0` itself,
     run `binding_check` on it, check its buffer-size guess, and write the
     20-line beat-while-visible program.
   - Alternative without terminal mode: `pause_coverage_threshold 0.2` (see
     the neowall memory note).
2. **Interactive koi** (input, shader-owned world plus program-owned
   memory)
   - Click to scatter food and the koi come to eat (koi already has a
     "curious" mode); drag to stir; the wheel scrubs the time of day.
   - The program remembers who was fed and how often, so the koi come to
     trust you over days.
3. **A garden that stays** (program-owned world, persistence, input, long
   timescales)
   - A small garden: moss, stones, a tree. Its layout starts as an ASCII
     map drawn in vim.
   - The program evolves it slowly: growth, fallen leaves, seasons from the
     date. Your raking or pruning drags and clicks are saved across reboots.
   - The shader paints it (koi's smooth-field trick turns coarse cells into
     organic shapes).
4. **Machine weather** (data, events, text)
   - The laptop's and the ThinkCentre's health as nature:
     - Forgejo pushes as rain
     - pending updates (`checkupdates`) as wilting
     - a failed unit (`systemctl --failed`) as an unlit lantern
     - a new Tailscale device as a new stone
   - Click the lantern to read which service it is, in real text.
   - Numbers only on the grid, and the collector sandboxed and
     least-privilege. A good security exercise in its own right.
5. **Ink and text** (fonts, glyph atlas)
   - Commit messages, or a line of text made from the machine's day,
     written in ink that bleeds into paper.
   - The atlas doubles as a sprite pipeline: print a glyph on a hidden row
     to get it rasterized, read that cell to learn where it sits in the
     atlas, then sample it anywhere as a sprite. A custom icon font would
     give crisp vector art without image files.
6. **CPU-shaped materials** (scatter, rules)
   - Falling sand or water you pour by dragging. The program runs the
     cellular automaton, which is easy on a CPU and awkward on a
     gather-only GPU, and the shader turns cells into smooth, lit material.
   - Or a small ecosystem: prey and predators with pathfinding.
7. **A desktop-aware scene** (Hyprland events as a new input class)
   - A leaf falls where a window opened; the scene pans a little toward the
     workspace you switched to; a lantern flashes for an urgent window.
8. **A diorama of scenes** (input, multi-scene)
   - Scenes drawn as ASCII maps in vim, with doors to click through, and
     transitions timed from the scene cell's change stamp. A small world
     that remembers where you left off.
9. **Earlier ideas, improved:** from the first brainstorm this session.
   - A candle clock can keep its burn time across reboots and let you
     click to light a new candle.
   - Frost can keep the paths you wipe with the pointer and regrow into
     them.

Suggested order: 1 then 2. Together they port a real shader into terminal
mode, prove the heartbeat policy, and pay off immediately. Then 3 or 4 as the
first piece built for terminal mode from scratch.

## Open questions

- Does `neowall reload` really ignore term_shader edits, and does
  `set-terminal` rebuild? (Read in the source, not tried.)
- What size is Buffer A really in terminal mode: 70% or 75%?
- CPU cost of a big grid (e.g. 480x135) changing at 30-60 Hz.
- Click-to-ripple latency, measured.
- Keyboard focus on Hyprland: does clicking the wallpaper actually give it
  keys, and does clicking a window take them back?
- Two monitors: two copies of the program?
- Suspend and resume, and what the program sees when neowall restarts it.

## Files and tools

- This folder: `termtest.sh`, `termtest.glsl`, `termtest.vibe`, and these
  notes. The neowall memory note (Claude's memory,
  `reference_neowall_internals.md`) has the same facts in brief.
- neowall's source: upstream `https://github.com/1ay1/neowall`, release
  commit `fd79109` ("release: neowall 0.7.1"). A checkout was at
  `/tmp/claude-1000/-home-robbie/f5945148-4fc8-40dc-adf4-a8819d0f66b8/scratchpad/neowall-src`,
  gone after a reboot.
- Test tools: durable copies of the sources are in `../nighttrain/tools/`,
  with `build.sh` (it clones neowall at `fd79109` if no checkout is given).
  The night train's implementation plan is `../nighttrain/PLAN.md`. The
  tools:
  - `binding_check`: neowall's real parser (`multipass_parse.c`) plus its
    channel guess copied verbatim (`sed -n 785,939p shader_multipass.c`).
    Prints the binding each pass gets.
  - `cellcheck`: feeds a byte stream through neowall's own `screen.c` and
    `vtparse.c`, and prints what lands in the header cells and the text rows.
  - `drive.py`: runs a program in a 160x45 pty the way neowall does, sends
    it the exact bytes neowall sends for clicks, wheel and keys, and saves
    what it prints after each step.
  - `harness_term`: the offscreen koi harness from
    `.../75a7d156-.../scratchpad/h/`, plus fake terminal textures on units
    5-8 and a scripted session. `-x 1`: the heartbeat stops at 1 s; `-x 2`:
    no script at all. `-T` for timing, which prints p10.
