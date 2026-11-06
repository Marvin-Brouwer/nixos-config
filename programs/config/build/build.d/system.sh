# shellcheck shell=bash
# Part of build.sh, inlined into it at build time.
# Building, comparing with what runs now, and switching.

# Unprivileged, with the result kept out of the checkout. The switch afterwards
# re-evaluates but builds nothing.
build_system() {
  info "Building the system. This can take a while."
  nix build \
    "$CHECKOUT#nixosConfigurations.$HOST_NAME.config.system.build.toplevel" \
    --out-link "$TMP/result" || die "the build failed, nothing was switched"
}

# The same store path is the same system: nothing to diff and nothing to
# switch, which is the usual outcome of a change to docs or comments.
stop_if_already_running() {
  if [ "$(readlink -f "$TMP/result")" = "$(readlink -f /run/current-system)" ]; then
    info "That is the system already running, nothing to switch."
    exit 0
  fi
}

show_diff() {
  echo
  nvd diff /run/current-system "$TMP/result"
  echo
}

switch_system() {
  sudo "$(command -v nixos-rebuild)" switch --flake "$CHECKOUT#$HOST_NAME" \
    || die "the switch failed, see the output above"
  info "Switched."
}
