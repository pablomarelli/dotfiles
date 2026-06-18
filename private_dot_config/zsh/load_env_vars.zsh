
# Bitwarden session + JIRA credentials.
# ponytail: do not call bw during shell startup; run jira-env when credentials are needed.
if command -v bw >/dev/null 2>&1; then
  source ~/.local/bin/bw-session

  export JIRA_URL="https://whatifmediagroup.atlassian.net"
  _jira_cache="$HOME/.cache/.bw_jira_creds"

  if [[ -s "$_jira_cache" ]]; then
    source "$_jira_cache"
    export JIRA_USERNAME JIRA_API_TOKEN
  fi

  jira-env() {
    _jira_cache="$HOME/.cache/.bw_jira_creds"
    JIRA_USERNAME="$(bw get item JIRA_USERNAME | jq -r '.fields[] | select(.name=="JIRA_USERNAME") | .value')"
    JIRA_API_TOKEN="$(bw get item JIRA_API_TOKEN | jq -r '.fields[] | select(.name=="JIRA_API_TOKEN") | .value')"
    mkdir -p "$(dirname "$_jira_cache")"
    printf 'export JIRA_USERNAME=%q\nexport JIRA_API_TOKEN=%q\n' "$JIRA_USERNAME" "$JIRA_API_TOKEN" > "$_jira_cache"
    chmod 600 "$_jira_cache"
    export JIRA_USERNAME JIRA_API_TOKEN
  }

  unset _jira_cache

  # Refresh all Bitwarden caches (session + JIRA creds)
  bw-refresh() {
    rm -f "$HOME/.cache/.bw_session" "$HOME/.cache/.bw_jira_creds"
    source ~/.local/bin/bw-session
    jira-env
    echo "Bitwarden session and JIRA credentials refreshed."
  }
fi

if [[ -r "$HOME/.config/opencode/ntfy.env" ]]; then
  source "$HOME/.config/opencode/ntfy.env"
fi

# if command -v 1p
