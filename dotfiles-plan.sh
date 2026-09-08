# shellcheck shell=sh
# Read-only profile planner for install.sh --dryrun.
# Keep these lists aligned with the profile templates; tests compare this output
# with rendered templates so drift is caught before release.
set -eu

plan_join_words() {
  if [ "$#" -eq 0 ]; then
    printf 'none\n'
  else
    printf '%s\n' "$@"
  fi
}

plan_mise_tools() {
  profile="$1"
  plan_join_words \
    'node = "24"' \
    'jq = "latest"' \
    'fzf = "latest"' \
    'tmux = "latest"' \
    'fd = "latest"' \
    'gh = "latest"' \
    'ripgrep = "latest"' \
    'delta = "latest"' \
    'tree-sitter = "latest"' \
    'chezmoi = "2.70.0"' \
    '"github:neovim/neovim" = "latest"' \
    '"npm:@opencode-ai/cli" = { version = "0.0.0-beta-19151", allow_builds = ["@opencode-ai/cli"] }' \
    '"npm:@earendil-works/pi-coding-agent" = "0.84.4"' \
    'go = "latest"' \
    'python = "3.10.20"' \
    'worktrunk = "latest"'
  case "$profile" in
    minimal|full)
      plan_join_words \
        'zoxide = "latest"' \
        'bat = "latest"' \
        'eza = "latest"' \
        'lazygit = "latest"' \
        '"cargo:navi" = "latest"' \
        '"aqua:alexpasmantier/television" = "latest"' \
        '"aqua:joshmedeski/sesh" = "latest"' \
        'ast-grep = "latest"' \
        'starship = "latest"' \
        'rust = "latest"' \
        '"github:ogulcancelik/herdr" = "latest"'
      ;;
  esac
  if [ "$profile" = "full" ]; then
    plan_join_words \
      'lazydocker = "latest"' \
      'kubectx = "latest"' \
      '"npm:sql-formatter" = "latest"' \
      'k9s = "latest"' \
      'glow = "latest"' \
      'duf = "latest"' \
      'xh = "latest"' \
      'tlrc = "latest"' \
      'cheat = "latest"' \
      'pipx = "latest"' \
      'docker-cli = "latest"' \
      'coreutils = "latest"' \
      'usage = "latest"' \
      'k3d = "latest"' \
      'terragrunt = "latest"' \
      'opentofu = "latest"' \
      'kubectl = "latest"'
  fi
}

plan_linux_apt_packages() {
  profile="$1"
  ubuntu="$2"
  set -- zsh git gcc build-essential curl wget unzip python3-venv
  if [ "$profile" != "remote" ]; then
    set -- "$@" xclip xdg-utils
  fi
  if [ "$ubuntu" = "1" ]; then
    set -- "$@" software-properties-common
  fi
  plan_join_words "$@"
}

plan_linux_terminal_packages() {
  profile="$1"
  headless="$2"
  if [ "$profile" != "remote" ] && [ "$headless" != "1" ]; then
    plan_join_words alacritty
  else
    plan_join_words
  fi
}

plan_darwin_brew_packages() {
  profile="$1"
  set -- zsh git gcc
  case "$profile" in
    minimal)
      set -- "$@" dark-notify
      ;;
    full)
      set -- "$@" git-crypt dark-notify hunk tailspin
      ;;
  esac
  plan_join_words "$@"
}

plan_darwin_brew_taps() {
  profile="$1"
  case "$profile" in
    minimal)
      plan_join_words cormacrelf/tap
      ;;
    full)
      plan_join_words cormacrelf/tap modem-dev/tap felixkratz/formulae
      ;;
    *)
      plan_join_words
      ;;
  esac
}

plan_darwin_brew_casks() {
  profile="$1"
  headless="$2"
  if [ "$profile" = "remote" ] || [ "$headless" = "1" ]; then
    plan_join_words
  elif [ "$profile" = "minimal" ]; then
    plan_join_words ghostty alacritty
  else
    plan_join_words ghostty alacritty raycast ngrok font-symbols-only-nerd-font
  fi
}

