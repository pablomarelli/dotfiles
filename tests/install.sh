#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_CHEZMOI="$(command -v chezmoi)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1" text="$2"
  if ! grep -Fq -- "$text" "$file"; then
    printf 'Expected to find: %s\n--- %s ---\n' "$text" "$file" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1" text="$2"
  if grep -Fq -- "$text" "$file"; then
    printf 'Did not expect to find: %s\n--- %s ---\n' "$text" "$file" >&2
    cat "$file" >&2
    exit 1
  fi
}

write_op() {
  local bin="$1"
  cat >"$bin/op" <<'EOF'
#!/bin/sh
if [ -n "${OP_SESSION:-}" ]; then
  printf 'op env-session REDACTED %s\n' "$1" >>"$EVENT_LOG"
else
  printf 'op %s\n' "$*" >>"$EVENT_LOG"
fi
case "$1" in
  whoami)
    [ -n "${OP_SESSION:-}" ] && exit 0
    [ "${OP_AUTHENTICATED:-1}" = "1" ]
    exit $?
    ;;
  signin)
    if [ "$2" = "--raw" ]; then
      if [ -n "${OP_REQUIRE_SIGNIN_STDIN:-}" ]; then
        IFS= read -r marker || exit 3
        [ "$marker" = "$OP_REQUIRE_SIGNIN_STDIN" ] || exit 4
      fi
      printf '%s' "${OP_SIGNIN_OUTPUT:-session-token}"
      exit 0
    fi
    exit 2
    ;;
  read)
    if [ "${OP_READ_REQUIRES_SESSION:-0}" = "1" ] && [ -z "${OP_SESSION:-}" ]; then
      exit 5
    fi
    if [ "${OP_FAIL_READ:-0}" = "1" ]; then
      exit 1
    fi
    ref="$3"
    case "$ref" in
      'op://Homelab/OpenCode ntfy/url') value="${OP_NTFY_URL-https://ntfy.example}" ;;
      'op://Homelab/OpenCode ntfy/token') value="${OP_NTFY_TOKEN-fake-token}" ;;
      *) value="${OP_DEFAULT_VALUE-fake-secret}" ;;
    esac
    printf '%s' "$value"
    exit 0
    ;;
esac
exit 0
EOF
  chmod +x "$bin/op"
}

make_fixture() {
  local dir="$1" with_op="${2:-with-op}" bin="$dir/bin" log="$dir/events.log"
  mkdir -p "$bin" "$dir/home" "$dir/source"
  : >"$log"
  cp "$ROOT_DIR/secret-refs.txt" "$dir/source/secret-refs.txt"
  cat >"$dir/os-release" <<'EOF'
ID=ubuntu
ID_LIKE=debian
EOF

  cat >"$bin/chezmoi" <<'EOF'
#!/bin/sh
printf 'chezmoi %s\n' "$*" >>"$EVENT_LOG"
printf 'chezmoi-env OP_SESSION=%s\n' "${OP_SESSION:+present}" >>"$EVENT_LOG"
printf 'chezmoi-env DOTFILES_INCLUDE_SECRETS=%s DOTFILES_INSTALL_PROFILE=%s DOTFILES_FORCE_IGNORE_SECRETS=%s\n' "${DOTFILES_INCLUDE_SECRETS:-}" "${DOTFILES_INSTALL_PROFILE:-}" "${DOTFILES_FORCE_IGNORE_SECRETS:-}" >>"$EVENT_LOG"
if [ "$1" = "source-path" ]; then
  printf '%s\n' "$FAKE_SOURCE_DIR"
elif [ "$1" = "apply" ]; then
  shift
  is_secret_apply=0
  for target in "$@"; do
    case "$target" in
      */.config/opencode/ntfy.env|*/.aws/credentials)
        is_secret_apply=1
        ;;
    esac
  done
  if [ "$is_secret_apply" = "1" ]; then
    printf 'secret-apply OP_SESSION=%s\n' "${OP_SESSION:+present}" >>"$EVENT_LOG"
    [ "${FAIL_SECRET_APPLY:-0}" != "1" ] || exit 11
    OP_READ_REQUIRES_SESSION="${APPLY_REQUIRES_OP_SESSION:-0}" op read --no-newline 'op://Homelab/OpenCode ntfy/url' >/dev/null || exit 9
  else
    printf 'general-apply OP_SESSION=%s\n' "${OP_SESSION:+present}" >>"$EVENT_LOG"
    [ -z "${OP_SESSION:-}" ] || exit 10
  fi
fi
EOF
  chmod +x "$bin/chezmoi"

  cat >"$bin/curl" <<'EOF'
#!/bin/sh
printf 'curl %s\n' "$*" >>"$EVENT_LOG"
printf 'curl-env OP_SESSION=%s\n' "${OP_SESSION:+present}" >>"$EVENT_LOG"
out=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|-Lo|-sSLo|-fsSLo|-fSLo|-fsLo)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [ -n "$out" ]; then
  printf 'fake-download' >"$out"
else
  printf '#!/bin/sh\nexit 0\n'
fi
EOF
  chmod +x "$bin/curl"

  cat >"$bin/brew" <<'EOF'
#!/bin/sh
printf 'brew %s\n' "$*" >>"$EVENT_LOG"
printf 'brew-env OP_SESSION=%s\n' "${OP_SESSION:+present}" >>"$EVENT_LOG"
if [ "$1" = "install" ] && [ "$2" = "--cask" ] && [ "$3" = "1password-cli" ]; then
  cat >"$TEST_BIN_DIR/op" <<'OP_EOF'
#!/bin/sh
if [ -n "${OP_SESSION:-}" ]; then
  printf 'op env-session REDACTED %s\n' "$1" >>"$EVENT_LOG"
else
  printf 'op %s\n' "$*" >>"$EVENT_LOG"
fi
case "$1" in
  whoami) exit 0 ;;
  read)
    case "$3" in
      'op://Homelab/OpenCode ntfy/url') printf 'https://ntfy.example' ;;
      'op://Homelab/OpenCode ntfy/token') printf 'fake-token' ;;
      *) printf 'fake-secret' ;;
    esac
    exit 0
    ;;
esac
exit 0
OP_EOF
  chmod +x "$TEST_BIN_DIR/op"
fi
EOF
  chmod +x "$bin/brew"

  cat >"$bin/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >>"$EVENT_LOG"
printf 'sudo-env OP_SESSION=%s\n' "${OP_SESSION:+present}" >>"$EVENT_LOG"
case "$1" in
  install)
    exit 0
    ;;
  tee)
    cat >/dev/null
    exit 0
    ;;
  apt-get)
    if [ "$2" = "install" ]; then
      cat >"$TEST_BIN_DIR/op" <<'OP_EOF'
#!/bin/sh
if [ -n "${OP_SESSION:-}" ]; then
  printf 'op env-session REDACTED %s\n' "$1" >>"$EVENT_LOG"
else
  printf 'op %s\n' "$*" >>"$EVENT_LOG"
fi
case "$1" in
  whoami) exit 0 ;;
  read)
    case "$3" in
      'op://Homelab/OpenCode ntfy/url') printf 'https://ntfy.example' ;;
      'op://Homelab/OpenCode ntfy/token') printf 'fake-token' ;;
      *) printf 'fake-secret' ;;
    esac
    exit 0
    ;;
esac
exit 0
OP_EOF
      chmod +x "$TEST_BIN_DIR/op"
    fi
    exit 0
    ;;
esac
exit 0
EOF
  chmod +x "$bin/sudo"

  cat >"$bin/gpg" <<'EOF'
#!/bin/sh
printf 'gpg %s\n' "$*" >>"$EVENT_LOG"
case " $* " in
  *" --show-keys "*) printf 'fpr:::::::::%s:\n' "${GPG_FINGERPRINT:-3FEF9748469ADBE15DA7CA80AC2D62742012EA22}"; exit 0 ;;
esac
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--output" ]; then
    out="$2"
    break
  fi
  shift
done
[ -n "$out" ] && printf 'keyring' >"$out"
EOF
  chmod +x "$bin/gpg"

  cat >"$bin/dpkg" <<'EOF'
#!/bin/sh
printf 'dpkg %s\n' "$*" >>"$EVENT_LOG"
if [ "$1" = "--print-architecture" ]; then
  printf 'amd64\n'
fi
EOF
  chmod +x "$bin/dpkg"

  cat >"$bin/apt-get" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$bin/apt-get"

  [ "$with_op" = "without-op" ] || write_op "$bin"
}

run_installer() {
  local dir="$1"
  shift
  EVENT_LOG="$dir/events.log" \
  HOME="$dir/home" \
  PATH="$dir/bin:$PATH" \
  TEST_BIN_DIR="$dir/bin" \
  FAKE_SOURCE_DIR="$dir/source" \
  DOTFILES_REPO_URL="https://github.com/pablomarelli/dotfiles.git" \
  DOTFILES_TEST_OS="${TEST_OS:-linux}" \
  DOTFILES_TEST_OS_RELEASE="$dir/os-release" \
  DOTFILES_FORCE_INSTALL_OP="${DOTFILES_FORCE_INSTALL_OP:-0}" \
  OP_AUTHENTICATED="${OP_AUTHENTICATED:-1}" \
  OP_FAIL_READ="${OP_FAIL_READ:-0}" \
  OP_NTFY_URL="${OP_NTFY_URL-https://ntfy.example}" \
  OP_NTFY_TOKEN="${OP_NTFY_TOKEN-fake-token}" \
  OP_DEFAULT_VALUE="${OP_DEFAULT_VALUE:-fake-secret}" \
  OP_SIGNIN_OUTPUT="${OP_SIGNIN_OUTPUT:-session-token}" \
  OP_REQUIRE_SIGNIN_STDIN="${OP_REQUIRE_SIGNIN_STDIN:-}" \
  APPLY_REQUIRES_OP_SESSION="${APPLY_REQUIRES_OP_SESSION:-0}" \
  FAIL_SECRET_APPLY="${FAIL_SECRET_APPLY:-0}" \
  GPG_FINGERPRINT="${GPG_FINGERPRINT:-3FEF9748469ADBE15DA7CA80AC2D62742012EA22}" \
  "$ROOT_DIR/install.sh" "$@"
}

