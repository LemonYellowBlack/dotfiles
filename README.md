# dotfiles

Personal config for Arch Linux + Hyprland (Wayland), managed with [GNU Stow].
One theme throughout, Kanagawa Wave by default, from a palette system each
machine picks from (see [Theme](#theme)).

## Layout

Each top-level dir is a Stow package whose tree mirrors `$HOME`, e.g.
`hypr/.config/hypr/hyprland.lua` → `~/.config/hypr/hyprland.lua`.

| Area | Packages |
|------|----------|
| Shell / prompt | `zsh` |
| Terminal / editor | `kitty` `tmux` `nvim` `herdr` |
| Wayland desktop | `hypr` `quickshell` `neowall` `mako` `fuzzel` `gammastep` `waybar` |
| Theme | `gtk` (colors: `theme/`, below) |
| CLI tools | `bat` `btop` `lazygit` `television` `yazi` `zathura` |
| Database | `psql` `pspg` |
| System | `git` `ssh` `environment.d` `mimeapps` |
| Scripts | `bin` (→ `~/.local/bin`) |
| Claude Code | `claude` (→ `~/.claude/statusline-command.sh`) |

`scripts/` is **not** a Stow package — it holds helper assets (e.g.
`kanagawa_wallpaper.py`) referenced by scripts in `bin/`. Don't stow it. Nor are
`theme/` (below), `boot/` (the boot splash and greeter, see [Boot](#boot)), `zen/` (the browser's
prefs, see [Zen](#zen)) and `sbin/` (what sudo runs without a password, see [Gotchas](#gotchas)).

### Per-machine packages

`<pkg>-xps` and `<pkg>-hotdog` hold the files that differ between machines.
Each machine stows its own alongside the shared `<pkg>`, into the same
directory:

| Shared | Per machine | What differs |
|--------|-------------|--------------|
| `hypr` | `hypr-xps` `hypr-hotdog` | monitors, GPU env, idle, `host.lua` |
| `zsh` | `zsh-xps` `zsh-hotdog` | `~/.zshrc.local` |
| `neowall` | `neowall-xps` `neowall-hotdog` | `config.vibe` (which wallpaper); the shaders are shared |
| `quickshell` | `quickshell-xps` `quickshell-hotdog` | `Host.qml`: what hardware the Liquid shell can expect |

## Theme

Colors come from `theme/` (not a Stow package either), in three layers:

- **Palettes** (`theme/palettes/`): a set of colors under their own names
  (Kanagawa Wave, Dragon and Lotus, Catppuccin Mocha, Gruvbox Dark), each saying
  which of its colors fills the shared slots in `theme/slots.toml` (`bg0`, `fg`,
  `yellow`, `blue_bright`, …).
- **Variations** (`theme/variations/`): the tokens, the job each slot does:
  `accent`, `surface`, `line`, the terminal's 16, the syntax colors. They name
  slots, never a palette's own colors, so any variation works with any palette.
  `carp` is the default; `classic` is the shell's first, blue-and-violet look.
- **Hosts** (`theme/hosts/<host>.toml`): the palette and variation a machine
  uses, and the tokens it picks for itself. This is the only per-machine part:
  every config is shared, and only the colors in it differ.

`theme/retheme` (on `PATH` as `retheme`) renders a machine's theme through the
templates in `theme/templates/`, which sit at the path their output takes under
`$HOME`. The output belongs to that machine and is never committed. Most of it
goes to `~/.config/theme/`, which configs include: kitty, Hyprland, hyprlock,
nvim, fuzzel, mako, zathura, delta, psql, the Claude statusline, and zsh's fzf
colors and `LS_COLORS`. bat, yazi and television get a theme called `theme` in
their own directories (`.gitignore` covers the ones that land in here).
starship, bottom and satty can't include a file, so their whole config is a
template: edit `theme/templates/.config/starship.toml`, not `~/.config`. The
Liquid shell's `Theme.qml` watches `~/.config/theme/theme.json` and recolors in
place.

```sh
retheme                    # render this machine's theme, reload what reads it
retheme status             # its palette, variation and overrides
retheme palette kanagawa-dragon
retheme variation classic
retheme set accent blue    # this machine only; `retheme unset accent` undoes it
retheme copy hotdog        # take the other machine's picks
retheme save dusk          # keep the current picks as a new variation
retheme lint               # render every palette with every variation
RETHEME_HOME=/tmp/t RETHEME_HOST=hotdog retheme   # render elsewhere, as another machine; reloads nothing
```

The Liquid shell's colors drawer (`SUPER T`, or the palette button in the
control center) does the same with swatches. A pick rewrites `theme/hosts/<host>.toml`: commit it to
keep it. After a pull, run `retheme` to render whatever changed. A new machine
needs its host file first: `retheme copy xps`.

## Boot

From power on to the desktop and back is one picture, the wallpaper:

1. The firmware's logo. Plymouth's first frame (`boot/plymouth/`) draws the same logo in the same
   place, then fades it into the wallpaper. Its bright stars breathe and now and then a meteor
   crosses, like `galaxy.glsl`'s.
2. Just before the greeter starts, the splash fades to black (a `plymouth-quit` drop-in in
   `boot/systemd/`).
3. The greeter (`greeter.qml` in the shell, run by greetd in a Hyprland of its own from
   `boot/greeter/`) comes in from black: first the wallpaper, then the lock screen's blur, the frame
   growing in from the edges, and the clock. It logs in through greetd, and its power button can
   suspend, restart or shut down.
4. The session's first shell grows its frame in again over neowall's wallpaper.
5. Log out, restart or shut down from the power menu, and the outro (`surfaces/OutroView.qml`)
   clears the windows to the wallpaper, lets the frame go and fades to black. Plymouth's shutdown
   screen then comes up dim with the bar's island saying "shutting down" or "restarting".

`boot/install` sets it all up and needs root once. It keeps a copy of every file it changes as
`FILE.liquid-orig`:

```sh
sudo ~/dotfiles/boot/install          # plymouth + greetd, the splash, the hook, kernel line, greeter
sudo ~/dotfiles/boot/install theme    # re-render the splash after a new wallpaper or palette
sudo ~/dotfiles/boot/install undo     # back to the text login on tty1 and no splash
boot/plymouth/render /tmp/splash      # see what the splash would be drawn from, as yourself
~/dotfiles/boot/plymouth/try shutdown # play the installed splash in a window (asks for root)
qs -p ~/.config/quickshell/liquid/greeter.qml   # the greeter as a preview: checks nothing, Esc closes
qs -c liquid ipc call shell leave preview      # the outro, played back without leaving
```

The splash is rendered from the wallpaper and theme as they are when it runs. A retheme or a new
wallpaper doesn't reach it until `install theme`. The greeter reads the live config, so it follows
both. It runs as greetd's `greeter` user, so it relies on your home, `~/.config` and the wallpaper
being world-readable, as they are now. If it ever won't come up, Ctrl+Alt+F2 gives a text login
to run `undo` from. The kernel line hides the console cursor everywhere, the TTYs too.

## Zen

Zen keeps its settings in a profile folder with a random name (`~/.config/zen/ezewh6oe.Default
(release)`) that differs per machine, so it can't be a Stow package. `zen/link` finds the default
profile from `installs.ini` and links three files into it, and nothing else of the profile (cookies,
history, logins, `prefs.js`) comes near the repo:

- `user.js` → `zen/user.js`: telemetry off, and Zen told to read the two stylesheets below.
- `chrome/userChrome.css` and `chrome/userContent.css` → `~/.config/theme/zen/`, rendered by
  `retheme` from `theme/templates/.config/theme/zen/`. They paint the space behind a page, and
  `about:blank`, in the `content` token, so there's no white flash between page loads.

```sh
~/dotfiles/zen/link        # after retheme; safe to run again, keeps what was there as FILE.dotfiles-orig
~/dotfiles/zen/link undo   # remove the links, put the originals back
```

Zen reads all three only at startup: restart it after a `retheme` or an edit to `user.js`. A pref
in `user.js` wins over `about:config` at every start, and taking a line out doesn't undo it; reset
it in `about:config` too. `chrome/zen-themes.css` belongs to Zen Mods and stays out of the repo.

## Install

```sh
git clone https://github.com/LemonYellowBlack/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow zsh kitty tmux nvim hypr mako fuzzel gammastep waybar \
     gtk bat btop lazygit television yazi zathura \
     psql pspg git ssh environment.d mimeapps claude
stow --no-folding bin herdr neowall quickshell

host=xps   # or hotdog
stow hypr-$host zsh-$host
stow --no-folding neowall-$host quickshell-$host
theme/retheme              # colors; on a new machine, `theme/retheme copy xps` first
zen/link                   # Zen's prefs and theme into its profile (start Zen once first)
```

Stow only creates symlinks; install the underlying programs separately.

On a host with the exit node tile (`Host.exitNode`), make yourself Tailscale's operator once so
the shell can switch exit nodes without sudo: `sudo tailscale set --operator=$USER`.

On the XPS, `sudo sbin/install` puts `gpu-on`, `gpu-off` and `platform-profile` in
`/usr/local/sbin` for the GPU and profile toggles. It only moves NOPASSWD rules that already exist;
on a new machine, add them with `sudo visudo -f /etc/sudoers.d/dotfiles`:
`yourname ALL=(root) NOPASSWD: /usr/local/sbin/gpu-on, /usr/local/sbin/gpu-off, /usr/local/sbin/platform-profile`.

## Gotchas

- **What sudo runs without a password lives in `sbin/`, never `bin/`.** Everything in this repo
  can be changed by you without root, so a NOPASSWD rule naming a file here (or its link in
  `~/.local/bin`) lets anything running as you become root. `sbin/install` copies the helpers to
  `/usr/local/sbin`, owned by root, and the rules name those copies. After editing one, run
  `sudo sbin/install` again; until then root keeps running the old copy.
- **`bin` must use `--no-folding`.** `~/.local/bin` is a standard install
  target (`pip --user`, `cargo`, `pipx`, `go install`). Without `--no-folding`,
  Stow collapses it into a single directory symlink and those installers would
  write into this repo. `--no-folding` keeps `~/.local/bin` a real directory
  with per-file symlinks.
- **`herdr` must use `--no-folding` too**, for the mirror-image reason: herdr
  itself writes runtime state into `~/.config/herdr` alongside `config.toml` —
  two Unix sockets, three logs, and a constantly-rewritten `session.json`.
  Folded, that directory becomes one symlink into this repo and all of it
  lands in git. Only `config.toml` belongs here.
- **`hypr` is folded** — `~/.config/hypr` is a single directory symlink into
  this repo, so any file a tool auto-generates there lands in git. Re-stow with
  `stow --restow --no-folding hypr` if that becomes a problem.
- **Hyprland's config is Lua**, not hyprlang (`hyprland.conf` is deprecated since 0.55). The API
  stubs are at `/usr/share/hypr/stubs/hl.meta.lua`; `hyprctl reload` applies an edit.
- **`neowall` must use `--no-folding` too**, same reason as herdr: neowall
  writes a runtime `state` file into `~/.config/neowall/` beside
  `config.vibe` and `shaders/`. On a machine with no `~/.config/neowall` yet,
  a plain `stow` folds it and `state` lands in git. `neowall-<host>` too: it
  adds `config.vibe` to that same directory, which only works while it's a
  real directory and not one symlink into `neowall/`.
- **`quickshell` must use `--no-folding` too**, and so must `quickshell-<host>`: the host
  package adds `Host.qml` to the same `~/.config/quickshell/liquid/` directory, which only works
  while it's a real directory. Start the shell with `qs -c liquid`; `hypr/liquid.lua` (required
  from `hyprland.lua`) starts it with Hyprland, sets the look it's drawn for and binds its keys.
  `qs -c liquid ipc call shell reload` re-reads the config after edits the shell missed (an
  editor that saves by replacing the file, a `git pull`).
- **The shell is the notification daemon.** mako and Quickshell both want
  `org.freedesktop.Notifications`, and Quickshell waits while mako holds it. mako isn't enabled
  anywhere; D-Bus starts it on the first notification nobody else is there for, so disabling it
  does nothing. Switch with `systemctl --user mask --now mako`; `unmask` switches back.
- **The shell is the lock screen.** SUPER L, the power menu, idle and sleep all go through
  `loginctl lock-session`, and hypridle's `lock_cmd` asks the shell to lock
  (`qs -c liquid ipc call lock lock`), falling back to hyprlock when the shell isn't running.
  `qs -c liquid ipc call lock preview` shows it in an ordinary window, with the real password
  check, that Esc closes. If the shell dies while locked, the session stays locked: from a TTY,
  `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'` starts hyprlock to unlock with.
- **The homelab drawer runs `bin/labstatus` on hotdog**, over SSH from the XPS, so hotdog needs
  `bin` stowed and the XPS needs an SSH key it can use without a prompt.
- **`pspg`'s theme uses colour *names*, not hex — keep it that way.** pspg
  renders hex by reassigning 256-colour palette slots from 64 up, via the
  terminfo `initc` capability (an `OSC 4` sequence). Nvim's built-in terminal
  does not implement `OSC 4` and only lets indices 0–15 be set, so a hex theme
  leaves those slots at their default xterm-cube values — almost all greens —
  and the pager renders as a green wash inside `:terminal`. Colour names stay
  within 0–15, which kanagawa.nvim already populates. `TERM=xterm-direct` is not
  a way out: it makes pspg emit true colour as `38:2::R:G:B`, and nvim
  mis-parses that empty-colourspace form, shifting channels for a pink wash.
- **`psql` needs a real UTF-8 locale.** `.psqlrc` sets `\pset linestyle unicode`
  and `\pset null '∅'`, and the prompt uses `❯`. If `LANG` names a locale that
  isn't generated, glibc silently falls back to non-UTF-8 `C` and every
  multi-byte character renders as separate caret-notation cells (`~T~B`).
  Check with `locale`; fix by enabling the locale in `/etc/locale.gen` and
  running `locale-gen`.
- A stowed file shows as a symlink (`ls -l`); a plain file means that config
  isn't stowed and has drifted from the repo.

[GNU Stow]: https://www.gnu.org/software/stow/
