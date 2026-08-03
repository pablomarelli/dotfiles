#!/bin/sh
set -eu

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/pablomarelli/dotfiles.git}"
CHEZMOI_INSTALLER_URL="${CHEZMOI_INSTALLER_URL:-https://get.chezmoi.io}"
CHEZMOI_VERSION="${CHEZMOI_VERSION:-2.70.0}"
ONEPASSWORD_SIGNING_KEY_ID="AC2D62742012EA22"
WITH_SECRETS=0
SECRETS_EXPLICIT=0
INSTALL_PROFILE=""
PROFILE_EXPLICIT=0
NON_INTERACTIVE=0
DRYRUN=0
OP_SESSION_TOKEN="${OP_SESSION:-}"
unset OP_SESSION

cleanup_secrets() {
  unset OP_SESSION OP_SESSION_TOKEN
}
trap cleanup_secrets EXIT

die() {
  printf 'Error: %s\n' "$*" >&2
  cleanup_secrets
  exit 1
}

usage() {
  cat <<'EOF'
Usage: install.sh [--dryrun] [--profile remote|minimal|full] [--with-secrets|--without-secrets] [--non-interactive]

Bootstrap public dotfiles. With a controlling TTY, the default command opens a short wizard.

  --dryrun            Print the install plan without making changes. Alias: --dry-run.
  --profile            Install profile: remote, minimal, or full.
  --with-secrets       Opt in to 1Password-backed templates after verifying access.
  --without-secrets    Skip 1Password-backed templates.
  --non-interactive    Do not prompt; defaults to remote without secrets.
EOF
}

valid_profile() {
  case "$1" in
    remote|minimal|full) return 0 ;;
    *) return 1 ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --with-secrets)
      WITH_SECRETS=1
      SECRETS_EXPLICIT=1
      ;;
    --without-secrets)
      WITH_SECRETS=0
      SECRETS_EXPLICIT=1
      ;;
    --profile)
      [ "$#" -gt 1 ] || die "--profile requires one of: remote, minimal, full"
      INSTALL_PROFILE="$2"
      PROFILE_EXPLICIT=1
      shift
      ;;
    --profile=*)
      INSTALL_PROFILE="${1#--profile=}"
      PROFILE_EXPLICIT=1
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
      ;;
    --dryrun|--dry-run)
      DRYRUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ -n "$INSTALL_PROFILE" ] && ! valid_profile "$INSTALL_PROFILE"; then
  die "Invalid profile: $INSTALL_PROFILE. Expected one of: remote, minimal, full."
fi

log() {
  printf '%s\n' "$*"
}

script_dir() {
  CDPATH= cd -- "$(dirname -- "$0")" && pwd
}

is_interactive() {
  [ -r /dev/tty ] && [ -w /dev/tty ] && ( : </dev/tty ) >/dev/null 2>&1
}

open_prompt_tty() {
  is_interactive || return 1
  exec 3</dev/tty
  if ! [ -t 3 ]; then
    exec 3>&-
    return 1
  fi
  exec 4>/dev/tty
  return 0
}

can_read_auth_tty() {
  is_interactive
}

prompt_profile() {
  while :; do
    {
      printf '\nChoose install profile [1]:\n'
      printf '  1) remote  - SSH/server coding setup, no GUI\n'
      printf '  2) minimal - focused workstation tools, no infra/cloud stack\n'
      printf '  3) full    - full personal workstation setup\n'
      printf 'Profile: '
    } >&4
    IFS= read -r choice <&3 || choice=""
    case "$choice" in
      ""|1|remote) INSTALL_PROFILE=remote; return 0 ;;
      2|minimal) INSTALL_PROFILE=minimal; return 0 ;;
      3|full) INSTALL_PROFILE=full; return 0 ;;
      *) printf 'Invalid choice. Enter 1, 2, or 3.\n' >&4 ;;
    esac
  done
}

prompt_secrets() {
  while :; do
    printf '\nEnable 1Password-backed secrets? [y/N]: ' >&4
    IFS= read -r choice <&3 || choice=""
    case "$choice" in
      ""|n|N|no|NO|No) WITH_SECRETS=0; return 0 ;;
      y|Y|yes|YES|Yes) WITH_SECRETS=1; return 0 ;;
      *) printf 'Invalid choice. Enter y or n.\n' >&4 ;;
    esac
  done
}