run_installer_with_pty() {
  local dir="$1" tty_input="$2" stdin_input="$3" prefix="$4"
  shift 4
  python3 - "$ROOT_DIR/install.sh" "$dir" "$tty_input" "$stdin_input" "$prefix" "$@" <<'PY'
import errno, fcntl, os, select, signal, sys, termios, time

script, directory, tty_input, stdin_input, prefix, *args = sys.argv[1:]
tty_input = tty_input.encode().decode("unicode_escape")
stdin_input = stdin_input.encode().decode("unicode_escape")
timeout_seconds = 10.0
try:
    master, slave = os.openpty()
except (AttributeError, OSError) as exc:
    reason = f"SKIP: Python PTY support unavailable: {exc}\n"
    os.makedirs(directory, exist_ok=True)
    open(f"{directory}/{prefix}.skip", "w", encoding="utf-8").write(reason)
    sys.stderr.write(reason)
    sys.exit(0)

slave_name = os.ttyname(slave)
stdin_r, stdin_w = os.pipe()
stdout_r, stdout_w = os.pipe()
stderr_r, stderr_w = os.pipe()
with open(script, "rb") as script_file:
    script_bytes = script_file.read()

pid = os.fork()
if pid == 0:
    try:
        os.setsid()
        ctty = os.open(slave_name, os.O_RDWR)
        fcntl.ioctl(ctty, termios.TIOCSCTTY, 0)
        os.open("/dev/tty", os.O_RDWR)
        os.dup2(stdin_r, 0)
        os.dup2(stdout_w, 1)
        os.dup2(stderr_w, 2)
        for fd in (master, slave, stdin_r, stdin_w, stdout_r, stdout_w, stderr_r, stderr_w):
            try:
                os.close(fd)
            except OSError:
                pass
        env = os.environ.copy()
        env.update({
            "EVENT_LOG": f"{directory}/events.log",
            "HOME": f"{directory}/home",
            "PATH": f"{directory}/bin:" + env.get("PATH", ""),
            "TEST_BIN_DIR": f"{directory}/bin",
            "FAKE_SOURCE_DIR": f"{directory}/source",
            "DOTFILES_REPO_URL": "https://github.com/pablomarelli/dotfiles.git",
            "DOTFILES_TEST_OS": env.get("TEST_OS", "linux"),
            "DOTFILES_TEST_OS_RELEASE": f"{directory}/os-release",
            "DOTFILES_FORCE_INSTALL_OP": env.get("DOTFILES_FORCE_INSTALL_OP", "0"),
            "OP_AUTHENTICATED": env.get("OP_AUTHENTICATED", "1"),
            "OP_FAIL_READ": env.get("OP_FAIL_READ", "0"),
            "OP_NTFY_URL": env.get("OP_NTFY_URL", "https://ntfy.example"),
            "OP_NTFY_TOKEN": env.get("OP_NTFY_TOKEN", "fake-token"),
            "OP_DEFAULT_VALUE": env.get("OP_DEFAULT_VALUE", "fake-secret"),
            "OP_SIGNIN_OUTPUT": env.get("OP_SIGNIN_OUTPUT", "session-token"),
            "OP_REQUIRE_SIGNIN_STDIN": env.get("OP_REQUIRE_SIGNIN_STDIN", ""),
            "APPLY_REQUIRES_OP_SESSION": env.get("APPLY_REQUIRES_OP_SESSION", "0"),
            "FAIL_SECRET_APPLY": env.get("FAIL_SECRET_APPLY", "0"),
        })
        os.execve("/bin/sh", ["sh", "-s", "--"] + args, env)
    except BaseException as exc:
        os.write(2, f"child exec failed: {exc}\n".encode())
        os._exit(127)

for fd in (slave, stdin_r, stdout_w, stderr_w):
    os.close(fd)
open(f"{directory}/{prefix}.invocation", "w", encoding="utf-8").write(
    "argv=sh -s -- " + " ".join(args) + "\n"
    "stdin=install.sh\n"
    "tty_input=" + repr(tty_input) + "\n"
    "ignored_stdin_probe=" + repr(stdin_input) + "\n"
)
os.write(stdin_w, script_bytes)
os.close(stdin_w)
time.sleep(0.05)
tty_bytes = tty_input.encode()
tty_index = 0
next_tty_write = time.monotonic() + 0.1
deadline = time.monotonic() + timeout_seconds
timed_out = False
status = None

buffers = {master: bytearray(), stdout_r: bytearray(), stderr_r: bytearray()}
open_fds = set(buffers)
while open_fds:
    if time.monotonic() > deadline:
        timed_out = True
        try:
            os.killpg(pid, signal.SIGTERM)
        except OSError:
            pass
        time.sleep(0.2)
        try:
            os.killpg(pid, signal.SIGKILL)
        except OSError:
            pass
        break
    if tty_index < len(tty_bytes) and time.monotonic() >= next_tty_write:
        try:
            os.write(master, tty_bytes[tty_index:tty_index + 1])
        except OSError:
            tty_index = len(tty_bytes)
        else:
            tty_index += 1
            next_tty_write = time.monotonic() + 0.03
    readable, _, _ = select.select(list(open_fds), [], [], 0.1)
    if not readable:
        done, _ = os.waitpid(pid, os.WNOHANG)
        if done:
            status = _
            break
        continue
    for fd in readable:
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            chunk = b""
        if chunk:
            buffers[fd].extend(chunk)
        else:
            open_fds.discard(fd)
            if fd != master:
                try:
                    os.close(fd)
                except OSError:
                    pass

if status is None:
    try:
        _, status = os.waitpid(pid, 0)
    except ChildProcessError:
        status = 1
for fd in list(open_fds):
    try:
        os.close(fd)
    except OSError:
        pass
open(f"{directory}/{prefix}.tty", "wb").write(buffers.get(master, b""))
open(f"{directory}/{prefix}.out", "wb").write(buffers.get(stdout_r, b""))
open(f"{directory}/{prefix}.err", "wb").write(buffers.get(stderr_r, b""))
if timed_out:
    sys.stderr.write(f"PTY installer harness timed out after {timeout_seconds:.1f}s\n")
    sys.exit(124)
if os.WIFEXITED(status):
    sys.exit(os.WEXITSTATUS(status))
sys.exit(1)
PY
}

extract_plan_section() {
  local file="$1" section="$2"
  awk -v section="## $section" '
    $0 == section { in_section=1; next }
    /^## / && in_section { exit }
    in_section && /^- / { sub(/^- /, ""); print }
  ' "$file"
}

dryrun_installer() {
  local dir="$1"
  shift
  run_installer "$dir" --dryrun "$@" >"$dir/dryrun.out" 2>"$dir/dryrun.err"
}

make_real_config() {
  local dir="$1" include="$2" os="$3"
  local profile="${4:-remote}"
  local headless="${5:-0}"
  mkdir -p "$dir/home/.config/chezmoi"
  DOTFILES_INCLUDE_SECRETS="$include" DOTFILES_TEST_OS="$os" DOTFILES_INSTALL_PROFILE="$profile" DOTFILES_HEADLESS="$headless" \
    HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" execute-template --init <"$ROOT_DIR/.chezmoi.toml.tmpl" >"$dir/home/.config/chezmoi/chezmoi.toml"
}

render_with_config() {
  local dir="$1" template="$2" output="$3"
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" execute-template <"$template" >"$output"
}

assert_line_set() {
  local file="$1" expected="$2" actual
  actual="$(awk '/^\[tools\]/{in_tools=1; next} /^\[/{in_tools=0} in_tools && /^[[:space:]]*[A-Za-z0-9_.\/:@"-]+ = / { sub(/[[:space:]]*#.*/, ""); print }' "$file" | sort)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected line set in %s\n--- expected ---\n%s\n--- actual ---\n%s\n' "$file" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_ignored_for_profile() {
  local dir="$1" os="$2" profile="$3" include="$4" output="$dir/ignored-$os-$profile-$include"
  make_real_config "$dir" "$include" "$os" "$profile"
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$output"
  if [[ "$profile" == "full" ]]; then
    if [[ "$include" == "1" ]]; then
      assert_not_contains "$output" ".aws/credentials"
    else
      assert_contains "$output" ".aws/credentials"
    fi
    assert_not_contains "$output" ".gitconfig.work"
    assert_not_contains "$output" ".config/opencode/commands/reviewpr.md"
  else
    assert_contains "$output" ".aws"
    assert_contains "$output" ".gitconfig.work"
    assert_contains "$output" ".config/opencode/commands/reviewpr.md"
    assert_contains "$output" ".config/zsh/jangl.zsh"
    if [[ "$profile" == "remote" ]]; then
      assert_contains "$output" ".config/navi"
    else
      assert_contains "$output" ".config/navi/jangl.cheat"
    fi
  fi
  if [[ "$include" == "1" ]]; then
    assert_not_contains "$output" ".config/opencode/ntfy.env"
    assert_not_contains "$output" ".config/opencode/zen.env"
  else
    assert_contains "$output" ".config/opencode/ntfy.env"
    assert_contains "$output" ".config/opencode/zen.env"
  fi
}

test_dryrun_aliases_and_no_mutation_or_auth() {
  local dir bin before after
  dir="$(mktemp -d)"
  make_fixture "$dir"
  mkdir -p "$dir/tmp"
  bin="$dir/bin"
  for cmd in curl wget git op gh sudo apt apt-get brew chezmoi; do
    cat >"$bin/$cmd" <<'EOF'
#!/bin/sh
printf 'HOSTILE %s\n' "$0" >>"$EVENT_LOG"
exit 99
EOF
    chmod +x "$bin/$cmd"
  done
  before="$(find "$dir/home" "$dir/source" "$dir/tmp" -type f -o -type d | sort)"

  (export OP_SESSION=ambient-secret TEST_OS=linux TMPDIR="$dir/tmp"; dryrun_installer "$dir" --profile remote --without-secrets --non-interactive)

  after="$(find "$dir/home" "$dir/source" "$dir/tmp" -type f -o -type d | sort)"
  [[ "$before" == "$after" ]] || fail "dryrun changed HOME, source, or temp files"
  [[ ! -s "$dir/events.log" ]] || fail "dryrun executed a mutating/network/auth mock"
  assert_contains "$dir/dryrun.out" "Selected profile: remote"
  assert_contains "$dir/dryrun.out" "Secrets choice: without-secrets"
  assert_contains "$dir/dryrun.out" "NO CHANGES WERE MADE."
  assert_not_contains "$dir/dryrun.out" "ambient-secret"

  : >"$dir/events.log"
  run_installer "$dir" --dry-run --profile minimal --without-secrets --non-interactive >"$dir/dry-run.out"
  assert_contains "$dir/dry-run.out" "Selected profile: minimal"
  [[ ! -s "$dir/events.log" ]] || fail "--dry-run alias executed a mutating/network/auth mock"
}

test_dryrun_help_documents_primary_and_alias() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  run_installer "$dir" --help >"$dir/help.out"

  assert_contains "$dir/help.out" "--dryrun"
  assert_contains "$dir/help.out" "Alias: --dry-run"
  [[ ! -s "$dir/events.log" ]] || fail "help should not execute external commands"
}

