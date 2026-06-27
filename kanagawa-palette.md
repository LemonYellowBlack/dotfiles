# Kanagawa Color Palette

Reference for the [kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim) theme.

## Semantic roles

The four chrome roles used across all themed tools in this repo. Source of truth for the role files at `~/.config/kanagawa/roles.{conf,hypr,css}`.

| Role | Hex | Palette name | Used for |
|---|---|---|---|
| content | `#1F1F28` | sumiInk3 | editor/terminal/notification body, active tab bg |
| chrome | `#16161D` | sumiInk0 | tab/status bars, inactive tab bg, window dim |
| focus accent | `#2D4F67` | waveBlue2 | active borders, focused window frame, selection bg |
| dim accent | `#2A2A37` | sumiInk4 | inactive borders |

**Shared via include** (edit `~/.config/kanagawa/roles.*` once): kitty, hyprland, waybar.
**Inline values** (grep + edit per tool): mako, fuzzel, btop, yazi, television, starship, vivid, bat, nvim.

To change a role across the shared tools, edit the matching file in the [`kanagawa/`](kanagawa/.config/kanagawa/) stow package. To change a role across inline tools, `rg <hex> dotfiles/`.

## Wave (dark default)

### Backgrounds

| Name | Hex | Preview |
|---|---|---|
| sumiInk0 | `#16161D` | darkest bg |
| sumiInk1 | `#181820` | |
| sumiInk2 | `#1a1a22` | |
| sumiInk3 | `#1F1F28` | default bg |
| sumiInk4 | `#2A2A37` | darker fg (line numbers) |
| sumiInk5 | `#363646` | |
| sumiInk6 | `#54546D` | |

### Popup and Float

| Name | Hex | Preview |
|---|---|---|
| waveBlue1 | `#223249` | popup bg |
| waveBlue2 | `#2D4F67` | popup highlight |

### Diff and Git

| Name | Hex | Preview |
|---|---|---|
| winterGreen | `#2B3328` | diff add bg |
| winterYellow | `#49443C` | diff change bg |
| winterRed | `#43242B` | diff delete bg |
| winterBlue | `#252535` | diff line bg |
| autumnGreen | `#76946A` | git add |
| autumnRed | `#C34043` | git delete |
| autumnYellow | `#DCA561` | git change |

### Diagnostics

| Name | Hex | Preview |
|---|---|---|
| samuraiRed | `#E82424` | error |
| roninYellow | `#FF9E3B` | warning |
| waveAqua1 | `#6A9589` | hint |
| dragonBlue | `#658594` | info |

### Foreground and Syntax

| Name | Hex | Preview |
|---|---|---|
| fujiWhite | `#DCD7BA` | default fg |
| oldWhite | `#C8C093` | dark fg |
| fujiGray | `#727169` | comments |
| oniViolet | `#957FB8` | statements, keywords |
| oniViolet2 | `#b8b4d0` | |
| crystalBlue | `#7E9CD8` | functions |
| springViolet1 | `#938AA9` | light fg |
| springViolet2 | `#9CABCA` | brackets |
| springBlue | `#7FB4CA` | specials |
| lightBlue | `#A3D4D5` | |
| waveAqua2 | `#7AA89F` | types |
| springGreen | `#98BB6C` | strings |
| boatYellow1 | `#938056` | |
| boatYellow2 | `#C0A36E` | operators |
| carpYellow | `#E6C384` | identifiers |
| sakuraPink | `#D27E99` | numbers |
| waveRed | `#E46876` | standout specials |
| peachRed | `#FF5D62` | standout specials 2 |
| surimiOrange | `#FFA066` | constants, params |
| katanaGray | `#717C7C` | |

## Dragon (dark warm)

### Backgrounds

| Name | Hex | Preview |
|---|---|---|
| dragonBlack0 | `#0d0c0c` | |
| dragonBlack1 | `#12120f` | |
| dragonBlack2 | `#1D1C19` | |
| dragonBlack3 | `#181616` | default bg |
| dragonBlack4 | `#282727` | |
| dragonBlack5 | `#393836` | |
| dragonBlack6 | `#625e5a` | |

### Foreground and Syntax

| Name | Hex | Preview |
|---|---|---|
| dragonWhite | `#c5c9c5` | default fg |
| dragonGreen | `#87a987` | |
| dragonGreen2 | `#8a9a7b` | |
| dragonPink | `#a292a3` | |
| dragonOrange | `#b6927b` | |
| dragonOrange2 | `#b98d7b` | |
| dragonGray | `#a6a69c` | |
| dragonGray2 | `#9e9b93` | |
| dragonGray3 | `#7a8382` | |
| dragonBlue2 | `#8ba4b0` | |
| dragonViolet | `#8992a7` | |
| dragonRed | `#c4746e` | |
| dragonAqua | `#8ea4a2` | |
| dragonAsh | `#737c73` | |
| dragonTeal | `#949fb5` | |
| dragonYellow | `#c4b28a` | |

## Lotus (light)

### Backgrounds

| Name | Hex | Preview |
|---|---|---|
| lotusWhite0 | `#d5cea3` | |
| lotusWhite1 | `#dcd5ac` | |
| lotusWhite2 | `#e5ddb0` | |
| lotusWhite3 | `#f2ecbc` | default bg |
| lotusWhite4 | `#e7dba0` | |
| lotusWhite5 | `#e4d794` | |

### Foreground and Syntax

| Name | Hex | Preview |
|---|---|---|
| lotusInk1 | `#545464` | default fg |
| lotusInk2 | `#43436c` | |
| lotusGray | `#dcd7ba` | |
| lotusGray2 | `#716e61` | |
| lotusGray3 | `#8a8980` | |
| lotusViolet1 | `#a09cac` | |
| lotusViolet2 | `#766b90` | |
| lotusViolet3 | `#c9cbd1` | |
| lotusViolet4 | `#624c83` | |
| lotusBlue1 | `#c7d7e0` | |
| lotusBlue2 | `#b5cbd2` | |
| lotusBlue3 | `#9fb5c9` | |
| lotusBlue4 | `#4d699b` | |
| lotusBlue5 | `#5d57a3` | |
| lotusGreen | `#6f894e` | |
| lotusGreen2 | `#6e915f` | |
| lotusGreen3 | `#b7d0ae` | |
| lotusPink | `#b35b79` | |
| lotusOrange | `#cc6d00` | |
| lotusOrange2 | `#e98a00` | |
| lotusYellow | `#77713f` | |
| lotusYellow2 | `#836f4a` | |
| lotusYellow3 | `#de9800` | |
| lotusYellow4 | `#f9d791` | |
| lotusRed | `#c84053` | |
| lotusRed2 | `#d7474b` | |
| lotusRed3 | `#e82424` | |
| lotusRed4 | `#d9a594` | |
| lotusAqua | `#597b75` | |
| lotusAqua2 | `#5e857a` | |
| lotusTeal1 | `#4e8ca2` | |
| lotusTeal2 | `#6693bf` | |
| lotusTeal3 | `#5a7785` | |
| lotusCyan | `#d7e3d8` | |
