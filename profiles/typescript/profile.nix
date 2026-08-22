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
      # The browsers npm-installed Playwright downloads for itself are linked
      # against an FHS layout NixOS doesn't have. They install without
      # complaint (Playwright's own "no chromium-based browser found" check
      # passes, the binary really is there) and then die the instant they
      # launch, as a "Protocol error (Browser.getVersion): Internal server
      # error, session closed". These are the same browsers patched for Nix.
      #
      # A plain `pkgs.chromium` is enough to *run* tests, since Playwright
      # accepts an `executablePath`, but not for `playwright test --ui`: that
      # window always goes through the browser registry. Hence the driver's
      # browser bundle for a dev profile.
      playwright.browsers
      # Escape hatch for when the revisions no longer line up -- see
      # ./playwright.nix. Drops into an FHS sandbox where Playwright can
      # download and run its own browsers, whatever version it is on.
      playwright.fhs
    ];
    extensions = import ./vscode.nix;
    env = {
      NODE_OPTIONS = "--max-old-space-size=4096";

      # NOTE: the browser revision has to match the Playwright version, or the
      # lookup fails instead of the launch. Playwright resolves browsers by
      # revision number out of `playwright-core/browsers.json` (1.62.1 wants
      # Chromium r1234), and nixpkgs trails upstream Playwright, so a
      # project-side bump can outrun this at any time. `playwright.browserCheck`
      # reports the gap on shell entry; `playwright-fhs` is the way through it.
      PLAYWRIGHT_BROWSERS_PATH = "${playwright.browsers}";
      # Stop npm's postinstall re-downloading the broken ones over the top.
      # For the same reason, never run `playwright install` here -- the
      # browsers come from the store path above. Drive tests with the
      # project's own CLI (`npx playwright test`), so the CLI version and the
      # browser revisions stay in step; there is deliberately no global
      # `playwright` on PATH. Inside `playwright-fhs` both of these are
      # reversed, because there the downloads are the point.
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    };
    shellHook = ''
      ${playwright.browserCheck}
    '';
  };
}
