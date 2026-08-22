# -----------------------------------------------------------------
# Playwright support for the TypeScript profile.
#
# The primary mechanism is not here: it is `programs.nix-ld.libraries` in
# configuration.nix, which makes the browsers Playwright downloads for
# itself runnable. That needs nothing per project --
# `pnpm exec playwright install chromium && pnpm exec playwright test`
# just works, and no PLAYWRIGHT_* variable points anywhere unusual.
#
# What is deliberately NOT done here is pointing PLAYWRIGHT_BROWSERS_PATH at
# `pkgs.playwright-driver.browsers`. That looks like the natural Nix answer
# and fails three ways:
#
#   1. Playwright resolves browsers by revision number, so the packaged
#      Playwright release has to match the project's npm one exactly.
#      nixpkgs trails upstream, so any project-side bump can break it.
#   2. Even matched, the layout differs. Current Playwright ships Chrome for
#      Testing and expects `chromium-<rev>/chrome-linux64/chrome`; nixpkgs
#      25.05 packages the older registry build at `chrome-linux/chrome`.
#   3. `playwright install` writes into PLAYWRIGHT_BROWSERS_PATH (a
#      `__dirlock`, a `.links/` directory), and /nix/store is read-only. It
#      does not fail -- it retries the lock 20 times over ten minutes in
#      silence, presenting as a command that hangs with no output.
#
# `playwright-fhs` below stays as a fallback for whatever nix-ld does not
# cover: an FHS sandbox where the downloaded binaries run unmodified. It is
# a bigger hammer than the executablePath route (it covers UI mode, which
# always goes through the browser registry) and needs no project support.
# -----------------------------------------------------------------

{ pkgs, lib }:

let
  browserLibs = import ../../lib/browser-libs.nix { inherit pkgs lib; };

  fhs = pkgs.buildFHSEnv {
    name = "playwright-fhs";
    targetPkgs =
      p:
      browserLibs
      ++ (with p; [
        nodejs_24
        pnpm
        cacert
        curl
        git
      ]);
    profile = ''
      export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
    '';
    runScript = "bash";
  };

in
{
  inherit fhs;
}
