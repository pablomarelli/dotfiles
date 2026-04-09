#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=chezmoi-sandbox
CONTAINER_NAME=chezmoi-sandbox
PLATFORM="${DOCKER_DEFAULT_PLATFORM:-linux/amd64}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="$ROOT_DIR/tests/docker/Dockerfile"

build() {
  docker build --platform "$PLATFORM" -t "$IMAGE_NAME" -f "$DOCKERFILE" "$ROOT_DIR"
}

up() {
  local source_mode mount_args env_args

  source_mode=git
  env_args=(-e DOTFILES_SOURCE_MODE="$source_mode")
  if [[ "${1:-}" == "--source" ]]; then
    source_mode="${2:-}"
    shift 2 || true
  fi

  env_args=(-e DOTFILES_SOURCE_MODE="$source_mode")
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    env_args+=(-e GITHUB_TOKEN)
  fi

  case "$source_mode" in
    mount)
      mount_args=(--mount "type=bind,src=$ROOT_DIR,dst=/dotfiles-src,readonly")
      ;;
    git)
      mount_args=()
      ;;
    *)
      printf 'Unknown source mode: %s\n' "$source_mode" >&2
      exit 1
      ;;
  esac

  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker run -d \
    --platform "$PLATFORM" \
    --name "$CONTAINER_NAME" \
    "${env_args[@]}" \
    "${mount_args[@]}" \
    "$IMAGE_NAME"
}

shell() {
  docker exec -it "$CONTAINER_NAME" bash
}

logs() {
  docker exec "$CONTAINER_NAME" bash -lc 'if [ -f /tmp/bootstrap.exit ]; then cat /tmp/bootstrap.exit; else echo RUNNING; fi; echo; echo "---"; cat /tmp/bootstrap.log'
}

destroy() {
  docker rm -f "$CONTAINER_NAME"
}

case "${1:-}" in
  build)
    build
    ;;
  up)
    shift
    up "$@"
    ;;
  shell)
    shell
    ;;
  logs)
    logs
    ;;
  destroy)
    destroy
    ;;
  *)
    printf 'Usage: %s {build|up [--source mount|git]|shell|logs|destroy}\n' "$0" >&2
    exit 1
    ;;
esac
