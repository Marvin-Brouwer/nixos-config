# shellcheck shell=bash
# `tool docker`: stop the Docker daemon, or say whether it runs. main, at the
# bottom, picks one.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${PREFIX:?}"

# Defines highlight.
# shellcheck source=../../lib/highlight.sh
. "$HIGHLIGHT"

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$(highlight "$*")"; }
die()  { printf '\033[1;31mdocker:\033[0m %s\n' "$(highlight "$*")" >&2; exit 1; }
usage() {
  cat <<USAGE
usage: $PREFIX tool docker <stop|status>

  stop    stop the daemon and its socket, and with them every container
  status  whether the daemon runs, and how many containers are up

There is no start: the first 'docker' command starts the daemon by itself.
USAGE
}

running() { systemctl is-active --quiet docker.service; }

# Asked only when the daemon already runs, since asking would start it.
container_count() {
  docker ps -q 2>/dev/null | wc -l
}

show_status() {
  if running; then
    info "The daemon is running, with $(container_count) containers up. \`$PREFIX tool docker stop\` stops it."
  else
    info "The daemon is not running. The next \`docker\` command starts it."
  fi
}

# The socket first: with it gone nothing can start the service again halfway.
stop_daemon() {
  if ! running && ! systemctl is-active --quiet docker.socket; then
    info "The daemon is not running."
    return 0
  fi
  running && info "Stopping the daemon and its $(container_count) running containers..."
  sudo systemctl stop docker.socket docker.service || die "could not stop it, see the output above"
  sudo systemctl start docker.socket || die "stopped, but could not re-arm docker.socket"
  info "Stopped. The next \`docker\` command starts it again."
}

main() {
  case "${1:-}" in
    stop)              stop_daemon ;;
    status)            show_status ;;
    ""|-h|--help|help) usage ;;
    *)                 usage >&2; die "unknown subcommand: $1" ;;
  esac
}

main "$@"
