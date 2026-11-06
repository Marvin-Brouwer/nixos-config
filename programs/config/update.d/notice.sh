# shellcheck shell=bash
# Part of update.sh, inlined into it at build time.
# Keeping sysupdate's notice true after the update.

# A pulled flake.lock bump is usually the one sysupdate's notice was announcing,
# applied on another machine. Drop the cached notice and check again in the
# background, as sysupdate does after applying a bump itself. No sudo for the
# files: the state directory belongs to the user the check runs as, which is
# the user sitting here.
refresh_update_notice() {
  git diff --quiet "$BEFORE" HEAD -- flake.lock && return 0
  rm -f \
    "$SYSUPDATE_STATE_DIR/status.txt" "$SYSUPDATE_STATE_DIR/status.ansi" \
    "$SYSUPDATE_STATE_DIR/state.json" "$SYSUPDATE_STATE_DIR/staged" \
    "$SYSUPDATE_STATE_DIR/last-attempt"
  sudo systemctl start --no-block sysupdate-check.service || true
}
