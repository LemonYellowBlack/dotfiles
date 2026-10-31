#!/usr/bin/env bash
# Claude Code status line — Kanagawa-themed, mirrors Starship prompt style

input=$(cat)

# Extract fields
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
host=$(uname -n)

# Colors from this machine's theme (theme/retheme writes statusline.sh); plain text without it.
blue='' cream='' amber='' yellow='' muted='' orange=''
. "$HOME/.config/theme/statusline.sh" 2>/dev/null
reset='\033[0m'

# Shorten cwd: replace $HOME with ~, then keep last 3 path segments
home="$HOME"
cwd="${cwd/#$home/\~}"
IFS='/' read -ra parts <<< "$cwd"
if [ "${#parts[@]}" -gt 3 ]; then
  cwd="…/${parts[-3]}/${parts[-2]}/${parts[-1]}"
fi

# Hostname (blue)
out="$(printf "${blue}%s${reset}" "$host")"

# Directory (cream)
out="${out}  $(printf "${cream}%s${reset}" "$cwd")"

# Git branch (amber)
if [ -n "$branch" ]; then
  out="${out}  $(printf "${amber}(%s)${reset}" "$branch")"
fi

# Model (yellow), with effort level appended when present
if [ -n "$model" ]; then
  if [ -n "$effort" ]; then
    out="${out}  $(printf "${yellow}%s (%s)${reset}" "$model" "$effort")"
  else
    out="${out}  $(printf "${yellow}%s${reset}" "$model")"
  fi
fi

# Context usage (muted, shifts to orange when >=75%)
if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")
  if [ "$used_int" -ge 75 ]; then
    ctx_color="$orange"
  else
    ctx_color="$muted"
  fi
  out="${out}  $(printf "${ctx_color}ctx:%s%%%s" "$used_int" "$reset")"
fi

# Session name (orange, only when explicitly set via /rename)
if [ -n "$session_name" ]; then
  out="${out}  $(printf "${orange}[%s]${reset}" "$session_name")"
fi

printf "%b\n" "$out"
