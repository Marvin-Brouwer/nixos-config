{ pkgs, lib, ... }:

let
  playwright = import ./playwright.nix { inherit pkgs lib; };
in
(import ../../templates/profile.nix { inherit pkgs lib; }) {
  profile = {
    name = "typescript";
    packages = [
      pkgs.nodejs_24
      pkgs.typescript
      pkgs.eslint
      pkgs.pnpm
      pkgs.esbuild
      # Playwright browsers come from `playwright install` and are made
      # runnable by programs.nix-ld.libraries in configuration.nix; see
      # ./playwright.nix for why this profile does not ship
      # pkgs.playwright-driver.browsers.
      #
      # Fallback if nix-ld leaves something uncovered: an FHS sandbox where
      # the downloaded binaries run unmodified.
      playwright.fhs
      # Second fallback, for projects that accept an `executablePath` (in
      # five-dice, via PLAYWRIGHT_CHROMIUM_PATH). Bypasses browser
      # resolution entirely, so neither revision nor layout matters, but it
      # does not cover `playwright test --ui`.
      pkgs.chromium
    ];
    extensions = import ./vscode.nix;
    env = {
      NODE_OPTIONS = "--max-old-space-size=4096";

      # Playwright validates the host against a list of known Linux
      # distributions and refuses to recognise NixOS. The check is advisory;
      # the browsers themselves run fine once nix-ld can load them.
      #
      # Note there is deliberately no PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD here:
      # it only suppresses the npm postinstall hook (an explicit
      # `playwright install` downloads regardless), and under nix-ld the
      # download is what we want.
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    };
  };
}
