# shellcheck shell=bash
# `tool docker`: start, stop or restart the Docker daemon, or say whether it
# runs. main, at the bottom, picks one.
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
usage: $PREFIX tool docker <start|stop|restart|status>

  start    start the daemon now, rather than on the first 'docker' command
  stop     stop the daemon and its socket, and with them every container
  restart  stop and start the daemon, for a stuck one or a changed config
  status   whether the daemon runs, and how many containers are up

Without a start the first 'docker' command starts the daemon by itself.
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

start_daemon() {
  if running; then
    info "The daemon is already running."
    return 0
  fi
  sudo systemctl start docker.socket docker.service || die "could not start it, see the output above"
  info "Started."
}

# Containers without a restart policy stay stopped afterwards, as with any
# daemon restart.
restart_daemon() {
  running && info "Restarting the daemon and its $(container_count) running containers..."
  sudo systemctl restart docker.service || die "could not restart it, see the output above"
  sudo systemctl start docker.socket || die "restarted, but could not re-arm docker.socket"
  info "Restarted."
}

main() {
  case "${1:-}" in
    start)             start_daemon ;;
    stop)              stop_daemon ;;
    restart)           restart_daemon ;;
    status)            show_status ;;
    ""|-h|--help|help) usage ;;
    *)                 usage >&2; die "unknown subcommand: $1" ;;
  esac
}

main "$@"
