# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt nomatch
unsetopt autocd beep extendedglob notify
unsetopt PROMPT_SP
bindkey -e
bindkey "^[[1;5D" backward-word   # Ctrl+Left:  back a word
bindkey "^[[1;5D" backward-word   # Ctrl+Left:  back a word
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/robbie/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

alias ls='ls -aF'
# clear also resets the first-prompt flag so a cleared screen has no top gap
alias clear='command clear; unset _PROMPT_NEWLINE_READY'
alias zload='source ~/.zshrc'
alias bwsesh='export BW_SESSION=$(bw unlock --raw)'
alias vlt='cd ~/.vlt-mnt && ls'
alias vltopen='gocryptfs ~/.vlt ~/.vlt-mnt'
alias vltclose='fusermount3 -u ~/.vlt-mnt'
alias vltkeys='source ~/.vlt-mnt/keys.sh && echo "keys loaded"'
alias vltget='vltopen && vltkeys && vltclose'
alias tor='torbrowser-launcher'
alias srv="ssh thinkcentre"
alias pwroff='shutdown now'
alias claude='claude --allow-dangerously-skip-permissions'
alias prime='__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia'

# Yazi shell wrapper (cd on quit)
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

eval "$(starship init zsh)"

autoload -Uz add-zsh-hook
# Blank line between prompts for breathing room, but not before the
# first prompt of the session (avoids a gap at the top of a fresh terminal).
_prompt_newline() {
	if [[ -n $_PROMPT_NEWLINE_READY ]]; then
		print
	fi
	_PROMPT_NEWLINE_READY=1
}
#add-zsh-hook precmd _prompt_newline

eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"

# fzf — Ctrl+R history, Ctrl+T file, Alt+C cd, ** completion
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# zsh-syntax-highlighting must be sourced last
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
export GPG_TTY=$(tty)
export LS_COLORS="$(vivid generate kanagawa)"
export FZF_DEFAULT_OPTS="--color=fg:#DCD7BA,bg:-1,hl:#E46876,fg+:#DCD7BA,bg+:#2A2A37,hl+:#E46876,info:#658594,prompt:#7E9CD8,pointer:#E46876,marker:#98BB6C,spinner:#957FB8,header:#7AA89F,border:#363646"

# Beads (Dolt server on ThinkCentre)
export BEADS_DIR=~/lyb/.beads
export BEADS_DOLT_SERVER_MODE=1
export BEADS_DOLT_SERVER_HOST=thinkcentre
export BEADS_DOLT_SERVER_PORT=3307
export BEADS_DOLT_SERVER_USER=root

# disable/enable nvidia drivers, dodges secure_path issue with sudo and bin
gpu-off() { sudo /home/robbie/.local/bin/gpu-off "$@"; }
gpu-on()  { sudo /home/robbie/.local/bin/gpu-on  "$@"; }

# Workload tag for cpu-templog / gpu-templog CSVs.
#   tag <name>   set the current tag (written to each sample row)
#   tag          print the current tag
#   tag clear    clear the tag
tag() {
    local f="${XDG_STATE_HOME:-$HOME/.local/state}/templog/tag"
    mkdir -p "${f:h}"
    case "$1" in
        "")        [[ -s $f ]] && cat "$f" && echo || echo "(no tag)" ;;
        clear|off) : > "$f"; echo "tag cleared" ;;
        *)         printf '%s' "$1" > "$f"; echo "tag set: $1" ;;
    esac
}

# Rust/cargo binaries (tree-sitter CLI, etc.) — needed by nvim-treesitter to build parsers
export PATH="$HOME/.cargo/bin:$PATH"
