# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io). Supports macOS and Linux (Ubuntu/Debian).

## Quick start

### Prerequisites

- **macOS**: [Homebrew](https://brew.sh) installed
- **Both**: [1Password CLI](https://developer.1password.com/docs/cli) installed and signed in (`op signin`)

### Bootstrap a new machine

```bash
chezmoi init --apply https://github.com/PabloMarelli/dotfiles
mise install
```

That's it. The first command deploys all configs and runs the OS-specific install script. The second installs all CLI tools via mise.

> On a fresh machine, chezmoi itself can be bootstrapped with:
> ```bash
> curl https://mise.run | sh && mise install chezmoi && chezmoi init --apply https://github.com/PabloMarelli/dotfiles
> ```

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
| `~/.aws/credentials` | AWS credentials — injected from 1Password at apply time |
| `~/.config/opencode/` | OpenCode AI assistant config, agents, skills |
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
| AWS credentials (1Password) | ✓ | — (TODO) |
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
| opencode | AI coding assistant |
| codex | OpenAI coding agent |
| 1password-cli | 1Password CLI (`op`) |
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
| diffnav | Diff navigator |
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

1. **Check mise first**: `mise registry <tool>` — if available, add to `~/.config/mise/config.toml`
2. **Otherwise**: add to the `BREW_PKGS` or `BREW_CASKS` array in `run_once_install-packages-darwin.sh.tmpl` (and the Linux equivalent if applicable)
3. Run `mise install` or `chezmoi apply` to install

### Adding a new config

```bash
chezmoi add ~/.config/newtool
chezmoi diff    # verify it looks right
chezmoi apply
```

> Never add directories that contain secrets, `node_modules`, or nested git repos.
> `.env` files, `node_modules/`, `bun.lock`, and `lazy-lock.json` are globally ignored.