test_dryrun_interactive_wizard_reads_tty_only() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  run_installer_with_pty "$dir" '3\ny\n' '1\nn\n' dryrun --dryrun

  assert_contains "$dir/dryrun.invocation" "argv=sh -s -- --dryrun"
  assert_contains "$dir/dryrun.invocation" "stdin=install.sh"
  assert_contains "$dir/dryrun.invocation" "ignored_stdin_probe='1\\nn\\n'"
  assert_contains "$dir/dryrun.out" "Selected profile: full"
  assert_contains "$dir/dryrun.out" "Secrets choice: with-secrets"
  assert_contains "$dir/dryrun.tty" "Choose install profile"
  assert_contains "$dir/dryrun.tty" "Enable 1Password-backed secrets"
  assert_not_contains "$dir/dryrun.out" "Choose install profile"
  [[ ! -s "$dir/events.log" ]] || fail "dryrun wizard executed external commands"
}

test_dryrun_explicit_flags_suppress_prompts() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  run_installer "$dir" --dryrun --profile remote --without-secrets >"$dir/dryrun.out" 2>"$dir/dryrun.err"

  assert_contains "$dir/dryrun.out" "Selected profile: remote"
  assert_not_contains "$dir/dryrun.out" "Choose install profile"
  assert_not_contains "$dir/dryrun.out" "Enable 1Password-backed secrets"
  [[ ! -s "$dir/events.log" ]] || fail "dryrun explicit flags executed external commands"
}

test_dryrun_without_chezmoi_still_plans_without_installing() {
  local dir bin
  dir="$(mktemp -d)"
  make_fixture "$dir"
  bin="$dir/bin"
  for cmd in chezmoi curl; do
    cat >"$bin/$cmd" <<'EOF'
#!/bin/sh
printf 'HOSTILE %s\n' "$0" >>"$EVENT_LOG"
exit 99
EOF
    chmod +x "$bin/$cmd"
  done

  PATH="$bin:/usr/bin:/bin" EVENT_LOG="$dir/events.log" HOME="$dir/home" DOTFILES_TEST_OS=linux DOTFILES_TEST_OS_RELEASE="$dir/os-release" "$ROOT_DIR/install.sh" --dryrun --profile remote --without-secrets --non-interactive >"$dir/dryrun.out" 2>"$dir/dryrun.err"

  assert_contains "$dir/dryrun.out" "Selected profile: remote"
  assert_contains "$dir/dryrun.out" "NO CHANGES WERE MADE."
  [[ ! -s "$dir/events.log" ]] || fail "dryrun without chezmoi attempted install/network"
}

test_production_ignores_regular_file_tty_override() {
  local dir fake_tty before after
  dir="$(mktemp -d)"
  make_fixture "$dir"
  fake_tty="$dir/regular-tty"
  printf '3\ny\n' >"$fake_tty"
  before="$(cksum <"$fake_tty")"

  EVENT_LOG="$dir/events.log" HOME="$dir/home" PATH="$dir/bin:/usr/bin:/bin" DOTFILES_TTY_DEVICE="$fake_tty" DOTFILES_TEST_OS=linux DOTFILES_TEST_OS_RELEASE="$dir/os-release" "$ROOT_DIR/install.sh" --dryrun >"$dir/dryrun.out" 2>"$dir/dryrun.err"

  after="$(cksum <"$fake_tty")"
  [[ "$before" == "$after" ]] || fail "production dryrun modified arbitrary regular-file TTY override"
  assert_contains "$dir/dryrun.out" "Selected profile: remote"
  assert_not_contains "$fake_tty" "Choose install profile"
  [[ ! -s "$dir/events.log" ]] || fail "production regular-file TTY dryrun executed external commands"
}

test_dryrun_real_pty_wizard_if_python_available() {
  command -v python3 >/dev/null 2>&1 || return 0
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"
  run_installer_with_pty "$dir" '2\ny\n' '3\nn\n' pty --dryrun
  assert_contains "$dir/pty.out" "Selected profile: minimal"
  assert_contains "$dir/pty.out" "Secrets choice: with-secrets"
  [[ ! -s "$dir/events.log" ]] || fail "PTY dryrun wizard executed external commands"
}

test_planner_contains_no_execution_primitives() {
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" "eval"
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" '$('
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" '`'
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" "OP_SESSION"
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" "git clone"
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" "rm -"
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" "mkdir "
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" "touch "
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" "sudo "
  assert_not_contains "$ROOT_DIR/dotfiles-plan.sh" "apt install"
  local matches
  if matches="$(grep -nE '^[[:space:]]*(source|exec|curl|wget|git|op|gh|sudo|apt|apt-get|brew|chezmoi|mise|mktemp|mkdir|rm|touch)[[:space:]]' "$ROOT_DIR/dotfiles-plan.sh")"; then
    printf '%s\n' "$matches" >&2
    fail "planner contains command tokens that would mutate, authenticate, or contact the network"
  fi
}

test_planner_runs_with_no_path() {
  local dir
  dir="$(mktemp -d)"
  env -i HOME=/nonexistent XDG_CONFIG_HOME=/nonexistent XDG_CACHE_HOME=/nonexistent PATH=/nonexistent \
    /bin/sh "$ROOT_DIR/dotfiles-plan.sh" minimal 1 linux 1 1 "$dir/home" https://github.com/pablomarelli/dotfiles.git https://get.chezmoi.io >"$dir/plan.out"
  assert_contains "$dir/plan.out" "Selected profile: minimal"
  assert_contains "$dir/plan.out" "$dir/home/.config/opencode/ntfy.env"
  assert_contains "$dir/plan.out" "$dir/home/.config/opencode/zen.env"
  assert_contains "$dir/plan.out" "NO CHANGES WERE MADE."
}

test_default_skips_op_and_secret_apply() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  run_installer "$dir"

  assert_contains "$dir/events.log" "chezmoi init --apply https://github.com/pablomarelli/dotfiles.git"
  assert_contains "$dir/events.log" "DOTFILES_INCLUDE_SECRETS=0 DOTFILES_INSTALL_PROFILE=remote"
  assert_not_contains "$dir/events.log" "op "
}

test_noninteractive_defaults_remote_without_secrets() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  run_installer "$dir" --non-interactive

  assert_contains "$dir/events.log" "chezmoi init --apply https://github.com/pablomarelli/dotfiles.git"
  assert_contains "$dir/events.log" "DOTFILES_INCLUDE_SECRETS=0 DOTFILES_INSTALL_PROFILE=remote"
  assert_not_contains "$dir/events.log" "op "
}

test_invalid_profile_fails_before_mutation_or_network() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  if run_installer "$dir" --profile nope >"$dir/stdout" 2>"$dir/stderr"; then
    fail "invalid profile unexpectedly succeeded"
  fi

  assert_contains "$dir/stderr" "Invalid profile: nope"
  [[ ! -s "$dir/events.log" ]] || fail "invalid profile should fail before tool/network calls"
}

test_interactive_wizard_selects_profile_and_secrets() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  run_installer_with_pty "$dir" '2\ny\n' '3\nn\n' install

  assert_contains "$dir/install.invocation" "argv=sh -s -- "
  assert_contains "$dir/install.invocation" "stdin=install.sh"
  assert_contains "$dir/install.invocation" "ignored_stdin_probe='3\\nn\\n'"
  assert_contains "$dir/events.log" "chezmoi init https://github.com/pablomarelli/dotfiles.git"
  assert_contains "$dir/events.log" "DOTFILES_INCLUDE_SECRETS=1 DOTFILES_INSTALL_PROFILE=minimal"
  assert_contains "$dir/events.log" "chezmoi apply $dir/home/.config/opencode/ntfy.env"
  assert_contains "$dir/events.log" "DOTFILES_FORCE_IGNORE_SECRETS=1"
  assert_contains "$dir/install.tty" "Choose install profile"
  assert_contains "$dir/install.tty" "Enable 1Password-backed secrets"
  assert_not_contains "$dir/install.out" "Choose install profile"
  assert_not_contains "$dir/install.out" "Enable 1Password-backed secrets"
}

test_explicit_flags_suppress_prompts() {
  local dir stdout stderr
  dir="$(mktemp -d)"
  make_fixture "$dir"
  stdout="$dir/stdout"
  stderr="$dir/stderr"

  run_installer "$dir" --profile remote --without-secrets >"$stdout" 2>"$stderr"

  assert_contains "$dir/events.log" "chezmoi init --apply https://github.com/pablomarelli/dotfiles.git"
  assert_contains "$dir/events.log" "DOTFILES_INCLUDE_SECRETS=0 DOTFILES_INSTALL_PROFILE=remote"
  assert_not_contains "$dir/events.log" "op "
  assert_not_contains "$stdout" "Choose install profile"
}

test_with_secrets_verifies_before_apply() {
  local dir init_line read_line apply_line
  dir="$(mktemp -d)"
  make_fixture "$dir"

  run_installer "$dir" --profile remote --with-secrets

  assert_contains "$dir/events.log" "chezmoi init https://github.com/pablomarelli/dotfiles.git"
  assert_contains "$dir/events.log" "chezmoi source-path"
  assert_contains "$dir/events.log" "op whoami"
  assert_contains "$dir/events.log" "op read --no-newline op://Homelab/OpenCode ntfy/url"
  assert_contains "$dir/events.log" "op read --no-newline op://Homelab/OpenCode Zen/api_key"
  assert_contains "$dir/events.log" "chezmoi apply $dir/home/.config/opencode/ntfy.env $dir/home/.config/opencode/zen.env"
  [[ -d "$dir/home/.config/opencode" ]] || fail "secret apply did not create the OpenCode config directory"
  assert_contains "$dir/events.log" "general-apply OP_SESSION="

  init_line="$(grep -nF 'chezmoi init ' "$dir/events.log" | cut -d: -f1 | head -n1)"
  read_line="$(grep -nF 'op read ' "$dir/events.log" | cut -d: -f1 | head -n1)"
  apply_line="$(grep -nF "chezmoi apply $dir/home/.config/opencode/ntfy.env" "$dir/events.log" | cut -d: -f1 | head -n1)"
  [[ "$init_line" -lt "$read_line" ]] || fail "secrets should be verified after init"
  [[ "$read_line" -lt "$apply_line" ]] || fail "apply should run after secret verification"
}

test_failed_secret_verification_prevents_apply() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  if (export OP_FAIL_READ=1; run_installer "$dir" --profile remote --with-secrets) >"$dir/stdout" 2>"$dir/stderr"; then
    fail "installer unexpectedly succeeded"
  fi

  assert_contains "$dir/events.log" "op read --no-newline op://Homelab/OpenCode ntfy/url"
  assert_not_contains "$dir/events.log" "chezmoi apply"
  assert_contains "$dir/stderr" "Secret verification failed before apply"
}

