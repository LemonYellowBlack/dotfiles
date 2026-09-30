#!/usr/bin/env python3
# nighttrain.py: the program half of the night-train wallpaper. neowall runs
# it as a terminal wallpaper (nighttrain.vibe's `terminal` line) and hands
# everything it prints to nighttrain.glsl, which draws the view from a train
# window at night: land going by, stations, tunnels, rain on the glass.
#
# The two halves split the work by what each can know:
#   this program   the why and when: it hears the outside world (your clicks
#                  and keys, an inbox anything can write to, new git commits,
#                  whether the desktop is covered), keeps the journey on disk,
#                  runs the weather, and decides when the train stops, leaves,
#                  changes line or goes to sleep
#   the shader     the how: exactly where the train is, every frame, and
#                  everything it looks like. It brakes to the metre it's told
#                  to stop at, so this program never needs to know the fine
#                  motion; it only gives orders ("stop in 1100 m") and waits
#                  long enough.
#
# They talk through the terminal grid. Row 0's first six cells are a header
# the shader reads as numbers: each cell's background and foreground colours
# carry three bytes each (PLAN.md section 4 has the table). Rows 1 and 2 hold a
# station sign's two lines of text, and rows 4 and up a status report, which
# the shader shows only if this program isn't running properly (so an error
# shows up on the wallpaper instead of vanishing).
#
# neowall only draws a terminal wallpaper for 0.7 s after something in the
# grid changes. So a heartbeat cell changes every 0.4 s while the train should
# move, and stopping it is how the wallpaper sleeps: the last frame stays on
# the screen and the GPU does nothing. It sleeps when the desktop is covered
# by windows (nobody can see it), and after a long quiet spell, at a halt.
#
# Sending it a station, from any script or terminal:
#   echo "BUILD PASSED|radar" > $XDG_RUNTIME_DIR/nighttrain/inbox
# The part before | is the sign's main line, after it the small line. Only
# A-Z 0-9 space . : / # - + survive (lower case is raised), 24 characters a
# line at most. Lines closer together than 10 s merge into one "N EVENTS".
#
# Security, briefly: the inbox is a named pipe only you can write to (in a
# directory only you can enter); what arrives is only ever shown, never run,
# and anything but the plain characters above is dropped before it reaches
# the screen, so nothing that arrives can send the terminal escape codes. The
# log records what kind of thing happened, never what you typed or sent. The
# git check only reads each repo's HEAD. There's no network use at all.
#
# Every number worth tweaking is in SETTINGS, just below. Tests can override
# any of them with NIGHTTRAIN_OVERRIDES='{"IDLE_AFTER": 20}' in the
# environment (tests/drive_nt.py does that).

# ============================================================================
# SETTINGS
# ============================================================================

# --- the journey
V_NOMINAL     = 25.0          # m/s, the train's average speed: only for the rough km count on the idle halt's sign
START_TILE    = 1000          # a brand-new journey starts this many 1024 m stretches down the line
START_LINE    = 0             # and on this line: 0 mixed country, 1 coast, 2 hills, 3 plains

# --- stations
STOP_IN       = (900, 1400)   # metres ahead a station is announced: more than the 826 m it takes to brake from top speed
ARRIVE_SLACK  = 10.0          # it's surely stopped after stop-in / 12 m/s + this many seconds
DWELL         = 25.0          # seconds an event's station waits before leaving
DEPART_CLEAR  = 60.0          # seconds after leaving before the next station is announced, so the last one is out of sight before its sign changes
EVENT_GAP     = 10.0          # events closer together than this merge into one station
QUEUE_MAX     = 5             # at most this many stations waiting; past that they merge into "N EVENTS"

# --- quiet spells and sleep
IDLE_AFTER    = 20 * 60       # seconds without an event before the train halts somewhere quiet and sleeps
IDLE_MARGIN   = 1000          # metres added to the idle halt's estimate, since the shader may move a stop past a tunnel or bridge
SLEEP_FADE    = 3.0           # seconds the shader gets to settle the rain and lights before the last frame
FORCE_NIGHT   = False         # True: always night, whatever the clock says (key n toggles it)

# --- the heartbeat
BEAT_EVERY    = 0.4           # seconds between heartbeats (neowall stops drawing 0.7 s after the last change)

