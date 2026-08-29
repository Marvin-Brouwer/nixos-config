#!/usr/bin/env bash
# ------------------------------------------------------------
# setup.sh – one‑click bootstrap for the NixOS‑WSL dev‑profile repo
# ------------------------------------------------------------
# What it does:
#   0. Reset all previous configuration back to defaults.
#   1. Enable flakes in the user's nix config.
#   2. Symlink /etc/nixos to this repo so nixos-rebuild auto-detects the flake.
#   3. Rebuild the NixOS system (installs mise, nix-ld, etc. system-wide).
#   4. Set up the global gitignore and VSCode for WSL development.
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

  # Direnv shell hook – remove lines written by older versions of this script.
  # direnv is gone entirely: per-project tooling comes from mise now, and its
  # shell hook is written to /etc/bashrc by programs.bash.interactiveShellInit
  # in configuration.nix.
  local rc_file
  rc_file="$(get_rc_file)"
  if [[ -n "${rc_file}" && -f "${rc_file}" ]]; then
    info "Removing any legacy direnv hooks from ${rc_file}"
    sed -i '/# Added by nixos-config\/setup\.sh.*direnv/d' "${rc_file}"
    sed -i '/eval "\$(direnv hook/d' "${rc_file}"
    sed -i '/eval "\$(nix-direnv)"/d' "${rc_file}"
  fi

  # Direnvrc – remove if written by an older version of this script.
  local direnvrc_file="${HOME}/.config/direnv/direnvrc"
  if [[ -f "${direnvrc_file}" ]]; then
    info "Removing legacy ${direnvrc_file}"
    rm -f "${direnvrc_file}"
  fi

  # Global gitignore – drop the direnv entries older versions added. They are
  # meaningless now and would just sit in everyone's config forever.
  local ignore_file="${HOME}/.config/git/ignore"
  if [[ -f "${ignore_file}" ]]; then
    info "Removing obsolete direnv entries from ${ignore_file}"
    sed -i '/^\.direnv\/$/d; /^\.envrc$/d' "${ignore_file}"
    sed -i '/# nix-direnv cache/d; /# direnv config/d' "${ignore_file}"
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

# ---------- 3. Rebuild the WSL system ----------
rebuild_wsl() {
  info "Rebuilding the NixOS-WSL system (may take a few minutes)..."
  sudo nixos-rebuild switch --flake "${SCRIPT_DIR}#nix-wsl"
}

# ---------- 4. Set up global gitignore ----------
setup_global_gitignore() {
  local ignore_dir="${HOME}/.config/git"
  local ignore_file="${ignore_dir}/ignore"

  mkdir -p "${ignore_dir}"
  touch "${ignore_file}"

  # Entries to ensure are present (pattern + comment pairs).
  #
  # mise.toml and mise.lock are deliberately NOT here: both are meant to be
  # committed, so a project's tool versions travel with it. Only the local
  # override file is personal.
  local -a entries=(
    "mise.local.toml:# mise local overrides (personal, never committed)"
  )

  local changed=0
  for entry in "${entries[@]}"; do
    local pattern="${entry%%:*}"
    local comment="${entry#*:}"
    if ! grep -qxF "${pattern}" "${ignore_file}"; then
      echo "${comment}" >> "${ignore_file}"
      echo "${pattern}" >> "${ignore_file}"
      changed=1
    fi
  done

  if [[ "${changed}" -eq 1 ]]; then
    info "Updated global gitignore at ${ignore_file}"
  else
    info "Global gitignore already up to date."
  fi
}

# ---------- 5. Install VSCode WSL Remote extension on Windows ----------
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
  echo "After restart, set up a project with mise:"
  echo "    cd ~/repos/my-project"
  echo "    mise use node@lts       # writes mise.toml and mise.lock"
  echo "    mise trust              # allow this project's config to load"
  echo
  echo "VSCode plugins come from the project's .vscode/extensions.json,"
  echo "unioned with your base list in programs/vscode-plugins.nix."
  echo

  info "Reloading shell to activate hooks in the current session..."
  exec "${SHELL:-bash}"
}

main "$@"