resolve_wizard_choices() {
  if [ "$NON_INTERACTIVE" -eq 0 ] && open_prompt_tty; then
    [ "$PROFILE_EXPLICIT" -eq 1 ] || prompt_profile
    [ "$SECRETS_EXPLICIT" -eq 1 ] || prompt_secrets
    exec 3>&-
    exec 4>&-
  fi

  INSTALL_PROFILE="${INSTALL_PROFILE:-remote}"
  valid_profile "$INSTALL_PROFILE" || die "Invalid profile: $INSTALL_PROFILE. Expected one of: remote, minimal, full."
}

have() {
  command -v "$1" >/dev/null 2>&1
}

install_chezmoi() {
  if have chezmoi; then
    return 0
  fi

  have curl || die "curl is required to install chezmoi. Install curl, then rerun this command."

  bin_dir="${HOME}/.local/bin"
  mkdir -p "$bin_dir"
  log "Installing chezmoi with the official installer..."
  installer_tmp="$(mktemp)"
  cleanup_installer() { rm -f "$installer_tmp"; }
  trap 'cleanup_installer; cleanup_secrets; exit 1' HUP INT TERM
  curl -fsSLo "$installer_tmp" "$CHEZMOI_INSTALLER_URL" || die "Failed to download the chezmoi installer. Check network access and rerun."
  sh "$installer_tmp" -t "v$CHEZMOI_VERSION" -b "$bin_dir"
  cleanup_installer
  trap - HUP INT TERM
  PATH="$bin_dir:$PATH"
  export PATH
  have chezmoi || die "chezmoi installation completed but chezmoi is not on PATH."
}

os_name() {
  if [ -n "${DOTFILES_TEST_OS:-}" ]; then
    case "$DOTFILES_TEST_OS" in
      darwin) printf 'Darwin' ;;
      linux) printf 'Linux' ;;
      *) printf '%s' "$DOTFILES_TEST_OS" ;;
    esac
    return 0
  fi
  uname -s 2>/dev/null || printf 'unknown'
}

is_debian_like() {
  if [ -n "${DOTFILES_TEST_OS_RELEASE:-}" ]; then
    grep -Eq '^(ID|ID_LIKE)=.*(debian|ubuntu)' "$DOTFILES_TEST_OS_RELEASE"
    return $?
  fi
  [ -r /etc/os-release ] && grep -Eq '^(ID|ID_LIKE)=.*(debian|ubuntu)' /etc/os-release
}

os_key() {
  case "$(os_name)" in
    Darwin) printf 'darwin' ;;
    Linux) printf 'linux' ;;
    *) printf 'unknown' ;;
  esac
}

os_release_path() {
  if [ -n "${DOTFILES_TEST_OS_RELEASE:-}" ]; then
    printf '%s' "$DOTFILES_TEST_OS_RELEASE"
  else
    printf '%s' /etc/os-release
  fi
}

is_ubuntu_os_release() {
  os_release="$1"
  [ -r "$os_release" ] || return 1
  while IFS= read -r line; do
    case "$line" in
      ID=ubuntu|ID='ubuntu'|ID="ubuntu") return 0 ;;
    esac
  done <"$os_release"
  return 1
}

emit_dryrun_plan() {
  plan_file="$(script_dir)/dotfiles-plan.sh"
  [ -r "$plan_file" ] || die "--dryrun requires the local dotfiles source next to install.sh. Run it from a checked-out repository, or download the repository before planning. No changes were made."
  os_key_value="$(os_key)"
  os_release="$(os_release_path)"
  headless="${DOTFILES_HEADLESS:-0}"
  ubuntu=0
  [ "$os_key_value" = "linux" ] && is_ubuntu_os_release "$os_release" && ubuntu=1
  cleanup_secrets
  if ! env -i \
    HOME="/nonexistent" \
    XDG_CONFIG_HOME="/nonexistent" \
    XDG_CACHE_HOME="/nonexistent" \
    PATH="/nonexistent" \
    /bin/sh "$plan_file" "$INSTALL_PROFILE" "$WITH_SECRETS" "$os_key_value" "$headless" "$ubuntu" "$HOME" "$DOTFILES_REPO_URL" "$CHEZMOI_INSTALLER_URL"; then
    die "Dryrun planner failed. No changes were made."
  fi
  trap cleanup_secrets EXIT
}

preflight_default_apply() {
  have curl || die "curl is required. Install curl, then rerun this command."

  case "$(os_name)" in
    Darwin)
      ;;
    Linux)
      is_debian_like || die "This public bootstrap supports Debian/Ubuntu Linux. Unsupported distributions should install chezmoi manually and inspect the repo before applying."
      have sudo || die "sudo is required on Debian/Ubuntu because the first apply installs system packages."
      ;;
    *)
      die "Unsupported OS for this bootstrap. Supported platforms are macOS and Debian/Ubuntu Linux."
      ;;
  esac
}