plan_secret_targets() {
  os_key="$1"
  profile="$2"
  include_secrets="$3"
  if [ "$include_secrets" != "1" ]; then
    plan_join_words
    return 0
  fi
  set -- "$HOME/.config/opencode/ntfy.env" "$HOME/.config/opencode/zen.env"
  if [ "$os_key" = "darwin" ] && [ "$profile" = "full" ]; then
    set -- "$@" "$HOME/.aws/credentials"
  fi
  plan_join_words "$@"
}

plan_external_downloads() {
  os_key="$1"
  profile="$2"
  include_secrets="$3"
  headless="$4"
  repo_url="$5"
  chezmoi_url="$6"
  set -- \
    "dotfiles source repository: $repo_url (chezmoi init during real install)" \
    "chezmoi official installer: $chezmoi_url (only if chezmoi is missing during real install)" \
    "mise installer: https://mise.run (only if mise is missing during package bootstrap)"
  if [ "$include_secrets" = "1" ]; then
    case "$os_key" in
      darwin) set -- "$@" "1Password CLI Homebrew cask: 1password-cli (only if op is missing)" ;;
      linux) set -- "$@" "1Password apt repository/key/policy downloads (only if op is missing)" ;;
    esac
  fi
  if [ "$os_key" = "darwin" ]; then
    set -- "$@" "Homebrew installer: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh (only if brew is missing)"
  fi
  if [ "$os_key" = "linux" ] && [ "$profile" != "remote" ] && [ "$headless" != "1" ]; then
    set -- "$@" \
      "terminal installer: Ghostty Ubuntu installer https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh" \
      "terminal package source: Alacritty Ubuntu PPA ppa:aslatter/ppa (Ubuntu only)"
  fi
  if [ "$profile" != "remote" ]; then
    set -- "$@" \
      "Oh My Zsh installer: https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" \
      "zsh plugin repositories: zsh-users/zsh-autosuggestions, zsh-users/zsh-syntax-highlighting, Aloxaf/fzf-tab, jeffreytse/zsh-vi-mode" \
      "tmux plugin manager repository: tmux-plugins/tpm"
  fi
  plan_join_words "$@"
}

print_plan_lines() {
  title="$1"
  shift
  printf '\n## %s\n' "$title"
  if [ "$#" -eq 0 ]; then
    printf -- '- none\n'
  else
    for item in "$@"; do
      printf -- '- %s\n' "$item"
    done
  fi
}

print_plan_stream() {
  title="$1"
  printf '\n## %s\n' "$title"
  while IFS= read -r item; do
    [ "$item" = "none" ] && printf -- '- none\n' || printf -- '- %s\n' "$item"
  done
}

