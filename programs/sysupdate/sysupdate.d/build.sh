# shellcheck shell=bash
# Part of sysupdate.sh, inlined into it at build time.
# Moving the lock, building against it, and asking what to do with the result.

restore() { git checkout -- flake.lock; }

# Keeps the lock as it was, both to restore on discard and to describe the
# bump accurately in the commit message afterwards. Ends the run when the
# lock does not move.
update_chosen_inputs() {
  cp flake.lock "$TMP/before.lock"

  info "Updating: ${CHOSEN[*]}"
  nix flake update "${CHOSEN[@]}" || { restore; die "nix flake update failed"; }

  if git diff --quiet -- flake.lock; then
    info "The lock did not move after all, nothing to do."
    exit 0
  fi
}

# Build before asking anything: `nixos-rebuild build` with the output kept
# out of the repo. The switch afterwards re-evaluates but rebuilds nothing.
build_system() {
  info "Building the new system. This is the slow part."
  nix build \
    "$REPO#nixosConfigurations.$HOST_NAME.config.system.build.toplevel" \
    --out-link "$TMP/result" || { restore; die "the build failed, flake.lock restored"; }
}

# Sets ACTION.
show_diff_and_ask() {
  echo
  nvd diff /run/current-system "$TMP/result"
  echo

  read -r -p "  [a] apply now  [s] stage for next start  [d] discard  " ACTION
  echo

  input_revs "$TMP/before.lock" "$REPO/flake.lock" > "$TMP/applied.json"
}
