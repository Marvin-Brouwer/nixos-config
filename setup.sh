#!/usr/bin/env bash
# ------------------------------------------------------------
# setup.sh – one‑click bootstrap for the NixOS‑WSL dev‑profile repo
# ------------------------------------------------------------
# What it does (new):
#   • Prompt you for a password for the default WSL user.
#   • Rebuild the NixOS system **without** storing the password.
#   • Immediately set the password inside the running VM using `chpasswd`.
#   • (All previous steps – flakes, direnv, home‑manager, etc. – unchanged.)
# ------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# ---------- Helper functions ----------
info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }

# ---------- 2️⃣ Ensure flakes are enabled ----------
ensure_nix_conf() {
  local conf_dir="${HOME}/.config/nix"
  local conf_file="${conf_dir}/nix.conf"

  mkdir -p "${conf_dir}"
  if [[ -f "${conf_file}" && $(grep -c "experimental-features" "${conf_file}") -gt 0 ]]; then
    info "Nix config already contains experimental‑features."
  else
    info "Creating/updating ${conf_file} to enable flakes."
    {
      echo "# Added by nixos‑config/setup.sh"
      echo "experimental-features = nix-command flakes"
    } >> "${conf_file}"
  fi
}

# ---------- 3️⃣ Install nix‑direnv ----------
install_nix_direnv() {
  if nix profile list | grep -q nix-direnv; then
    info "nix-direnv already installed."
  else
    info "Installing nix-direnv ..."
    nix profile install nixpkgs#nix-direnv
  fi

  # Detect rc file (bash or zsh)
  local rc_file=""
  if [[ -n "${BASH_VERSION-}" ]]; then
    rc_file="${HOME}/.bashrc"
  elif [[ -n "${ZSH_VERSION-}" ]]; then
    rc_file="${HOME}/.zshrc"
  else
    warn "Cannot detect bash or zsh. Add 'eval \"$(nix-direnv)\"' to your shell startup manually."
    return
  fi

  if grep -Fxq 'eval "$(nix-direnv)"' "${rc_file}" 2>/dev/null; then
    info "direnv hook already present in ${rc_file}"
  else
    info "Appending direnv hook to ${rc_file}"
    {
      echo ""
      echo "# Added by nixos‑config/setup.sh – enable nix‑direnv"
      echo 'eval "$(nix-direnv)"'
    } >> "${rc_file}"
  fi
}

# ---------- 4️⃣ Install home‑manager ----------
install_home_manager() {
  if nix profile list | grep -q home-manager; then
    info "home-manager already installed."
  else
    info "Installing home-manager ..."
    nix profile install nixpkgs#home-manager
  fi
}

# ---------- 5️⃣ Migrate legacy home.nix ----------
migrate_legacy_home_nix() {
  local old_path="${HOME}/.config/nixpkgs/home.nix"
  local new_dir="${HOME}/.config/home-manager"
  local new_path="${new_dir}/home.nix"

  # If the old file does not exist, nothing to do.
  if [[ ! -f "${old_path}" ]]; then
    info "No legacy home.nix to migrate."
    return
  fi

  mkdir -p "${new_dir}"

  # If the destination already exists and is the same inode as the source,
  # we can safely skip the move.
  if [[ -f "${new_path}" ]] && cmp -s "${old_path}" "${new_path}"; then
    info "Legacy home.nix is already at the new location – nothing to move."
  else
    info "Migrating legacy home.nix to ${new_path}"
    mv "${old_path}" "${new_path}"
  fi

  # Optional: keep a symlink at the old location for scripts that still look there.
  # If you don’t want the symlink, just comment out the next line.
  ln -sf "${new_path}" "${old_path}"
}

# ---------- 6️⃣ Create minimal home.nix if missing ----------
create_home_nix_if_missing() {
  local home_dir="${HOME}/.config/home-manager"
  local home_file="${home_dir}/home.nix"

  if [[ -f "${home_file}" ]]; then
    info "home.nix already exists."
    return
  fi

  info "Creating a minimal home.nix at ${home_file}"

  local nixos_version
  nixos_version=$(nixos-version | awk '{print $1}')

  cat > "${home_file}" <<EOF
# ~/.config/home-manager/home.nix
{ pkgs, ... }:

let
  shared = import "${HOME}/nixos-config/profiles/default.profile.nix" { inherit pkgs; };
in {
  home.stateVersion = "${nixos_version}";
  home.packages = shared.commonPackages;
  home.sessionVariables = shared.env;

  programs.zsh.enable = true;
  programs.zsh.promptInit = ''
    PROMPT='%F{green}%n@%m %F{blue}%~ %F{yellow}\\\$ %f'
  '';
}
EOF
}

# ---------- 7️⃣ Generate hardware‑configuration.nix ----------
generate_hardware_config() {
  local hw_file="./hardware-configuration.nix"
  if [[ -f "${hw_file}" ]]; then
    info "hardware-configuration.nix already exists – skipping."
  else
    info "Generating hardware-configuration.nix (first run)."
    nixos-generate-config --root "$(pwd)" --dir "$(pwd)"
  fi
}

# ---------- 8️⃣ Rebuild the WSL system ----------
rebuild_wsl() {
  info "Rebuilding the NixOS‑WSL system (may take a few minutes)…"
  sudo nixos-rebuild switch --flake ".#wsl"
}

# ---------- Main execution flow ----------
main() {
  info "===== Starting NixOS‑WSL bootstrap ====="

  # ----- 1️⃣ Remaining bootstrap steps (unchanged) -----
  ensure_nix_conf
  install_nix_direnv
  install_home_manager
  migrate_legacy_home_nix
  create_home_nix_if_missing
  generate_hardware_config

  # ----- 2️⃣ Rebuild the system (no password in configuration.nix) -----
  rebuild_wsl

  # ----- 3️⃣ Apply the password -----
  local wsl_user="nixos"   # <-- change if you use a different username

  info "===== Bootstrap complete! ====="
  echo
  echo "Please set a password for '${user}' inside the WSL VM, run the following command:"
  echo "    sudo passwd ${user}"
  echo 
  echo "⚠️  IMPORTANT: Restart the WSL VM so the new system takes effect:"
  echo "    wsl --shutdown"
  echo "    wsl"
  echo
  echo "You can now use the dev‑shells, e.g.:"
  echo "    cd ~/repos/my‑first‑proj"
  echo "    direnv allow   # loads the profile you defined in .envrc"
  echo "    nix develop .#typescript   # manual invocation if you prefer"
  echo
}

main "$@"