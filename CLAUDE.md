# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Read README.md first: it covers layout, the theme system, install and gotchas. This file only adds
what changes how you work here.

## This is the live config

Stowed files are symlinks, so editing the repo edits the running system. `hypr` is folded, so
anything a tool writes into `~/.config/hypr` shows up in `git status`. Read the README's Gotchas
before changing how any package is stowed.

## Where an edit goes

- Shared behavior goes in the shared package; `<pkg>-xps` / `<pkg>-hotdog` hold only host facts.
  In the shell, describe hardware in `Host.qml` rather than branching on hostname.
- Colors: edit `theme/` (palettes, variations, templates), never generated output or `~/.config`.
  Variations name slots from `theme/slots.toml`, never a palette's own color names. Template
  syntax is in the docstring at the top of `theme/retheme`.
- Hyprland config is Lua, not hyprlang. Don't write `hyprland.conf` syntax.
- Color direction: lean away from purple; off-whites and yellows lead, crystal blue is the cool
  counterpart.

## Checking a change

There is no build or test suite. Reload what you touched:

- theme: `retheme lint` (every palette × variation), then `retheme`, or render somewhere
  harmless with `RETHEME_HOME`/`RETHEME_HOST`
- Hyprland: `hyprctl reload`
- Liquid shell: `qs -c liquid ipc call shell reload`
- Boot splash: `boot/plymouth/render <dir>` renders it as you; installing it (`boot/install theme`)
  needs the user's sudo. The greeter previews with `qs -p ~/.config/quickshell/liquid/greeter.qml`;
  the outro with `qs -c liquid ipc call shell leave preview`.

## Don't

- Lock the real session to test the lock screen; use `qs -c liquid ipc call lock preview`.
- Start or restart `greetd` from a session: it takes tty1, and the session on it goes with it.
  `shell leave` with anything but `preview` really logs out, restarts or shuts down.
- Commit generated theme output, or a `theme/hosts/<host>.toml` change unless the pick is meant
  to stick.

## Commits

Subject `<package or area>: <lowercase summary>` (`theme: …`, `quickshell: …`, `hypr-xps: …`);
the body says why.

## Shipping from a worktree

Sessions usually start in a worktree (the `claude` wrapper in `zsh/.zshrc`), but the live config is
the main checkout at `~/dotfiles`, so nothing is testable until it lands on `main`. When the user
asks to test, try, ship or apply a change, do it without handing back commands:

1. Commit in the worktree.
2. `ExitWorktree` with `keep` (git can't reach the main checkout from inside the worktree).
3. In `~/dotfiles`: stop and ask if it isn't clean on `main`; otherwise `git merge --ff-only
   <worktree branch>`. If `main` has moved, rebase the branch onto `main` first.
4. Reload what you touched (see Checking a change) and verify it took.

Don't push to a remote unless asked.