# --- tunnels (the right button, or key t, asks for one; the line changes inside it)
TUNNEL_LEN    = (480, 1600)   # metres long
TUNNEL_GAP    = 60.0          # seconds before another can be asked for

# --- weather: a slow random walk between four kinds, one step every WEATHER_EVERY
WEATHER_EVERY = 600           # seconds
WEATHER_STAY  = 0.55          # the chance it stays as it is at a step
# where it goes otherwise, with weights (so rain mostly comes and goes through cloud)
WEATHER_NEXT  = {"CLEAR": {"CLOUDY": 3, "RAIN": 1},
                 "CLOUDY": {"CLEAR": 2, "RAIN": 2, "HEAVY": 0.5},
                 "RAIN": {"CLOUDY": 2, "HEAVY": 1, "CLEAR": 0.5},
                 "HEAVY": {"RAIN": 3, "CLOUDY": 1}}
# how each looks, 0..255: rain on the glass, how fast the glass mists, cloud cover
WEATHER_LOOK  = {"CLEAR": (0, 30, 30), "CLOUDY": (0, 70, 170), "RAIN": (120, 190, 225), "HEAVY": (230, 255, 250)}
WIND          = (20, 200)     # how fast the clouds drift, 0..255, drawn afresh at each step

# --- where events come from
GIT_ROOTS     = ["~/lyb"]     # a new commit in any git repo up to GIT_DEPTH folders down is a station
GIT_DEPTH     = 2
GIT_EXCLUDE   = ["node_modules", ".*", "vendor", "target", "build", "dist"]   # folder names not to look inside (shell patterns)
GIT_EVERY     = 60            # seconds between checks of every repo
GIT_RESCAN    = 3600          # seconds between looking for new repos

# --- saving the journey
SAVE_EVERY    = 60            # seconds

# ============================================================================
# Everything below is how it works: tuning shouldn't need anything past here.
# ============================================================================

import errno, fcntl, fnmatch, json, os, random, re, selectors, signal, socket, stat
import subprocess, sys, termios, time, traceback, tty

SETTING_NAMES = [n for n in list(globals()) if n.isupper()]

def same_kind(old, value):
    """Is value a sensible replacement for setting old? (JSON has no tuples.)"""
    if isinstance(old, bool) or isinstance(value, bool):
        return isinstance(old, bool) and isinstance(value, bool)
    if isinstance(old, (int, float)):
        return isinstance(value, (int, float))
    if isinstance(old, (tuple, list)):
        return isinstance(value, list)
    return isinstance(value, type(old))

def apply_overrides():
    """Settings from NIGHTTRAIN_OVERRIDES, for tests: only known names, and
    only values of the same kind as the default."""
    raw = os.environ.get("NIGHTTRAIN_OVERRIDES")
    if not raw:
        return
    try:
        new = json.loads(raw)
    except ValueError:
        log("NIGHTTRAIN_OVERRIDES isn't JSON; ignored")
        return
    for name, value in new.items():
        if name not in SETTING_NAMES or not same_kind(globals()[name], value):
            log(f"override {name}: no such setting, or the wrong kind of value")
            continue
        globals()[name] = tuple(value) if isinstance(globals()[name], tuple) else value
        log(f"override {name}")

# ----------------------------------------------------------------------------
# Files: the log first, since anything written to stderr would otherwise land
# in the terminal grid (neowall gives the program one terminal for both), and
# show up painted on the wallpaper.

RUN_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/nighttrain-{os.getuid()}", "nighttrain")
STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "nighttrain")

def private_dir(path):
    """A directory only we can use: made with mode 0700, or checked and
    tightened if it's there already (refusing one someone else owns)."""
    os.makedirs(path, mode=0o700, exist_ok=True)
    st = os.lstat(path)
    if not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid():
        raise SystemExit(f"{path} isn't a directory of ours")
    if st.st_mode & 0o077:
        os.chmod(path, 0o700)

def open_log():
    private_dir(RUN_DIR)
    path = os.path.join(RUN_DIR, "log")
    try:
        if os.path.getsize(path) > 1_000_000:       # keep it from growing forever
            os.replace(path, path + ".old")
    except OSError:
        pass
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    os.dup2(fd, 2)                                  # everything, even a crash's traceback, goes here
    os.close(fd)
    sys.stderr = open(2, "w", buffering=1, closefd=False)

