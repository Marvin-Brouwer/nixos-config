# shellcheck shell=bash
# Shared by compact.sh and check.sh. Inlined into both at build time, so it
# runs with their PATH and variables.

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mcompact:\033[0m %s\n' "$*" >&2; exit 1; }

SYSTEM_PROFILE=/nix/var/nix/profiles/system

# Bytes held by store paths nothing refers to any more, which is what a plain
# garbage collection frees. An estimate: paths hardlinked by store
# optimisation are counted once per path.
dead_bytes() {
  nix-store --gc --print-dead 2>/dev/null \
    | tr '\n' '\0' \
    | du -scb --files0-from=- 2>/dev/null \
    | awk 'END { print ($1 == "" ? 0 : $1) }'
}

# How many system generations a run would delete: older than KEEP_DAYS and
# not the current one, which is what --delete-older-than keeps.
old_generations() {
  local cutoff
  cutoff=$(date -d "-$KEEP_DAYS days" +%F)
  nix-env --list-generations -p "$SYSTEM_PROFILE" 2>/dev/null \
    | awk -v cutoff="$cutoff" '$2 < cutoff && $NF != "(current)" { n++ } END { print n + 0 }'
}

human() { numfmt --to=iec-i --suffix=B "$1"; }
