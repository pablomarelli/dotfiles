# Starship (cached for faster startup)
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

if [[ -z "$STARSHIP_DISABLE" ]] && command -v starship >/dev/null 2>&1; then
  mkdir -p "$HOME/.cache/zsh"
  _starship_cache="$HOME/.cache/zsh/starship_init.zsh"
  if [[ ! -f "$_starship_cache" ]] || [[ "$(command -v starship)" -nt "$_starship_cache" ]]; then
    starship init zsh > "$_starship_cache" 2>/dev/null
  fi
  [[ -f "$_starship_cache" ]] && source "$_starship_cache"
fi
