# shellcheck shell=bash
# Part of sysupdate.sh, inlined into it at build time.
# Which inputs have moved, and which of those to update.

# Sets MOVED to the inputs with a newer revision, and ends the run when there
# are none.
find_moved_inputs() {
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
}

# Numbered rather than one letter per input: the inputs are whatever
# flake.nix declares, and they are offered separately because bumping
# nixpkgs and bumping the OS module are different decisions.
list_moved_inputs() {
  local name i width=0 old new old_date new_date
  echo
  echo "  Inputs with a newer revision:"
  for name in "${MOVED[@]}"; do
    [ "${#name}" -gt "$width" ] && width=${#name}
  done
  for i in "${!MOVED[@]}"; do
    read -r old new old_date new_date < <(
      jq -r --arg name "${MOVED[$i]}" \
        '.[$name] | "\(.old[:7]) \(.new[:7]) \(.old_date) \(.new_date)"' \
        "$TMP/candidate.json"
    )
    printf '    %d) %-*s   %s -> %s   (%s -> %s)\n' \
      "$((i + 1))" "$width" "${MOVED[$i]}" "$old" "$new" "$old_date" "$new_date"
  done
  echo
}

# Sets CHOSEN from the answer, and ends the run on quit.
choose_inputs() {
  local answer pick
  read -r -p "  Update which? [numbers, a = all, q = quit] " answer
  echo

  CHOSEN=()
  case "$answer" in
    q|Q|"") info "Nothing changed."; exit 0 ;;
    a|A)    CHOSEN=("${MOVED[@]}") ;;
    *)
      for pick in $answer; do
        case "$pick" in
          "" | *[!0-9]*) die "not a number: $pick" ;;
        esac
        [ "$pick" -ge 1 ] && [ "$pick" -le "${#MOVED[@]}" ] || die "out of range: $pick"
        CHOSEN+=("${MOVED[$((pick - 1))]}")
      done
      ;;
  esac
  [ "${#CHOSEN[@]}" -gt 0 ] || die "nothing selected"
}
