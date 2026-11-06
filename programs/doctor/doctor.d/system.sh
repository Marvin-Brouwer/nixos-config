# shellcheck shell=bash
# Part of doctor.sh, inlined into it at build time.
# The machine itself: what is running, what broke, what is filling up, and
# whether the background checks are still running at all.

check_running_system() {
  if [ "$(readlink -f /run/current-system)" = "$(readlink -f /nix/var/nix/profiles/system)" ]; then
    ok "running the newest built system"
  else
    warn "a newer system is staged but not running" \
      "restart to use it: \`wsl --shutdown\` from Windows, or reboot"
  fi
}

check_failed_units() {
  local units unit
  if ! units=$(systemctl --failed --no-legend --plain 2>/dev/null); then
    fail "systemd does not answer" "\`systemctl status\`"
    return
  fi
  units=$(awk '{ print $1 }' <<< "$units")
  if [ -z "$units" ]; then
    ok "no failed systemd units"
    return
  fi
  for unit in $units; do
    fail "systemd unit $unit failed" "\`journalctl -u $unit -b\`"
  done
}

check_disk_space() {
  local used
  used=$(df --output=pcent / | tail -n 1 | tr -dc '0-9')
  if [ "$used" -ge 90 ]; then
    fail "the disk is ${used}% full" "\`$PREFIX sys compact\`"
  elif [ "$used" -ge 80 ]; then
    warn "the disk is ${used}% full" "\`$PREFIX sys compact\`"
  else
    ok "the disk is ${used}% full"
  fi
}

# A stamp file's age in days, or nothing when it does not exist.
days_since() {
  [ -f "$1" ] || return 0
  echo $(( ($(date +%s) - $(stat -c %Y "$1")) / 86400 ))
}

# The timer fires on boot and twice a day, and the check rate limits itself to
# 12h, so three days of silence means it is not running rather than idle.
check_update_timer() {
  local age
  age=$(days_since "$SYSUPDATE_STATE_DIR/last-attempt")
  if [ -z "$age" ]; then
    warn "the update check has never run" "\`$PREFIX sys update --check\`"
  elif [ -f "$SYSUPDATE_STATE_DIR/last-failed" ]; then
    warn "the last update check failed" "\`journalctl -u sysupdate-check\`"
  elif [ "$age" -gt 3 ]; then
    warn "the update check last ran $age days ago" "\`systemctl list-timers sysupdate-check\`"
  else
    ok "the update check ran recently"
  fi
}

check_compact_timer() {
  local age
  age=$(days_since "$COMPACT_STATE_DIR/last-check")
  if [ -z "$age" ]; then
    warn "the clean-up check has never run" "\`$PREFIX sys compact --check\`"
  elif [ "$age" -gt 3 ]; then
    warn "the clean-up check last ran $age days ago" "\`systemctl list-timers compact-check\`"
  else
    ok "the clean-up check ran recently"
  fi
}
