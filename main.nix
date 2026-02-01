{ pkgs }:

{
  commonPackages = with pkgs; [
    git
    jq
    curl
    htop
    vscode
  ];

  # Configure the default VSCODE editor.
  env = {
    EDITOR = "code -w";
    LANG   = "en_US.UTF-8";
  };

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
}