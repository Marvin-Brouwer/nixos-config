{ pkgs }:

# The list of extensions you want for the TypeScript dev environment.
# Each entry comes from `pkgs.vscode-extensions.<publisher>.<extension>`
# (these are the names used in the upstream nixpkgs collection).
let  
  baseExtensions = import ../default/vscode.nix { inherit pkgs; };
  tsSpecific = [
    pkgs.vscode-extensions.dbaeumer.vscode-eslint    # ESLint integration
    pkgs.vscode-extensions.ms-vscode.vscode-typescript-next # Latest TS language features
  ];
in

# Export combined
baseExtensions ++ tsSpecific

