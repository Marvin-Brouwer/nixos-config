#!/usr/bin/env bash
# ------------------------------------------------------------
# setup.sh – one‑click bootstrap for the NixOS‑WSL dev‑profile repo
# ------------------------------------------------------------
# What it does:
#   1️⃣ Enable flakes in ~/.config/nix/nix.conf
#   2️⃣ Install nix-direnv and add the direnv hook to the shell rc
#   3️⃣ Install home‑manager and create a minimal home.nix that
#      imports the shared main.nix from this repo
#   4️⃣ Generate hardware‑configuration.nix (if missing)
#   5️⃣ Build the WSL NixOS system (nixosConfigurations.wsl)
#   6️⃣ Print a short “restart WSL” reminder
#
# Usage (after cloning the repo):
#   $ bash ./setup.sh
#
# ------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# ---------- Helpers ----------
info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()    { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }

# ---------- 1️⃣ Enable flakes ----------
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

# ---------- 2️⃣ Install nix‑direnv ----------
install_nix_direnv() {
  # Install via the Nix profile (does not require sudo)
  if nix profile list | grep -q nix-direnv; then
    info "nix-direnv already installed in the user profile."
  else
    info "Installing nix-direnv ..."
    nix profile install nixpkgs#nix-direnv
  fi

  # Detect the user's shell rc file (bash or zsh)
  local rc_file=""
  if [[ -n "${BASH_VERSION-}" ]]; then
    rc_file="${HOME}/.bashrc"
  elif [[ -n "${ZSH_VERSION-}" ]]; then
    rc_file="${HOME}/.zshrc"
  else
    warn "Could not detect bash or zsh. Please add the direnv hook manually:"
    warn '  eval "$(nix-direnv)"'
    return
  fi

  # Append the hook if it is not already present
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

# ---------- 3️⃣ Install home‑manager ----------
install_home_manager() {
  # Home manager is a Nix package; we install it via the user profile
  if nix profile list | grep -q home-manager; then
    info "home-manager already installed in the user profile."
  else
    info "Installing home-manager ..."
    nix profile install nixpkgs#home-manager
  fi

  # Create ~/.config/nixpkgs if it does not exist
  local hm_dir="${HOME}/.config/nixpkgs"
  mkdir -p "${hm_dir}"

  local hm_file="${hm_dir}/home.nix"
  if [[ -f "${hm_file}" ]]; then
    info "home.nix already exists – leaving it untouched."
  else
    info "Creating minimal home.nix that imports the shared main.nix"
    cat > "${hm_file}" <<'EOF'
{ pkgs, ... }:

let
  # Adjust the path if you moved the repo somewhere else
  shared = import ~/nixos-config/main.nix { inherit pkgs; };
in {
  # Packages that should be installed globally for your user
  home.packages = shared.commonPackages;

  # Environment variables (EDITOR, LANG, …)
  home.sessionVariables = shared.env;

  # Example: enable Zsh (feel free to customise)
  programs.zsh.enable = true;
  programs.zsh.promptInit = ''
    PROMPT='%F{green}%n@%m %F{blue}%~ %F{yellow}$ %f'
  '';
}
EOF
  fi

  # Activate the new home-manager configuration
  info "Activating home-manager configuration ..."
  home-manager switch
}

# ---------- 4️⃣ Generate hardware‑configuration.nix ----------
generate_hardware_config() {
  local hw_file="./hardware-configuration.nix"
  if [[ -f "${hw_file}" ]]; then
    info "hardware-configuration.nix already exists – skipping generation."
  else
    info "Generating hardware-configuration.nix (first‑time only)."
    # This command must be run *inside* the WSL distro that will host the NixOS system.
    # It writes the file into the repository root.
    nixos-generate-config --root "$(pwd)" --dir "$(pwd)"
  fi
}

# ---------- 5️⃣ Build the WSL system ----------
rebuild_wsl() {
  info "Building the NixOS‑WSL system (this may take a few minutes)..."
  # The flake defines a `nixosConfigurations.wsl` attribute.
  # Use sudo because we need to write to /etc/nixos (inside the WSL VM).
  sudo nixos-rebuild switch --flake ".#wsl"
}

# ---------- Main flow ----------
main() {
  info "===== Starting automated NixOS‑WSL bootstrap ====="

  ensure_nix_conf
  install_nix_direnv
  install_home_manager
  generate_hardware_config
  rebuild_wsl

  info "===== Bootstrap complete! ====="
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