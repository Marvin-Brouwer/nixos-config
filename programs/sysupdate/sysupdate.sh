# shellcheck shell=bash
# `sysupdate`, the interactive command: bump inputs, build, diff, apply or
# stage. Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${STATE_DIR:?}" "${HELPERS:?}" "${HOST_NAME:?}" "${PREFIX:?}"
: "${REBOOT_HINT:?}" "${DIFF_PY:?}"
# 1 in WSL, empty elsewhere. Only the kernel check below depends on it.
: "${IS_WSL?}"

# Defines info, warn, die, repo_root, candidate_lock and input_revs.
# shellcheck source=helpers.sh
. "$HELPERS"

say()   { printf '   %s\n' "$*"; }
usage() {
  cat <<USAGE
usage: $PREFIX sysupdate [option]

  (no option)  update the inputs, build, show the diff, apply or stage
  --status     reprint the cached notice
  --check      run the background check now
  --audit      scan the running system for known vulnerabilities
USAGE
}

case "${1:-}" in
  --status) exec sysupdate-notice --force ;;
  --audit)  exec vulnix --system ;;
  --check)
    info "Checking (this evaluates the whole configuration, give it a few minutes)..."
    rm -f "$STATE_DIR/last-attempt"
    sudo systemctl start sysupdate-check.service \
      || die "the check failed, see: journalctl -u sysupdate-check"
    echo
    sysupdate-notice --force || true
    exit 0
    ;;
  -h|--help) usage; exit 0 ;;
  "")        ;;
  *)         usage >&2; die "unknown option: $1" ;;
esac

REPO=$(repo_root) || die "/etc/nixos does not resolve to a git repository"
cd "$REPO" || die "cannot enter $REPO"

# Everything below writes flake.lock and restores it on the way out, so it
# must start from a clean one or a discard would throw away your work.
git diff --quiet -- flake.lock \
  || die "flake.lock has uncommitted changes, commit or restore it first"
git diff --cached --quiet -- flake.lock \
  || die "flake.lock is staged, commit or restore it first"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

printf '\n\033[1;34m== sysupdate (%s)\033[0m\n\n' "$HOST_NAME"

info "Resolving the newest inputs..."
candidate_lock "$REPO" "$TMP/candidate.lock" >/dev/null 2>"$TMP/nix.err" \
  || { cat "$TMP/nix.err" >&2; die "could not resolve the newest inputs"; }
input_revs "$REPO/flake.lock" "$TMP/candidate.lock" > "$TMP/candidate.json" \
  || die "could not read the lock files"

mapfile -t MOVED < <(
  jq -r 'to_entries[] | select(.value.old != .value.new) | .key' \
    "$TMP/candidate.json"
)

if [ "${#MOVED[@]}" -eq 0 ]; then
  info "Every input is already at its newest revision."
  exit 0
fi

# Numbered rather than one letter per input: the inputs are whatever
# flake.nix declares, and they are offered separately because bumping
# nixpkgs and bumping the OS module are different decisions.
echo
echo "  Inputs with a newer revision:"
WIDTH=0
for name in "${MOVED[@]}"; do
  [ "${#name}" -gt "$WIDTH" ] && WIDTH=${#name}
done
for i in "${!MOVED[@]}"; do
  read -r OLD NEW OLD_DATE NEW_DATE < <(
    jq -r --arg name "${MOVED[$i]}" \
      '.[$name] | "\(.old[:7]) \(.new[:7]) \(.old_date) \(.new_date)"' \
      "$TMP/candidate.json"
  )
  printf '    %d) %-*s   %s -> %s   (%s -> %s)\n' \
    "$((i + 1))" "$WIDTH" "${MOVED[$i]}" "$OLD" "$NEW" "$OLD_DATE" "$NEW_DATE"
done
echo
read -r -p "  Update which? [numbers, a = all, q = quit] " ANSWER
echo

CHOSEN=()
case "$ANSWER" in
  q|Q|"") info "Nothing changed."; exit 0 ;;
  a|A)    CHOSEN=("${MOVED[@]}") ;;
  *)
    for pick in $ANSWER; do
      case "$pick" in
        "" | *[!0-9]*) die "not a number: $pick" ;;
      esac
      [ "$pick" -ge 1 ] && [ "$pick" -le "${#MOVED[@]}" ] || die "out of range: $pick"
      CHOSEN+=("${MOVED[$((pick - 1))]}")
    done
    ;;
esac
[ "${#CHOSEN[@]}" -gt 0 ] || die "nothing selected"

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

# Committing is what makes the machine reproducible and what carries the
# bump to the other machine. Path-scoped so an unrelated staged change
# cannot be swept into it.
commit_lock() {
  if [ -z "$(git config user.email)" ]; then
    warn "no git user.email in this repo, leaving flake.lock uncommitted"
    return 0
  fi

  local subject body
  subject="flake.lock: update $(printf '%s, ' "${CHOSEN[@]}" | sed 's/, $//')"
  body=$(jq -r --args '
    . as $revs | $ARGS.positional[]
    | "\(.): \($revs[.].old[:7]) -> \($revs[.].new[:7])  (\($revs[.].old_date) -> \($revs[.].new_date))"
  ' "${CHOSEN[@]}" < "$TMP/applied.json")

  if git commit -q -m "$subject" -m "$body" -- flake.lock; then
    info "Committed the flake.lock bump."
    push_lock
  else
    warn "could not commit flake.lock, it is left in the working tree"
  fi
}

# Pushing is what carries the bump to the other machine, and only ever
# follows a commit, which only ever follows a successful switch or boot.
# A failed push is a warning, not a failure: the system is already
# activated and the commit is safe locally, so the run itself succeeded.
push_lock() {
  local upstream
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || {
    warn "this branch has no upstream, leaving the commit unpushed"
    return 0
  }

  info "Pushing to $upstream..."
  if git push -q; then
    info "Pushed."
  else
    warn "could not push to $upstream, the commit is still local. Push it by hand."
  fi
}

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
