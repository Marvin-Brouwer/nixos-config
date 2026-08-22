{ pkgs, lib, ... }:

(import ../../templates/profile.nix { inherit pkgs lib; }) {
  profile = {
    name = "typescript";
    packages = [
      pkgs.nodejs_24
      pkgs.typescript
      pkgs.eslint
      pkgs.pnpm
      pkgs.esbuild
      # The browsers npm-installed Playwright downloads for itself are linked
      # against an FHS layout NixOS doesn't have. They install without
      # complaint (Playwright's own "no chromium-based browser found" check
      # passes, the binary really is there) and then die the instant they
      # launch, as a "Protocol error (Browser.getVersion): Internal server
      # error, session closed". This package ships the same browsers patched
      # for Nix.
      #
      # A plain `pkgs.chromium` is enough to *run* tests, since Playwright
      # accepts an `executablePath`, but not for `playwright test --ui`: that
      # window always goes through the browser registry. Hence the driver's
      # browser bundle for a dev profile.
      pkgs.playwright-driver.browsers
    ];
    extensions = import ./vscode.nix;
    env = {
      NODE_OPTIONS = "--max-old-space-size=4096";

      # NOTE: the browser revision has to match the Playwright version, or the
      # lookup fails instead of the launch. Playwright resolves browsers by
      # revision number out of `playwright-core/browsers.json` (1.62.1 wants
      # Chromium r1234), so if the project's `playwright` release and
      # `pkgs.playwright-driver` disagree the directory names won't line up.
      # Keep the two paired: check what this profile provides with
      #   nix eval --raw github:NixOS/nixpkgs/nixos-25.05#playwright-driver.version
      # and pin the project's `playwright` dependency to it.
      PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
      # Stop npm's postinstall re-downloading the broken ones over the top.
      # For the same reason, never run `playwright install` here -- the
      # browsers come from the store path above. Drive tests with the
      # project's own CLI (`npx playwright test`), so the CLI version and the
      # browser revisions stay in step; there is deliberately no global
      # `playwright` on PATH.
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    };
  };
}