main() {
  [ "$#" -eq 8 ] || { printf 'Usage: dotfiles-plan.sh profile include_secrets os headless ubuntu target_home repo_url chezmoi_url\n' >&2; exit 2; }
  profile="$1"
  include_secrets="$2"
  os_key="$3"
  headless="$4"
  ubuntu="$5"
  target_home="$6"
  repo_url="$7"
  chezmoi_url="$8"
  case "$profile" in remote|minimal|full) ;; *) printf 'Invalid profile\n' >&2; exit 2 ;; esac
  case "$include_secrets" in 0|1) ;; *) printf 'Invalid secrets flag\n' >&2; exit 2 ;; esac
  case "$os_key" in linux|darwin|unknown) ;; *) printf 'Invalid os\n' >&2; exit 2 ;; esac
  case "$headless" in 0|1) ;; *) printf 'Invalid headless flag\n' >&2; exit 2 ;; esac
  case "$ubuntu" in 0|1) ;; *) printf 'Invalid ubuntu flag\n' >&2; exit 2 ;; esac

  secrets_label="without-secrets"
  [ "$include_secrets" = "1" ] && secrets_label="with-secrets"

  printf '# Dotfiles installer plan (--dryrun)\n'
  printf '\nSelected profile: %s\n' "$profile"
  printf 'Secrets choice: %s\n' "$secrets_label"
  printf 'Platform: %s\n' "$os_key"
  printf 'Headless mode: %s\n' "$headless"

  case "$os_key" in
    linux)
      print_plan_lines "System package manager/action" "apt: update package index" "apt: install packages listed below" "sudo: required during real install"
      plan_linux_apt_packages "$profile" "$ubuntu" | print_plan_stream "Apt packages"
      plan_linux_terminal_packages "$profile" "$headless" | print_plan_stream "Additional terminal packages/installers"
      ;;
    darwin)
      print_plan_lines "System package manager/action" "Homebrew: tap/install packages and casks listed below"
      plan_darwin_brew_taps "$profile" | print_plan_stream "Homebrew taps"
      plan_darwin_brew_packages "$profile" | print_plan_stream "Homebrew packages"
      plan_darwin_brew_casks "$profile" "$headless" | print_plan_stream "Homebrew casks"
      ;;
    *)
      print_plan_lines "System package manager/action" "unsupported platform for real bootstrap; no package plan available"
      ;;
  esac

  printf '\n## Mise tool entries\n'
  plan_mise_tools "$profile" | while IFS= read -r tool; do
    [ -n "$tool" ] && printf -- '- %s\n' "$tool"
  done

  case "$profile:$headless" in
    remote:*)
      print_plan_lines "Managed configuration groups" "core shell/PATH without Oh My Zsh rich plugin bootstrap" "Neovim" "tmux config (not plugin checkout)" "OpenCode and Pi with free Zen defaults" "Git personal/default config" "Mise core tools"
      print_plan_lines "Excluded important target families" "GUI terminals and desktop automation" "Herdr/rich shell UX" "work-specific config including .gitconfig.work/worktrunk/jangl" "AWS config/credentials" "container/Kubernetes/cloud/infra tools"
      ;;
    minimal:1)
      print_plan_lines "Managed configuration groups" "Remote profile groups" "rich shell UX and Oh My Zsh plugin bootstrap" "Herdr"
      print_plan_lines "Excluded important target families" "terminal GUI configuration and installation" "work-specific config including .gitconfig.work/worktrunk/jangl" "AWS config/credentials" "container/Kubernetes/cloud/infra tools" "desktop automation extras"
      ;;
    minimal:0)
      print_plan_lines "Managed configuration groups" "Remote profile groups" "rich shell UX and Oh My Zsh plugin bootstrap" "Herdr" "terminal GUI config/installers"
      print_plan_lines "Excluded important target families" "work-specific config including .gitconfig.work/worktrunk/jangl" "AWS config/credentials" "container/Kubernetes/cloud/infra tools" "desktop automation extras"
      ;;
    full:1)
      print_plan_lines "Managed configuration groups" "Remote and Minimal profile groups" "work-specific Git/config targets" "AWS config and Darwin credentials when secrets are enabled" "container/Kubernetes/cloud/infra tools"
      print_plan_lines "Excluded important target families" "terminal GUI configuration and installation" "Codex global tool entry remains intentionally absent"
      ;;
    full:0)
      print_plan_lines "Managed configuration groups" "Remote and Minimal profile groups" "work-specific Git/config targets" "AWS config and Darwin credentials when secrets are enabled" "container/Kubernetes/cloud/infra tools" "GUI/desktop extras"
      print_plan_lines "Excluded important target families" "Codex global tool entry remains intentionally absent"
      ;;
  esac

  printf '\n## Secret targets that would be attempted\n'
  HOME="$target_home" plan_secret_targets "$os_key" "$profile" "$include_secrets" | while IFS= read -r target; do
    [ -n "$target" ] && printf -- '- %s\n' "$target"
  done
  if [ "$include_secrets" = "1" ]; then
    print_plan_lines "Secret/auth notes" "1Password CLI authentication is required during real install, but --dryrun does not call op or read secret values."
  else
    print_plan_lines "Secret/auth notes" "secret-backed targets remain ignored"
  fi

  printf '\n## External downloads/installers that real install may contact\n'
  plan_external_downloads "$os_key" "$profile" "$include_secrets" "$headless" "$repo_url" "$chezmoi_url" | while IFS= read -r download; do
    [ -n "$download" ] && printf -- '- %s\n' "$download"
  done

  print_plan_lines "Follow-up notes" \
    "GitHub auth is optional; if mise hits rate limits, run 'gh auth login' or export GITHUB_TOKEN, then retry mise install." \
    "Smaller profiles stop managing excluded targets but do not uninstall existing tools or delete existing files." \
    "chezmoi apply --dry-run only previews file operations; it is not equivalent to this installer plan."

  printf '\nNO CHANGES WERE MADE.\n'
}

main "$@"