install_op_macos() {
  have brew || die "Homebrew is required to install 1Password CLI on macOS. Install it from https://brew.sh, then rerun with --with-secrets."
  log "Installing 1Password CLI with Homebrew..."
  brew install --cask 1password-cli
}

install_op_debian() {
  for cmd in curl sudo gpg dpkg apt-get tee mktemp; do
    have "$cmd" || die "$cmd is required to install 1Password CLI on Debian/Ubuntu. Install it, then rerun with --with-secrets."
  done

  tmp_dir="$(mktemp -d)"
  cleanup_tmp() { rm -rf "$tmp_dir"; }
  trap 'cleanup_tmp; cleanup_secrets; exit 1' HUP INT TERM
  key_file="$tmp_dir/1password.asc"
  archive_keyring="$tmp_dir/1password-archive-keyring.gpg"
  debsig_keyring="$tmp_dir/debsig.gpg"
  policy_file="$tmp_dir/1password.pol"

  log "Installing 1Password CLI with the official Debian/Ubuntu repository..."

  curl -fsSLo "$key_file" https://downloads.1password.com/linux/keys/1password.asc || die "Failed to download the 1Password signing key. Check network access and rerun."
  gpg --dearmor --output "$archive_keyring" "$key_file" || die "Failed to prepare the 1Password apt signing key."
  gpg --dearmor --output "$debsig_keyring" "$key_file" || die "Failed to prepare the 1Password debsig key."
  curl -fsSLo "$policy_file" https://downloads.1password.com/linux/debian/debsig/1password.pol || die "Failed to download the 1Password debsig policy."

  arch="$(dpkg --print-architecture)"
  sudo install -D -m 0644 "$archive_keyring" /usr/share/keyrings/1password-archive-keyring.gpg || die "Failed to install the 1Password apt signing key."
  printf 'deb [arch=%s signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/%s stable main\n' "$arch" "$arch" |
    sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
  sudo install -D -m 0644 "$policy_file" "/etc/debsig/policies/$ONEPASSWORD_SIGNING_KEY_ID/1password.pol" || die "Failed to install the 1Password debsig policy."
  sudo install -D -m 0644 "$debsig_keyring" "/usr/share/debsig/keyrings/$ONEPASSWORD_SIGNING_KEY_ID/debsig.gpg" || die "Failed to install the 1Password debsig key."

  sudo apt-get update || die "apt-get update failed after adding the 1Password repository. Check apt output, then rerun."
  sudo apt-get install -y 1password-cli || die "1Password CLI package installation failed. Check apt output, then rerun."
  trap - HUP INT TERM
  cleanup_tmp
}

install_op() {
  if have op && [ "${DOTFILES_FORCE_INSTALL_OP:-0}" != "1" ]; then
    return 0
  fi

  case "$(os_name)" in
    Darwin)
      install_op_macos
      ;;
    Linux)
      if is_debian_like; then
        install_op_debian
      else
        die "Unsupported Linux package environment for automatic 1Password CLI install. Install op manually from https://developer.1password.com/docs/cli/get-started/, then rerun with --with-secrets."
      fi
      ;;
    *)
      die "Unsupported OS for automatic 1Password CLI install. Install op manually from https://developer.1password.com/docs/cli/get-started/, then rerun with --with-secrets."
      ;;
  esac

  hash -r 2>/dev/null || true
  have op || die "1Password CLI installation completed but op is not on PATH."
}

op_cmd() {
  if [ -n "$OP_SESSION_TOKEN" ]; then
    OP_SESSION="$OP_SESSION_TOKEN" op "$@"
  else
    op "$@"
  fi
}

ensure_op_authenticated() {
  if op_cmd whoami >/dev/null 2>&1; then
    return 0
  fi

  if ! can_read_auth_tty; then
    die "--with-secrets requires an authenticated 1Password CLI session in non-interactive mode. Sign in with op first, or rerun without --with-secrets."
  fi

  log "Signing in to 1Password CLI..."
  OP_SESSION_TOKEN="$(op signin --raw </dev/tty)" || die "1Password sign-in failed. Rerun without --with-secrets to skip secret-backed templates."
  [ -n "$OP_SESSION_TOKEN" ] || die "1Password sign-in returned an empty session. Rerun without --with-secrets to skip secret-backed templates."

  op_cmd whoami >/dev/null 2>&1 || die "1Password CLI is still not authenticated. Rerun without --with-secrets to skip secret-backed templates."
}

