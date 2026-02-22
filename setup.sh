#!/usr/bin/env bash
# ------------------------------------------------------------
# setup.sh – one‑click bootstrap for the NixOS‑WSL dev‑profile repo
# ------------------------------------------------------------
# What it does:
#   0. Reset all previous configuration back to defaults.
#   1. Enable flakes in the user's nix config.
#   2. Configure direnv to use nix-direnv for flake-based dev shells.
#   3. Symlink /etc/nixos to this repo so nixos-rebuild auto-detects the flake.
#   4. Rebuild the NixOS system (installs direnv, nix-direnv, etc. system-wide).
#   5. Set up VSCode default settings for WSL development.
# ------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- Helper functions ----------
info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }

# ---------- Shared: detect shell rc file ----------
get_rc_file() {
  if [[ -n "${BASH_VERSION-}" ]]; then
    echo "${HOME}/.bashrc"
  elif [[ -n "${ZSH_VERSION-}" ]]; then
    echo "${HOME}/.zshrc"
  else
    echo ""
  fi
}

# ---------- 0. Reset all previous configuration ----------
reset_all() {
  info "===== Resetting all previous configuration ====="

  # Nix config – remove lines added by setup.sh
  local conf_file="${HOME}/.config/nix/nix.conf"
  if [[ -f "${conf_file}" ]]; then
    info "Removing setup.sh entries from ${conf_file}"
    sed -i '/# Added by nixos-config\/setup\.sh/d' "${conf_file}"
    sed -i '/experimental-features = nix-command flakes/d' "${conf_file}"
  fi

  # Direnv shell hook – remove any lines written by older versions of this script.
  # Current setup relies on programs.direnv in configuration.nix (writes to /etc/bashrc).
  local rc_file
  rc_file="$(get_rc_file)"
  if [[ -n "${rc_file}" && -f "${rc_file}" ]]; then
    info "Removing any legacy direnv hooks from ${rc_file}"
    sed -i '/# Added by nixos-config\/setup\.sh.*direnv/d' "${rc_file}"
    sed -i '/eval "\$(direnv hook/d' "${rc_file}"
    sed -i '/eval "\$(nix-direnv)"/d' "${rc_file}"
  fi

  # Direnvrc – remove if written by an older version of this script.
  # nix-direnv integration is now handled by programs.direnv.nix-direnv in NixOS.
  local direnvrc_file="${HOME}/.config/direnv/direnvrc"
  if [[ -f "${direnvrc_file}" ]]; then
    info "Removing legacy ${direnvrc_file}"
    rm -f "${direnvrc_file}"
  fi

  # /etc/nixos symlink
  if [[ -L /etc/nixos ]]; then
    info "Removing /etc/nixos symlink"
    sudo rm -f /etc/nixos
  fi

  # VSCode extension sync marker files
  local marker_dir="${HOME}/.config/nixos-vscode-profiles"
  if [[ -d "${marker_dir}" ]]; then
    info "Removing VSCode extension sync markers (will re-sync on next shell entry)"
    rm -rf "${marker_dir}"
  fi

  info "Reset complete."
}

# ---------- 1. Ensure flakes are enabled ----------
ensure_nix_conf() {
  local conf_dir="${HOME}/.config/nix"
  local conf_file="${conf_dir}/nix.conf"

  mkdir -p "${conf_dir}"
  info "Creating/updating ${conf_file} to enable flakes."
  {
    echo "# Added by nixos-config/setup.sh"
    echo "experimental-features = nix-command flakes"
  } >> "${conf_file}"
}

# ---------- 2. Symlink /etc/nixos to this repo ----------
link_etc_nixos() {
  if [[ -d /etc/nixos ]]; then
    info "Backing up existing /etc/nixos to /etc/nixos.bak"
    sudo mv /etc/nixos /etc/nixos.bak
  fi

  info "Symlinking /etc/nixos -> ${SCRIPT_DIR}"
  sudo ln -sfn "${SCRIPT_DIR}" /etc/nixos
}

# ---------- 4. Rebuild the WSL system ----------
rebuild_wsl() {
  info "Rebuilding the NixOS-WSL system (may take a few minutes)..."
  sudo nixos-rebuild switch --flake "${SCRIPT_DIR}#nix-wsl"
}

# ---------- 5. Set up global gitignore ----------
setup_global_gitignore() {
  local ignore_dir="${HOME}/.config/git"
  local ignore_file="${ignore_dir}/ignore"

  mkdir -p "${ignore_dir}"
  info "Creating global gitignore at ${ignore_file}"
  cat > "${ignore_file}" <<'GITIGNORE'
# nix-direnv cache (per-project shell environment)
.direnv/
GITIGNORE
}

# ---------- 6. Install VSCode WSL Remote extension on Windows ----------
setup_vscode_wsl() {
  if ! command -v cmd.exe >/dev/null 2>&1; then
    warn "cmd.exe not found — skipping Windows VSCode setup."
    return
  fi

  info "Installing VSCode WSL Remote extension on the Windows side..."
  (cd /mnt/c && cmd.exe /c code --install-extension ms-vscode-remote.remote-wsl --force) || \
    warn "Failed to install WSL Remote extension. You may need to install it manually."
}

# ---------- Main execution flow ----------
main() {
  info "===== Starting NixOS-WSL bootstrap ====="

  reset_all
  ensure_nix_conf
  link_etc_nixos
  rebuild_wsl
  setup_global_gitignore
  setup_vscode_wsl

  local wsl_user="nixos"

  info "===== Bootstrap complete! ====="
  echo
  echo "Please set a password for '${wsl_user}', run:"
  echo "    sudo passwd ${wsl_user}"
  echo
  echo "IMPORTANT: Restart the WSL VM so the new system takes effect:"
  echo "    wsl --shutdown"
  echo "    wsl"
  echo
  echo "After restart, you can use dev-shells in any project:"
  echo "    cd ~/repos/my-project"
  echo "    echo 'use flake ~/nixos-config#typescript' > .envrc"
  echo "    direnv allow"
  echo

  info "Reloading shell to activate hooks in the current session..."
  exec "${SHELL:-bash}"
}

main "$@"