test_empty_and_invalid_secret_values_prevent_apply() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  if (export OP_NTFY_TOKEN=; run_installer "$dir" --profile remote --with-secrets) >"$dir/stdout-empty" 2>"$dir/stderr-empty"; then
    fail "empty token unexpectedly succeeded"
  fi
  assert_contains "$dir/stderr-empty" "Empty 1Password reference: op://Homelab/OpenCode ntfy/token"
  assert_not_contains "$dir/events.log" "chezmoi apply"

  : >"$dir/events.log"
  if (export OP_NTFY_URL=http://ntfy.example; run_installer "$dir" --profile remote --with-secrets) >"$dir/stdout-url" 2>"$dir/stderr-url"; then
    fail "non-HTTPS URL unexpectedly succeeded"
  fi
  assert_contains "$dir/stderr-url" "Invalid ntfy URL reference"
  assert_not_contains "$dir/events.log" "chezmoi apply"
}

test_unauthenticated_with_controlling_tty_signs_in() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  (export OP_AUTHENTICATED=0 OP_REQUIRE_SIGNIN_STDIN=tty-marker APPLY_REQUIRES_OP_SESSION=1; run_installer_with_pty "$dir" 'tty-marker\n' '' signin --profile remote --with-secrets)

  assert_contains "$dir/signin.invocation" "argv=sh -s -- --profile remote --with-secrets"
  assert_contains "$dir/signin.invocation" "stdin=install.sh"
  assert_contains "$dir/events.log" "op whoami"
  assert_contains "$dir/events.log" "op signin --raw"
  assert_contains "$dir/events.log" "op env-session REDACTED whoami"
  assert_contains "$dir/events.log" "op env-session REDACTED read"
  assert_contains "$dir/events.log" "secret-apply OP_SESSION=present"
  assert_contains "$dir/events.log" "general-apply OP_SESSION="
}

test_failed_secret_apply_prevents_general_apply() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  if (export OP_AUTHENTICATED=0 OP_REQUIRE_SIGNIN_STDIN=tty-marker APPLY_REQUIRES_OP_SESSION=1 FAIL_SECRET_APPLY=1; run_installer_with_pty "$dir" 'tty-marker\n' '' failsecret --profile remote --with-secrets) >"$dir/stdout" 2>"$dir/stderr"; then
    fail "failed secret apply unexpectedly succeeded"
  fi

  assert_contains "$dir/events.log" "secret-apply OP_SESSION=present"
  assert_not_contains "$dir/events.log" "general-apply"
  assert_contains "$dir/failsecret.err" "Secret target apply failed. General apply was not run."
}

test_signin_output_is_not_executed_or_logged() {
  local dir injected
  dir="$(mktemp -d)"
  make_fixture "$dir"
  injected="$dir/signin-output-executed"

  (export OP_AUTHENTICATED=0 OP_REQUIRE_SIGNIN_STDIN=tty-marker OP_SIGNIN_OUTPUT="session-token; touch $injected"; run_installer_with_pty "$dir" 'tty-marker\n' '' signininject --profile remote --with-secrets)

  assert_contains "$dir/events.log" "op signin --raw"
  assert_contains "$dir/events.log" "op env-session REDACTED whoami"
  assert_not_contains "$dir/events.log" "session-token; touch"
  [[ ! -e "$injected" ]] || fail "signin output was executed"
}

test_unauthenticated_without_tty_fails() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  if (export OP_AUTHENTICATED=0; run_installer "$dir" --profile remote --with-secrets) >"$dir/stdout" 2>"$dir/stderr"; then
    fail "non-TTY unauthenticated installer unexpectedly succeeded"
  fi

  assert_contains "$dir/stderr" "requires an authenticated 1Password CLI session in non-interactive mode"
  assert_not_contains "$dir/events.log" "op signin"
  assert_not_contains "$dir/events.log" "chezmoi apply"
}

test_debian_op_install_path_is_mockable() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir" without-op

  (export DOTFILES_FORCE_INSTALL_OP=1; run_installer "$dir" --profile remote --with-secrets)

  assert_contains "$dir/events.log" "curl -fsSLo"
  assert_contains "$dir/events.log" "gpg --batch --show-keys --with-colons"
  assert_contains "$dir/events.log" "gpg --dearmor --output"
  assert_contains "$dir/events.log" "sudo install -D -m 0644"
  assert_contains "$dir/events.log" "sudo apt-get install -y 1password-cli"
  assert_contains "$dir/events.log" "chezmoi apply"
}

test_debian_op_rejects_unexpected_signing_key() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir" without-op

  if (export DOTFILES_FORCE_INSTALL_OP=1 GPG_FINGERPRINT=BAD; run_installer "$dir" --profile remote --with-secrets) >"$dir/stdout" 2>"$dir/stderr"; then
    fail "unexpected 1Password signing key was trusted"
  fi

  assert_contains "$dir/stderr" "fingerprint does not match"
  assert_not_contains "$dir/events.log" "sudo install -D -m 0644"
  assert_not_contains "$dir/events.log" "chezmoi apply"
}

test_darwin_homebrew_op_install_and_refs() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir" without-op

  (export TEST_OS=darwin DOTFILES_FORCE_INSTALL_OP=1; run_installer "$dir" --profile full --with-secrets)

  assert_contains "$dir/events.log" "brew install --cask 1password-cli"
  assert_contains "$dir/events.log" "op read --no-newline op://Private/AWS Credentials/default_key_id"
  assert_contains "$dir/events.log" "op read --no-newline op://Private/AWS Credentials/jobnation_secret"
  assert_contains "$dir/events.log" "chezmoi apply"
}

test_secret_target_selection_by_os_profile() {
  local os profile include dir
  for os in linux darwin; do
    for profile in remote minimal full; do
      for include in false true; do
        dir="$(mktemp -d)"
        make_fixture "$dir"
        if [[ "$include" == "true" ]]; then
          (export TEST_OS="$os"; run_installer "$dir" --profile "$profile" --with-secrets)
          assert_contains "$dir/events.log" "chezmoi apply $dir/home/.config/opencode/ntfy.env $dir/home/.config/opencode/zen.env"
          if [[ "$os" == "darwin" && "$profile" == "full" ]]; then
            assert_contains "$dir/events.log" "$dir/home/.aws/credentials"
            assert_contains "$dir/events.log" "op read --no-newline op://Private/AWS Credentials/default_key_id"
          else
            assert_not_contains "$dir/events.log" "$dir/home/.aws/credentials"
            assert_not_contains "$dir/events.log" "op read --no-newline op://Private/AWS Credentials/default_key_id"
          fi
        else
          (export TEST_OS="$os"; run_installer "$dir" --profile "$profile" --without-secrets)
          assert_contains "$dir/events.log" "chezmoi init --apply https://github.com/pablomarelli/dotfiles.git"
          assert_not_contains "$dir/events.log" "chezmoi apply $dir/home/.config/opencode/ntfy.env"
          assert_not_contains "$dir/events.log" "$dir/home/.aws/credentials"
        fi
      done
    done
  done
}

test_secret_target_apply_is_independent_of_cwd() {
  local dir outside
  dir="$(mktemp -d)"
  make_fixture "$dir"
  outside="$(mktemp -d)"

  (cd "$outside" && run_installer "$dir" --profile full --with-secrets)

  assert_contains "$dir/events.log" "chezmoi apply $dir/home/.config/opencode/ntfy.env $dir/home/.config/opencode/zen.env"
  assert_contains "$dir/events.log" "secret-apply OP_SESSION="
  assert_not_contains "$dir/events.log" "chezmoi apply .config/opencode/ntfy.env"
}

test_real_chezmoi_ignore_and_config_data() {
  local dir os profile include
  dir="$(mktemp -d)"

  make_real_config "$dir" 0 linux
  assert_contains "$dir/home/.config/chezmoi/chezmoi.toml" "include_secrets = false"
  assert_contains "$dir/home/.config/chezmoi/chezmoi.toml" 'dotfiles_os = "linux"'
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/ignored-linux"
  assert_contains "$dir/ignored-linux" ".config/opencode/ntfy.env"
  assert_contains "$dir/ignored-linux" ".config/opencode/zen.env"
  assert_contains "$dir/ignored-linux" ".aws"

  make_real_config "$dir" 0 darwin
  assert_contains "$dir/home/.config/chezmoi/chezmoi.toml" "include_secrets = false"
  assert_contains "$dir/home/.config/chezmoi/chezmoi.toml" 'dotfiles_os = "darwin"'
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/ignored-darwin"
  assert_contains "$dir/ignored-darwin" ".config/opencode/ntfy.env"
  assert_contains "$dir/ignored-darwin" ".config/opencode/zen.env"
  assert_contains "$dir/ignored-darwin" ".aws"

  make_real_config "$dir" 1 darwin full
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/ignored-secrets"
  assert_not_contains "$dir/ignored-secrets" ".config/opencode/ntfy.env"
  assert_not_contains "$dir/ignored-secrets" ".config/opencode/zen.env"
  assert_not_contains "$dir/ignored-secrets" ".aws/credentials"

  for os in linux darwin; do
    for profile in remote minimal full; do
      for include in 0 1; do
        assert_ignored_for_profile "$dir" "$os" "$profile" "$include"
      done
    done
  done

  make_real_config "$dir" 1 linux full
  DOTFILES_FORCE_IGNORE_SECRETS=1 HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/ignored-force-linux"
  assert_contains "$dir/ignored-force-linux" ".config/opencode/ntfy.env"
  assert_contains "$dir/ignored-force-linux" ".config/opencode/zen.env"
  assert_contains "$dir/ignored-force-linux" ".aws/credentials"
  mkdir -p "$dir/bin"
  cat >"$dir/bin/op" <<'EOF'
#!/bin/sh
exit 99
EOF
  chmod +x "$dir/bin/op"
  DOTFILES_FORCE_IGNORE_SECRETS=1 HOME="$dir/home" PATH="$dir/bin:$PATH" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" apply --dry-run --no-tty >/dev/null

  make_real_config "$dir" 1 darwin full
  DOTFILES_FORCE_IGNORE_SECRETS=1 HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/ignored-force-darwin"
  assert_contains "$dir/ignored-force-darwin" ".config/opencode/ntfy.env"
  assert_contains "$dir/ignored-force-darwin" ".config/opencode/zen.env"
  assert_contains "$dir/ignored-force-darwin" ".aws/credentials"
}

