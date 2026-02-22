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

  # Direnv shell hook
  local rc_file
  rc_file="$(get_rc_file)"
  if [[ -n "${rc_file}" && -f "${rc_file}" ]]; then
    info "Removing direnv hooks from ${rc_file}"
    sed -i '/# Added by nixos-config\/setup\.sh.*direnv/d' "${rc_file}"
    sed -i '/eval "\$(direnv hook/d' "${rc_file}"
    sed -i '/eval "\$(nix-direnv)"/d' "${rc_file}"
  fi

  # Direnvrc
  local direnvrc_file="${HOME}/.config/direnv/direnvrc"
  if [[ -f "${direnvrc_file}" ]]; then
    info "Removing ${direnvrc_file}"
    rm -f "${direnvrc_file}"
  fi

  # /etc/nixos symlink
  if [[ -L /etc/nixos ]]; then
    info "Removing /etc/nixos symlink"
    sudo rm -f /etc/nixos
  fi

  # VSCode settings
  local settings_file="${HOME}/.config/Code/User/settings.json"
  if [[ -f "${settings_file}" ]]; then
    info "Removing VSCode settings.json"
    rm -f "${settings_file}"
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

# ---------- 2. Configure direnv + nix-direnv shell integration ----------
configure_direnv() {
  # direnv and nix-direnv are installed as system packages via configuration.nix.
  # Here we just wire up the shell hooks and direnvrc.

  local rc_file
  rc_file="$(get_rc_file)"
  if [[ -z "${rc_file}" ]]; then
    warn "Cannot detect bash or zsh. Add 'eval \"\$(direnv hook bash)\"' to your shell startup manually."
    return
  fi

  local shell_name
  shell_name="$(basename "${SHELL:-bash}")"

  local direnvrc_dir="${HOME}/.config/direnv"
  local direnvrc_file="${direnvrc_dir}/direnvrc"
  local nix_direnv_source='source /run/current-system/sw/share/nix-direnv/direnvrc'

  info "Appending direnv hook to ${rc_file}"
  {
    echo ""
    echo "# Added by nixos-config/setup.sh – enable direnv"
    echo "eval \"\$(direnv hook ${shell_name})\""
  } >> "${rc_file}"

  mkdir -p "${direnvrc_dir}"
  info "Configuring direnvrc to source nix-direnv."
  {
    echo "# Added by nixos-config/setup.sh – use nix-direnv for 'use flake'"
    echo "${nix_direnv_source}"
  } > "${direnvrc_file}"
}

# ---------- 3. Symlink /etc/nixos to this repo ----------
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

# ---------- 5. Set up VSCode settings for WSL ----------
setup_vscode_settings() {
  local settings_dir="${HOME}/.config/Code/User"
  local settings_file="${settings_dir}/settings.json"

  mkdir -p "${settings_dir}"
  info "Creating default VSCode settings for WSL development."
  cat > "${settings_file}" <<'SETTINGS'
{
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.profiles.linux": {
    "bash": {
      "path": "/run/current-system/sw/bin/bash",
      "icon": "terminal-bash"
    }
  }
}
SETTINGS
}

# ---------- Main execution flow ----------
main() {
  info "===== Starting NixOS-WSL bootstrap ====="

  reset_all
  ensure_nix_conf
  configure_direnv
  link_etc_nixos
  rebuild_wsl
  setup_vscode_settings

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