secret_target_paths() {
  printf '%s\n' "$HOME/.config/opencode/ntfy.env"
  if [ "$(os_name)" = "Darwin" ] && [ "$INSTALL_PROFILE" = "full" ]; then
    printf '%s\n' "$HOME/.aws/credentials"
  fi
}

apply_secret_targets() {
  ntfy_target="$HOME/.config/opencode/ntfy.env"
  if [ "$(os_name)" = "Darwin" ] && [ "$INSTALL_PROFILE" = "full" ]; then
    aws_target="$HOME/.aws/credentials"
    if [ -n "$OP_SESSION_TOKEN" ]; then
      OP_SESSION="$OP_SESSION_TOKEN" chezmoi apply "$ntfy_target" "$aws_target"
    else
      chezmoi apply "$ntfy_target" "$aws_target"
    fi
  else
    if [ -n "$OP_SESSION_TOKEN" ]; then
      OP_SESSION="$OP_SESSION_TOKEN" chezmoi apply "$ntfy_target"
    else
      chezmoi apply "$ntfy_target"
    fi
  fi
}

required_op_refs() {
  manifest_path="${DOTFILES_SECRET_REFS_FILE:-${DOTFILES_SOURCE:-}/secret-refs.txt}"
  if [ -z "$manifest_path" ] || [ ! -r "$manifest_path" ]; then
    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    manifest_path="$script_dir/secret-refs.txt"
  fi
  [ -r "$manifest_path" ] || die "Cannot read secret reference manifest: $manifest_path"

  target_os="all"
  [ "$(os_name)" = "Darwin" ] && [ "$INSTALL_PROFILE" = "full" ] && target_os="darwin"

  while IFS=' ' read -r os_key field_name ref_rest; do
    case "$os_key" in ''|'#'*) continue ;; esac
    ref="$ref_rest"
    [ "$os_key" = "all" ] || [ "$os_key" = "$target_os" ] || continue
    printf '%s %s\n' "$field_name" "$ref"
  done <"$manifest_path"
}

verify_op_refs() {
  failed=0
  required_op_refs | while IFS=' ' read -r field_name ref; do
    [ -n "$ref" ] || continue
    if ! value="$(op_cmd read --no-newline "$ref")"; then
      printf 'Missing or unreadable 1Password reference: %s\n' "$ref" >&2
      failed=1
    elif [ -z "$value" ]; then
      printf 'Empty 1Password reference: %s\n' "$ref" >&2
      failed=1
    elif [ "$field_name" = "ntfy_url" ]; then
      case "$value" in
        https://*) ;;
        *)
          printf 'Invalid ntfy URL reference (must be non-empty HTTPS): %s\n' "$ref" >&2
          failed=1
          ;;
      esac
    fi
    unset value
    if [ "$failed" -ne 0 ]; then
      exit 1
    fi
  done || die "Secret verification failed before apply. Fix 1Password access, or rerun without --with-secrets to skip secret-backed templates."
}

resolve_wizard_choices

if [ "$DRYRUN" -eq 1 ]; then
  emit_dryrun_plan
  exit 0
fi

preflight_default_apply

install_chezmoi

if [ "$WITH_SECRETS" -eq 1 ]; then
  log "Initializing dotfiles source without applying so secrets can be verified first..."
  DOTFILES_INCLUDE_SECRETS=1 DOTFILES_INSTALL_PROFILE="$INSTALL_PROFILE" DOTFILES_HEADLESS="${DOTFILES_HEADLESS:-0}" chezmoi init "$DOTFILES_REPO_URL"
  DOTFILES_SOURCE="$(chezmoi source-path)"
  export DOTFILES_SOURCE
  install_op
  ensure_op_authenticated
  verify_op_refs
  log "Applying secret-backed dotfiles targets..."
  if ! apply_secret_targets; then
    cleanup_secrets
    die "Secret target apply failed. General apply was not run."
  fi
  cleanup_secrets
  log "Applying remaining dotfiles with secret targets ignored..."
  DOTFILES_FORCE_IGNORE_SECRETS=1 DOTFILES_INSTALL_PROFILE="$INSTALL_PROFILE" DOTFILES_HEADLESS="${DOTFILES_HEADLESS:-0}" chezmoi apply
else
  log "Initializing and applying public dotfiles without secret-backed templates..."
  DOTFILES_INCLUDE_SECRETS=0 DOTFILES_INSTALL_PROFILE="$INSTALL_PROFILE" DOTFILES_HEADLESS="${DOTFILES_HEADLESS:-0}" chezmoi init --apply "$DOTFILES_REPO_URL"
fi

cleanup_secrets
log "Dotfiles bootstrap complete."