test_profile_mise_rendering() {
  local dir expected_remote expected_minimal expected_full
  dir="$(mktemp -d)"

  expected_remote="$(cat <<'EOF' | sort
"github:neovim/neovim" = "latest"
"npm:@opencode-ai/cli" = { version = "0.0.0-beta-19151", allow_builds = ["@opencode-ai/cli"] }
"npm:@earendil-works/pi-coding-agent" = "0.84.4"
chezmoi = "2.70.0"
delta = "latest"
fd = "latest"
fzf = "latest"
gh = "latest"
jq = "latest"
node = "24"
ripgrep = "latest"
tmux = "latest"
tree-sitter = "latest"
EOF
)"
  expected_minimal="$(cat <<'EOF' | sort
"aqua:alexpasmantier/television" = "latest"
"aqua:joshmedeski/sesh" = "latest"
"cargo:navi" = "latest"
"github:neovim/neovim" = "latest"
rust = "latest"
starship = "latest"
"github:ogulcancelik/herdr" = "latest"
"npm:@earendil-works/pi-coding-agent" = "0.84.4"
"npm:@opencode-ai/cli" = { version = "0.0.0-beta-19151", allow_builds = ["@opencode-ai/cli"] }
ast-grep = "latest"
bat = "latest"
chezmoi = "2.70.0"
delta = "latest"
eza = "latest"
fd = "latest"
fzf = "latest"
gh = "latest"
jq = "latest"
lazygit = "latest"
node = "24"
ripgrep = "latest"
tmux = "latest"
tree-sitter = "latest"
zoxide = "latest"
EOF
)"
  expected_full="$(cat <<'EOF' | sort
"aqua:alexpasmantier/television" = "latest"
"aqua:joshmedeski/sesh" = "latest"
"cargo:navi" = "latest"
"github:neovim/neovim" = "latest"
"github:ogulcancelik/herdr" = "latest"
starship = "latest"
"npm:@earendil-works/pi-coding-agent" = "0.84.4"
"npm:@opencode-ai/cli" = { version = "0.0.0-beta-19151", allow_builds = ["@opencode-ai/cli"] }
"npm:sql-formatter" = "latest"
ast-grep = "latest"
bat = "latest"
cheat = "latest"
chezmoi = "2.70.0"
coreutils = "latest"
delta = "latest"
docker-cli = "latest"
duf = "latest"
eza = "latest"
fd = "latest"
fzf = "latest"
gh = "latest"
glow = "latest"
go = "latest"
jq = "latest"
k3d = "latest"
k9s = "latest"
kubectl = "latest"
kubectx = "latest"
lazydocker = "latest"
lazygit = "latest"
node = "24"
opentofu = "latest"
pipx = "latest"
python = "3.10.20"
ripgrep = "latest"
rust = "latest"
terragrunt = "latest"
tlrc = "latest"
tmux = "latest"
tree-sitter = "latest"
usage = "latest"
xh = "latest"
zoxide = "latest"
EOF
)"

  make_real_config "$dir" 0 linux remote
  render_with_config "$dir" "$ROOT_DIR/private_dot_config/mise/config.toml.tmpl" "$dir/mise-remote.toml"
  assert_line_set "$dir/mise-remote.toml" "$expected_remote"

  make_real_config "$dir" 0 linux minimal
  render_with_config "$dir" "$ROOT_DIR/private_dot_config/mise/config.toml.tmpl" "$dir/mise-minimal.toml"
  assert_line_set "$dir/mise-minimal.toml" "$expected_minimal"

  make_real_config "$dir" 0 linux full
  render_with_config "$dir" "$ROOT_DIR/private_dot_config/mise/config.toml.tmpl" "$dir/mise-full.toml"
  assert_line_set "$dir/mise-full.toml" "$expected_full"
}

test_dryrun_mise_sets_match_rendered_templates() {
  local dir profile rendered_set dryrun_set
  dir="$(mktemp -d)"
  make_fixture "$dir"
  for profile in remote minimal full; do
    make_real_config "$dir" 0 linux "$profile"
    render_with_config "$dir" "$ROOT_DIR/private_dot_config/mise/config.toml.tmpl" "$dir/mise-$profile.toml"
    rendered_set="$(awk '/^\[tools\]/{in_tools=1; next} /^\[/{in_tools=0} in_tools && /^[[:space:]]*[A-Za-z0-9_.\/:@"-]+ = / { sub(/[[:space:]]*#.*/, ""); print }' "$dir/mise-$profile.toml" | sort)"
    (export TEST_OS=linux; dryrun_installer "$dir" --profile "$profile" --without-secrets --non-interactive)
    dryrun_set="$(extract_plan_section "$dir/dryrun.out" "Mise tool entries" | sort)"
    [[ "$dryrun_set" == "$rendered_set" ]] || fail "dryrun mise set drift for $profile"
  done
}

test_dryrun_package_sets_match_profile_contracts() {
  local dir profile headless section expected actual ubuntu_extra
  dir="$(mktemp -d)"
  make_fixture "$dir"
  ubuntu_extra="software-properties-common"
  for profile in remote minimal full; do
    for headless in 0 1; do
      (export TEST_OS=linux DOTFILES_HEADLESS="$headless"; dryrun_installer "$dir" --profile "$profile" --without-secrets --non-interactive)
      actual="$(extract_plan_section "$dir/dryrun.out" "Apt packages" | sort | tr '\n' ' ' | sed 's/ $//')"
      case "$profile" in
        remote) expected="build-essential curl gcc git $ubuntu_extra wget zsh" ;;
        minimal|full) expected="build-essential curl gcc git $ubuntu_extra wget xclip xdg-utils zsh" ;;
      esac
      expected="$(printf '%s\n' $expected | sort | tr '\n' ' ' | sed 's/ $//')"
      [[ "$actual" == "$expected" ]] || fail "dryrun linux apt drift for $profile headless=$headless: $actual"
      section="$(extract_plan_section "$dir/dryrun.out" "Additional terminal packages/installers" | sort | tr '\n' ' ' | sed 's/ $//')"
      if [[ "$profile" != "remote" && "$headless" == "0" ]]; then
        [[ "$section" == "alacritty" ]] || fail "dryrun linux terminal drift for $profile headless=$headless: $section"
      else
        [[ "$section" == "none" ]] || fail "dryrun linux terminal should be none for $profile headless=$headless: $section"
      fi
    done
  done

  for profile in remote minimal full; do
    for headless in 0 1; do
      (export TEST_OS=darwin DOTFILES_HEADLESS="$headless"; dryrun_installer "$dir" --profile "$profile" --without-secrets --non-interactive)
      actual="$(extract_plan_section "$dir/dryrun.out" "Homebrew packages" | sort | tr '\n' ' ' | sed 's/ $//')"
      case "$profile" in
        remote) expected="gcc git zsh" ;;
        minimal) expected="dark-notify gcc git zsh" ;;
        full) expected="dark-notify gcc git git-crypt hunk tailspin worktrunk zsh" ;;
      esac
      expected="$(printf '%s\n' $expected | sort | tr '\n' ' ' | sed 's/ $//')"
      [[ "$actual" == "$expected" ]] || fail "dryrun darwin brew package drift for $profile headless=$headless: $actual"

      actual="$(extract_plan_section "$dir/dryrun.out" "Homebrew taps" | sort | tr '\n' ' ' | sed 's/ $//')"
      case "$profile" in
        remote) expected="none" ;;
        minimal) expected="cormacrelf/tap" ;;
        full) expected="cormacrelf/tap felixkratz/formulae modem-dev/tap" ;;
      esac
      expected="$(printf '%s\n' $expected | sort | tr '\n' ' ' | sed 's/ $//')"
      [[ "$actual" == "$expected" ]] || fail "dryrun darwin tap drift for $profile headless=$headless: $actual"

      actual="$(extract_plan_section "$dir/dryrun.out" "Homebrew casks" | sort | tr '\n' ' ' | sed 's/ $//')"
      case "$profile:$headless" in
        remote:*|minimal:1|full:1) expected="none" ;;
        minimal:0) expected="alacritty ghostty" ;;
        full:0) expected="alacritty font-symbols-only-nerd-font ghostty ngrok raycast" ;;
      esac
      expected="$(printf '%s\n' $expected | sort | tr '\n' ' ' | sed 's/ $//')"
      [[ "$actual" == "$expected" ]] || fail "dryrun darwin cask drift for $profile headless=$headless: $actual"
    done
  done
}

test_dryrun_secret_target_plan() {
  local dir output
  dir="$(mktemp -d)"
  make_fixture "$dir"
  for profile in remote minimal full; do
    (export TEST_OS=linux; dryrun_installer "$dir" --profile "$profile" --with-secrets --non-interactive)
    output="$dir/dryrun.out"
    assert_contains "$output" "$dir/home/.config/opencode/ntfy.env"
    assert_contains "$output" "$dir/home/.config/opencode/zen.env"
    assert_not_contains "$output" "$dir/home/.aws/credentials"

    (export TEST_OS=darwin; dryrun_installer "$dir" --profile "$profile" --with-secrets --non-interactive)
    output="$dir/dryrun.out"
    assert_contains "$output" "$dir/home/.config/opencode/ntfy.env"
    assert_contains "$output" "$dir/home/.config/opencode/zen.env"
    if [[ "$profile" == "full" ]]; then
      assert_contains "$output" "$dir/home/.aws/credentials"
    else
      assert_not_contains "$output" "$dir/home/.aws/credentials"
    fi
  done
  (export TEST_OS=darwin; dryrun_installer "$dir" --profile full --without-secrets --non-interactive)
  assert_contains "$dir/dryrun.out" "Secret targets that would be attempted"
  assert_contains "$dir/dryrun.out" "- none"
}

test_headless_gui_config_ignore_matches_plan() {
  local dir profile output plan_excluded
  dir="$(mktemp -d)"
  make_fixture "$dir"
  for profile in minimal full; do
    make_real_config "$dir" 0 linux "$profile" 1
    HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/ignored-headless-$profile"
    assert_contains "$dir/ignored-headless-$profile" ".config/ghostty"
    assert_contains "$dir/ignored-headless-$profile" ".config/alacritty"
    (export TEST_OS=linux DOTFILES_HEADLESS=1; dryrun_installer "$dir" --profile "$profile" --without-secrets --non-interactive)
    assert_contains "$dir/dryrun.out" "terminal GUI configuration and installation"

    make_real_config "$dir" 0 linux "$profile" 0
    HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/ignored-gui-$profile"
    assert_not_contains "$dir/ignored-gui-$profile" ".config/ghostty"
  done
}

