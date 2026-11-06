{
  description = "NixOS-WSL system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Import the WSL module from the nixos-wsl flake (makes the `wsl` attribute set available).
    nixos-wsl.url   = "github:nix-community/nixos-wsl/release-26.05";
  };

  # There is deliberately no devShells output. Per-project tooling comes from
  # mise, because nixpkgs only carries the runtime majors it packages and this
  # setup exists to run whatever version a project asks for.
  # See programs/mise.toml.
  outputs = { self, nixpkgs, nixos-wsl, ... }:
    let
      system = "x86_64-linux";
    in {
      # The attribute name is the host name, and `sysupdate` builds
      # `.#${hostName}` from configuration.nix -- keep the two in step.
      nixosConfigurations.nix-wsl = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-wsl.nixosModules.default
          ./configuration.nix
          # ./hardware-configuration.nix This is removed, NixOS-WSL solves this
        ];
      };
    };
}
