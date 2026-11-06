# shellcheck shell=bash
# Part of doctor.sh, inlined into it at build time.
# The Windows side, which VS Code and the plugin sync both go through.

check_windows_drive() {
  if mountpoint -q /mnt/c; then
    ok "/mnt/c is mounted"
  else
    fail "/mnt/c is not mounted" "check automount in /etc/wsl.conf, then \`wsl --shutdown\`"
  fi
}

# Interop is what runs a .exe from here. Without it `code .` and the Windows
# half of vscode-sync both fail, with errors that do not mention interop.
check_interop() {
  if ! command -v cmd.exe >/dev/null; then
    fail "Windows binaries are not on PATH" "wsl.interop.includePath in configuration.nix"
  elif timeout 10 cmd.exe /c exit 0 >/dev/null 2>&1; then
    ok "Windows binaries run"
  else
    fail "Windows binaries do not run" "interop is off or broken: \`wsl --shutdown\` from Windows and retry"
  fi

  if command -v code >/dev/null; then
    ok "VS Code is reachable as code"
  else
    warn "VS Code is not on PATH" "install VS Code on Windows, or open a new shell"
  fi
}

# Trimmed blocks only go back to Windows when the .vhdx is sparse, and only
# Windows can tell, so this asks it through compact-vhd.
check_sparse_disk() {
  local distro=${WSL_DISTRO_NAME:-NixOS}
  case "$("$VHD_CHECK")" in
    sparse) ok "the virtual disk is sparse, freed space goes back to Windows" ;;
    not-sparse)
      warn "the virtual disk is not sparse, it never shrinks" \
        "from Windows: \`wsl --shutdown\`, then \`wsl --manage $distro --set-sparse true\`" ;;
    *)
      warn "could not ask Windows whether the virtual disk is sparse" \
        "see docs/compact.md" ;;
  esac
}
