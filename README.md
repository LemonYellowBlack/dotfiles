# dotfiles

Personal config for Arch Linux + Hyprland (Wayland), managed with [GNU Stow].
Kanagawa (Wave) theme throughout.

## Layout

Each top-level dir is a Stow package whose tree mirrors `$HOME`, e.g.
`hypr/.config/hypr/hyprland.lua` → `~/.config/hypr/hyprland.lua`.

| Area | Packages |
|------|----------|
| Shell / prompt | `zsh` `starship` |
| Terminal / editor | `kitty` `tmux` `nvim` `herdr` |
| Wayland desktop | `hypr` `quickshell` `neowall` `mako` `fuzzel` `gammastep` `waybar` `satty` |
| Theme | `kanagawa` `vivid` `gtk` |
| CLI tools | `bat` `bottom` `btop` `lazygit` `television` `yazi` `zathura` |
| Database | `psql` `pspg` |
| System | `git` `ssh` `environment.d` `mimeapps` |
| Scripts | `bin` (→ `~/.local/bin`) |
| Claude Code | `claude` (→ `~/.claude/statusline-command.sh`) |

`scripts/` is **not** a Stow package — it holds helper assets (e.g.
`kanagawa_wallpaper.py`) referenced by scripts in `bin/`. Don't stow it.

`theme/` isn't a Stow package either. `theme/theme.toml` holds every color: the
Kanagawa palette by name, the tokens that give each color a job (`accent`,
`surface`, `line`, …), the chrome roles, the terminal's 16 colors and the syntax
colors. `theme/retheme` writes them into the packages from the templates in
`theme/templates/`, each at the path it fills: whole theme files (kitty, bat,
yazi, television), `kanagawa/`'s `theme.{lua,conf,css}` for configs that name
colors themselves (Hyprland, hyprlock, waybar, nvim), and blocks between
`theme:begin` and `theme:end` lines inside configs that are otherwise
hand-edited (fuzzel, mako, zathura, starship, `.zshrc`, `.gitconfig`, …). Edit
`theme.toml`, then run `theme/retheme`; `--check` shows anything out of date.
The generated files are committed, so the other machine gets them by pulling;
`theme/retheme --reload` there rebuilds bat's theme cache and reloads what's
running.

`yazi`'s Kanagawa flavor is generated too, so it's no longer a `ya pkg`
dependency: `ya pkg upgrade` would overwrite it.

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

## Install

```sh
git clone https://github.com/LemonYellowBlack/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow zsh starship kitty tmux nvim hypr mako fuzzel gammastep waybar satty \
     kanagawa vivid gtk bat bottom btop lazygit television yazi zathura \
     psql pspg git ssh environment.d mimeapps claude
stow --no-folding bin herdr neowall quickshell

host=xps   # or hotdog
stow hypr-$host zsh-$host
stow --no-folding neowall-$host quickshell-$host
```

Stow only creates symlinks; install the underlying programs separately.

## Gotchas

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
- **The shell is the notification daemon.** mako and Quickshell both want
  `org.freedesktop.Notifications`, and Quickshell waits while mako holds it. mako isn't enabled
  anywhere; D-Bus starts it on the first notification nobody else is there for, so disabling it
  does nothing. Switch with `systemctl --user mask --now mako`; `unmask` switches back.
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