test_dryrun_external_contacts_are_complete() {
  local dir profile headless section expected actual
  dir="$(mktemp -d)"
  make_fixture "$dir"
  for profile in remote minimal full; do
    for headless in 0 1; do
      for os in linux darwin; do
        (export TEST_OS="$os" DOTFILES_HEADLESS="$headless"; dryrun_installer "$dir" --profile "$profile" --with-secrets --non-interactive)
        section="$(extract_plan_section "$dir/dryrun.out" "External downloads/installers that real install may contact")"
        assert_contains "$dir/dryrun.out" "dotfiles source repository: https://github.com/pablomarelli/dotfiles.git"
        assert_contains "$dir/dryrun.out" "chezmoi official installer: https://get.chezmoi.io"
        assert_contains "$dir/dryrun.out" "mise installer: https://mise.run"
        if [[ "$os" == "linux" ]]; then
          assert_contains "$dir/dryrun.out" "1Password apt repository/key/policy downloads"
          if [[ "$profile" != "remote" && "$headless" == "0" ]]; then
            assert_contains "$dir/dryrun.out" "terminal installer: Ghostty Ubuntu installer https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh"
            assert_contains "$dir/dryrun.out" "terminal package source: Alacritty Ubuntu PPA ppa:aslatter/ppa"
          else
            assert_not_contains "$dir/dryrun.out" "Ghostty Ubuntu installer"
            assert_not_contains "$dir/dryrun.out" "Alacritty Ubuntu PPA"
          fi
        else
          assert_contains "$dir/dryrun.out" "1Password CLI Homebrew cask: 1password-cli"
          assert_contains "$dir/dryrun.out" "Homebrew installer: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
        fi
        if [[ "$profile" == "remote" ]]; then
          assert_not_contains "$dir/dryrun.out" "Oh My Zsh installer"
          assert_not_contains "$dir/dryrun.out" "zsh plugin repositories"
        else
          assert_contains "$dir/dryrun.out" "Oh My Zsh installer: https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
          assert_contains "$dir/dryrun.out" "zsh-users/zsh-autosuggestions"
          assert_contains "$dir/dryrun.out" "zsh-users/zsh-syntax-highlighting"
          assert_contains "$dir/dryrun.out" "Aloxaf/fzf-tab"
          assert_contains "$dir/dryrun.out" "jeffreytse/zsh-vi-mode"
          assert_contains "$dir/dryrun.out" "tmux-plugins/tpm"
        fi
      done
    done
  done
}

test_profile_package_script_rendering() {
  local dir
  dir="$(mktemp -d)"

  make_real_config "$dir" 0 linux remote
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-linux.sh.tmpl" "$dir/linux-remote.sh"
  assert_contains "$dir/linux-remote.sh" 'PROFILE="remote"'
  assert_contains "$dir/linux-remote.sh" 'Remote profile: skipping GUI terminal installers'

  make_real_config "$dir" 0 linux minimal
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-linux.sh.tmpl" "$dir/linux-minimal.sh"
  assert_contains "$dir/linux-minimal.sh" 'PROFILE="minimal"'

  make_real_config "$dir" 0 linux minimal 1
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-linux.sh.tmpl" "$dir/linux-minimal-headless.sh"
  assert_contains "$dir/linux-minimal-headless.sh" 'HEADLESS="1"'

  make_real_config "$dir" 0 linux minimal 0
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-linux.sh.tmpl" "$dir/linux-minimal-gui.sh"
  assert_contains "$dir/linux-minimal-gui.sh" 'HEADLESS="0"'

  make_real_config "$dir" 0 darwin remote
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-darwin.sh.tmpl" "$dir/darwin-remote.sh"
  assert_contains "$dir/darwin-remote.sh" 'PROFILE="remote"'
  assert_contains "$dir/darwin-remote.sh" 'BREW_CASKS=()'

  make_real_config "$dir" 0 darwin full 1
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-darwin.sh.tmpl" "$dir/darwin-full-headless.sh"
  assert_contains "$dir/darwin-full-headless.sh" 'HEADLESS="1"'
  assert_not_contains "$ROOT_DIR/run_onchange_install-packages-darwin.sh.tmpl" 'eval '
}

test_zsh_plugin_profile_contract() {
  local dir remote_hash minimal_hash full_hash
  dir="$(mktemp -d)"

  make_real_config "$dir" 0 linux remote
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-zsh-plugins.sh.tmpl" "$dir/zsh-remote.sh"
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/ignored-remote"
  [[ ! -s "$dir/zsh-remote.sh" ]] || fail "remote zsh plugin script should render empty"

  make_real_config "$dir" 0 linux minimal
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-zsh-plugins.sh.tmpl" "$dir/zsh-minimal.sh"
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/ignored-minimal"
  assert_contains "$dir/zsh-minimal.sh" "Installing Oh My Zsh and plugins for minimal profile"
  assert_contains "$dir/zsh-minimal.sh" "curl -fsSL"
  assert_not_contains "$dir/zsh-minimal.sh" 'sh -c "$(curl'
  assert_not_contains "$dir/ignored-minimal" "run_onchange_install-zsh-plugins.sh"

  make_real_config "$dir" 0 linux full
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-zsh-plugins.sh.tmpl" "$dir/zsh-full.sh"
  assert_contains "$dir/zsh-full.sh" "Installing Oh My Zsh and plugins for full profile"

  remote_hash="$(cksum <"$dir/zsh-remote.sh")"
  minimal_hash="$(cksum <"$dir/zsh-minimal.sh")"
  full_hash="$(cksum <"$dir/zsh-full.sh")"
  [[ "$remote_hash" != "$minimal_hash" ]] || fail "remote to minimal should change run_onchange content"
  [[ "$minimal_hash" != "$full_hash" ]] || fail "minimal to full should change run_onchange content"
}

test_portable_profile_configs() {
  local dir
  dir="$(mktemp -d)"

  make_real_config "$dir" 0 linux remote
  render_with_config "$dir" "$ROOT_DIR/dot_zprofile.tmpl" "$dir/zprofile-linux"
  assert_not_contains "$dir/zprofile-linux" "/opt/homebrew"
  assert_not_contains "$dir/zprofile-linux" "/opt/local"

  render_with_config "$dir" "$ROOT_DIR/private_dot_config/opencode/opencode.jsonc.tmpl" "$dir/opencode-remote.json"
  jq -e '.model == "opencode/mimo-v2.5-free" and .small_model == "opencode/ling-3.0-flash-fin-free"' "$dir/opencode-remote.json" >/dev/null
  assert_not_contains "$dir/opencode-remote.json" '"atlassian"'
  assert_not_contains "$dir/opencode-remote.json" '"Devops-MCP-hub"'
  assert_not_contains "$dir/opencode-remote.json" '"sentry"'

  render_with_config "$dir" "$ROOT_DIR/dot_pi/private_agent/settings.json.tmpl" "$dir/pi-remote.json"
  jq -e '.defaultProvider == "opencode" and .defaultModel == "mimo-v2.5-free"' "$dir/pi-remote.json" >/dev/null

  make_real_config "$dir" 0 darwin full
  render_with_config "$dir" "$ROOT_DIR/dot_zprofile.tmpl" "$dir/zprofile-darwin"
  assert_contains "$dir/zprofile-darwin" "/opt/homebrew"
  assert_contains "$dir/zprofile-darwin" "/opt/local"

  render_with_config "$dir" "$ROOT_DIR/private_dot_config/ghostty/config.tmpl" "$dir/ghostty-config"
  assert_contains "$dir/ghostty-config" "$dir/home/.config/ghostty/shaders/cursor_smear.glsl"

  render_with_config "$dir" "$ROOT_DIR/private_dot_config/opencode/opencode.jsonc.tmpl" "$dir/opencode-full.json"
  jq -e '.model == "openai/gpt-5.6-sol" and (.mcp.servers.atlassian.codemode == false) and .mcp.servers["Devops-MCP-hub"] and .mcp.servers.sentry and (.websearch.provider == "random")' "$dir/opencode-full.json" >/dev/null

  render_with_config "$dir" "$ROOT_DIR/dot_pi/private_agent/settings.json.tmpl" "$dir/pi-full.json"
  jq -e '.defaultProvider == "openai-codex" and .defaultModel == "gpt-5.6-sol"' "$dir/pi-full.json" >/dev/null

}

test_pi_work_agents_are_local_only() {
  local dir
  dir="$(mktemp -d)"
  [[ ! -e "$ROOT_DIR/dot_pi/private_agent/agents/calls-integrations-maker.md.tmpl" ]] || fail "calls work agent is still managed by chezmoi"
  [[ ! -e "$ROOT_DIR/dot_pi/private_agent/agents/webleads-integrations-maker.md.tmpl" ]] || fail "webleads work agent is still managed by chezmoi"
  [[ ! -e "$ROOT_DIR/private_dot_config/opencode/agent/calls-integrations-maker.md.tmpl" ]] || fail "calls work agent is still managed by OpenCode chezmoi config"
  [[ ! -e "$ROOT_DIR/private_dot_config/opencode/agent/webleads-integrations-maker.md.tmpl" ]] || fail "webleads work agent is still managed by OpenCode chezmoi config"
  assert_contains "$ROOT_DIR/.chezmoiignore" ".pi/agent/agents/work/**"

  make_real_config "$dir" 0 darwin full
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" managed >"$dir/managed"
  assert_not_contains "$dir/managed" ".pi/agent/agents/calls-integrations-maker.md"
  assert_not_contains "$dir/managed" ".pi/agent/agents/webleads-integrations-maker.md"
}

test_agent_keys_are_scoped_to_agent_processes() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/bin" "$dir/home/.config/opencode"
  make_real_config "$dir" 0 linux remote
  render_with_config "$dir" "$ROOT_DIR/private_dot_config/zsh/load_env_vars.zsh.tmpl" "$dir/load-env.zsh"

  cat >"$dir/home/.config/opencode/zen.env" <<'EOF'
export OPENCODE_API_KEY=zen-secret
EOF
  cat >"$dir/home/.config/opencode/ntfy.env" <<'EOF'
export OPENCODE_NTFY_TOKEN=ntfy-secret
EOF
  cat >"$dir/bin/pi" <<'EOF'
#!/bin/sh
printf 'zen=%s ntfy=%s\n' "${OPENCODE_API_KEY:-}" "${OPENCODE_NTFY_TOKEN:-}"
EOF
  cp "$dir/bin/pi" "$dir/bin/opencode2"
  chmod +x "$dir/bin/pi" "$dir/bin/opencode2"

  HOME="$dir/home" PATH="$dir/bin:/usr/bin:/bin" /bin/zsh -f -c '
    source "$1"
    [[ -z ${OPENCODE_API_KEY:-} ]]
    [[ -z ${OPENCODE_NTFY_TOKEN:-} ]]
    pi >"$2/pi.out"
    opencode2 >"$2/opencode.out"
    [[ -z ${OPENCODE_API_KEY:-} ]]
    [[ -z ${OPENCODE_NTFY_TOKEN:-} ]]
  ' _ "$dir/load-env.zsh" "$dir"

  assert_contains "$dir/pi.out" "zen=zen-secret ntfy="
  assert_contains "$dir/opencode.out" "zen=zen-secret ntfy=ntfy-secret"
}

