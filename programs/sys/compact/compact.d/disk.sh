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

# Trimmed blocks only go back to Windows when the virtual disk is sparse.
# Only Windows can see that, so compact-vhd asks it, and the how-to is only
# printed when the answer is no, or when there was no answer.
vhd_hint() {
  [ -n "$IS_WSL" ] || return 0
  local distro=${WSL_DISTRO_NAME:-NixOS}
  case "$(compact-vhd)" in
    sparse)
      info "The virtual disk is sparse, so Windows gets the space back."
      echo
      return
      ;;
    not-sparse)
      warn "The virtual disk is not sparse, so Windows keeps its full size."
      ;;
    *)
      warn "Could not ask Windows whether the virtual disk is sparse."
      ;;
  esac
  say "$(highlight "Make it sparse once, from Windows: \`wsl --shutdown\`, then")"
  say "$(highlight "\`wsl --manage $distro --set-sparse true\`")"
  echo
}
