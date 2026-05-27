# Starship (cached for faster startup)
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

if [[ -z "$STARSHIP_DISABLE" ]] && command -v starship >/dev/null 2>&1; then
  mkdir -p "$HOME/.cache/zsh"

  _starship_bin="$(mise which starship 2>/dev/null || command -v starship)"
  _starship_cache_key="direct_${_starship_bin//\//_}"
  _starship_cache="$HOME/.cache/zsh/starship_init_${_starship_cache_key}.zsh"

  if [[ ! -f "$_starship_cache" ]] || [[ "$_starship_bin" -nt "$_starship_cache" ]]; then
    PATH="${_starship_bin:h}:$PATH" "$_starship_bin" init zsh > "$_starship_cache" 2>/dev/null
  fi
  [[ -f "$_starship_cache" ]] && source "$_starship_cache"
fi
