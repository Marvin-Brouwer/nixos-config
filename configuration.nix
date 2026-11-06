{ config, pkgs, lib, ... }:

let
  # The facts about this particular machine, as opposed to about the setup.
  # Nothing under programs/ names a host, so a second machine is these three
  # bindings and a flake output rather than a rewrite.
  hostName = "nix-wsl";
  isWsl = true;
  mainUser = "nixos";

  # Upstream packages, in a binding because `sysupdate` names them in the
  # pending-update notice. Anything built in this repo stays out of it: a local
  # script has no upstream version to compare against.
  systemTools = with pkgs; [
    librewolf
    # No git here on purpose. programs.git below installs it and registers the
    # LFS filters in /etc/gitconfig, which listing it here would not do.
    gh
    curl
    wget  # required by VS Code Remote-WSL to download the server

    # Not version sensitive per project, so they belong to the machine.
    jq
    htop

    # Per-project tool versions. See programs/mise.toml.
    mise
    # mise verifies the OpenPGP signature on node releases with external gpg,
    # and skips the check with a warning when it cannot find one.
    gnupg

    # Scans the system closure against NVD, so there is an answer to whether
    # being behind actually matters this time rather than only how long it has
    # been. Expect false positives: it matches on name and version, and NixOS
    # backports fixes without always bumping the version string. A prompt to
    # look, not a verdict. `sysupdate --audit` is the shorthand.
    vulnix
  ];

  # The one command this repo puts on PATH. Everything below is reached through
  # it (`rig sys update`, `rig repo init ...`), so there is a single name to
  # remember and `rig --help` to fall back on. Renaming it is this one string.
  devPrefix = "rig";

  vscode = import ./programs/tool/vscode-sync { inherit pkgs lib; prefix = devPrefix; };
  repoconfig = import ./programs/repo/init {
    inherit pkgs lib;
    prefix = devPrefix;
    vscodeSync = vscode;
  };

  # Every command this repo builds is an entry here, which is the only way it
  # becomes reachable. See programs/rig.nix.
  rig = import ./programs/rig.nix {
    inherit pkgs lib;
    prefix = devPrefix;
    commands = {
      sys = {
        summary = "the machine itself: updates, disk space, health";
        commands = {
          update = {
            package = sysupdate.sysupdate;
            summary = "see pending system updates and apply or stage them";
            usage = "[--status|--check|--audit]";
            complete = [ "--status" "--check" "--audit" ];
          };
          compact = {
            package = compact.compact;
            summary = "free disk space: old generations, Docker, unused mise tools";
            usage = "[--yes|--status|--check]";
            complete = [ "--yes" "--status" "--check" ];
          };
          doctor = {
            package = doctor;
            summary = "check every piece this setup leans on, when something is off";
            usage = "";
          };
        };
      };
      repo = {
        summary = "the git repo you are in, or a throwaway one";
        commands = {
          init = {
            package = repoconfig.repoconfig;
            summary = "set up the git repo you are in, once after cloning";
            usage = "<preset> <email>, --list for presets";
            complete = [ "--list" ] ++ repoconfig.presets;
          };
          scratch = {
            package = scratch;
            summary = "a throwaway repo with a preset, and a shell in it";
            usage = "[preset] [--keep]";
            complete = [ "--keep" ] ++ repoconfig.presets;
          };
        };
      };
      config = {
        summary = "this nixos-config repo: try a branch, or go back to main";
        commands = {
          build = {
            package = configBuild;
            summary = "build the checked-out branch of this config and switch to it";
            usage = "";
          };
          update = {
            package = configUpdate;
            summary = "back to main: pull it, and build when that changed anything";
            usage = "";
          };
        };
      };
      tool = {
        summary = "helpers for the tools projects use";
        commands = {
          vscode-sync = {
            package = vscode;
            summary = "sync VSCode plugins for this repo (runs on entering one)";
            usage = "[--wait|--detach]";
            complete = [ "--wait" "--detach" ];
          };
          docker = {
            package = dockerDaemon;
            summary = "start, stop or restart the Docker daemon, or see if it runs";
            usage = "<start|stop|restart|status>";
            complete = [ "start" "stop" "restart" "status" ];
          };
          playwright = {
            package = playwright;
            bin = "playwright-fhs";
            summary = "FHS sandbox for browsers nix-ld does not cover";
            usage = "[-c 'command']";
            # The sandbox runs bash, so --help would be bash's.
            help = ''
              usage: ${devPrefix} tool playwright [-c 'command']

              Opens a bash shell in an FHS sandbox with the browser libraries, mise,
              node and pnpm, for when nix-ld is not enough for a browser. Arguments
              go to that bash, so -c 'pnpm exec playwright test' runs one command
              and exits.
            '';
          };
        };
      };
    };
  };
  dockerDaemon = import ./programs/tool/docker { inherit pkgs lib; prefix = devPrefix; };
  playwright = import ./programs/tool/playwright { inherit pkgs lib; };
  sysupdate = import ./programs/sys/update {
    inherit pkgs lib hostName isWsl;
    prefix = devPrefix;
    # git comes from programs.git rather than the list above, so it is named
    # here explicitly. Otherwise the one package most worth seeing a version
    # bump for would be the one the notice never mentions.
    # Docker is installed by virtualisation.docker below, for the same reason.
    watch = systemTools ++ [ pkgs.git config.virtualisation.docker.package ];
  };
  # Both read sysupdate's state directory: the clean-up notice stays quiet while
  # an update is pending, and doctor checks the update timer still runs.
  sysupdateStateDir = sysupdate.stateDir;
  compact = import ./programs/sys/compact {
    inherit pkgs lib isWsl sysupdateStateDir;
    prefix = devPrefix;
  };
  doctor = import ./programs/sys/doctor {
    inherit pkgs lib isWsl sysupdateStateDir;
    prefix = devPrefix;
    inherit compact;
  };
  configBuild = import ./programs/config/build {
    inherit pkgs lib hostName;
    prefix = devPrefix;
  };
  configUpdate = import ./programs/config/update {
    inherit pkgs lib sysupdateStateDir;
    prefix = devPrefix;
    build = configBuild;
  };
  scratch = import ./programs/repo/scratch {
    inherit pkgs lib repoconfig;
    prefix = devPrefix;
  };
  # What Claude Code knows about this machine, from the same list as rig --help.
  claudeSkill = import ./programs/claude-skill {
    inherit pkgs lib;
    inherit (rig) leaves;
    prefix = devPrefix;
    docs = ./docs;
  };
  mainHome = config.users.users.${mainUser}.home;
