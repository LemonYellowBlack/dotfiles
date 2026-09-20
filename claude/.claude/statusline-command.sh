#!/usr/bin/env bash
# Claude Code status line — Kanagawa-themed, mirrors Starship prompt style

input=$(cat)

# Extract fields
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)

# Kanagawa palette (true-color ANSI)
# #957FB8 → purple  (directory, matches starship)
# #76946A → green   (git branch, autumnGreen — "git add" in the palette)
# #E6C384 → yellow  (model name)
# #727169 → muted   (context usage)
# #FFA066 → orange  (session name / high context warning)
purple='\033[38;2;149;127;184m'
green='\033[38;2;118;148;106m'
yellow='\033[38;2;230;195;132m'
muted='\033[38;2;114;113;105m'
orange='\033[38;2;255;160;102m'
reset='\033[0m'

# Shorten cwd: replace $HOME with ~, then keep last 3 path segments
home="$HOME"
cwd="${cwd/#$home/\~}"
IFS='/' read -ra parts <<< "$cwd"
if [ "${#parts[@]}" -gt 3 ]; then
  cwd="…/${parts[-3]}/${parts[-2]}/${parts[-1]}"
fi

# Directory (purple)
out="$(printf "${purple}%s${reset}" "$cwd")"

# Git branch (green)
if [ -n "$branch" ]; then
  out="${out}  $(printf "${green}(%s)${reset}" "$branch")"
fi

# Model (yellow)
if [ -n "$model" ]; then
  out="${out}  $(printf "${yellow}%s${reset}" "$model")"
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
