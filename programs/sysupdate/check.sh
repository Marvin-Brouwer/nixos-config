# shellcheck shell=bash
# `sysupdate-check`, the background job behind the notice, run by a systemd
# timer. Not run as is: default.nix fills in the @-delimited placeholders.
#
# Evaluating the configuration is the only way to know what changed: Nix has
# no package index to diff against the way apt does. That is why this is a
# timer job with a cached result rather than something a shell could do.

set -uo pipefail

# Sets STATE_DIR and defines info, warn, die, repo_root, candidate_lock and
# input_revs.
# shellcheck source=helpers.sh
. @helpers@

FORCE=""
[ "${1:-}" = "--force" ] && FORCE=1

@coreutils@/bin/mkdir -p "$STATE_DIR"
STAMP="$STATE_DIR/last-attempt"

# A staged update outranks a pending one: the answer is already "restart",
# so there is nothing worth a full eval until that system is the running
# one. Once it is, this falls through and the marker clears itself.
if [ -f "$STATE_DIR/staged" ] \
  && [ "$(@coreutils@/bin/readlink -f "$(@coreutils@/bin/cat "$STATE_DIR/staged")")" \
    != "$(@coreutils@/bin/readlink -f /run/current-system)" ]; then
  echo "[sysupdate] an update is staged, nothing to check"
  exit 0
fi

# Rate limit here rather than in the timer: timer state does not survive a
# WSL shutdown, and on a machine that is off overnight it does not survive
# that either. A file does.
if [ -z "$FORCE" ] && [ -f "$STAMP" ]; then
  NOW=$(@coreutils@/bin/date +%s)
  LAST=$(@coreutils@/bin/stat -c %Y "$STAMP")
  INTERVAL=@minInterval@
  [ -f "$STATE_DIR/last-failed" ] && INTERVAL=@retryInterval@
  if [ "$((NOW - LAST))" -lt "$INTERVAL" ]; then
    echo "[sysupdate] checked $(( (NOW - LAST) / 60 ))m ago, nothing to do"
    exit 0
  fi
fi

REPO=$(repo_root) || {
  echo "[sysupdate] /etc/nixos is not a git repository, skipping" >&2
  exit 0
}

TMP=$(@coreutils@/bin/mktemp -d)
trap '@coreutils@/bin/rm -rf "$TMP"' EXIT

# Count the attempt before making it, so a run that dies mid-eval still
# rate limits the next one.
@coreutils@/bin/touch "$STAMP"

# A failure leaves the previous status files exactly as they were. That is
# the cache-then-revalidate half: the first shell after boot shows the last
# known answer rather than nothing, and a flaky network never blanks it.
# Exit 0 regardless, so a missing network does not show up as a failed unit.
fail() {
  echo "[sysupdate] $*" >&2
  @coreutils@/bin/touch "$STATE_DIR/last-failed"
  exit 0
}

candidate_lock "$REPO" "$TMP/candidate.lock" >/dev/null \
  || fail "could not resolve the newest inputs"
input_revs "$REPO/flake.lock" "$TMP/candidate.lock" > "$TMP/inputs.json" \
  || fail "could not read the lock files"

# --raw on drvPath instantiates the whole system without realising it: the
# derivations are enough to know every package's version, and nothing is
# downloaded or built.
DRV=$(@nix@/bin/nix eval --raw \
  "$REPO#nixosConfigurations.@hostName@.config.system.build.toplevel.drvPath" \
  --reference-lock-file "$TMP/candidate.lock" \
  --no-write-lock-file) || fail "could not evaluate the new system"

# The candidate side is a derivation closure and the running side an output
# closure, so this compares build-time against runtime. Names present on
# one side only fall out in the diff; only version changes are reported.
@nix@/bin/nix-store -q --requisites "$DRV" \
  | @gnugrep@/bin/grep '\.drv$' > "$TMP/new" || fail "empty candidate closure"
@nix@/bin/nix-store -q --requisites /run/current-system > "$TMP/old" \
  || fail "could not read the running closure"

@python@/bin/python3 @diff@ \
  --old "$TMP/old" \
  --new "$TMP/new" \
  --watch "@watchNames@" \
  --inputs "$TMP/inputs.json" \
  --state-dir "$STATE_DIR" \
  --reboot-hint "@rebootHint@" \
  --command "@prefix@ sysupdate" || fail "could not render the notice"

@coreutils@/bin/rm -f "$STATE_DIR/last-failed"
echo "[sysupdate] check complete"
