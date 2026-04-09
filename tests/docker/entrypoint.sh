#!/usr/bin/env bash
set -u

LOG_FILE=/tmp/bootstrap.log
EXIT_FILE=/tmp/bootstrap.exit

run_bootstrap() {
  local source_mode source_dir

  source_mode="${DOTFILES_SOURCE_MODE:-git}"
  source_dir=""

  if [[ "$source_mode" == "mount" && -d /dotfiles-src ]]; then
    source_dir=/dotfiles-src
  else
    source_dir="$(mktemp -d)"
    git clone --depth 1 https://github.com/pablomarelli/dotfiles.git "$source_dir"
  fi

  export DOTFILES_HEADLESS=1
  export DOTFILES_SOURCE="$source_dir"
  export MISE_PYTHON_GITHUB_ATTESTATIONS="${MISE_PYTHON_GITHUB_ATTESTATIONS:-false}"

  chezmoi --config "$HOME/.config/chezmoi/chezmoi.toml" --source "$DOTFILES_SOURCE" apply --keep-going --no-tty
}

rm -f "$LOG_FILE" "$EXIT_FILE"
run_bootstrap >"$LOG_FILE" 2>&1
printf '%s\n' "$?" >"$EXIT_FILE"

sleep infinity
