
# Bitwarden session + JIRA credentials (cached to avoid slow bw CLI calls on every shell)
if command -v bw >/dev/null 2>&1; then
  source ~/.local/bin/bw-session

  export JIRA_URL="https://whatifmediagroup.atlassian.net"
  _jira_cache="$HOME/.cache/.bw_jira_creds"
  _jira_ttl=86400  # 24 hours

  if [[ -s "$_jira_cache" ]] && [[ $(( $(date +%s) - $(stat -f%m "$_jira_cache") )) -lt $_jira_ttl ]]; then
    source "$_jira_cache"
  else
    JIRA_USERNAME="$(bw get item JIRA_USERNAME | jq -r '.fields[] | select(.name=="JIRA_USERNAME") | .value')"
    JIRA_API_TOKEN="$(bw get item JIRA_API_TOKEN | jq -r '.fields[] | select(.name=="JIRA_API_TOKEN") | .value')"
    mkdir -p "$(dirname "$_jira_cache")"
    printf 'JIRA_USERNAME=%s\nJIRA_API_TOKEN=%s\n' "$JIRA_USERNAME" "$JIRA_API_TOKEN" > "$_jira_cache"
    chmod 600 "$_jira_cache"
  fi
  export JIRA_USERNAME JIRA_API_TOKEN
  unset _jira_cache _jira_ttl

  # Refresh all Bitwarden caches (session + JIRA creds)
  bw-refresh() {
    rm -f "$HOME/.cache/.bw_session" "$HOME/.cache/.bw_jira_creds"
    source ~/.local/bin/bw-session
    JIRA_USERNAME="$(bw get item JIRA_USERNAME | jq -r '.fields[] | select(.name=="JIRA_USERNAME") | .value')"
    JIRA_API_TOKEN="$(bw get item JIRA_API_TOKEN | jq -r '.fields[] | select(.name=="JIRA_API_TOKEN") | .value')"
    printf 'JIRA_USERNAME=%s\nJIRA_API_TOKEN=%s\n' "$JIRA_USERNAME" "$JIRA_API_TOKEN" > "$HOME/.cache/.bw_jira_creds"
    chmod 600 "$HOME/.cache/.bw_jira_creds"
    export JIRA_USERNAME JIRA_API_TOKEN
    echo "Bitwarden session and JIRA credentials refreshed."
  }
fi

# if command -v 1p