def log(msg):
    print(time.strftime("%H:%M:%S ") + msg, file=sys.stderr)

# ----------------------------------------------------------------------------
# The grid: what every cell we use holds now, so only changes are sent, all
# of a tick's changes in one write.

ESC = "\x1b"

class Grid:
    def __init__(self):
        self.cols, self.rows = 160, 45
        self.cells, self.texts, self.out = {}, {}, []

    def resize(self):
        try:
            self.cols, self.rows = os.get_terminal_size(0)
        except OSError:
            self.cols, self.rows = 160, 45
        self.cells.clear(); self.texts.clear()
        self.out.append(f"{ESC}[0m{ESC}[2J")

    def cell(self, col, row, bg, fg=(0, 0, 0)):
        """A header cell: a space whose two colours carry six bytes."""
        bg, fg = tuple(int(v) & 255 for v in bg), tuple(int(v) & 255 for v in fg)
        if self.cells.get((col, row)) == (bg, fg):
            return
        self.cells[(col, row)] = (bg, fg)
        self.out.append(f"{ESC}[{row + 1};{col + 1}H{ESC}[0m{ESC}[38;2;{fg[0]};{fg[1]};{fg[2]}m"
                        f"{ESC}[48;2;{bg[0]};{bg[1]};{bg[2]}m {ESC}[0m")

    def text(self, row, s, col=0):
        """A line of plain text on a row of its own, in the default colours."""
        if row >= self.rows or self.texts.get(row) == (col, s):
            return
        self.texts[row] = (col, s)
        self.out.append(f"{ESC}[{row + 1};1H{ESC}[0m{ESC}[2K{ESC}[{row + 1};{col + 1}H{s[:self.cols - col]}")

    def flush(self):
        if not self.out:
            return
        data = "".join(self.out).encode()
        self.out.clear()
        while data:
            try:
                n = os.write(1, data)
            except BlockingIOError:
                time.sleep(0.01)
                continue
            data = data[n:]

# ----------------------------------------------------------------------------
# Text for the signs: only what's safe and legible gets through.

SIGN_COLS = 24
UNSAFE = re.compile(r"[^A-Z0-9 .:/#+-]")

def clean(s):
    s = UNSAFE.sub("", s.upper())
    return " ".join(s.split())[:SIGN_COLS].strip()

