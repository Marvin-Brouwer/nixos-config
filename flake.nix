{
  description = "NixOS-WSL system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # A handful of tools whose release cadence stable cannot keep up with. A
    # stable branch freezes most packages at branch-off, so 26.05 still ships
    # the mise from May. Only the packages configuration.nix names from
    # `unstable` come from here; everything else stays on the release.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Import the WSL module from the nixos-wsl flake (makes the `wsl` attribute set available).
    nixos-wsl.url   = "github:nix-community/nixos-wsl/release-26.05";
  };

  # There is deliberately no devShells output. Per-project tooling comes from
  # mise, because nixpkgs only carries the runtime majors it packages and this
  # setup exists to run whatever version a project asks for.
  # See programs/mise.toml.
  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-wsl, ... }:
    let
      system = "x86_64-linux";
    in {
      # The attribute name is the host name, and `sysupdate` builds
      # `.#${hostName}` from configuration.nix -- keep the two in step.
      nixosConfigurations.nix-wsl = nixpkgs.lib.nixosSystem {
        inherit system;
        # Handed to the modules as their own argument rather than overlaid onto
        # pkgs. An overlay replacing git would rebuild everything that builds
        # with git, none of it in the binary cache; taking the package directly
        # changes only the one store path.
        specialArgs.unstable = nixpkgs-unstable.legacyPackages.${system};
        modules = [
          nixos-wsl.nixosModules.default
          ./configuration.nix
          # ./hardware-configuration.nix This is removed, NixOS-WSL solves this
        ];
      };
    };
}
