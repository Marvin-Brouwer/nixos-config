# shellcheck shell=bash
# Part of sysupdate.sh, inlined into it in order at build time.
# Updates the chosen inputs, builds the new system, shows the diff and
# asks what to do with it.

# Keep the lock as it was, both to restore on discard and to describe the
# bump accurately in the commit message afterwards.
cp flake.lock "$TMP/before.lock"
restore() { git checkout -- flake.lock; }

info "Updating: ${CHOSEN[*]}"
nix flake update "${CHOSEN[@]}" || { restore; die "nix flake update failed"; }

if git diff --quiet -- flake.lock; then
  info "The lock did not move after all, nothing to do."
  exit 0
fi

# Build before asking anything: `nixos-rebuild build` with the output kept
# out of the repo. The switch below re-evaluates but rebuilds nothing.
info "Building the new system. This is the slow part."
nix build \
  "$REPO#nixosConfigurations.$HOST_NAME.config.system.build.toplevel" \
  --out-link "$TMP/result" || { restore; die "the build failed, flake.lock restored"; }

echo
nvd diff /run/current-system "$TMP/result"
echo

read -r -p "  [a] apply now  [s] stage for next start  [d] discard  " ACTION
echo

input_revs "$TMP/before.lock" "$REPO/flake.lock" > "$TMP/applied.json"
