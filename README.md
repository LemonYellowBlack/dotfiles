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
     git ssh environment.d mimeapps
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
- A stowed file shows as a symlink (`ls -l`); a plain file means that config
  isn't stowed and has drifted from the repo.

[GNU Stow]: https://www.gnu.org/software/stow/
