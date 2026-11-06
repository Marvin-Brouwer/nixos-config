# shellcheck shell=bash
# Shared by sysupdate.sh and check.sh. Inlined into both at build time, so it
# runs with their PATH and variables.

# highlight comes from lib/highlight.sh, sourced by the script ahead of this.
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$(highlight "$*")"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$(highlight "$*")"; }
die()  { printf '\033[1;31msysupdate:\033[0m %s\n' "$(highlight "$*")" >&2; exit 1; }

# repo_root comes from lib/config-repo.sh, sourced by the script ahead of this.

# What the inputs would move to, without writing flake.lock.
#
# `nix flake update` rewrites the lock in place; --output-lock-file sends
# the result somewhere else instead. That is what lets the check look at
# the newest nixpkgs while leaving the repo untouched -- only `sysupdate`
# itself is allowed to write the lock.
candidate_lock() { # repo  destination
  nix flake update \
    --flake "$1" \
    --reference-lock-file "$1/flake.lock" \
    --output-lock-file "$2"
}

# {input: {old, new, old_date, new_date}} from two lock files. Each side is
# read through its own root.inputs, because nix renames nodes freely
# (nixpkgs_2 and friends) and the node key is not stable between locks.
input_revs() { # old-lock  new-lock
  jq -n --slurpfile old "$1" --slurpfile new "$2" '
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
