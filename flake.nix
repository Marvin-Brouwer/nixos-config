{
  description = "NixOS‑style dev‑profile collection (used with nix‑direnv)";

  # -----------------------------------------------------------------
  # Inputs – we only need nixpkgs (you can pin a specific rev if you like)
  # -----------------------------------------------------------------
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    # nix-direnv is a tiny wrapper that makes `use nix` work with flakes.
    # It ships as a Nix expression, no external dependency needed.
    nix-direnv.url = "github:nix-community/nix-direnv";
  };

  # -----------------------------------------------------------------
  # Outputs – we expose three things:
  #   * `devShells.<system>.default` – a generic shell (optional)
  #   * `devShells.<system>.typescript` – the TS/Node profile
  #   * `packages.<system>.profiles` – a convenient attrset of all
  #     profile derivations (useful for CI or testing)
  # -----------------------------------------------------------------
  outputs = { self, nixpkgs, nix-direnv, ... }:
    let
      system = "x86_64-linux";
      pkgs   = import nixpkgs { inherit system; };
    in {
      # -------------------------------------------------------------
      # Helper to load a profile from ./profiles/<name>/profile.nix
      # -------------------------------------------------------------
      lib = {
        mkProfile = name:
          pkgs.callPackage ./profiles/${name}/profile.nix { inherit pkgs; };
      };

      # -------------------------------------------------------------
      # Dev shells – these are what `nix develop` or `direnv` will use.
      # -------------------------------------------------------------
      devShells.${system} = {
        default   = self.lib.mkProfile "default";
        typescript = self.lib.mkProfile "typescript";
        # add more: e.g. python = self.lib.mkProfile "python";
      };

      # -------------------------------------------------------------
      # Optional: expose each profile as a normal package (useful for CI)
      # -------------------------------------------------------------
      packages.${system}.profiles = {
        inherit (self.devShells.${system}) default typescript;
      };
    };
}