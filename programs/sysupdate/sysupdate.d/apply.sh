# shellcheck shell=bash
# Part of sysupdate.sh, inlined into it in order at build time.
# Applies, stages or discards the build.

case "$ACTION" in
  a|A)
    sudo "$(command -v nixos-rebuild)" switch --flake "$REPO#$HOST_NAME" \
      || { restore; die "switch failed, flake.lock restored"; }
    commit_lock

    # Drop the notice now rather than waiting up to 12h for the next check
    # to notice it is stale, and kick off a fresh one in the background.
    # No sudo: the state directory belongs to the same user the check runs
    # as, which is the user sitting here.
    rm -f \
      "$STATE_DIR/status.txt" "$STATE_DIR/status.ansi" \
      "$STATE_DIR/state.json" "$STATE_DIR/staged" "$STATE_DIR/last-attempt"
    sudo systemctl start --no-block sysupdate-check.service || true
    if [ -z "$IS_WSL" ]; then
      # switch activates in place, which cannot swap the running kernel.
      # (Skipped in WSL: Microsoft supplies the kernel, so a NixOS kernel
      # change is not something a restart would apply.)
      for part in kernel initrd kernel-modules; do
        if [ "$(readlink -f "/run/booted-system/$part" 2>/dev/null)" \
           != "$(readlink -f "/run/current-system/$part" 2>/dev/null)" ]; then
          warn "The kernel changed. Reboot to finish applying it."
          break
        fi
      done
    fi
    info "Done."
    ;;

  s|S)
    sudo "$(command -v nixos-rebuild)" boot --flake "$REPO#$HOST_NAME" \
      || { restore; die "staging failed, flake.lock restored"; }
    commit_lock

    # The notice switches from "pending" to "staged" straight away. The
    # marker clears itself once the system it names is the one running.
    readlink -f "$TMP/result" > "$STATE_DIR/staged"
    python3 "$DIFF_PY" \
      --state-dir "$STATE_DIR" --reboot-hint "$REBOOT_HINT" || true

    info "$REBOOT_HINT to activate it."
    ;;

  d|D|*)
    restore
    info "Discarded. flake.lock is back to where it was."
    ;;
esac