test_aliases_preserve_system_commands_without_optional_tools() {
  PATH=/usr/bin:/bin /bin/zsh -f -c '
    source "$1"
    (( ! $+aliases[ls] ))
    (( ! $+aliases[diff] ))
    command -v ls >/dev/null
    command -v diff >/dev/null
  ' _ "$ROOT_DIR/private_dot_config/zsh/aliases.zsh"
}

test_direct_template_profile_validation_and_legacy_defaults() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/home/.config/chezmoi"

  if DOTFILES_INSTALL_PROFILE=nope HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" execute-template --init <"$ROOT_DIR/.chezmoi.toml.tmpl" >"$dir/invalid-config" 2>"$dir/invalid-error"; then
    fail "direct initialization accepted an invalid profile"
  fi
  assert_contains "$dir/invalid-error" "expected remote, minimal, or full"

  cat >"$dir/home/.config/chezmoi/chezmoi.toml" <<'EOF'
[data]
  name = "Legacy config"
EOF
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" --config "$dir/home/.config/chezmoi/chezmoi.toml" ignored >"$dir/legacy-ignored"
  render_with_config "$dir" "$ROOT_DIR/private_dot_config/mise/config.toml.tmpl" "$dir/legacy-mise.toml"
  assert_contains "$dir/legacy-mise.toml" '"npm:@earendil-works/pi-coding-agent" = "0.84.4"'
}

test_package_scripts_track_mise_config() {
  assert_contains "$ROOT_DIR/run_onchange_install-packages-darwin.sh.tmpl" 'includeTemplate "private_dot_config/mise/config.toml.tmpl"'
  assert_contains "$ROOT_DIR/run_onchange_install-packages-linux.sh.tmpl" 'includeTemplate "private_dot_config/mise/config.toml.tmpl"'
  assert_not_contains "$ROOT_DIR/run_onchange_install-packages-darwin.sh.tmpl" 'gh auth token'
  assert_not_contains "$ROOT_DIR/run_onchange_install-packages-linux.sh.tmpl" 'gh auth token'
}

test_darwin_package_sets_without_github_token() {
  local dir bin home script output profile headless expected_pkgs expected_casks actual_pkgs actual_casks
  for profile in remote minimal full; do
    for headless in 0 1; do
      dir="$(mktemp -d)"
      bin="$dir/bin"
      home="$dir/home"
      mkdir -p "$bin" "$home"
      make_real_config "$dir" 0 darwin "$profile" "$headless"
      render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-darwin.sh.tmpl" "$dir/darwin.sh"
      script="$dir/darwin.sh"
      output="$dir/output.log"
      cat >"$bin/brew" <<'EOF'
#!/bin/sh
case "$1" in
  tap) shift; printf 'tap %s\n' "$*" >>"$BREW_LOG"; exit 0 ;;
  list) exit 1 ;;
  install)
    if [ "$2" = "--cask" ]; then printf 'cask %s\n' "$3" >>"$BREW_LOG"; else printf 'pkg %s\n' "$2" >>"$BREW_LOG"; fi
    exit 0
    ;;
esac
exit 0
EOF
      chmod +x "$bin/brew"
      cat >"$bin/mise" <<'EOF'
#!/bin/sh
printf 'GITHUB_TOKEN=%s\n' "${GITHUB_TOKEN:+present}" >>"$MISE_LOG"
printf 'mise %s\n' "$*" >>"$MISE_LOG"
exit "${MISE_EXIT:-0}"
EOF
      chmod +x "$bin/mise"
      cat >"$bin/gh" <<'EOF'
#!/bin/sh
if [ "$1" = "auth" ] && [ "$2" = "token" ]; then printf 'mock-token'; exit 0; fi
exit 1
EOF
      chmod +x "$bin/gh"
      BREW_LOG="$dir/brew.log" MISE_LOG="$dir/mise.log" HOME="$home" PATH="$bin:/usr/bin:/bin" bash "$script" >"$output" 2>&1
      actual_pkgs="$(grep '^pkg ' "$dir/brew.log" 2>/dev/null | cut -d' ' -f2- | sort | tr '\n' ' ' | sed 's/ $//' || true)"
      actual_casks="$(grep '^cask ' "$dir/brew.log" 2>/dev/null | cut -d' ' -f2- | sort | tr '\n' ' ' | sed 's/ $//' || true)"
      case "$profile:$headless" in
        remote:*) expected_pkgs="gcc git zsh"; expected_casks="" ;;
        minimal:0) expected_pkgs="dark-notify gcc git zsh"; expected_casks="alacritty ghostty" ;;
        minimal:1) expected_pkgs="dark-notify gcc git zsh"; expected_casks="" ;;
        full:0) expected_pkgs="dark-notify gcc git git-crypt hunk tailspin worktrunk zsh"; expected_casks="alacritty font-symbols-only-nerd-font ghostty ngrok raycast" ;;
        full:1) expected_pkgs="dark-notify gcc git git-crypt hunk tailspin worktrunk zsh"; expected_casks="" ;;
      esac
      [[ "$actual_pkgs" == "$expected_pkgs" ]] || fail "unexpected darwin packages for $profile headless=$headless: $actual_pkgs"
      [[ "$actual_casks" == "$expected_casks" ]] || fail "unexpected darwin casks for $profile headless=$headless: $actual_casks"
      assert_contains "$dir/mise.log" "GITHUB_TOKEN="
      assert_not_contains "$dir/mise.log" "GITHUB_TOKEN=present"
    done
  done

  dir="$(mktemp -d)"
  bin="$dir/bin"
  home="$dir/home"
  mkdir -p "$bin" "$home"
  make_real_config "$dir" 0 darwin remote
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-darwin.sh.tmpl" "$dir/darwin.sh"
  cat >"$bin/brew" <<'EOF'
#!/bin/sh
case "$1" in tap) exit 0 ;; list) exit 0 ;; install) exit 0 ;; esac
exit 0
EOF
  chmod +x "$bin/brew"
  cat >"$bin/gh" <<'EOF'
#!/bin/sh
exit 1
EOF
  chmod +x "$bin/gh"
  cat >"$bin/mise" <<'EOF'
#!/bin/sh
printf 'GITHUB_TOKEN=%s\n' "${GITHUB_TOKEN:+present}" >>"$MISE_LOG"
exit 42
EOF
  chmod +x "$bin/mise"
  if BREW_LOG="$dir/brew.log" MISE_LOG="$dir/mise.log" HOME="$home" PATH="$bin:/usr/bin:/bin" bash "$dir/darwin.sh" >"$dir/fail-output" 2>&1; then
    fail "darwin mise failure unexpectedly succeeded"
  fi
  assert_contains "$dir/mise.log" "GITHUB_TOKEN="
  assert_contains "$dir/fail-output" "run 'gh auth login' or export GITHUB_TOKEN"
}

test_linux_package_sets_by_profile_headless_on_linux() {
  local dir bin home script output profile headless expected actual ubuntu_extra
  [[ -r /etc/os-release ]] || return 0
  ubuntu_extra=""
  if grep -Eq '^ID=ubuntu' /etc/os-release; then
    ubuntu_extra=" software-properties-common"
  fi
  for profile in remote minimal full; do
    for headless in 0 1; do
      dir="$(mktemp -d)"
      bin="$dir/bin"
      home="$dir/home"
      mkdir -p "$bin" "$home"
      make_real_config "$dir" 0 linux "$profile" "$headless"
      render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-linux.sh.tmpl" "$dir/linux.sh"
      script="$dir/linux.sh"
      output="$dir/output.log"
      cat >"$bin/sudo" <<'EOF'
#!/bin/sh
case "$1" in
  apt)
    if [ "$2" = "install" ]; then printf 'pkg %s\n' "$4" >>"$APT_LOG"; fi
    exit 0
    ;;
  add-apt-repository)
    exit 0
    ;;
  chown)
    exit 0
    ;;
esac
exit 0
EOF
      chmod +x "$bin/sudo"
      cat >"$bin/dpkg" <<'EOF'
#!/bin/sh
exit 1
EOF
      chmod +x "$bin/dpkg"
      cat >"$bin/curl" <<'EOF'
#!/bin/sh
out=""
while [ "$#" -gt 0 ]; do
  case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac
done
[ -n "$out" ] || exit 1
cat >"$out" <<'SCRIPT'
#!/bin/sh
mkdir -p "$TEST_BIN_DIR"
touch "$TEST_BIN_DIR/ghostty"
chmod +x "$TEST_BIN_DIR/ghostty"
SCRIPT
EOF
      chmod +x "$bin/curl"
      cat >"$bin/mise" <<'EOF'
#!/bin/sh
printf 'mise %s\n' "$*" >>"$MISE_LOG"
EOF
      chmod +x "$bin/mise"
      APT_LOG="$dir/apt.log" MISE_LOG="$dir/mise.log" TEST_BIN_DIR="$bin" HOME="$home" PATH="$bin:/usr/bin:/bin" bash "$script" >"$output" 2>&1
      actual="$(sort "$dir/apt.log" | cut -d' ' -f2- | tr '\n' ' ' | sed 's/ $//')"
      case "$profile:$headless" in
        remote:*) expected="build-essential curl gcc git${ubuntu_extra} wget zsh" ;;
        minimal:0|full:0)
          expected="build-essential curl gcc git${ubuntu_extra} wget xclip xdg-utils zsh"
          command -v alacritty >/dev/null 2>&1 || expected="alacritty $expected"
          ;;
        minimal:1|full:1) expected="build-essential curl gcc git${ubuntu_extra} wget xclip xdg-utils zsh" ;;
      esac
      expected="$(printf '%s\n' $expected | sort | tr '\n' ' ' | sed 's/ $//')"
      [[ "$actual" == "$expected" ]] || fail "unexpected linux packages for $profile headless=$headless: $actual"
      if [[ "$profile" == "remote" ]]; then
        assert_contains "$output" "Remote profile: skipping GUI terminal installers"
      elif [[ "$headless" == "1" ]]; then
        assert_contains "$output" "Headless mode: skipping Ghostty and Alacritty"
      fi
    done
  done
}

