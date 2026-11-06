# shellcheck shell=bash
# `scratch`: a temp repo, set up with a preset, and a shell in it. main, at
# the bottom, is the whole run in order.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${PREFIX:?}" "${REPOCONFIG:?}" "${PRESET_NAMES:?}"

# Nobody pushes from a scratch repo, so it needs an identity, not yours.
EMAIL="scratch@localhost"

die() { printf '\033[1;31mscratch:\033[0m %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<USAGE
usage: $PREFIX repo scratch [preset] [--keep]

Makes a temp git repo, runs '$PREFIX repo init <preset>' in it and opens a
shell there. Leaving the shell asks whether to delete it; --keep skips the
question and keeps it. The preset defaults to empty.

presets: $PRESET_NAMES
USAGE
}

# Sets PRESET and KEEP. The flag may go anywhere.
parse_args() {
  local arg
  PRESET=empty
  KEEP=""
  for arg in "$@"; do
    case "$arg" in
      -h|--help) usage; exit 0 ;;
      --keep)    KEEP=1 ;;
      -*)        usage >&2; die "unknown option: $arg" ;;
      *)         PRESET=$arg ;;
    esac
  done
  [[ " $PRESET_NAMES " == *" $PRESET "* ]] || die "unknown preset: $PRESET (presets: $PRESET_NAMES)"
}

make_repo() {
  mkdir -p "${TMPDIR:-/tmp}/scratch"
  DIR=$(mktemp -d "${TMPDIR:-/tmp}/scratch/$PRESET-$(date +%m%d)-XXXX") \
    || die "could not create a temp directory"
  git -C "$DIR" init --quiet || die "git init failed"
}

configure_repo() {
  (cd "$DIR" && "$REPOCONFIG" "$PRESET" "$EMAIL") \
    || printf '   repoconfig reported a problem, the repo is there anyway\n'
}

# Your own shell, so your prompt, aliases and the mise hook all come along.
enter_shell() {
  printf '\n   \033[1;34m%s\033[0m\n   exit when done.\n\n' "$DIR"
  (cd "$DIR" && "${SHELL:-bash}")
}

# Asked rather than assumed, since by now it may hold something worth having.
clean_up() {
  local answer
  if [ -z "$KEEP" ]; then
    read -rp "   Delete $DIR? [Y/n] " answer
    case "$answer" in
      n|N) KEEP=1 ;;
    esac
  fi
  if [ -n "$KEEP" ]; then
    printf '   Kept: %s\n' "$DIR"
  else
    rm -rf "$DIR"
    printf '   Deleted.\n'
  fi
}

main() {
  parse_args "$@"
  make_repo
  configure_repo
  enter_shell
  clean_up
}

main "$@"
