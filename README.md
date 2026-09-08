# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io). Supports macOS and Linux (Ubuntu/Debian).

## Quick start

### Prerequisites

- **Default public bootstrap**: `curl`, `sh`, GitHub network access, and a supported platform (macOS or Debian/Ubuntu Linux). The installer installs `chezmoi` with the official installer when needed.
- **macOS package installs after apply**: [Homebrew](https://brew.sh) installed.
- **Secret-backed bootstrap**: interactive terminal access, or an already authenticated [1Password CLI](https://developer.1password.com/docs/cli) session.

### Bootstrap a new machine

### Preview the installer plan

Run the planner locally before installing:

```bash
./install.sh --dryrun
./install.sh --dryrun --profile remote --without-secrets --non-interactive
```

`--dryrun` opens the same profile/secrets wizard as the installer unless you pass explicit flags. In the reviewed implementation, it performs zero network/auth/package/home/source/temp writes: no network requests, package installs, `sudo`, `chezmoi init/apply`, 1Password reads, GitHub auth, or writes under the managed home/source/temp areas. The alias `--dry-run` is accepted, but `--dryrun` is the documented spelling. Set `DOTFILES_HEADLESS=1` to preview or install a headless Minimal/Full profile without terminal GUI installation or terminal GUI configuration.

`chezmoi apply --dry-run` is useful later, but it only previews chezmoi file operations. It is not equivalent to the installer plan because it does not explain package installs, Mise tools, external installers, auth notes, or profile boundaries.

### Install

```bash
curl -fsSL https://dotfiles.pablomarelli.dev | sh
"$HOME/.local/bin/mise" install
```

With a controlling terminal this opens a short wizard. Choose an install profile, then choose whether to include 1Password-backed secrets. The second command is safe after a fresh shell because it uses the guaranteed mise path.

| Profile | Use case | Includes | Excludes |
|---|---|---|---|
| Remote | Fast SSH/server coding | Neovim, tmux, OpenCode, Pi, Git/GitHub CLI, shell PATH, Node 24, focused search/build tools; OpenCode Zen free-model defaults | GUI terminals, desktop automation, Herdr, containers, Kubernetes, cloud/infra, work/AWS configs |
| Minimal | Focused workstation | Remote + Herdr, rich shell UX, Starship, zoxide, bat/eza, lazygit, navi, television, sesh, ast-grep, terminal config/install when not headless | Kubernetes/container/cloud/infra stack, AWS/work-specific config, desktop automation extras |
| Full | Complete personal workstation | Everything currently intended, including languages, container/Kubernetes/cloud/infra and GUI/work/personal extras | Codex remains intentionally absent |

Profiles are forward-management choices. Switching from `full` to `minimal` or `remote` stops managing excluded targets and stops installing their profile tools on future runs; it does not uninstall existing tools or delete existing files. Work-specific Pi agents live locally under `~/.pi/agent/agents/work/` and are intentionally excluded from chezmoi.

Secret-backed templates are explicit opt-in:

```bash
curl -fsSL https://dotfiles.pablomarelli.dev | sh -s -- --with-secrets
"$HOME/.local/bin/mise" install
```

`--with-secrets` initializes the source first, installs `op` only on supported macOS Homebrew or Debian/Ubuntu environments, signs in interactively when needed, verifies every required `op://` reference, and only then runs `chezmoi apply`. If verification fails, apply is not run; rerun without `--with-secrets` for the public-only setup. The `Homelab/OpenCode Zen` item must contain an `api_key` field.

Automation can skip the wizard explicitly:

```bash
curl -fsSL https://dotfiles.pablomarelli.dev | sh -s -- --non-interactive
curl -fsSL https://dotfiles.pablomarelli.dev | sh -s -- --profile minimal --without-secrets
curl -fsSL https://dotfiles.pablomarelli.dev | sh -s -- --profile full --with-secrets
```

Noninteractive defaults are `--profile remote --without-secrets`.

To switch profiles later:

```bash
DOTFILES_INSTALL_PROFILE=minimal DOTFILES_INCLUDE_SECRETS=0 chezmoi init https://github.com/pablomarelli/dotfiles.git
DOTFILES_FORCE_IGNORE_SECRETS=1 chezmoi apply
"$HOME/.local/bin/mise" install
```

Set `DOTFILES_INCLUDE_SECRETS=1` and run the bootstrap with `--with-secrets` when you want secret targets verified/applied safely. Remote defaults Pi and OpenCode to the currently free `mimo-v2.5-free` model, with `ling-3.0-flash-fin-free` for smaller OpenCode tasks. Zen free models are temporary and may collect prompts or completions; do not use them with confidential code. Disable Zen billing auto-reload if the account should remain $0.

If you prefer to inspect before running, download the installer first:

```bash
curl -fsSLo install.sh https://dotfiles.pablomarelli.dev
less install.sh
sh install.sh
```

This repository intentionally uses a mutable `main` branch and a curl-pipe-shell bootstrap for a short personal setup command. Treat that as a trust decision in this public GitHub repository; inspect first when running on a machine you cannot easily rebuild.

On Debian/Ubuntu, the first apply installs system packages with `sudo`. `gh` is installed in every profile, but GitHub authentication is optional and separate from 1Password. Public installs are attempted unauthenticated; an existing `gh` token is not exported to installers. If GitHub rate limits a mise plugin, explicitly export a narrowly scoped `GITHUB_TOKEN`, then retry `"$HOME/.local/bin/mise" install`.

`chezmoi` bootstrap is pinned to `2.70.0` through the official installer `-t v2.70.0` flag, which downloads the matching release and verifies upstream checksums. Package setup still trusts the official `https://mise.run` installer and, for non-headless Linux GUI setup, the community Ghostty Ubuntu installer at `ghostty-ubuntu/HEAD`; those are existing personal bootstrap dependencies, now fetched with `curl -f` where used but not fully pinned in this pass.

### Rollout order for `dotfiles.pablomarelli.dev`

1. Publish and test this repository's `install.sh` on GitHub first.
2. Merge/apply the homelab DNS and Traefik redirect after the raw GitHub URL exists.
3. Then validate `curl -fsSL https://dotfiles.pablomarelli.dev | sh` from a disposable environment.

Until step 1 is merged, the raw redirect target may return 404. That is expected during cross-repo rollout.

Rollback/fix-forward:

- If dotfiles bootstrap breaks before infra rollout, revert the dotfiles commit or publish a fix and validate the raw GitHub URL again.
- If the redirect points at a bad `main`, update the homelab redirect target to a known-good raw commit URL until `main` is fixed.
- If infra rollout fails, disable/remove the `dotfiles` DNS record and Traefik route, then revert or fix-forward the infra change.

### Tests

```bash
sh -n install.sh
bash -n tests/install.sh
tests/install.sh
```

GitHub Actions runs the lightweight installer/template tests. The Docker sandbox remains a manual smoke test because it performs broader package/bootstrap work and is less deterministic than the focused CI path.

---

## What's managed

### Shell
| File | Description |
|---|---|
| `~/.zshrc` | Main zsh config, OS-conditional sourcing |
| `~/.config/zsh/aliases.zsh` | Aliases (eza, git, docker, tmux, etc.) |
| `~/.config/zsh/paths.zsh` | PATH setup, OS-conditional |
| `~/.config/zsh/cli-tools.zsh` | fzf, zoxide, navi init (cached) |
| `~/.config/zsh/oh-my-zsh.zsh` | Oh My Zsh + plugins config |
| `~/.config/zsh/prompt.zsh` | Starship init (cached) |
| `~/.config/zsh/programming-languages.zsh` | Go, bun, etc. (OS-conditional) |
| `~/.config/zsh/jangl.zsh` | Work config — macOS only |
| `~/.config/starship/starship.toml` | Starship prompt config |
| `~/.p10k.zsh` | Powerlevel10k config (fallback) |

### Editor
| File | Description |
|---|---|
| `~/.config/nvim/` | Neovim config (LazyVim-based, 40+ plugins) |

### Terminal emulators
| File | Description |
|---|---|
| `~/.config/ghostty/` | Ghostty config + 40 GLSL shaders — macOS + Linux |
| `~/.config/alacritty/alacritty.toml` | Alacritty config |

### Multiplexer
| File | Description |
|---|---|
| `~/.config/tmux/tmux.conf` | tmux config (tpm plugins not managed, installed by tpm) |

### Herdr
`prefix+o` opens the Television workspace picker.

### macOS only
| File | Description |
|---|---|
| `~/.config/aerospace/` | AeroSpace tiling window manager |
| `~/.config/karabiner/` | Karabiner-Elements key remapping |

### Linux only
| File | Description |
|---|---|
| `~/.config/albert/` | Albert launcher |

### CLI tools
| File | Description |
|---|---|
| `~/.config/mise/config.toml` | All CLI tools — see [Tools](#tools) |
| `~/.config/navi/` | Navi cheat sheets |
| `~/.config/television/` | Television config |

### Other
| File | Description |
|---|---|
| `~/.gitconfig` | Git config, OS-conditional include paths |
| `~/.gitconfig.pers` | Personal git profile (SSH key, email) |
| `~/.gitconfig.work` | Work git profile (SSH key, email) |
| `~/.aws/config` | AWS profile config (non-secret) |
| `~/.aws/credentials` | macOS AWS credentials — injected from 1Password only with `--with-secrets` |
| `~/.config/opencode/` | OpenCode AI assistant config, commands, skills |
| `~/.config/worktrunk/` | Worktrunk git worktree tool config |

---

## OS support

| Feature | macOS | Linux |
|---|---|---|
| Shell (zsh + oh-my-zsh) | ✓ | ✓ |
| Neovim | ✓ | ✓ |
| tmux | ✓ | ✓ |
| Ghostty | ✓ | ✓ |
| Alacritty | ✓ | ✓ |
| Starship | ✓ | ✓ |
| mise tools | ✓ | ✓ |
| AeroSpace | ✓ | — |
| Karabiner | ✓ | — |
| Albert | — | ✓ |
| AWS credentials (1Password, opt-in) | ✓ | — (TODO) |
| Work config (jangl.zsh) | ✓ | — |


---

## Tools

All CLI tools are managed via [mise](https://mise.jdx.dev) in `~/.config/mise/config.toml`.

| Tool | Description |
|---|---|
| neovim | Editor |
| tmux | Terminal multiplexer |
| starship | Shell prompt |
| navi | Interactive cheatsheet |
| fzf | Fuzzy finder |
| zoxide | Smarter cd |
| bat | Better cat |
| eza | Better ls |
| fd | Better find |
| ripgrep | Better grep |
| delta | Better git diff |
| gh | GitHub CLI |
| lazygit | Terminal git UI |
| lazydocker | Terminal docker UI |
| k9s | Kubernetes TUI |
| kubectx | Kubernetes context switcher |
| glow | Markdown renderer |
| xh | Modern HTTP client |
| television | Fuzzy finder TUI |
| opencode2 | OpenCode 2 beta AI coding assistant |
| pi | Pi coding agent |
| worktrunk | Git worktree management |
| 1Password CLI (`op`) | Optional secret bootstrap dependency, installed by `--with-secrets` when supported |
| chezmoi | Dotfiles manager |
| go / node / python / rust | Languages |
| k3d / terragrunt / opentofu | Infrastructure tools |

macOS-only (via Homebrew):

| Tool | Description |
|---|---|
| ghostty | Primary terminal emulator |
| alacritty | Secondary terminal emulator |
| raycast | Launcher |
| git-crypt | Git encryption |
| hunk | Terminal diff viewer |
| tailspin | Log highlighter |

---

## Day-to-day workflow

```bash
# Edit a managed file (opens in $EDITOR, applies on save)
chezmoi edit ~/.zshrc

# Add a new config to chezmoi
chezmoi add ~/.config/someapp/config

# Preview what would change
chezmoi diff

# Apply all changes
chezmoi apply

# Pull latest from repo and apply
chezmoi update
```

### Adding a new tool

1. **Choose the profile tier first**: Remote for SSH/server essentials, Minimal for focused rich-shell/workstation tools, Full for personal/work/cloud/infra extras.
2. **Check mise first**: `mise registry <tool>` — if available, add it to the matching profile block in `private_dot_config/mise/config.toml.tmpl`.
3. **Otherwise**: add to the relevant profile section in `run_onchange_install-packages-darwin.sh.tmpl` or `run_onchange_install-packages-linux.sh.tmpl`.
4. If the change affects profile tools, package lists, managed/excluded config families, or external installers/repositories, update `dotfiles-plan.sh` and the parity tests in `tests/install.sh` in the same work unit. The dryrun planner intentionally duplicates the user-facing contract and tests fail when it drifts from rendered templates.
5. Run `chezmoi apply`; Mise configuration changes alter the package script hash and rerun `mise install`.

### Adding a new config

```bash
chezmoi add ~/.config/newtool
chezmoi diff    # verify it looks right
chezmoi apply
```

> Never add directories that contain secrets, `node_modules`, or nested git repos.
> `.env` files, `node_modules/`, `bun.lock`, and `lazy-lock.json` are globally ignored.
