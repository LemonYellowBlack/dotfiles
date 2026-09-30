# drive.py: run termtest.sh in a 160x45 pseudo-terminal, like neowall does,
# send it the byte sequences neowall would send for clicks/wheel/keys, and
# save everything it prints, cumulatively, after each step.
import os, sys, time, fcntl, termios, struct, select
script, outdir = sys.argv[1], sys.argv[2]
master, slave = os.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 45, 160, 0, 0))
pid = os.fork()
if pid == 0:
    os.setsid(); fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
    for fd in (0, 1, 2): os.dup2(slave, fd)
    os.close(master); os.close(slave)
    env = dict(os.environ, TERM='xterm-256color', COLORTERM='truecolor', XDG_RUNTIME_DIR=outdir)
    os.execve('/usr/bin/bash', ['bash', script], env)
os.close(slave)
out = bytearray()
def pump(secs):
    end = time.time() + secs
    while time.time() < end:
        r, _, _ = select.select([master], [], [], 0.02)
        if r:
            try: out.extend(os.read(master, 65536))
            except OSError: return
steps = [
    ('start', b''),
    ('left click col 41 row 12', b'\x1b[<0;41;12M\x1b[<0;41;12m'),
    ('wheel up x2', b'\x1b[<64;41;12M\x1b[<64;41;12M'),
    ('right click', b'\x1b[<2;10;10M\x1b[<2;10;10m'),
    ('middle click', b'\x1b[<1;5;5M\x1b[<1;5;5m'),
    ('junk typing + arrow key', b'hello\x1b[A'),
    ('left drag to col 50 row 20', b'\x1b[<32;50;20M'),
    ('key 1 (scene 1) then r (rain) for 1.3 s', b'1r'),
]
for i, (name, data) in enumerate(steps):
    if data: os.write(master, data)
    pump(1.3 if b'r' in data and name.startswith('key') else 0.6)
    open(f'{outdir}/step{i}.bin', 'wb').write(out)
    print(f'step{i}: {name} ({len(out)} bytes so far)')
os.kill(pid, 15); pump(0.3); os.waitpid(pid, 0)
open(f'{outdir}/final.bin', 'wb').write(out)
