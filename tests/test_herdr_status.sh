#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script="$root/private_dot_config/herdr/executable_status.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/bin"
export FIXTURES="$tmp"
export REAL_AWK
REAL_AWK=$(command -v awk)

cat >"$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_OS"
EOF
for command in top df pmset; do
  cat >"$tmp/bin/$command" <<'EOF'
#!/bin/sh
cat "$FIXTURES/${0##*/}"
EOF
done
cat >"$tmp/bin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/awk" <<'EOF'
#!/bin/sh
case "${2:-}" in
  /proc/stat)
    if [ -f "$FIXTURES/sampled" ]; then
      printf 'cpu 120 0 80 700 0 0 0 0 0 0\n'
    else
      touch "$FIXTURES/sampled"
      printf 'cpu 100 0 50 650 0 0 0 0 0 0\n'
    fi | "$REAL_AWK" "$1"
    ;;
  /proc/meminfo)
    printf 'MemTotal: 1000 kB\nMemAvailable: 250 kB\n' | "$REAL_AWK" "$1"
    ;;
  *) exec "$REAL_AWK" "$@" ;;
esac
EOF
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
export TEST_OS=Darwin

cat >"$tmp/df" <<'EOF'
Filesystem 1024-blocks Used Available Capacity Mounted
/dev/test 1000 300 700 30% /home
EOF
cat >"$tmp/top" <<'EOF'
CPU usage: 80.0% user, 10.0% sys, 10.0% idle
PhysMem: 3G used (1G wired, 1G compressor), 1G unused.
CPU usage: 12.5% user, 7.5% sys, 80.0% idle
PhysMem: 768M used (100M wired, 100M compressor), 256M unused.
EOF
printf ' -InternalBattery-0 (id=123)\t85%%; discharging; present: true\n' >"$tmp/pmset"

check() {
  actual=$(sh "$script")
  # A Linux host may expose a real battery even with mocked /proc data.
  if [ "$TEST_OS" = Linux ]; then
    actual="${actual% | BAT *}"
  fi
  if [ "$actual" != "$1" ]; then
    printf 'FAIL: expected <%s>, got <%s>\n' "$1" "$actual" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$actual"
}

check 'CPU 20% | MEM 75% | DISK 30% | BAT 85%'
printf 'CPU usage: 0.0%% user, 0.0%% sys, 100.0%% idle\nPhysMem: 1G used, 1024M unused.\n' >"$tmp/top"
check 'CPU 0% | MEM 50% | DISK 30% | BAT 85%'
: >"$tmp/pmset"
check 'CPU 0% | MEM 50% | DISK 30%'
: >"$tmp/top"
check 'DISK 30%'
export TEST_OS=Linux
check 'CPU 50% | MEM 75% | DISK 30%'
