# fzf_git_branch_insert() {
#   if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
#     print -r "Not in a Git repo."
#     zle .abort
#     return 1
#   fi
#
#   local original_fragment current_fragment branch
#   original_fragment=$LBUFFER
#
#   current_fragment=${LBUFFER##* }
#   LBUFFER=${LBUFFER%$current_fragment}
#
#   local git_user
#   git_user=$(git config user.name)
#
#   # Format: author|date|branch - use | delimiter then column for alignment
#   local fmt='%(authorname)|%(committerdate:relative)|%(refname:short)'
#   local all_cmd="git for-each-ref --sort=-committerdate --format='$fmt' refs/heads/ | column -t -s'|'"
#   local mine_cmd="git for-each-ref --sort=-committerdate --format='$fmt' refs/heads/ | grep -i '^$git_user|' | column -t -s'|'"
#
#   branch=$(eval "$all_cmd" | \
#     fzf --query="$current_fragment" \
#         --height 40% \
#         --reverse \
#         --border \
#         --nth=3.. \
#         --header "ctrl-o: my branches | ctrl-a: all" \
#         --bind "ctrl-o:reload($mine_cmd)" \
#         --bind "ctrl-a:reload($all_cmd)" \
#         --preview 'branch=$(echo {} | awk "{print \$NF}") && git log -5 --format="%C(yellow)%h %C(green)%cr %C(blue)%an%C(reset) %s" "$branch"' \
#     | awk '{print $NF}')
#   if [[ -z "$branch" ]]; then
#     LBUFFER=$original_fragment
#     zle redisplay
#     return 1
#   fi
#
#   LBUFFER+="$branch"
#   zle redisplay
# }
#
# # zle -N fzf_git_branch_insert
#
# zvm_after_lazy_keybindings() {
#   zvm_define_widget fzf_git_branch_insert
#   zvm_bindkey viins '\eg' fzf_git_branch_insert
#   zvm_bindkey vicmd '\eg' fzf_git_branch_insert
#
#   # Keybindings
#   bindkey '^p' history-search-backward
#   bindkey '^n' history-search-forward
# }
