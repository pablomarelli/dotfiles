#!/bin/bash
set -euo pipefail

# Use the detected window, even if focus changes before this callback runs.
window_id=${AEROSPACE_WINDOW_ID:?Missing detected window ID}
pid=$(aerospace list-windows --all --format '%{window-id}|%{app-pid}|%{app-bundle-id}' |
  awk -F '|' -v id="$window_id" '$1 == id && $3 == "com.google.Chrome" { print $2 }')
[[ -n "$pid" ]] || exit 0
command=$(ps -ww -p "$pid" -o command=) || exit 0

# Both MCPs use dedicated profiles, with or without Chrome's sandbox enabled.
case "$command" in
  *--user-data-dir=*'/ms-playwright-mcp/'*|*--user-data-dir=*'/chrome-devtools-mcp/'*)
    aerospace move-node-to-workspace --window-id "$window_id" 1
    ;;
esac
