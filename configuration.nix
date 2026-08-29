{ config, pkgs, lib, ... }:

let
  vscode = import ./programs/vscode.nix { inherit pkgs lib; };
  playwright = import ./tools/playwright.nix { inherit pkgs lib; };
in
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

  # System-wide packages.
  #
  # Language runtimes are deliberately absent: those come from mise, per
  # project, so a repo pinned to an old node does not fight the system. What
  # lives here is the machine itself, plus anything needed before you are
  # inside a project at all.
  environment.systemPackages = with pkgs; [
    librewolf
    # git itself comes from programs.git below
    gh
    curl
    wget  # required by VS Code Remote-WSL to download the server

    # Was in templates/profile.nix's defaultPackages, which every dev shell
    # inherited. There are no dev shells now, and neither is version
    # sensitive per project, so they belong to the machine.
    jq
    htop

    # Per-project tool versions. See programs/mise.toml.
    mise

    # VSCode plugin sync, and the wrapper that opens this repo's profile.
    vscode.sync
    vscode.wrapper

    # Break-glass FHS sandbox for when nix-ld does not cover a browser.
    playwright
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

  # nix-ld: compatibility shim for dynamically linked binaries.
  #
  # Now that tool versions come from mise, this is what makes the whole
  # toolchain run, not just browsers: node, pnpm and the .NET SDK all arrive
  # as ordinary vendor builds expecting an FHS layout NixOS does not have.
  # Without the shim they install cleanly and then fail to start at all.
  #
  # For browsers specifically the symptom is different and more confusing:
  # Playwright and Puppeteer install fine and die the moment they launch, as
  # "Protocol error (Browser.getVersion): Internal server error, session
  # closed". With the libraries in place, `playwright install` and
  # `playwright test` behave the way the docs say, with nothing per project.
  programs.nix-ld = {
    enable = true;
    libraries = import ./lib/nix-ld-libs.nix { inherit pkgs lib; };
  };

  # mise: per-project tool versions, replacing the flake dev-shells and
  # direnv that used to live here.
  #
  # The settings file is real TOML in this repo rather than an inline string,
  # so it stays readable and greppable. Project tooling is not declared in it;
  # each repo carries its own mise.toml, because a version inherited from a
  # parent config never lands in that project's mise.lock.
  environment.etc."mise/config.toml".source = ./programs/mise.toml;

  # Activation goes here rather than in setup.sh, the same way programs.direnv
  # used to write its hook into /etc/bashrc. Hand-written shell rc hooks were
  # the old mistake; setup.sh's reset_all exists to clean them up.
  programs.bash.interactiveShellInit = ''
    eval "$(mise activate bash)"
  '';

  # These used to be exported by the dev shells, via defaultEnv in
  # templates/profile.nix and the typescript profile's own env block. With no
  # dev shells they need a home, and all of them are facts about this machine
  # rather than about any one project.
  environment.sessionVariables = {
    # librewolf as the default browser (privacy-focused, pre-compiled in the
    # nixpkgs cache)
    BROWSER = "librewolf";

    EDITOR = "code -w";
    LANG = "en_US.UTF-8";

    # Playwright validates the host against a list of known Linux
    # distributions and refuses to recognise NixOS. The check is advisory; the
    # browsers themselves run fine once nix-ld can load them. This is a
    # property of running on NixOS at all, so it belongs to the system rather
    # than to a project.
    #
    # Note there is deliberately no PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD here: it
    # only suppresses the npm postinstall hook (an explicit `playwright
    # install` downloads regardless), and under nix-ld the download is what we
    # want.
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";

    # A preference rather than a machine fact. A project that wants something
    # different can override it in its own mise.toml [env].
    NODE_OPTIONS = "--max-old-space-size=4096";
  };

  xdg.mime.defaultApplications = {
    "text/html" = "librewolf.desktop";
    "x-scheme-handler/http" = "librewolf.desktop";
    "x-scheme-handler/https" = "librewolf.desktop";
  };

  nix.settings = {
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
