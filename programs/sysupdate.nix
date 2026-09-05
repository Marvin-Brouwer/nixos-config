# -----------------------------------------------------------------
# `sysupdate` -- one command to see what is pending and apply it, plus the
# background check and the shell notice that tell you it is pending at all.
#
# Why this exists rather than `system.autoUpgrade`:
#
#   * autoUpgrade activates silently. Seeing what changed and choosing when is
#     the entire point here.
#   * In WSL it also cannot work. The VM idle-terminates once nothing is a
#     child of its init, so a 04:00 timer never fires, and `persistent = true`
#     turns that into a multi-minute rebuild starting the moment you sit down.
#
# On a bare-metal host autoUpgrade is still worth having, for the other half of
# the problem: pointed at the pushed repo it deploys a flake.lock this command
# already decided on and committed. See docs/sysupdate.md.
#
# Three commands come out of this file:
#
#   sysupdate         interactive: bump inputs, build, diff, apply or stage
#   sysupdate-check   the background job, run by a systemd timer
#   sysupdate-notice  prints the cached result on interactive shell start
#
# Nothing about this file names a host. `hostName` builds the flake attribute
# and `isWsl` decides the wording and the kernel check, both from
# configuration.nix, so a second machine is two bindings rather than a rewrite.
# -----------------------------------------------------------------

{ pkgs, lib, hostName, isWsl, watch }:

