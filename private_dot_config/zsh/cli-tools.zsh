# # Add custom completions directory to fpath
# fpath=(~/.config/zsh/completions $fpath)

# # Initialize zsh completions if not already done
# autoload -Uz compinit && compinit

# FZF (cached for faster startup)
# mkdir -p "$HOME/.cache/zsh"
# _fzf_cache="$HOME/.cache/zsh/fzf_init.zsh"
# if command -v fzf >/dev/null 2>&1; then
#   if [[ ! -f "$_fzf_cache" ]] || [[ "$(command -v fzf)" -nt "$_fzf_cache" ]]; then
#     fzf --zsh > "$_fzf_cache" 2>/dev/null
#   fi
#   [[ -f "$_fzf_cache" ]] && source "$_fzf_cache"
# fi

eval "$(tv init zsh)"

# export FZF_CTRL_R_OPTS='--tmux bottom,60% --height 60% --border top'

export FZF_DEFAULT_OPTS="
--style=minimal
"
# export FZF_DEFAULT_OPTS="
#   --style=full
#   --tmux 80%
#   --border --padding=1,2
#   --border-label=' Demo ' --input-label=' Input ' --header-label=' File Type '
#   --preview='bat --color=always --style=numbers --line-range=:500 {}'
#   --bind='result:transform-list-label:
#     if [[ -z \$FZF_QUERY ]]; then
#       echo \" \$FZF_MATCH_COUNT items \"
#     else
#       echo \" \$FZF_MATCH_COUNT matches for [\$FZF_QUERY] \"
#     fi'
#   --bind='focus:transform-preview-label:[[ -n {} ]] && printf \" Previewing [%s] \" {}'
#   --bind='focus:+transform-header:file --brief {} || echo \"No file selected\"'
#   --bind='ctrl-r:change-list-label( Reloading the list )+reload(sleep 2; git ls-files)'
#   --color='border:#aaaaaa,label:#cccccc'
#   --color='preview-border:#9999cc,preview-label:#ccccff'
#   --color='list-border:#669966,list-label:#99cc99'
#   --color='input-border:#996666,input-label:#ffcccc'
#   --color='header-border:#6699cc,header-label:#99ccff'
# "

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

