{ config, pkgs, lib, ... }:

{
  # Configure network identity
  networking.hostName = "nix-wsl";

  # Ensure both users exist during transition
  users.users = {
    nixos = {
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager"];
    };
  };

  # System-wide packages
  environment.systemPackages = with pkgs; [
    librewolf
    # git itself comes from programs.git below
    gh
    curl
    wget  # required by VS Code Remote-WSL to download the server
  ];

  # git-lfs is enabled system-wide rather than per profile: it is a general
  # footgun, not a TypeScript one. Without the LFS filters registered in the
  # gitconfig, LFS-tracked files check out as ~130-byte pointer stubs
  # (`version https://git-lfs.github.com/spec/v1`) instead of their contents,
  # and nothing warns you -- it only shows up much later as a confusing
  # runtime error, e.g. an audio file that decodes to
  # `EncodingError: Unable to decode audio data`. CI checkouts that pass
  # `lfs: true` are unaffected, so this only bites local clones.
  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  # nix-ld: compatibility shim for dynamically linked binaries (e.g. VS Code Server's node)
  programs.nix-ld.enable = true;

  # direnv + nix-direnv: the NixOS module writes the shell hook into /etc/bashrc
  # (sourced for every bash session) and configures the direnvrc for nix-direnv,
  # so the hook is active on every terminal start without any manual setup.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Set librewolf as the default browser (privacy-focused, pre-compiled in nixpkgs cache)
  environment.sessionVariables.BROWSER = "librewolf";
  xdg.mime.defaultApplications = {
    "text/html" = "librewolf.desktop";
    "x-scheme-handler/http" = "librewolf.desktop";
    "x-scheme-handler/https" = "librewolf.desktop";
  };

  # Keep nix-direnv derivations alive (prevents GC from removing dev shells)
  nix.settings = {
    keep-outputs = true;
    keep-derivations = true;
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Override common settings that don't work well in WSL
  services = {
    xserver.enable = lib.mkForce false;                 # no X server needed
    displayManager.sddm.enable = lib.mkForce false;     # no DM
    desktopManager.plasma6.enable = lib.mkForce false;
    pipewire.enable = lib.mkForce false;                # audio handled by Windows (wsl-host)
  };
  # Disable networking services unnecessary in WSL
  networking.wireless.enable = lib.mkForce false; # Disables wpa_supplicant
  # WSL-specific settings
  wsl = {
    enable = true;
    defaultUser = "nixos";
    startMenuLaunchers = true;
    wslConf = {
      automount.root = "/mnt";
      network.generateResolvConf = true;
    };
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05";
}
