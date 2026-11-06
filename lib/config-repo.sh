# shellcheck shell=bash
# `repo_root`: where this config is checked out. Shared by sysupdate, build
# and pull, inlined into each like any other part; see shell-script.nix.
#
# /etc/nixos is a symlink to the repo, put there by setup.sh. Resolving it
# rather than hardcoding ~/nixos-config keeps this working when the check
# runs as root and the repo lives in someone's home.
repo_root() {
  local root
  root=$(readlink -f /etc/nixos) || return 1
  [ -n "$root" ] || return 1
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  printf '%s\n' "$root"
}
