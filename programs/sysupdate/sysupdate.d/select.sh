# shellcheck shell=bash
# Part of sysupdate.sh, inlined into it in order at build time.
# Resolves the newest inputs and asks which ones to update.

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

# Numbered rather than one letter per input: the inputs are whatever
# flake.nix declares, and they are offered separately because bumping
# nixpkgs and bumping the OS module are different decisions.
echo
echo "  Inputs with a newer revision:"
WIDTH=0
for name in "${MOVED[@]}"; do
  [ "${#name}" -gt "$WIDTH" ] && WIDTH=${#name}
done
for i in "${!MOVED[@]}"; do
  read -r OLD NEW OLD_DATE NEW_DATE < <(
    jq -r --arg name "${MOVED[$i]}" \
      '.[$name] | "\(.old[:7]) \(.new[:7]) \(.old_date) \(.new_date)"' \
      "$TMP/candidate.json"
  )
  printf '    %d) %-*s   %s -> %s   (%s -> %s)\n' \
    "$((i + 1))" "$WIDTH" "${MOVED[$i]}" "$OLD" "$NEW" "$OLD_DATE" "$NEW_DATE"
done
echo
read -r -p "  Update which? [numbers, a = all, q = quit] " ANSWER
echo

CHOSEN=()
case "$ANSWER" in
  q|Q|"") info "Nothing changed."; exit 0 ;;
  a|A)    CHOSEN=("${MOVED[@]}") ;;
  *)
    for pick in $ANSWER; do
      case "$pick" in
        "" | *[!0-9]*) die "not a number: $pick" ;;
      esac
      [ "$pick" -ge 1 ] && [ "$pick" -le "${#MOVED[@]}" ] || die "out of range: $pick"
      CHOSEN+=("${MOVED[$((pick - 1))]}")
    done
    ;;
esac
[ "${#CHOSEN[@]}" -gt 0 ] || die "nothing selected"