def centred(s):
    return max(0, (SIGN_COLS - len(s)) // 2)

# ----------------------------------------------------------------------------
# The header (PLAN.md section 4). Counts run 1..255 and wrap back to 1, so 0
# can mean "nothing yet"; the shader acts when a count changes.

def bump(n):
    return n % 255 + 1

H_BEAT, H_SYNC, H_STATION, H_TUNNEL, H_ENV, H_WIPE = range(6)
MARKER = (78, 84)          # "NT": tells the shader this program is the one running
PROTOCOL = 1

# ----------------------------------------------------------------------------
# The train, as this program sees it: states, a queue of stations to come,
# and a clock that stops while nobody can see the wallpaper.

TRAVEL, ARRIVING, DWELLING, LEAVING, SLEEP_PENDING, ASLEEP = \
    "TRAVEL", "ARRIVING", "DWELL", "LEAVING", "SLEEP_PENDING", "ASLEEP"
LINE_NAMES = ["mixed", "coast", "hills", "plains"]

class Train:
    def __init__(self, grid):
        self.g = grid
        self.state = TRAVEL
        self.idle_halt = False          # is the stop we're heading for (or at) the quiet one?
        self.phase_end = 0.0            # journey-clock time the current state is over
        self.queue = []                 # stations to come: [main, sub, how many merged, when]
        self.last_event = None          # journey clock, for the quiet spell
        self.last_queued = -1e9         # wall clock, for merging close events
        self.last_tunnel = -1e9
        self.hidden = False             # the desktop is covered
        self.hidden_since = 0.0
        self.paused_total = 0.0         # time spent hidden, taken off the journey clock
        self.beat = 0
        self.flags = 0
        self.force_night = FORCE_NIGHT
        self.counts = {"arrive": 0, "depart": 0, "tunnel": 0, "wipe": 0, "sync": 1}
        self.stop_in = 0
        self.last_input = "none"
        # the journey: kept on disk
        self.km = 0.0
        self.line = START_LINE
        self.weather, self.wind = "CLEAR", 60
        self.load()
        if self.last_event is None:
            self.last_event = self.jnow()
        self.next_weather = time.monotonic() + WEATHER_EVERY
        self.last_advance = self.jnow()

    # ---- the journey clock: wall time, minus the time spent hidden
    def jnow(self):
        now = time.monotonic()
        return now - self.paused_total - ((now - self.hidden_since) if self.hidden else 0.0)

    # ---- persistence
    def state_path(self):
        return os.path.join(STATE_DIR, "state.json")

    def load(self):
        try:
            with open(self.state_path()) as f:
                s = json.load(f)
            if s.get("version") != 1:
                raise ValueError("unknown version")
            self.km = float(s["km"])
            self.line = int(s["line"]) % 4
            if s.get("weather") in WEATHER_LOOK:
                self.weather = s["weather"]
            self.wind = int(s.get("wind", self.wind)) & 255
            # Idle time carries across a restart, but give it a couple of
            # minutes' travel first, rather than halting straight away.
            quiet = time.time() - float(s.get("last_event_at", time.time()))
            self.last_event = self.jnow() - min(max(quiet, 0.0), max(IDLE_AFTER - 120.0, 0.0))
            log(f"journey loaded: km {self.km:.1f}, line {self.line}")
        except FileNotFoundError:
            log("a new journey")
        except (ValueError, KeyError, TypeError) as e:
            log(f"state.json unreadable ({type(e).__name__}); a new journey")

    def save(self):
        private_dir(STATE_DIR)
        tile, offset = self.position()
        s = {"version": 1, "tile": tile, "offset": offset, "line": self.line, "km": round(self.km, 3),
             "weather": self.weather, "wind": self.wind,
             "last_event_at": time.time() - (self.jnow() - self.last_event)}
        tmp = self.state_path() + ".tmp"
        with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
            json.dump(s, f)
        os.replace(tmp, self.state_path())          # all or nothing, even if we're killed mid-write

    def position(self):
        """The rough position as the shader counts it: 1024 m tiles and metres."""
        m = START_TILE * 1024 + self.km * 1000.0
        return int(m // 1024) & 0xFFFFFF, int(m % 1024)

    def advance(self):
        """The km count moves on at the average speed while the train moves."""
        now = self.jnow()
        if self.state in (TRAVEL, ARRIVING, LEAVING) and not self.hidden:
            self.km += V_NOMINAL * (now - self.last_advance) / 1000.0
        self.last_advance = now

    # ---- the header cells
    def send_beat(self):
        self.g.cell(H_BEAT, 0, (self.beat, *MARKER), (PROTOCOL, self.flags | (2 if self.force_night else 0), 0))

    def send_sync(self):
        tile, offset = self.position()
        self.g.cell(H_SYNC, 0, (tile >> 16, tile >> 8, tile), (offset >> 8, offset, self.counts["sync"]))

    def send_station(self, kind=0):
        self.g.cell(H_STATION, 0, (self.counts["arrive"], self.stop_in // 8, kind), (self.counts["depart"], 0, 0))

    def send_env(self):
        rain, cond, cloud = WEATHER_LOOK[self.weather]
        self.g.cell(H_ENV, 0, (rain, cond, self.wind), (cloud, self.line, 0))

    def send_all(self):
        self.send_beat(); self.send_sync(); self.send_station()
        self.g.cell(H_TUNNEL, 0, (self.counts["tunnel"], 0, self.line))
        self.send_env()
        self.g.cell(H_WIPE, 0, (0, 0, 0), (self.counts["wipe"], 0, 0))

    def heartbeat(self):
        self.beat = (self.beat + 1) & 255
        self.send_beat()

    def awake(self):
        return self.state != ASLEEP and not self.hidden

    # ---- stations
    def event(self, main, sub=""):
        """Something happened: queue a station for it, merging it into the last
        one waiting if it came close behind (or the queue is full)."""
        main, sub = clean(main), clean(sub)
        if not main:
            return
        now = time.monotonic()
        if self.queue and (now - self.last_queued < EVENT_GAP or len(self.queue) >= QUEUE_MAX):
            last = self.queue[-1]
            last[2] += 1
            last[0] = clean(f"{last[2]} EVENTS")
            last[1] = sub if sub == last[1] else ""
        else:
            self.queue.append([main, sub, 1, now])
        self.last_queued = now
        self.last_event = self.jnow()
        log(f"event queued ({len(self.queue)} waiting)")
        if self.state in (ASLEEP, SLEEP_PENDING):
            self.wake()

    def announce(self, main, sub, idle=False):
        """ARRIVE: the sign's text and the order to stop go out in one write,
        so the shader never sees one without the other."""
        self.stop_in = random.randrange(STOP_IN[0], STOP_IN[1] + 1, 8)
        self.counts["arrive"] = bump(self.counts["arrive"])
        self.g.text(1, main, centred(main))
        self.g.text(2, sub, centred(sub))
        self.send_station(1 if idle else 0)
        self.idle_halt = idle
        self.state = ARRIVING
        margin = IDLE_MARGIN if idle else 0
        self.phase_end = self.jnow() + (self.stop_in + margin) / 12.0 + ARRIVE_SLACK
        log(f"arrive {'(idle halt)' if idle else ''} in {self.stop_in} m")

    def depart(self):
        self.counts["depart"] = bump(self.counts["depart"])
        self.send_station(1 if self.idle_halt else 0)
        self.state = LEAVING
        self.phase_end = self.jnow() + DEPART_CLEAR
        log("depart")

    def wake(self):
        log("waking")
        self.flags &= ~1
        self.heartbeat()
        self.depart()

    def tunnel(self, line=None):
        now = time.monotonic()
        if now - self.last_tunnel < TUNNEL_GAP:
            return
        self.last_tunnel = now
        self.line = (self.line + 1) % 4 if line is None else line
        length = random.randrange(TUNNEL_LEN[0], TUNNEL_LEN[1] + 1, 16)
        self.counts["tunnel"] = bump(self.counts["tunnel"])
        self.g.cell(H_TUNNEL, 0, (self.counts["tunnel"], length // 16, self.line))
        self.send_env()
        log(f"tunnel {length} m, then line {self.line}")

    def step(self):
        """Move the story on: called every tick."""
        now = self.jnow()
        self.advance()
        if self.hidden:
            return
        if self.state == TRAVEL:
            if self.queue:
                main, sub, _, _ = self.queue.pop(0)
                self.announce(main, sub)
            elif now - self.last_event > IDLE_AFTER:
                self.announce(clean(f"KM {int(self.km)}"), time.strftime("%H:%M"), idle=True)
        elif now < self.phase_end:
            return
        elif self.state == ARRIVING:
            if self.idle_halt and not self.queue:
                self.flags |= 1            # "sleeping soon": the shader settles everything
                self.send_beat()
                self.state = SLEEP_PENDING
                self.phase_end = now + SLEEP_FADE
                log("halted; sleeping soon")
            else:
                self.state = DWELLING
                self.phase_end = now + DWELL
        elif self.state == DWELLING:
            self.depart()
        elif self.state == LEAVING:
            self.state = TRAVEL
        elif self.state == SLEEP_PENDING:
            self.state = ASLEEP
            log("asleep")

    def weather_step(self):
        if time.monotonic() < self.next_weather:
            return
        self.next_weather = time.monotonic() + WEATHER_EVERY
        if random.random() >= WEATHER_STAY:
            nxt = WEATHER_NEXT[self.weather]
            self.weather = random.choices(list(nxt), weights=list(nxt.values()))[0]
        self.wind = max(0, min(255, int(self.wind * 0.5 + random.randint(*WIND) * 0.5)))
        self.send_env()
        log(f"weather {self.weather}")

    def cycle_weather(self):
        kinds = list(WEATHER_LOOK)
        self.weather = kinds[(kinds.index(self.weather) + 1) % len(kinds)]
        self.next_weather = time.monotonic() + WEATHER_EVERY
        self.send_env()

    # ---- visibility
    def set_hidden(self, hidden):
        if hidden == self.hidden:
            return
        self.advance()
        now = time.monotonic()
        if hidden:
            self.hidden_since = now
        else:
            self.paused_total += now - self.hidden_since
        self.hidden = hidden
        self.last_advance = self.jnow()
        log("hidden" if hidden else "visible")

    # ---- the status rows (seen only if the shader shows the raw terminal)
    def status(self):
        tile, offset = self.position()
        left = max(0.0, self.phase_end - self.jnow()) if self.state not in (TRAVEL, ASLEEP) else 0.0
        c = self.counts
        rows = [
            f"nighttrain  {self.state}{' (idle halt)' if self.idle_halt and self.state != TRAVEL else ''}"
            f"{'  ' + format(left, '.0f') + ' s left' if left else ''}  {'hidden' if self.hidden else 'visible'}",
            f"km {self.km:.1f}  tile {tile} + {offset} m  line {self.line} {LINE_NAMES[self.line]}"
            f"  weather {self.weather} wind {self.wind}{'  force night' if self.force_night else ''}",
            f"waiting {len(self.queue)}  counts: arrive {c['arrive']} depart {c['depart']} tunnel {c['tunnel']}"
            f" wipe {c['wipe']} sync {c['sync']}  last input: {self.last_input}",
        ]
        for i, s in enumerate(rows):
            self.g.text(4 + i, s)

# ----------------------------------------------------------------------------
# Input: neowall passes clicks on as xterm's SGR mouse reports (we ask for
# them at the start), ESC [ < button ; column ; row M (press) or m (release),
# counted from 1. Keys come through as typed, once the wallpaper has been
# clicked (neowall only gives it the keyboard then).

MOUSE = re.compile(rb"\x1b\[<(\d+);(\d+);(\d+)([Mm])")
PARTIAL = re.compile(rb"\x1b(\[(<[\d;]*)?)?\Z")
OTHER_ESC = re.compile(rb"\x1b\[[0-9;?]*[\x40-\x7e]|\x1b[^\[]")

class Input:
    def __init__(self, train):
        self.t = train
        self.buf = b""
        self.dragging = False

    def feed(self, data):
        self.buf += data
        while self.buf:
            m = MOUSE.match(self.buf)
            if m:
                self.mouse(int(m[1]), int(m[2]) - 1, int(m[3]) - 1, m[4] == b"M")
                self.buf = self.buf[m.end():]
                continue
            if self.buf[:1] == b"\x1b":
                if PARTIAL.match(self.buf):
                    return                  # the rest of it is still on its way
                m = OTHER_ESC.match(self.buf)
                self.buf = self.buf[m.end() if m else 1:]   # an arrow key or such: ignored
                continue
            self.key(self.buf[:1])
            self.buf = self.buf[1:]

    def mouse(self, b, x, y, press):
        t = self.t
        if b & 64:
            t.last_input = "wheel"          # nothing for the wheel, yet
            return
        button, motion = b & 3, bool(b & 32)
        if button == 0 and press:
            # a left press, or the pointer moving with it held: wipe the glass there
            t.counts["wipe"] = bump(t.counts["wipe"])
            t.g.cell(H_WIPE, 0, (x & 255, y & 255, (x >> 8) | ((y >> 8) << 4)), (t.counts["wipe"], 0, 0))
            t.last_input = "left drag" if motion else "left press"
        elif button == 2 and press and not motion:
            t.last_input = "right press"
            t.tunnel()
        elif button == 1:
            t.last_input = "middle"

    def key(self, k):
        t = self.t
        t.last_input = "key"                # which key, never
        k = k.lower()
        if k == b"s":
            t.event("TEST", time.strftime("%H:%M"))
        elif k == b"t":
            t.tunnel()
        elif k == b"r":
            t.cycle_weather()
        elif k == b"n":
            t.force_night = not t.force_night
            t.send_beat()
        elif k in (b"1", b"2", b"3", b"4"):
            t.tunnel(int(k) - 1)
        elif k == b"k":
            t.counts["sync"] = bump(t.counts["sync"])
            t.send_sync()

# ----------------------------------------------------------------------------
# The inbox: a named pipe. We hold it open for writing ourselves as well, so
# it never reads as closed between one writer and the next.

class Inbox:
    def __init__(self, train):
        self.t = train
        self.fd = self.keep = None
        self.buf = b""
        path = os.path.join(RUN_DIR, "inbox")
        try:
            try:
                os.mkfifo(path, 0o600)
            except FileExistsError:
                pass
            st = os.lstat(path)
            if not stat.S_ISFIFO(st.st_mode) or st.st_uid != os.getuid():
                log("the inbox isn't a pipe of ours; not using it")
                return
            os.chmod(path, 0o600)
            self.fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            self.keep = os.open(path, os.O_WRONLY | os.O_NONBLOCK)
        except OSError as e:
            log(f"no inbox ({e.strerror})")

    def read(self):
        try:
            data = os.read(self.fd, 4096)
        except BlockingIOError:
            return
        self.buf += data
        while b"\n" in self.buf:
            line, self.buf = self.buf.split(b"\n", 1)
            if len(line) > 512:
                continue                    # nothing that long is a station
            main, _, sub = line.decode("utf-8", "replace").partition("|")
            self.t.event(main, sub)
        if len(self.buf) > 4096:
            self.buf = b""

# ----------------------------------------------------------------------------
# Git: a new commit (HEAD moving) in any of your repos is a station.

class Git:
    def __init__(self, train):
        self.t = train
        self.repos, self.heads = [], {}
        self.next_scan = 0.0
        self.todo, self.next_check = [], 0.0

    def scan(self):
        found = []
        for root in GIT_ROOTS:
            root = os.path.expanduser(root)
            for dirpath, dirs, _ in os.walk(root):
                depth = dirpath[len(root):].count(os.sep)
                if os.path.exists(os.path.join(dirpath, ".git")):
                    found.append(dirpath)
                    dirs[:] = []            # a repo's insides are its own business
                    continue
                if depth >= GIT_DEPTH:
                    dirs[:] = []
                dirs[:] = [d for d in dirs if not any(fnmatch.fnmatch(d, p) for p in GIT_EXCLUDE)]
        self.repos = sorted(found)
        log(f"git: watching {len(self.repos)} repos")

    def git(self, repo, *args):
        env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0")
        try:
            r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, timeout=5,
                               stdin=subprocess.DEVNULL, env=env)
        except (OSError, subprocess.TimeoutExpired):
            return None
        return r.stdout.strip() if r.returncode == 0 else None

    def tick(self):
        now = time.monotonic()
        if now >= self.next_scan:
            self.next_scan = now + GIT_RESCAN
            self.scan()
        if now < self.next_check:
            return
        # One repo a tick, spread over GIT_EVERY, so no tick waits long.
        if not self.todo:
            self.todo = list(self.repos)
        if not self.todo:
            self.next_check = now + GIT_EVERY
            return
        self.next_check = now + GIT_EVERY / max(len(self.repos), 1)
        repo = self.todo.pop()
        head = self.git(repo, "rev-parse", "HEAD")
        old = self.heads.get(repo)
        if head:
            self.heads[repo] = head
        if head and old and head != old:
            n = self.git(repo, "rev-list", "--count", f"{old}..{head}")
            n = int(n) if n and n.isdigit() else 1
            self.t.event("COMMIT" if n <= 1 else f"{n} COMMITS", os.path.basename(repo))

# ----------------------------------------------------------------------------
# Hyprland: is the focused workspace empty? Its event socket says when
# anything that could change that happens; then we ask.

class Hypr:
    WATCH = (b"workspace", b"focusedmon", b"openwindow", b"closewindow", b"movewindow",
             b"changefloatingmode", b"fullscreen")

    def __init__(self, train):
        self.t = train
        self.sock = None
        self.buf = b""
        self.check_at = None
        self.retry_at = 0.0
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        base = os.environ.get("XDG_RUNTIME_DIR", "")
        # The real path, not one through a symlink: a socket's path must fit
        # in 108 bytes, and Hyprland's instance names are long.
        self.dir = os.path.realpath(os.path.join(base, "hypr", sig)) if sig and base else None
        self.said = None

    def connect(self, sel):
        if not self.dir or self.sock or time.monotonic() < self.retry_at:
            return
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(os.path.join(self.dir, ".socket2.sock"))
            s.setblocking(False)
            self.sock = s
            sel.register(s, selectors.EVENT_READ, "hypr")
            self.check_at = time.monotonic()
            log("hyprland: connected")
        except OSError as e:
            if e.strerror != self.said:     # say why once, not every 30 s
                self.said = e.strerror
                log(f"hyprland: can't connect ({e.strerror}); assuming the wallpaper can be seen")
            self.retry_at = time.monotonic() + 30
            self.t.set_hidden(False)        # without it, assume we can be seen

    def read(self, sel):
        try:
            data = self.sock.recv(65536)
        except BlockingIOError:
            return
        except OSError:
            data = b""
        if not data:
            log("hyprland: disconnected")
            sel.unregister(self.sock); self.sock.close(); self.sock = None
            self.t.set_hidden(False)
            return
        self.buf += data
        *lines, self.buf = self.buf.split(b"\n")
        if any(l.startswith(self.WATCH) for l in lines):
            self.check_at = time.monotonic() + 0.15     # let a burst of events settle

    def check(self):
        if self.check_at is None or time.monotonic() < self.check_at:
            return
        self.check_at = None
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(1.0)
                s.connect(os.path.join(self.dir, ".socket.sock"))
                s.sendall(b"j/activeworkspace")
                reply = b""
                while chunk := s.recv(65536):
                    reply += chunk
            self.t.set_hidden(json.loads(reply).get("windows", 0) > 0)
        except (OSError, ValueError):
            self.t.set_hidden(False)

# ----------------------------------------------------------------------------
# Setting up the terminal, and putting it back however we leave.

ENTER = f"{ESC}[?1049h{ESC}[?25l{ESC}[?7l{ESC}[?1002h{ESC}[?1006h{ESC}[0m{ESC}[2J"
LEAVE = f"{ESC}[?1006l{ESC}[?1002l{ESC}[?7h{ESC}[?25h{ESC}[0m{ESC}[?1049l"

def main():
    open_log()
    apply_overrides()
    log("starting")
    saved_tty = None
    try:
        saved_tty = termios.tcgetattr(0)
        tty.setraw(0)                        # clicks and keys arrive byte by byte, and nothing echoes
    except termios.error:
        pass

    def leave():
        try:
            os.write(1, LEAVE.encode())
        except OSError:
            pass
        if saved_tty:
            try:
                termios.tcsetattr(0, termios.TCSADRAIN, saved_tty)
            except termios.error:
                pass

    def on_signal(signum, _):
        raise SystemExit(0)
    for s in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(s, on_signal)
    resized = []
    signal.signal(signal.SIGWINCH, lambda *_: resized.append(1))

    grid = Grid()
    train = Train(grid)
    os.write(1, ENTER.encode())
    grid.resize()
    train.send_all()
    grid.flush()

    sel = selectors.DefaultSelector()
    fl = fcntl.fcntl(0, fcntl.F_GETFL)
    fcntl.fcntl(0, fcntl.F_SETFL, fl | os.O_NONBLOCK)
    sel.register(0, selectors.EVENT_READ, "stdin")
    inbox = Inbox(train)
    if inbox.fd is not None:
        sel.register(inbox.fd, selectors.EVENT_READ, "inbox")
    keys = Input(train)
    git = Git(train)
    hypr = Hypr(train)

    next_beat = next_status = time.monotonic()
    next_save = time.monotonic() + SAVE_EVERY
    try:
        while True:
            now = time.monotonic()
            wakeups = [next_save, now + 1.0]
            if train.awake():
                wakeups += [next_beat, next_status]
            if hypr.check_at is not None:
                wakeups.append(hypr.check_at)
            for key, _ in sel.select(max(0.0, min(wakeups) - now)):
                try:
                    if key.data == "stdin":
                        try:
                            data = os.read(0, 4096)
                        except BlockingIOError:
                            continue
                        if not data:
                            raise SystemExit(0)      # neowall has gone
                        keys.feed(data)
                    elif key.data == "inbox":
                        inbox.read()
                    elif key.data == "hypr":
                        hypr.read(sel)
                except SystemExit:
                    raise
                except Exception:
                    log("error handling input:\n" + traceback.format_exc())
            if resized:
                resized.clear()
                grid.resize()
                train.send_all()
            hypr.connect(sel)
            hypr.check()
            was_awake = train.awake()
            git.tick()
            train.weather_step()
            train.step()
            now = time.monotonic()
            if train.awake():
                if not was_awake or now >= next_beat:
                    train.heartbeat()
                    next_beat = now + BEAT_EVERY
                if now >= next_status:
                    train.status()
                    next_status = now + 1.0
            elif was_awake:
                train.status()                       # the last word before sleeping
            if now >= next_save:
                train.save()
                next_save = now + SAVE_EVERY
            # Asleep or hidden, nothing may be written: any change to the grid
            # makes neowall draw again for 0.7 s. (A new event wakes us first.)
            grid.flush()
    finally:
        try:
            train.save()
        except OSError as e:
            log(f"couldn't save: {e.strerror}")
        leave()
        log("stopped")

if __name__ == "__main__":
    main()
