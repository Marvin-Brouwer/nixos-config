# shellcheck shell=bash
# Part of compact.sh, inlined into it at build time.
# What a run would remove, and the one question before it does.

docker_running() {
  command -v docker >/dev/null && systemctl is-active --quiet docker.service 2>/dev/null
}

# Measured up front so the question is about numbers, not a leap of faith.
# Docker is only asked about when its daemon is already up: asking would start
# it, and a daemon that is not running has nothing new to prune anyway.
show_plan() {
  info "Measuring (this walks the Nix store, give it a moment)..."
  say "Nix store:  $(human "$(dead_bytes)") of store paths nothing uses"
  say "            $(old_generations) system generations older than $KEEP_DAYS days, and what only they use"

  if docker_running; then
    say "Docker:     stopped containers, dangling images, unused networks, build cache"
  else
    say "Docker:     daemon not running, skipped"
  fi

  if command -v mise >/dev/null; then
    local stale
    stale=$(mise prune --dry-run 2>&1 | grep -c . || true)
    say "mise:       $stale tool versions no tracked project uses"
  fi

  [ -n "$IS_WSL" ] && say "Disk:       trim, so the virtual disk can shrink"
  echo
}

confirm() {
  [ -n "$ASSUME_YES" ] && return
  local answer
  read -rp "   Remove all of that? [y/N] " answer
  case "$answer" in
    y|Y) echo ;;
    *)   say "Nothing removed."; exit 0 ;;
  esac
}
