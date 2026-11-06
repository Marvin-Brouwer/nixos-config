# shellcheck shell=bash
# Part of compact.sh, inlined into it at build time.
# The three places that pile up, pruned in turn. Each step stands alone, so
# one that fails says so and the rest still run.

# Your own profile first, without collecting, then the system profiles and
# the collection itself as root. Deleting a generation only removes the
# link; the collection is what frees the space.
delete_old_generations() {
  info "Deleting generations older than $KEEP_DAYS days and collecting garbage..."
  nix-env --delete-generations "${KEEP_DAYS}d" >/dev/null 2>&1 || true
  sudo nix-collect-garbage --delete-older-than "${KEEP_DAYS}d" \
    | tail -n 1 \
    || warn "nix-collect-garbage failed, see above"
}

# Not -a: images a project tagged and will run again stay. `docker system
# prune -a` by hand is the bigger hammer.
prune_docker() {
  docker_running || return 0
  info "Pruning Docker..."
  docker system prune --force | tail -n 1 || warn "docker system prune failed"
}

# mise remembers every config it has seen; a version none of them asks for
# any more is what this removes.
prune_mise() {
  command -v mise >/dev/null || return 0
  info "Pruning mise tool versions no project uses..."
  mise prune --yes || warn "mise prune failed"
}
