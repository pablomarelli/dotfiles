alias v=nvim

# Eza
alias la="eza --long --header --icons --git --all --group-directories-first"
alias lap="eza --long --header --absolute=follow --icons --git --all"
alias lad="eza --long --header --only-dirs --icons --git --all"
alias ls="eza --header --icons --git --all --group-directories-first"
alias lt="eza --tree --level=2 --long --icons --git"

# xh modern curl
alias http="xh"

# My ip address
alias checkip="ip address | grep -o \"inet 192.*/\" | awk '{ print \$2 }' | tr / ' ' | xargs"

# Check commands history most used
# alias checkhistory="history | awk '{print $2}' | sort | uniq -c | sort -rn | head -n 10"
alias checkhistory='history | awk '\''{print $2}'\'' | sort | uniq -c | sort -rn | head -n 10'

# Configs
alias ohmyzshconfig="nvim ~/.oh-my-zsh"
alias starshipconfig="nvim ~/.config/starship/starship.toml"
alias zshconfig="nvim ~/dotfiles/zsh/.config/zsh/.zshrc"
alias zshsource="source ~/.zshrc"
alias tmuxconfig="nvim ~/.config/tmux/tmux.conf"
alias nvimconfig="cd ~/.config/nvim/ && nvim ."
alias alacrittyconfig="nvim ~/.config/alacritty/alacritty.toml"
alias ghosttyconfig="nvim ~/.config/ghostty/config"
alias aerospaceconfig="nvim ~/.config/aerospace/"
alias miseconfig="nvim ~/.config/mise/config.toml"

# GH alias
alias prs="gh dash"

# Git alias
alias cbr="git branch --sort=-committerdate | fzf --header 'Checkout Recent Branch' --preview 'git diff {1} --color=always | delta' --pointer='>' | xargs git checkout"
alias gitcheckcommits="git diff HEAD^ HEAD"
alias glog="git --no-pager log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit -n 5"
# alias gitbranchremote="git branch -r --contains $(git rev-parse HEAD)"
alias lg1="log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)' --all"
alias lg2="log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'"

# WT - Aliases
alias wtf='wt switch $(wt list | tail -n +2 | sed "s/\x1b\[[0-9;]*m//g" | awk "{print \$2}" | fzf)'

# Other aliases
alias lzd="lazydocker"
alias k="kubectl"
alias vpnclient="/Applications/Pritunl.app/Contents/Resources/pritunl-client"

# Tmux - attach to existing session or create "main" session (only when no args)
unalias tmux 2>/dev/null
tmux() {
  if [[ $# -eq 0 ]]; then
    command tmux new-session -A -s main
  else
    command tmux "$@"
  fi
}
