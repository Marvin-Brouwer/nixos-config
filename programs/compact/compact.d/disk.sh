# shellcheck shell=bash
# Part of compact.sh, inlined into it at build time.
# The disk itself: what the run gave back, and getting it back to Windows.

used_bytes() { df -B1 --output=used / | tail -n 1 | tr -d ' '; }

# Freeing blocks inside ext4 does nothing for the .vhdx on the Windows side
# until they are discarded. WSL does not mount with discard, so this is that
# step, done once at the end rather than on every delete.
trim_disk() {
  [ -n "$IS_WSL" ] || return 0
  info "Trimming the disk..."
  sudo fstrim -v / || warn "fstrim failed, the virtual disk keeps its size"
}

report_freed() {
  local after freed
  after=$(used_bytes)
  freed=$(( USED_BEFORE - after ))
  [ "$freed" -lt 0 ] && freed=0
  echo
  info "Freed $(human "$freed"), $(df -h --output=avail / | tail -n 1 | tr -d ' ') now available."
}

# Trimmed blocks only go back to Windows when the virtual disk is sparse, and
# that can only be seen and set from the Windows side.
vhd_hint() {
  [ -n "$IS_WSL" ] || return 0
  cat <<HINT

   Windows gets this space back only if the virtual disk is sparse. If you
   have not done it yet, once, from a Windows terminal:
     wsl --shutdown
     wsl --manage ${WSL_DISTRO_NAME:-NixOS} --set-sparse true

HINT
}
