# templates/profile.nix
# --------------------------------------------------------------
# Arguments supplied when the file is imported
# --------------------------------------------------------------
{ pkgs, lib }:

# --------------------------------------------------------------
# The second argument is the *profile description* you pass from
#   profiles/<name>/profile.nix
# --------------------------------------------------------------
{ profile }:

let
  # -----------------------------------------------------------------
  # 1️⃣ Packages that you want in **every** dev‑shell (feel free to edit)
  # -----------------------------------------------------------------
  defaultPackages = with pkgs; [
    git
    curl
    jq
    htop
  ];

  # -----------------------------------------------------------------
  # 2️⃣ Merge the caller‑supplied packages with the defaults.
  #    The caller may already have inserted a `vscode-with-extensions`
  #    derivation (coming from `profiles/<name>/vscode.nix`), and that
  #    works automatically because it is just another package.
  # -----------------------------------------------------------------
  allPackages = defaultPackages ++ profile.packages;

  # -----------------------------------------------------------------
  # 3️⃣ Environment variables.
  #    • Some globals that you always want (EDITOR, LANG …)
  #    • Anything the caller puts in `profile.env` overrides / extends them.
  # -----------------------------------------------------------------
  defaultEnv = {
    EDITOR = "code -w";          # use the VS Code binary as editor
    LANG   = "en_US.UTF-8";
  };

  finalEnv = defaultEnv // (profile.env or {});

in
pkgs.mkShell {
  name = "dev-shell-${builtins.currentSystem}";

  # Packages that end up on $PATH
  packages = allPackages;

  networking.hostName = "nix-wsl";

  # Ensure both users exist during transition
  users.users = {
    nixos = {
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager"];
      # Keep nixos user temporarily
    };
    nixdev = {
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager"];
      initialPassword = "password";
    };
  };

  # Override common settings that don't work well in WSL
  services = {
    xserver.enable = lib.mkForce false;
    displayManager.sddm.enable = lib.mkForce false;
    desktopManager.plasma6.enable = lib.mkForce false;
    pipewire.enable = lib.mkForce false;
  };

  # Disable networking services unnecessary in WSL
  networking.wireless.enable = lib.mkForce false; # Disables wpa_supplicant

  # WSL-specific settings
  wsl = {
    enable = true;
    defaultUser = vars.user.name;
    startMenuLaunchers = true;
    wslConf = {
      automount.root = "/mnt";
      network.generateResolvConf = true;
    };
  };

  # Turn every key in `finalEnv` into an environment variable.
  # Nix automatically exports any attribute that isn’t a known
  # mkShell field as an env‑var, so this works for arbitrary keys.
  inherit (finalEnv) EDITOR LANG;
  # If the profile supplied extra vars (e.g. NODE_OPTIONS) they are
  # also exported – we just forward the whole attribute set.
  inherit finalEnv;
}