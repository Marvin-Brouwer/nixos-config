# shellcheck shell=bash
# `doctor`, the health check. main, at the bottom, is the whole run in order;
# the checks are in doctor.d/, one file per area.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${PREFIX:?}" "${SYSUPDATE_STATE_DIR:?}" "${COMPACT_STATE_DIR:?}"
# 1 in WSL, empty elsewhere. Decides whether the WSL checks run.
: "${IS_WSL?}"

FAILED=0
WARNED=0

# One line per check, and an indented hint under anything that is not fine.
ok()   { printf '   \033[1;32mok\033[0m    %s\n' "$1"; }
warn() { printf '   \033[1;33mwarn\033[0m  %s\n' "$1"; hint "${2:-}"; WARNED=$((WARNED + 1)); }
fail() { printf '   \033[1;31mFAIL\033[0m  %s\n' "$1"; hint "${2:-}"; FAILED=$((FAILED + 1)); }
hint() { [ -z "$1" ] || printf '         %s\n' "$1"; }
section() { printf '\n\033[1;34m== %s\033[0m\n' "$1"; }

usage() {
  cat <<USAGE
usage: $PREFIX doctor

Checks the pieces this setup leans on and prints ok, warn or FAIL for each,
with what to do about anything that is not ok. Changes nothing.
Exits 1 when something failed. See docs/doctor.md.
USAGE
}

# The checks, inlined here by lib/shell-script.nix when the command is built.
# shellcheck source=doctor.d/system.sh
. "$PARTS/system.sh"
# shellcheck source=doctor.d/wsl.sh
. "$PARTS/wsl.sh"
# shellcheck source=doctor.d/tools.sh
. "$PARTS/tools.sh"
# shellcheck source=doctor.d/repo.sh
. "$PARTS/repo.sh"

summary() {
  echo
  if [ "$FAILED" -gt 0 ]; then
    printf '   \033[1;31m%d failed\033[0m, %d warnings\n\n' "$FAILED" "$WARNED"
    exit 1
  fi
  printf '   \033[1;32mAll good\033[0m, %d warnings\n\n' "$WARNED"
}

main() {
  case "${1:-}" in
    "") ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac

  section "System"
  check_running_system
  check_failed_units
  check_disk_space
  check_update_timer
  check_compact_timer

  if [ -n "$IS_WSL" ]; then
    section "WSL"
    check_windows_drive
    check_interop
  fi

  section "Tools"
  check_nix_ld
  check_git_lfs
  check_mise
  check_gpg
  check_docker
  check_binary_cache

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    section "This repo ($(basename "$(git rev-parse --show-toplevel)"))"
    check_repo
  fi

  summary
}

main "$@"
