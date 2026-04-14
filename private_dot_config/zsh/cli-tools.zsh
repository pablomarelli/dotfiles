# # Add custom completions directory to fpath
# fpath=(~/.config/zsh/completions $fpath)

# # Initialize zsh completions if not already done
# autoload -Uz compinit && compinit

# FZF (cached for faster startup)
mkdir -p "$HOME/.cache/zsh"
_fzf_cache="$HOME/.cache/zsh/fzf_init.zsh"
if command -v fzf >/dev/null 2>&1; then
  if [[ ! -f "$_fzf_cache" ]] || [[ "$(command -v fzf)" -nt "$_fzf_cache" ]]; then
    fzf --zsh > "$_fzf_cache" 2>/dev/null
  fi
  [[ -f "$_fzf_cache" ]] && source "$_fzf_cache"
fi

# eval "$(tv init zsh)"

# Override tv shell history to use a file-backed channel that preserves
# Zsh history order instead of the generated pipe-based integration.
# _tv_shell_history() {
#     emulate -L zsh
#     zle -I
#     _disable_bracketed_paste
#     local current_prompt output
#     current_prompt=$LBUFFER
#     output=$(tv zsh-history --no-status-bar --input "$current_prompt" --inline)
#     zle reset-prompt
#     if [[ -n $output ]]; then
#         RBUFFER=""
#         LBUFFER=$output
#     fi
#     _enable_bracketed_paste
# }
#
# zle -N tv-shell-history _tv_shell_history
# bindkey '^R' tv-shell-history

# export FZF_CTRL_R_OPTS='--tmux bottom,60% --height 60% --border top'

export FZF_DEFAULT_OPTS="
--style=minimal
"
# ZOxide (cached for faster startup)
export _ZO_ECHO=1
_zoxide_cache="$HOME/.cache/zsh/zoxide_init.zsh"
if command -v zoxide >/dev/null 2>&1; then
  if [[ ! -f "$_zoxide_cache" ]] || [[ "$(command -v zoxide)" -nt "$_zoxide_cache" ]]; then
    zoxide init zsh > "$_zoxide_cache" 2>/dev/null
  fi
  [[ -f "$_zoxide_cache" ]] && source "$_zoxide_cache"
fi

# Navi widget (cached for faster startup)
_navi_cache="$HOME/.cache/zsh/navi_init.zsh"
if command -v navi >/dev/null 2>&1; then
  if [[ ! -f "$_navi_cache" ]] || [[ "$(command -v navi)" -nt "$_navi_cache" ]]; then
    navi widget zsh > "$_navi_cache" 2>/dev/null
  fi
  [[ -f "$_navi_cache" ]] && source "$_navi_cache"
fi