in
{
  # Configure network identity
  networking.hostName = hostName;

  # Ensure both users exist during transition
  users.users.${mainUser} = {
    isNormalUser = true;
    # docker: use the Docker Engine below without sudo. Membership is
    # root-equivalent, which is the usual trade on a single-user dev box.
    extraGroups = ["wheel" "networkmanager" "docker"];
  };

  # System-wide packages.
  #
  # Language runtimes are deliberately absent: those come from mise, per
  # project, so a repo pinned to an old node does not fight the system. What
  # lives here is the machine itself, plus anything needed before you are
  # inside a project at all. The upstream half is systemTools above.
  environment.systemPackages = systemTools ++ [
    # The commands this repo builds, all behind one name: repo setup, system
    # updates, VSCode plugin sync and the Playwright sandbox. `rig --help`.
    # They are deliberately not on PATH under their own names; the mise hook,
    # the shell notice and the systemd unit reference them by store path.
    rig.package
  ];

  # git-lfs is enabled system-wide because it is a general footgun, not a
  # per-language one. Without the LFS filters registered in the
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
  # This is what makes the whole toolchain run. Everything mise installs, node
  # and pnpm and the .NET SDK alike, arrives as an ordinary vendor build
  # expecting an FHS layout NixOS does not have. Without the shim they install
  # cleanly and then fail to start at all.
  #
  # For browsers the symptom is different and more confusing: Playwright and
  # Puppeteer install fine and die the moment they launch, as "Protocol error
  # (Browser.getVersion): Internal server error, session closed". With the
  # libraries in place, `playwright install` and `playwright test` behave the
  # way the docs say, with nothing set per project.
  programs.nix-ld = {
    enable = true;
    libraries = import ./lib/nix-ld-libs.nix { inherit pkgs lib; };
  };

  # Docker Engine, in this distro rather than through Docker Desktop.
  #
  # A daemon is the machine, not a per-project tool: it runs as root and owns
  # cgroups, iptables and the kernel modules, so mise cannot provide it. Docker
  # Desktop's WSL integration is no substitute either, because it runs
  # containers in its own docker-desktop distro, whose VM root disk is too small
  # for things like a self-hosted E2B (and which is not this system at all).
  #
  # Not started on boot: the socket is, and the first `docker` command starts
  # the daemon. So a WSL session that never touches containers pays nothing.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  # mise: per-project tool versions.
  #
  # The settings file is real TOML in this repo rather than an inline string,
  # so it stays readable and greppable. Project tooling is not declared in it;
  # each repo carries its own mise.toml, because a version inherited from a
  # parent config never lands in that project's mise.lock.
  # The one substitution is the enter hook's store path, since vscode-sync is not
  # on PATH under its own name.
  environment.etc."mise/config.toml".source = pkgs.replaceVars ./programs/mise.toml {
    vscodeSync = "${vscode}/bin/vscode-sync";
  };

  # Activation belongs in the system config rather than a hand-written shell
  # rc, so the hook is active on every terminal with no manual setup.
  programs.bash.interactiveShellInit = ''
    eval "$(mise activate bash)"

    # What system updates are pending, straight from the file the timer below
    # writes. A file test and a cat: no eval, no network, nothing slow between
    # you and the prompt. It nags on every new shell until you deal with it,
    # which is the point -- this box lives in WSL and is easy to forget.
    ${sysupdate.notice}/bin/sysupdate-notice

    # The same for disk space, but only when sysupdate printed nothing: one
    # nag per shell, and the update comes first. See programs/sys/compact.
    ${compact.notice}/bin/compact-notice

    # Names `repoconfig` when you cd into a repo it has not been run in. See
    # programs/repo/init.
    ${repoconfig.shellInit}

    # Tab completion for the prefix.
    ${rig.completion}
  '';

  # Pending system updates.
  #
  # Evaluating the configuration is the only way to know what changed: Nix has
  # no package index to diff against the way apt does. So it cannot happen in
  # the shell, and it lands here instead -- a timer that evaluates against the
  # newest inputs and caches the answer for the notice above to print.
  #
  # This is not system.autoUpgrade and does not want to be. See
  # programs/sys/update for why, in WSL and off it.
  systemd.services.sysupdate-check = {
    description = "Check for pending system updates";
    # Deliberately not network-online.target: nothing provides it in WSL, and
    # the check needs no ordering guarantee anyway. A run with no network fails
    # softly, keeps the previous answer, and retries in an hour.
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${sysupdate.check}/bin/sysupdate-check";

      # Runs as the user who owns the repo, not as root. It only reads the
      # flake and writes its own state directory, so root buys nothing, and git
      # refuses to touch a work tree owned by someone else ("dubious
      # ownership") which is exactly what a root-run check would hit.
      User = mainUser;

      # Creates /var/lib/sysupdate world-readable, which is what lets every
      # shell print a notice this unit wrote.
      StateDirectory = "sysupdate";
      StateDirectoryMode = "0755";
      # A full nixpkgs eval is not something that should be felt in a terminal.
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
    };
  };

  systemd.timers.sysupdate-check = {
    description = "Check for pending system updates";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Boot is the frequent event in WSL, roughly daily, so it is the good
      # trigger here; OnUnitActiveSec is what covers a machine left running for
      # weeks instead. Neither is the real rate limit -- timer state does not
      # survive a WSL shutdown, so the stamp file in sysupdate-check is what
      # actually enforces the interval.
      OnBootSec = "2min";
      OnUnitActiveSec = "12h";
      Unit = "sysupdate-check.service";
    };
  };

  # The Claude Code skill, as a user skill: ~/.claude/skills/<prefix> is a
  # symlink into the store, so it follows every rebuild. tmpfiles rather than a
  # home-manager file, since nothing else here needs home-manager. L+ replaces
  # whatever is at that one path; the rest of ~/.claude is left alone.
  systemd.tmpfiles.rules = [
    "d ${mainHome}/.claude 0700 ${mainUser} users -"
    "d ${mainHome}/.claude/skills 0755 ${mainUser} users -"
    "L+ ${mainHome}/.claude/skills/${devPrefix} - - - - ${claudeSkill}"
  ];

  # Whether `compact` is worth running, measured the same way: a timer writes
  # the answer, the shell only prints it. Measuring walks the Nix store, which
  # is fine at idle priority and not fine in front of a prompt.
  systemd.services.compact-check = {
    description = "Check whether a clean-up is worth running";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${compact.check}/bin/compact-check";
      # The main user, so `compact` can clear the notice after a run without
      # sudo. Listing dead store paths goes through the daemon, which needs no
      # root either.
      User = mainUser;
      StateDirectory = "compact";
      StateDirectoryMode = "0755";
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
    };
  };

  systemd.timers.compact-check = {
    description = "Check whether a clean-up is worth running";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # After the update check has had its turn at boot. The stamp file in
      # compact-check is the real once-a-day limit, as with sysupdate.
      OnBootSec = "10min";
      OnUnitActiveSec = "24h";
      Unit = "compact-check.service";
    };
  };

  # Facts about this machine rather than about any one project.
  environment.sessionVariables = {
    # librewolf as the default browser (privacy-focused, pre-compiled in the
    # nixpkgs cache)
    BROWSER = "librewolf";

    EDITOR = "code -w";
    LANG = "en_US.UTF-8";

    # Playwright validates the host against a list of known Linux
    # distributions and refuses to recognise NixOS. The check is advisory; the
    # browsers themselves run fine once nix-ld can load them. It is a property
    # of running on NixOS at all, hence system-wide.
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
    enable = isWsl;
    defaultUser = mainUser;
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
