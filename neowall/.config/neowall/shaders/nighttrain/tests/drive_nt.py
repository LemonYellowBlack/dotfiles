#!/usr/bin/env python3
# drive_nt.py: runs a terminal-mode wallpaper program the way neowall does (in
# a pseudo-terminal, as its controlling terminal), acts out a scenario on it
# (clicks, drags, keys, inbox lines, at set times) and records everything it
# prints, with the time it printed it. tools/bin/harness_term -R plays the
# recording back through neowall's own terminal emulator, frame by frame, so a
# shader can be checked against exactly what the program did.
#
#   python3 tests/drive_nt.py PROGRAM SCENARIO OUT.rec [--cols 160] [--rows 45]
#                             [--keep-hypr] [--state DIR]
#
# The program runs as `python3 PROGRAM` (or directly, if it isn't a .py),
# with its XDG_RUNTIME_DIR (log, inbox) and XDG_STATE_HOME (state.json) in a
# fresh temporary directory, so a test never touches the real ones. SSH_AUTH_SOCK is removed, as the
# vibe does. HYPRLAND_INSTANCE_SIGNATURE is removed too (so the program
# assumes it's visible) unless --keep-hypr, which links the real Hyprland
# sockets into the temp dir so it follows the real workspace. --state DIR
# keeps state.json in DIR instead, so a second run can test a restart.
#
# Scenario files: one action a line, # starts a comment.
#   set NAME VALUE           a SETTINGS override for the program, VALUE in JSON
#                            (set IDLE_AFTER 20, set GIT_ROOTS ["/tmp/x"])
#   keep                     don't delete the temp dir at the end
#   at T ACTION ...          do ACTION T seconds after the program started
#   +D ACTION ...            do ACTION D seconds after the previous one
# Actions (cells are 0-based column, row; neowall reports them 1-based):
#   click X Y                left press, then release
#   rclick X Y / mclick X Y  the same with the right / middle button
#   press X Y [left|middle|right] / release X Y [...]
#   drag X0 Y0 X1 Y1 SECS    left press, motion reports every 50 ms, release
#   wheel up|down X Y
#   key TEXT                 typed bytes (Python escapes work: key \x1b[A)
#   inbox LINE               a line written to the program's inbox
#   end                      SIGTERM the program (and record how it tidies up)
import json, os, sys, time, fcntl, termios, struct, select, signal, shutil, tempfile, argparse

def parse_scenario(path):
    overrides, actions, keep, t = {}, [], False, 0.0
    for n, raw in enumerate(open(path), 1):
        line = raw.strip()
        # A # starts a comment, except on inbox and key lines, whose text may
        # hold one (a sign can read "#42").
        if line.startswith('#') or not line:
            continue
        if ' inbox ' not in line and ' key ' not in line:
            line = line.split('#', 1)[0].strip()
        words = line.split()
        if words[0] == 'set':
            overrides[words[1]] = json.loads(line.split(None, 2)[2])
        elif words[0] == 'keep':
            keep = True
        elif words[0] == 'at' or words[0].startswith('+'):
            if words[0] == 'at':
                t, rest = float(words[1]), line.split(None, 2)[2]
            else:
                t, rest = t + float(words[0][1:]), line.split(None, 1)[1]
            actions.append((t, rest))
        else:
            sys.exit(f'{path}:{n}: what is "{words[0]}"?')
    actions.sort(key=lambda a: a[0])
    return overrides, actions, keep

BUTTON = {'left': 0, 'middle': 1, 'right': 2}

def sgr(b, x, y, press=True):
    return f'\x1b[<{b};{x + 1};{y + 1}{"M" if press else "m"}'.encode()

