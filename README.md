# dotfiles

Personal config for Arch Linux + Hyprland (Wayland), managed with [GNU Stow].
Kanagawa (Wave) theme throughout.

## Layout

Each top-level dir is a Stow package whose tree mirrors `$HOME`, e.g.
`hypr/.config/hypr/hyprland.conf` → `~/.config/hypr/hyprland.conf`.

| Area | Packages |
|------|----------|
| Shell / prompt | `zsh` `starship` |
| Terminal / editor | `kitty` `nvim` |
| Wayland desktop | `hypr` `mako` `fuzzel` `gammastep` `waybar` |
| Theme | `kanagawa` `vivid` `gtk` |
| CLI tools | `bat` `bottom` `btop` `television` `yazi` `zathura` |
| Database | `psql` `pspg` |
| System | `git` `ssh` `environment.d` `mimeapps` |
| Scripts | `bin` (→ `~/.local/bin`) |

`scripts/` is **not** a Stow package — it holds helper assets (e.g.
`kanagawa_wallpaper.py`) referenced by scripts in `bin/`. Don't stow it.

## Install

```sh
git clone git@forgejo:lemonyellowblack/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow zsh starship kitty nvim hypr mako fuzzel gammastep waybar \
     kanagawa vivid gtk bat bottom btop television yazi zathura \
     psql pspg git ssh environment.d mimeapps
stow --no-folding bin
```

Stow only creates symlinks; install the underlying programs separately.

## Gotchas

- **`bin` must use `--no-folding`.** `~/.local/bin` is a standard install
  target (`pip --user`, `cargo`, `pipx`, `go install`). Without `--no-folding`,
  Stow collapses it into a single directory symlink and those installers would
  write into this repo. `--no-folding` keeps `~/.local/bin` a real directory
  with per-file symlinks.
- **`hypr` is folded** — `~/.config/hypr` is a single directory symlink into
  this repo, so any file a tool auto-generates there lands in git. Re-stow with
  `stow --restow --no-folding hypr` if that becomes a problem.
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
