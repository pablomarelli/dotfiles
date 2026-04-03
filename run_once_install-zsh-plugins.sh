#!/usr/bin/env bash
# Install Oh My Zsh + plugins + tpm - runs once on first chezmoi apply
# Cross-platform (macOS + Linux)
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "==> Installing Oh My Zsh and plugins"

# Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo -e "${YELLOW}→${NC} Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  echo -e "${GREEN}✓${NC} Oh My Zsh installed"
else
  echo -e "${GREEN}✓${NC} Oh My Zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  echo -e "${YELLOW}→${NC} Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  echo -e "${GREEN}✓${NC} zsh-autosuggestions installed"
else
  echo -e "${GREEN}✓${NC} zsh-autosuggestions already installed"
fi

# zsh-syntax-highlighting
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  echo -e "${YELLOW}→${NC} Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  echo -e "${GREEN}✓${NC} zsh-syntax-highlighting installed"
else
  echo -e "${GREEN}✓${NC} zsh-syntax-highlighting already installed"
fi

# fzf-tab
if [[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]]; then
  echo -e "${YELLOW}→${NC} Installing fzf-tab..."
  git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
  echo -e "${GREEN}✓${NC} fzf-tab installed"
else
  echo -e "${GREEN}✓${NC} fzf-tab already installed"
fi

# zsh-vi-mode
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-vi-mode" ]]; then
  echo -e "${YELLOW}→${NC} Installing zsh-vi-mode..."
  git clone https://github.com/jeffreytse/zsh-vi-mode "$ZSH_CUSTOM/plugins/zsh-vi-mode"
  echo -e "${GREEN}✓${NC} zsh-vi-mode installed"
else
  echo -e "${GREEN}✓${NC} zsh-vi-mode already installed"
fi

# tmux plugin manager (tpm)
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo -e "${YELLOW}→${NC} Installing tmux plugin manager (tpm)..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  echo -e "${GREEN}✓${NC} tpm installed"
else
  echo -e "${GREEN}✓${NC} tpm already installed"
fi

echo ""
echo -e "${GREEN}✓${NC} All plugins installed!"
echo "  Restart zsh or run: exec zsh"
echo "  For tmux plugins: open tmux and press prefix + I"
