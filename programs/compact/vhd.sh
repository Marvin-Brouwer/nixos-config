# shellcheck shell=bash
# `compact-vhd`: whether this distro's .vhdx is sparse, asked of Windows,
# since nothing inside the distro can see it. Prints sparse, not-sparse or
# unknown, and always exits 0.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script. powershell.exe comes from the Windows half of your PATH.
#
# Interactive only: WSL_DISTRO_NAME is set in a WSL session, not in a systemd
# unit, which is why the timer does not ask this.

set -uo pipefail

: "${VHD_PS1:?}"

main() {
  local distro=${WSL_DISTRO_NAME:-} script encoded answer
  if [ -z "$distro" ] || ! command -v powershell.exe >/dev/null; then
    echo unknown
    return
  fi

  # -EncodedCommand takes base64 of UTF-16LE, which sidesteps every layer of
  # quoting between here and PowerShell. The distro name goes in as a
  # single-quoted PowerShell string, with its own quotes doubled.
  script="\$distro = '${distro//\'/\'\'}'"$'\n'"$(cat "$VHD_PS1")"
  encoded=$(printf '%s' "$script" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)
  answer=$(timeout 20 powershell.exe -NoProfile -NonInteractive -EncodedCommand "$encoded" 2>/dev/null | tr -d '\r')

  case "$answer" in
    sparse|not-sparse) echo "$answer" ;;
    *) echo unknown ;;
  esac
}

main "$@"