test_ambient_op_session_is_captured_and_not_leaked() {
  local dir
  dir="$(mktemp -d)"
  make_fixture "$dir"

  (export OP_SESSION=ambient-session APPLY_REQUIRES_OP_SESSION=1; run_installer "$dir" --profile remote --with-secrets)

  assert_contains "$dir/events.log" "op env-session REDACTED whoami"
  assert_contains "$dir/events.log" "secret-apply OP_SESSION=present"
  assert_contains "$dir/events.log" "general-apply OP_SESSION="
  assert_not_contains "$dir/events.log" "curl-env OP_SESSION=present"
  assert_not_contains "$dir/events.log" "sudo-env OP_SESSION=present"
  assert_not_contains "$dir/events.log" "brew-env OP_SESSION=present"
  assert_not_contains "$dir/events.log" "ambient-session"
}

test_secret_refs_manifest_covers_template_refs() {
  local dir
  dir="$(mktemp -d)"

  grep -Rho 'output "op" "read" "--no-newline" "op://[^"]*"' \
    "$ROOT_DIR/private_dot_config" "$ROOT_DIR/private_dot_aws" |
    sed 's/^.*"\(op:\/\/.*\)"$/\1/' | sort -u >"$dir/template-refs"
  awk 'NF && $1 !~ /^#/ { $1=""; $2=""; sub(/^  */, ""); print }' "$ROOT_DIR/secret-refs.txt" | sort -u >"$dir/manifest-refs"

  diff -u "$dir/template-refs" "$dir/manifest-refs"
}

test_ntfy_template_shell_quotes_hostile_values() {
  local dir rendered pwn_file
  dir="$(mktemp -d)"
  mkdir -p "$dir/bin" "$dir/home"
  : >"$dir/events.log"
  write_op "$dir/bin"
  rendered="$dir/ntfy.env"
  pwn_file="$dir/pwned"

  EVENT_LOG="$dir/events.log" \
  PATH="$dir/bin:$PATH" \
  OP_NTFY_URL='https://ntfy.example/$(touch SHOULD_NOT_RUN)' \
  OP_NTFY_TOKEN="abc'; touch SHOULD_NOT_RUN; #" \
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" execute-template <"$ROOT_DIR/private_dot_config/opencode/private_ntfy.env.tmpl" >"$rendered"

  (
    cd "$dir"
    EXPECTED_URL='https://ntfy.example/$(touch SHOULD_NOT_RUN)' \
    EXPECTED_TOKEN="abc'; touch SHOULD_NOT_RUN; #" \
    PWN_FILE="$pwn_file" \
      bash -c 'set -eu; source ./ntfy.env; test "$OPENCODE_NTFY_URL" = "$EXPECTED_URL"; test "$OPENCODE_NTFY_TOKEN" = "$EXPECTED_TOKEN"; test ! -e SHOULD_NOT_RUN; test ! -e "$PWN_FILE"'
  )
}

test_zen_template_shell_quotes_hostile_values() {
  local dir rendered
  dir="$(mktemp -d)"
  mkdir -p "$dir/bin" "$dir/home"
  : >"$dir/events.log"
  write_op "$dir/bin"
  rendered="$dir/zen.env"

  EVENT_LOG="$dir/events.log" \
  PATH="$dir/bin:$PATH" \
  OP_DEFAULT_VALUE="abc'; touch SHOULD_NOT_RUN; #" \
  HOME="$dir/home" "$REAL_CHEZMOI" --source "$ROOT_DIR" execute-template <"$ROOT_DIR/private_dot_config/opencode/private_zen.env.tmpl" >"$rendered"

  (
    cd "$dir"
    EXPECTED="abc'; touch SHOULD_NOT_RUN; #" \
      bash -c 'set -eu; source ./zen.env; test "$OPENCODE_API_KEY" = "$EXPECTED"; test ! -e SHOULD_NOT_RUN'
  )
}

test_linux_package_runs_mise_without_github_token() {
  local dir bin home script output
  dir="$(mktemp -d)"
  bin="$dir/bin"
  home="$dir/home"
  mkdir -p "$bin" "$home"
  cat >"$dir/os-release" <<'EOF'
ID=ubuntu
ID_LIKE=debian
EOF
  script="$dir/linux-bootstrap.sh"
  output="$dir/output.log"

  make_real_config "$dir" 0 linux remote 1
  render_with_config "$dir" "$ROOT_DIR/run_onchange_install-packages-linux.sh.tmpl" "$script"

  cat >"$bin/sudo" <<'EOF'
#!/bin/sh
case "$1" in
  apt)
    exit 0
    ;;
  chown)
    exit 0
    ;;
esac
exit 0
EOF
  chmod +x "$bin/sudo"

  cat >"$bin/dpkg" <<'EOF'
#!/bin/sh
if [ "$1" = "-l" ]; then
  exit 0
fi
exit 0
EOF
  chmod +x "$bin/dpkg"

  cat >"$bin/curl" <<'EOF'
#!/bin/sh
out=""
args="$*"
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [ -z "$out" ]; then
  exit 1
fi
case "$args" in
  *https://mise.run*)
    cat >"$out" <<'SCRIPT'
#!/bin/sh
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/mise" <<'MISE'
#!/bin/sh
printf 'mise %s\n' "$*" >>"$MISE_LOG"
MISE
chmod +x "$HOME/.local/bin/mise"
SCRIPT
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$bin/curl"

  MISE_LOG="$dir/mise.log" HOME="$home" DOTFILES_HEADLESS=1 DOTFILES_TEST_OS_RELEASE="$dir/os-release" PATH="$bin:/usr/bin:/bin" bash "$script" >"$output" 2>&1

  assert_contains "$output" "Running mise install for"
  [[ -x "$home/.local/bin/mise" ]] || fail "mise installer did not create expected artifact"
  assert_contains "$dir/mise.log" "mise install"
}

test_chezmoi_installer_download_failure_is_not_executed() {
  local dir bin home
  dir="$(mktemp -d)"
  bin="$dir/bin"
  home="$dir/home"
  mkdir -p "$bin" "$home"
  cat >"$dir/os-release" <<'EOF'
ID=ubuntu
ID_LIKE=debian
EOF

  cat >"$bin/sudo" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$bin/sudo"

  cat >"$bin/curl" <<'EOF'
#!/bin/sh
exit 22
EOF
  chmod +x "$bin/curl"

  if HOME="$home" PATH="$bin:/usr/bin:/bin" DOTFILES_TEST_OS=linux DOTFILES_TEST_OS_RELEASE="$dir/os-release" "$ROOT_DIR/install.sh" >"$dir/stdout" 2>"$dir/stderr"; then
    fail "installer unexpectedly succeeded after failed curl"
  fi

  [[ ! -e "$dir/installer-executed" ]] || fail "failed installer download was executed"
  assert_contains "$dir/stderr" "Failed to download the chezmoi installer"
}

test_chezmoi_installer_downloaded_before_execution() {
  local dir bin home
  dir="$(mktemp -d)"
  bin="$dir/bin"
  home="$dir/home"
  mkdir -p "$bin" "$home"
  cat >"$dir/os-release" <<'EOF'
ID=ubuntu
ID_LIKE=debian
EOF

  cat >"$bin/sudo" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$bin/sudo"

  cat >"$bin/curl" <<'EOF'
#!/bin/sh
out=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|-Lo|-sSLo|-fsSLo|-fSLo|-fsLo)
      out="$2"
      shift 2
      ;;
    -fsLS|-fsSL|-fsS)
      shift
      ;;
    *) shift ;;
  esac
done
[ -n "$out" ] || exit 2
cat >"$out" <<'SCRIPT'
#!/bin/sh
while [ "$#" -gt 0 ]; do
  case "$1" in
    -b) bin="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf 'executed\n' >"$HOME/installer-executed"
mkdir -p "$bin"
cat >"$bin/chezmoi" <<'CHEZMOI'
#!/bin/sh
exit 0
CHEZMOI
chmod +x "$bin/chezmoi"
SCRIPT
EOF
  chmod +x "$bin/curl"

  HOME="$home" PATH="$bin:/usr/bin:/bin" DOTFILES_TEST_OS=linux DOTFILES_TEST_OS_RELEASE="$dir/os-release" "$ROOT_DIR/install.sh" >"$dir/stdout" 2>"$dir/stderr"

  [[ -e "$home/installer-executed" ]] || fail "downloaded installer was not executed"
  [[ -x "$home/.local/bin/chezmoi" ]] || fail "installer did not create chezmoi"
}

test_default_skips_op_and_secret_apply
test_noninteractive_defaults_remote_without_secrets
test_invalid_profile_fails_before_mutation_or_network
test_dryrun_aliases_and_no_mutation_or_auth
test_dryrun_help_documents_primary_and_alias
test_dryrun_interactive_wizard_reads_tty_only
test_dryrun_explicit_flags_suppress_prompts
test_dryrun_without_chezmoi_still_plans_without_installing
test_production_ignores_regular_file_tty_override
test_dryrun_real_pty_wizard_if_python_available
test_planner_contains_no_execution_primitives
test_planner_runs_with_no_path
test_interactive_wizard_selects_profile_and_secrets
test_explicit_flags_suppress_prompts
test_with_secrets_verifies_before_apply
test_failed_secret_verification_prevents_apply
test_empty_and_invalid_secret_values_prevent_apply
test_unauthenticated_with_controlling_tty_signs_in
test_failed_secret_apply_prevents_general_apply
test_signin_output_is_not_executed_or_logged
test_unauthenticated_without_tty_fails
test_debian_op_install_path_is_mockable
test_debian_op_rejects_unexpected_signing_key
test_darwin_homebrew_op_install_and_refs
test_secret_target_selection_by_os_profile
test_secret_target_apply_is_independent_of_cwd
test_real_chezmoi_ignore_and_config_data
test_profile_mise_rendering
test_dryrun_mise_sets_match_rendered_templates
test_dryrun_package_sets_match_profile_contracts
test_dryrun_secret_target_plan
test_headless_gui_config_ignore_matches_plan
test_dryrun_external_contacts_are_complete
test_profile_package_script_rendering
test_zsh_plugin_profile_contract
test_portable_profile_configs
test_pi_work_agents_are_local_only
test_agent_keys_are_scoped_to_agent_processes
test_aliases_preserve_system_commands_without_optional_tools
test_direct_template_profile_validation_and_legacy_defaults
test_package_scripts_track_mise_config
test_darwin_package_sets_without_github_token
test_linux_package_sets_by_profile_headless_on_linux
test_ambient_op_session_is_captured_and_not_leaked
test_secret_refs_manifest_covers_template_refs
test_ntfy_template_shell_quotes_hostile_values
test_zen_template_shell_quotes_hostile_values
test_linux_package_runs_mise_without_github_token
test_chezmoi_installer_download_failure_is_not_executed
test_chezmoi_installer_downloaded_before_execution

printf 'install.sh tests passed\n'
