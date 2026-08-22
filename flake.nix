{
  description = "NixOS‑style dev‑profile collection (used with nix‑direnv)";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Import the WSL module from the nixos-wsl flake (makes the `wsl` attribute set available).
    nixos-wsl.url   = "github:nix-community/nixos-wsl/release-25.05";
  };

  outputs = { self, nixpkgs, nixos-wsl, ... }:
    let
      system = "x86_64-linux";
      pkgs   = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      lib    = pkgs.lib;

      # Discover profiles
      rawEntries   = builtins.readDir ./profiles;
      profileDirs  = lib.filterAttrs (_name: type: type == "directory") rawEntries;
      devShellsMap = lib.genAttrs (builtins.attrNames profileDirs) (name:
        import ./profiles/${name}/profile.nix { inherit pkgs lib; }
      );
    in {
      # Load static config
      nixosConfigurations.nix-wsl = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-wsl.nixosModules.default
          ./configuration.nix    
          # ./hardware-configuration.nix This is removed, NixOS-WSL solves this       
        ];
      };
      # Load profiles
      devShells.${system} = devShellsMap;
    };
}