let
  # Root-owned, world-readable: the check writes it, every shell reads it.
  stateDir = "/var/lib/sysupdate";

  # Names the notice is allowed to spell out, from the same list that builds
  # environment.systemPackages, so the two cannot drift apart.
  watchNames = lib.concatStringsSep "," (map lib.getName watch);

  # 12h between checks, whatever the timer does. WSL boots often enough that
  # without this every terminal would pay for a nixpkgs fetch and a full eval.
  minInterval = toString (12 * 3600);
  # A failed attempt (no network, usually) should come back sooner than that.
  retryInterval = toString (1 * 3600);

  # Reads as "<hint> to activate it." Deliberately backtick-free: this ends up
  # inside a double-quoted shell string, where a backtick is a command
  # substitution and `wsl` is not a command that exists in here.
  rebootHint =
    if isWsl
    then "Run 'wsl --shutdown' from Windows and start it again"
    else "Reboot";

  python = pkgs.python3;
  diff = ./sysupdate-diff.py;

  # Shared by the interactive command and the background check.
  helpers = ''
    STATE_DIR=${stateDir}

    info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
    warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
    die()  { printf '\033[1;31msysupdate:\033[0m %s\n' "$*" >&2; exit 1; }

    # /etc/nixos is a symlink to the repo, put there by setup.sh. Resolving it
    # rather than hardcoding ~/nixos-config keeps this working when the check
    # runs as root and the repo lives in someone's home.
    repo_root() {
      local root
      root=$(${pkgs.coreutils}/bin/readlink -f /etc/nixos) || return 1
      [ -n "$root" ] || return 1
      ${pkgs.git}/bin/git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
      printf '%s\n' "$root"
    }

    # What the inputs would move to, without writing flake.lock.
    #
    # `nix flake update` rewrites the lock in place; --output-lock-file sends
    # the result somewhere else instead. That is what lets the check look at
    # the newest nixpkgs while leaving the repo untouched -- only `sysupdate`
    # itself is allowed to write the lock.
    candidate_lock() { # repo  destination
      ${pkgs.nix}/bin/nix flake update \
        --flake "$1" \
        --reference-lock-file "$1/flake.lock" \
        --output-lock-file "$2"
    }

    # {input: {old, new, old_date, new_date}} from two lock files. Each side is
    # read through its own root.inputs, because nix renames nodes freely
    # (nixpkgs_2 and friends) and the node key is not stable between locks.
    input_revs() { # old-lock  new-lock
      ${pkgs.jq}/bin/jq -n --slurpfile old "$1" --slurpfile new "$2" '
        def revs(lock):
          (lock.nodes.root.inputs // {}) as $inputs
          | reduce ($inputs | keys[]) as $name ({};
              ($inputs[$name]) as $node
              | if ($node | type) == "string" and (lock.nodes[$node].locked?)
                then .[$name] = {
                  rev:  (lock.nodes[$node].locked.rev // ""),
                  date: (lock.nodes[$node].locked.lastModified // 0)
                }
                else . end);
        (revs($old[0])) as $o | (revs($new[0])) as $n
        | reduce ($o | keys[]) as $name ({};
            .[$name] = {
              old:      $o[$name].rev,
              new:      ($n[$name].rev // $o[$name].rev),
              old_date: ($o[$name].date | gmtime | strftime("%Y-%m-%d")),
              new_date: (($n[$name].date // $o[$name].date) | gmtime | strftime("%Y-%m-%d"))
            })
      '
    }
  '';

  # ---------------------------------------------------------------
  # The background check.
  # ---------------------------------------------------------------
  #
  # Evaluating the configuration is the only way to know what changed: Nix has
  # no package index to diff against the way apt does. That is why this is a
  # timer job with a cached result rather than something a shell could do.
  check = pkgs.writeShellScriptBin "sysupdate-check" ''
    set -uo pipefail

    ${helpers}

    FORCE=""
    [ "''${1:-}" = "--force" ] && FORCE=1

    ${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR"
    STAMP="$STATE_DIR/last-attempt"

    # A staged update outranks a pending one: the answer is already "restart",
    # so there is nothing worth a full eval until that system is the running
    # one. Once it is, this falls through and the marker clears itself.
    if [ -f "$STATE_DIR/staged" ] \
      && [ "$(${pkgs.coreutils}/bin/readlink -f "$(${pkgs.coreutils}/bin/cat "$STATE_DIR/staged")")" \
        != "$(${pkgs.coreutils}/bin/readlink -f /run/current-system)" ]; then
      echo "[sysupdate] an update is staged, nothing to check"
      exit 0
    fi

    # Rate limit here rather than in the timer: timer state does not survive a
    # WSL shutdown, and on a machine that is off overnight it does not survive
    # that either. A file does.
    if [ -z "$FORCE" ] && [ -f "$STAMP" ]; then
      NOW=$(${pkgs.coreutils}/bin/date +%s)
      LAST=$(${pkgs.coreutils}/bin/stat -c %Y "$STAMP")
      INTERVAL=${minInterval}
      [ -f "$STATE_DIR/last-failed" ] && INTERVAL=${retryInterval}
      if [ "$((NOW - LAST))" -lt "$INTERVAL" ]; then
        echo "[sysupdate] checked $(( (NOW - LAST) / 60 ))m ago, nothing to do"
        exit 0
      fi
    fi

    REPO=$(repo_root) || {
      echo "[sysupdate] /etc/nixos is not a git repository, skipping" >&2
      exit 0
    }

    TMP=$(${pkgs.coreutils}/bin/mktemp -d)
    trap '${pkgs.coreutils}/bin/rm -rf "$TMP"' EXIT

    # Count the attempt before making it, so a run that dies mid-eval still
    # rate limits the next one.
    ${pkgs.coreutils}/bin/touch "$STAMP"

    # A failure leaves the previous status files exactly as they were. That is
    # the cache-then-revalidate half: the first shell after boot shows the last
    # known answer rather than nothing, and a flaky network never blanks it.
    # Exit 0 regardless, so a missing network does not show up as a failed unit.
    fail() {
      echo "[sysupdate] $*" >&2
      ${pkgs.coreutils}/bin/touch "$STATE_DIR/last-failed"
      exit 0
    }

    candidate_lock "$REPO" "$TMP/candidate.lock" >/dev/null \
      || fail "could not resolve the newest inputs"
    input_revs "$REPO/flake.lock" "$TMP/candidate.lock" > "$TMP/inputs.json" \
      || fail "could not read the lock files"

    # --raw on drvPath instantiates the whole system without realising it: the
    # derivations are enough to know every package's version, and nothing is
    # downloaded or built.
    DRV=$(${pkgs.nix}/bin/nix eval --raw \
      "$REPO#nixosConfigurations.${hostName}.config.system.build.toplevel.drvPath" \
      --reference-lock-file "$TMP/candidate.lock" \
      --no-write-lock-file) || fail "could not evaluate the new system"

    # The candidate side is a derivation closure and the running side an output
    # closure, so this compares build-time against runtime. Names present on
    # one side only fall out in the diff; only version changes are reported.
    ${pkgs.nix}/bin/nix-store -q --requisites "$DRV" \
      | ${pkgs.gnugrep}/bin/grep '\.drv$' > "$TMP/new" || fail "empty candidate closure"
    ${pkgs.nix}/bin/nix-store -q --requisites /run/current-system > "$TMP/old" \
      || fail "could not read the running closure"

    ${python}/bin/python3 ${diff} \
      --old "$TMP/old" \
      --new "$TMP/new" \
      --watch "${watchNames}" \
      --inputs "$TMP/inputs.json" \
      --state-dir "$STATE_DIR" \
      --reboot-hint "${rebootHint}" || fail "could not render the notice"

    ${pkgs.coreutils}/bin/rm -f "$STATE_DIR/last-failed"
    echo "[sysupdate] check complete"
  '';

  # ---------------------------------------------------------------
  # The shell notice.
  # ---------------------------------------------------------------
  #
  # A file test and a cat. No eval, no network, nothing slow between you and
  # the prompt -- which is the only reason it is acceptable on every shell.
  notice = pkgs.writeShellScriptBin "sysupdate-notice" ''
    set -u

    STATE_DIR=${stateDir}

    # --force is for `sysupdate --status`, which is asked for explicitly.
    if [ "''${1:-}" != "--force" ] && [ ! -t 1 ]; then
      exit 0
    fi

    [ -f "$STATE_DIR/status.txt" ] || exit 0

    if [ -n "''${NO_COLOR:-}" ] || [ ! -t 1 ]; then
      ${pkgs.coreutils}/bin/cat "$STATE_DIR/status.txt"
    else
      ${pkgs.coreutils}/bin/cat "$STATE_DIR/status.ansi"
    fi
  '';

  # ---------------------------------------------------------------
  # The command.
  # ---------------------------------------------------------------
  sysupdate = pkgs.writeShellScriptBin "sysupdate" ''
    set -uo pipefail

    ${helpers}

    say()   { printf '   %s\n' "$*"; }
    usage() {
      ${pkgs.coreutils}/bin/cat <<'USAGE'
    usage: sysupdate [option]

      (no option)  update the inputs, build, show the diff, apply or stage
      --status     reprint the cached notice
      --check      run the background check now
      --audit      scan the running system for known vulnerabilities
    USAGE
    }

    case "''${1:-}" in
      --status) exec ${notice}/bin/sysupdate-notice --force ;;
      --audit)  exec ${pkgs.vulnix}/bin/vulnix --system ;;
      --check)
        info "Checking (this evaluates the whole configuration, give it a few minutes)..."
        ${pkgs.coreutils}/bin/rm -f "$STATE_DIR/last-attempt"
        sudo systemctl start sysupdate-check.service \
          || die "the check failed, see: journalctl -u sysupdate-check"
        echo
        ${notice}/bin/sysupdate-notice --force || true
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
    ${pkgs.git}/bin/git diff --quiet -- flake.lock \
      || die "flake.lock has uncommitted changes, commit or restore it first"
    ${pkgs.git}/bin/git diff --cached --quiet -- flake.lock \
      || die "flake.lock is staged, commit or restore it first"

    TMP=$(${pkgs.coreutils}/bin/mktemp -d)
    trap '${pkgs.coreutils}/bin/rm -rf "$TMP"' EXIT

    printf '\n\033[1;34m== sysupdate (%s)\033[0m\n\n' "${hostName}"

    info "Resolving the newest inputs..."
    candidate_lock "$REPO" "$TMP/candidate.lock" >/dev/null 2>"$TMP/nix.err" \
      || { ${pkgs.coreutils}/bin/cat "$TMP/nix.err" >&2; die "could not resolve the newest inputs"; }
    input_revs "$REPO/flake.lock" "$TMP/candidate.lock" > "$TMP/candidate.json" \
      || die "could not read the lock files"

    mapfile -t MOVED < <(
      ${pkgs.jq}/bin/jq -r 'to_entries[] | select(.value.old != .value.new) | .key' \
        "$TMP/candidate.json"
    )

    if [ "''${#MOVED[@]}" -eq 0 ]; then
      info "Every input is already at its newest revision."
      exit 0
    fi

    # Numbered rather than one letter per input: the inputs are whatever
    # flake.nix declares, and they are offered separately because bumping
    # nixpkgs and bumping the OS module are different decisions.
    echo
    echo "  Inputs with a newer revision:"
    WIDTH=0
    for name in "''${MOVED[@]}"; do
      [ "''${#name}" -gt "$WIDTH" ] && WIDTH=''${#name}
    done
    for i in "''${!MOVED[@]}"; do
      read -r OLD NEW OLD_DATE NEW_DATE < <(
        ${pkgs.jq}/bin/jq -r --arg name "''${MOVED[$i]}" \
          '.[$name] | "\(.old[:7]) \(.new[:7]) \(.old_date) \(.new_date)"' \
          "$TMP/candidate.json"
      )
      printf '    %d) %-*s   %s -> %s   (%s -> %s)\n' \
        "$((i + 1))" "$WIDTH" "''${MOVED[$i]}" "$OLD" "$NEW" "$OLD_DATE" "$NEW_DATE"
    done
    echo
    read -r -p "  Update which? [numbers, a = all, q = quit] " ANSWER
    echo

    CHOSEN=()
    case "$ANSWER" in
      q|Q|"") info "Nothing changed."; exit 0 ;;
      a|A)    CHOSEN=("''${MOVED[@]}") ;;
      *)
        for pick in $ANSWER; do
          case "$pick" in
            "" | *[!0-9]*) die "not a number: $pick" ;;
          esac
          [ "$pick" -ge 1 ] && [ "$pick" -le "''${#MOVED[@]}" ] || die "out of range: $pick"
          CHOSEN+=("''${MOVED[$((pick - 1))]}")
        done
        ;;
    esac
    [ "''${#CHOSEN[@]}" -gt 0 ] || die "nothing selected"

    # Keep the lock as it was, both to restore on discard and to describe the
    # bump accurately in the commit message afterwards.
    ${pkgs.coreutils}/bin/cp flake.lock "$TMP/before.lock"
    restore() { ${pkgs.git}/bin/git checkout -- flake.lock; }

    info "Updating: ''${CHOSEN[*]}"
    ${pkgs.nix}/bin/nix flake update "''${CHOSEN[@]}" || { restore; die "nix flake update failed"; }

    if ${pkgs.git}/bin/git diff --quiet -- flake.lock; then
      info "The lock did not move after all, nothing to do."
      exit 0
    fi

    # Build before asking anything: `nixos-rebuild build` with the output kept
    # out of the repo. The switch below re-evaluates but rebuilds nothing.
    info "Building the new system. This is the slow part."
    ${pkgs.nix}/bin/nix build \
      "$REPO#nixosConfigurations.${hostName}.config.system.build.toplevel" \
      --out-link "$TMP/result" || { restore; die "the build failed, flake.lock restored"; }

    echo
    ${pkgs.nvd}/bin/nvd diff /run/current-system "$TMP/result"
    echo

    read -r -p "  [a] apply now  [s] stage for next start  [d] discard  " ACTION
    echo

    input_revs "$TMP/before.lock" "$REPO/flake.lock" > "$TMP/applied.json"

    # Committing is what makes the machine reproducible and what carries the
    # bump to the other machine. Path-scoped so an unrelated staged change
    # cannot be swept into it.
    commit_lock() {
      if [ -z "$(${pkgs.git}/bin/git config user.email)" ]; then
        warn "no git user.email in this repo, leaving flake.lock uncommitted"
        return 0
      fi

      local subject body
      subject="flake.lock: update $(printf '%s, ' "''${CHOSEN[@]}" | ${pkgs.gnused}/bin/sed 's/, $//')"
      body=$(${pkgs.jq}/bin/jq -r --args '
        . as $revs | $ARGS.positional[]
        | "\(.): \($revs[.].old[:7]) -> \($revs[.].new[:7])  (\($revs[.].old_date) -> \($revs[.].new_date))"
      ' "''${CHOSEN[@]}" < "$TMP/applied.json")

      if ${pkgs.git}/bin/git commit -q -m "$subject" -m "$body" -- flake.lock; then
        info "Committed the flake.lock bump."
        say "Push it when you want the other machine to pick it up."
      else
        warn "could not commit flake.lock, it is left in the working tree"
      fi
    }

    case "$ACTION" in
      a|A)
        sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "$REPO#${hostName}" \
          || { restore; die "switch failed, flake.lock restored"; }
        commit_lock

        # Drop the notice now rather than waiting up to 12h for the next check
        # to notice it is stale, and kick off a fresh one in the background.
        # No sudo: the state directory belongs to the same user the check runs
        # as, which is the user sitting here.
        ${pkgs.coreutils}/bin/rm -f \
          "$STATE_DIR/status.txt" "$STATE_DIR/status.ansi" \
          "$STATE_DIR/state.json" "$STATE_DIR/staged" "$STATE_DIR/last-attempt"
        sudo systemctl start --no-block sysupdate-check.service || true
    ${lib.optionalString (!isWsl) ''
        # switch activates in place, which cannot swap the running kernel.
        # (In WSL this check is compiled out: Microsoft supplies the kernel, so
        # a NixOS kernel change is not something a restart would apply.)
        for part in kernel initrd kernel-modules; do
          if [ "$(${pkgs.coreutils}/bin/readlink -f "/run/booted-system/$part" 2>/dev/null)" \
             != "$(${pkgs.coreutils}/bin/readlink -f "/run/current-system/$part" 2>/dev/null)" ]; then
            warn "The kernel changed. Reboot to finish applying it."
            break
          fi
        done
    ''}
        info "Done."
        ;;

      s|S)
        sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot --flake "$REPO#${hostName}" \
          || { restore; die "staging failed, flake.lock restored"; }
        commit_lock

        # The notice switches from "pending" to "staged" straight away. The
        # marker clears itself once the system it names is the one running.
        ${pkgs.coreutils}/bin/readlink -f "$TMP/result" > "$STATE_DIR/staged"
        ${python}/bin/python3 ${diff} \
          --state-dir "$STATE_DIR" --reboot-hint "${rebootHint}" || true

        info "${rebootHint} to activate it."
        ;;

      d|D|*)
        restore
        info "Discarded. flake.lock is back to where it was."
        ;;
    esac
  '';

in
{
  inherit sysupdate check notice;
}
