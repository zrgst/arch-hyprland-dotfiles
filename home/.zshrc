# --- basic env ---
export EDITOR="nvim"
export PATH="$HOME/.local/bin:$PATH"

# --- Start SSH agent automatically ---
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
  eval "$(ssh-agent -s)" > /dev/null
fi

# --- history ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS EXTENDED_HISTORY
unsetopt beep
bindkey -e

# --- completion ---
autoload -Uz compinit && compinit

# Completion med case-insensitiv matching
autoload -Uz compinit; compinit
zmodload zsh/complist
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Case insensitiv Globbing
setopt nocaseglob

# --- fzf defaults (uses fd if present) ---
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# --- plugins (from distro packages if installed) ---
# autosuggestions
[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] \
  && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
# syntax highlighting (must load after autosuggestions)
[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] \
  && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# zoxide (smart cd)
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# --- prompt ---
eval "$(starship init zsh)"

# --- aliases ---
alias ls='eza -lah --group-directories-first --icons=auto'
alias cat='bat --paging=never'

# --- Starship ---
if command -v starship >/dev/null 2>&1; then
  unset PROMPT RPROMPT
  unsetopt promptsubst
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
  eval "$(starship init zsh)"
fi
