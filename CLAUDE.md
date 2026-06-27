# dotfiles

GNU Stow packages for terminal, editor, window manager, and supporting tools. Each top-level directory is one stow package.

## Stow workflow

```bash
cd ~/dotfiles
stow -n -v <pkg>   # dry-run (always do this first)
stow       <pkg>   # apply
stow -D    <pkg>   # unstow
stow -R    <pkg>   # restow (after structural changes)
```

No `-t` flag needed — stow's default target is the parent of the package dir (`~`).

A package's directory layout mirrors `~`. So `kitty/.config/kitty/kitty.conf` → `~/.config/kitty/kitty.conf` after stowing.

## Packages

**Terminal & shell**
- `kitty` — terminal emulator
- `zsh` — shell config (alias hub: `vltopen`, `vltget`, `srv`, etc.)
- `starship` — prompt
- `bat` — `cat` replacement, kanagawa-themed
- `vivid` — `LS_COLORS` generator, kanagawa-themed

**Editor**
- `nvim` — neovim, kanagawa via upstream `kanagawa.nvim` plugin, transparent bg

**Hyprland desktop (Arch only)**
- `hypr` — compositor (hyprland.conf, hypridle, hyprlock, hyprpaper)
- `waybar` — status bar
- `mako` — notifications
- `fuzzel` — launcher
- `gammastep` — blue light filter
- `gtk` — gtk-3.0 / gtk-4.0 settings
- `mimeapps` — default applications

**TUI tools**
- `btop` — process monitor
- `bottom` — alternative process monitor
- `yazi` — file manager
- `television` — fuzzy picker
- `zathura` — PDF viewer

**Theming source-of-truth**
- `kanagawa` — shared role files for kitty/hyprland/waybar (see Theming below)

**Misc**
- `git` — gitconfig
- `ssh` — ssh client config
- `environment.d` — systemd user environment
- `scripts` — `~/.local/bin` shell scripts (`caff`, `gpu-toggle`, `statuspopup`, etc.)

## Theming: Kanagawa

All themed tools use the [kanagawa](https://github.com/rebelot/kanagawa.nvim) palette. Two layers:

**1. Palette + role spec** — [`kanagawa-palette.md`](kanagawa-palette.md)

The full Wave/Dragon/Lotus palettes plus the four semantic chrome roles used across this repo:

| Role | Hex | Palette name | Used for |
|---|---|---|---|
| content | `#1F1F28` | sumiInk3 | editor/terminal/notification body, active tab bg |
| chrome | `#16161D` | sumiInk0 | tab/status bars, inactive tab bg |
| focus accent | `#2D4F67` | waveBlue2 | active borders, focused window frame, selection bg |
| dim accent | `#2A2A37` | sumiInk4 | inactive borders |

**2. Shared role files** — [`kanagawa/.config/kanagawa/`](kanagawa/.config/kanagawa/)

Three files, one per config language. Sourced by kitty / hyprland / waybar; edit once and changes propagate.

| File | Format | Consumed by |
|---|---|---|
| `roles.conf` | kitty `key value` | `kitty.conf` via `include ~/.config/kanagawa/roles.conf` |
| `roles.hypr` | hyprland `$var` | `hyprland.conf` via `source = ~/.config/kanagawa/roles.hypr` |
| `roles.css` | GTK `@define-color` | `waybar/style.css` via `@import "../kanagawa/roles.css";` |

**Tools with inline color values** (need per-file edits): mako, fuzzel, btop, yazi, television, starship, vivid, bat, nvim. To change a role across these, `rg <hex> dotfiles/`.

To change a palette role across the whole desktop:
1. Edit the matching role in all three files under `kanagawa/.config/kanagawa/`
2. `rg <old-hex> dotfiles/` and update inline values
3. Update the role table in `kanagawa-palette.md`
4. Reload affected daemons (`hyprctl reload`, restart waybar, kitty picks up on next launch)