def expand(t, rest):
    """An action as one or more (time, kind, payload) steps."""
    w = rest.split()
    kind = w[0]
    if kind in ('click', 'rclick', 'mclick'):
        b = {'click': 0, 'rclick': 2, 'mclick': 1}[kind]
        x, y = int(w[1]), int(w[2])
        return [(t, 'bytes', sgr(b, x, y)), (t + 0.03, 'bytes', sgr(b, x, y, False))]
    if kind in ('press', 'release'):
        b = BUTTON[w[3]] if len(w) > 3 else 0
        return [(t, 'bytes', sgr(b, int(w[1]), int(w[2]), kind == 'press'))]
    if kind == 'drag':
        x0, y0, x1, y1, secs = int(w[1]), int(w[2]), int(w[3]), int(w[4]), float(w[5])
        steps = [(t, 'bytes', sgr(0, x0, y0))]
        n = max(1, int(secs / 0.05))
        last = (x0, y0)
        for i in range(1, n + 1):
            x, y = round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)
            if (x, y) != last:                     # xterm reports motion only when the cell changes
                steps.append((t + secs * i / n, 'bytes', sgr(32, x, y)))
                last = (x, y)
        steps.append((t + secs + 0.02, 'bytes', sgr(0, x1, y1, False)))
        return steps
    if kind == 'wheel':
        b = 64 if w[1] == 'up' else 65
        return [(t, 'bytes', sgr(b, int(w[2]), int(w[3])))]
    if kind == 'key':
        text = rest.split(None, 1)[1]
        return [(t, 'bytes', text.encode('latin-1').decode('unicode_escape').encode('latin-1'))]
    if kind == 'inbox':
        return [(t, 'inbox', (rest.split(None, 1)[1] + '\n').encode())]
    if kind == 'end':
        return [(t, 'end', b'')]
    sys.exit(f'unknown action "{kind}"')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('program'); ap.add_argument('scenario'); ap.add_argument('out')
    ap.add_argument('--cols', type=int, default=160); ap.add_argument('--rows', type=int, default=45)
    ap.add_argument('--keep-hypr', action='store_true')
    ap.add_argument('--state', help='use this as XDG_STATE_HOME (kept), to test a restart')
    a = ap.parse_args()
    overrides, actions, keep = parse_scenario(a.scenario)
    steps = sorted((s for t, rest in actions for s in expand(t, rest)), key=lambda s: s[0])
    if not steps or steps[-1][1] != 'end':
        steps.append(((steps[-1][0] if steps else 0) + 1.0, 'end', b''))

    tmp = tempfile.mkdtemp(prefix='nt-drive-')
    run, state = os.path.join(tmp, 'run'), a.state or os.path.join(tmp, 'state')
    os.mkdir(run, 0o700); os.makedirs(state, 0o700, exist_ok=True)
    env = dict(os.environ, TERM='xterm-256color', COLORTERM='truecolor', XDG_RUNTIME_DIR=run, XDG_STATE_HOME=state)
    env.pop('SSH_AUTH_SOCK', None)
    if a.keep_hypr and os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        os.symlink(os.path.join(os.environ['XDG_RUNTIME_DIR'], 'hypr'), os.path.join(run, 'hypr'))
    else:
        env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    if overrides:
        env['NIGHTTRAIN_OVERRIDES'] = json.dumps(overrides)
    print(f'temp dir {tmp}', file=sys.stderr)

    master, slave = os.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', a.rows, a.cols, 0, 0))
    t0 = time.monotonic()
    pid = os.fork()
    if pid == 0:
        os.setsid(); fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
        for fd in (0, 1, 2):
            os.dup2(slave, fd)
        os.close(master); os.close(slave)
        argv = ['python3', a.program] if a.program.endswith('.py') else [a.program]
        os.execvpe(argv[0], argv, env)
    os.close(slave)

    chunks = []
    def pump(until):
        while True:
            left = until - (time.monotonic() - t0)
            if left <= 0:
                return True
            r, _, _ = select.select([master], [], [], min(left, 0.02))
            if r:
                try:
                    data = os.read(master, 65536)
                except OSError:
                    return False                       # the program has gone
                if not data:
                    return False
                chunks.append((time.monotonic() - t0, data))

    inbox = os.path.join(run, 'nighttrain', 'inbox')
    alive = True
    for t, kind, payload in steps:
        alive = alive and pump(t)
        if kind == 'end' or not alive:
            break
        if kind == 'bytes':
            os.write(master, payload)
        elif kind == 'inbox':
            for _ in range(40):                        # the program makes the inbox as it starts
                try:
                    fd = os.open(inbox, os.O_WRONLY | os.O_NONBLOCK)
                    os.write(fd, payload); os.close(fd)
                    break
                except OSError:
                    pump(time.monotonic() - t0 + 0.05)
            else:
                print(f'{t:.2f}: no inbox to write to', file=sys.stderr)
    end = time.monotonic() - t0
    if alive:
        os.kill(pid, signal.SIGTERM)
        pump(end + 0.6)
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    _, status = os.waitpid(pid, 0)

    with open(a.out, 'wb') as f:
        f.write(f'NTREC 1 {a.cols} {a.rows}\n'.encode())
        for t, data in chunks:
            f.write(struct.pack('<dI', t, len(data)) + data)
    total = sum(len(d) for _, d in chunks)
    print(f'{a.out}: {len(chunks)} chunks, {total} bytes over {end:.1f} s; exit status {status >> 8}', file=sys.stderr)
    log = os.path.join(run, 'nighttrain', 'log')
    if os.path.exists(log):
        print('--- the program\'s log ---\n' + open(log).read()[-3000:], file=sys.stderr)
    if not keep:
        shutil.rmtree(tmp, ignore_errors=True)

main()
