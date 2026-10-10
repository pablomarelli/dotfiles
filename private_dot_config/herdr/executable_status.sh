#!/bin/sh

# Keep decimal parsing consistent regardless of the terminal locale.
export LC_ALL=C
parts=""

append() {
  if [ -n "$1" ]; then
    parts="${parts:+$parts | }$1"
  fi
}

case "$(uname -s)" in
  Darwin)
    # The second sample measures the last second, rather than time since boot.
    health=$(top -l 2 -s 1 -n 0 2>/dev/null | awk '
      function bytes(value, unit) {
        unit = substr(value, length(value), 1)
        if (unit == "K") return value * 1024
        if (unit == "M") return value * 1024^2
        if (unit == "G") return value * 1024^3
        if (unit == "T") return value * 1024^4
        return value + 0
      }
      /CPU usage/ { cpu = $3 + $5; have_cpu = 1 }
      /PhysMem:/ {
        used = bytes($2)
        for (i = 3; i <= NF; i++)
          if ($i ~ /^unused/) { free = bytes($(i - 1)); have_mem = 1 }
      }
      END {
        if (have_cpu) printf "CPU %.0f%%", cpu
        if (have_mem && used + free > 0)
          printf "%sMEM %.0f%%", have_cpu ? " | " : "", 100 * used / (used + free)
      }')
    append "$health"
    battery=$(pmset -g batt 2>/dev/null | awk '
      /InternalBattery/ {
        for (i = 1; i <= NF; i++)
          if ($i ~ /^[0-9]+%;/) { sub(/;.*/, "", $i); print "BAT " $i; exit }
      }')
    ;;
  Linux)
    first=$(awk '/^cpu / { print; exit }' /proc/stat 2>/dev/null)
    sleep 1
    second=$(awk '/^cpu / { print; exit }' /proc/stat 2>/dev/null)
    cpu=$(printf '%s\n%s\n' "$first" "$second" | awk '
      /^cpu / {
        total = 0
        # Guest time is already included in user/nice, so exclude those fields.
        for (i = 2; i <= 9; i++) total += $i
        idle = $5 + $6
        if (NR == 1) { old_total = total; old_idle = idle }
        else if (total > old_total)
          printf "CPU %.0f%%", 100 * (1 - (idle - old_idle) / (total - old_total))
      }')
    append "$cpu"
    memory=$(awk '
      /^MemTotal:/ { total = $2 }
      /^MemAvailable:/ { available = $2; found = 1 }
      END { if (total > 0 && found) printf "MEM %.0f%%", 100 * (total - available) / total }
    ' /proc/meminfo 2>/dev/null)
    append "$memory"
    battery=""
    for device in /sys/class/power_supply/*; do
      [ -r "$device/type" ] && [ -r "$device/capacity" ] || continue
      [ "$(cat "$device/type")" = "Battery" ] || continue
      capacity=$(cat "$device/capacity")
      case "$capacity" in
        ''|*[!0-9]*) continue ;;
      esac
      battery="BAT $capacity%"
      break
    done
    ;;
  *) battery="" ;;
esac

# Use the home filesystem, including the macOS writable APFS data volume.
disk=$(df -Pk "$HOME" 2>/dev/null | awk 'NR == 2 && $3 + $4 > 0 { printf "DISK %.0f%%", 100 * $3 / ($3 + $4) }')
append "$disk"
append "$battery"

printf '%s\n' "$parts"
