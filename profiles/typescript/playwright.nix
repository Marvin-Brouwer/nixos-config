# -----------------------------------------------------------------
# Playwright support for the TypeScript profile.
#
# Two routes, because they fail in different directions:
#
#   1. `pkgs.playwright-driver.browsers` -- browsers patched for Nix, no
#      download, but a single fixed set of revisions. Playwright resolves
#      browsers by *revision number* out of `playwright-core/browsers.json`,
#      so this only works while the project's Playwright release and the
#      one nixpkgs packaged agree. nixpkgs runs behind upstream Playwright,
#      so a project-side bump can outrun it at any time.
#
#   2. `playwright-fhs` -- an FHS sandbox where Playwright downloads and
#      runs its own browsers, exactly as it would on Ubuntu. Slower to
#      start (one ~500MB download per version) but works with *any*
#      Playwright release, independent of what nixpkgs ships.
#
# Route 1 is the default; route 2 is the escape hatch when the revisions
# no longer line up. `browser-check` below detects which situation you are
# in and says so on shell entry.
# -----------------------------------------------------------------

{ pkgs, lib }:

let
  browsers = pkgs.playwright-driver.browsers;

  # A few of these have moved between nixpkgs releases. Take whatever this
  # channel actually has instead of failing to evaluate on the ones it lacks.
  maybe = names: lib.filter (p: p != null) (map (n: pkgs.${n} or null) names);

  # Shared libraries the vendor browser builds expect. Roughly Playwright's
  # own `install-deps` list for Ubuntu, translated into nixpkgs attributes.
  # webkit needs a longer tail than chromium and firefox do.
  browserLibs =
    (with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      harfbuzz
      icu
      libdrm
      libepoxy
      libGL
      libjpeg
      libpng
      libsecret
      libwebp
      libxkbcommon
      libxml2
      libxslt
      nspr
      nss
      openjpeg
      pango
      systemd # libudev
      woff2
      xorg.libX11
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXtst
      xorg.libxcb
      xorg.libxshmfence
      # Fonts, or every screenshot renders as tofu
      dejavu_fonts
      liberation_ttf
    ])
    ++ maybe [
      "libgbm" # split out of mesa in newer nixpkgs
      "mesa"
      "libgcc"
      "libnotify"
      "libpulseaudio"
      "libopus"
      "libvpx"
      "enchant" # webkit spellcheck
      "enchant2"
      "flite" # webkit speech synthesis
      "libgudev"
    ];

  # An FHS sandbox: /usr/lib et al. exist inside, so the browser binaries
  # Playwright downloads for itself run unmodified. PLAYWRIGHT_BROWSERS_PATH
  # is pointed back at the normal per-user cache and the download block is
  # lifted, so `npx playwright install` behaves the way the docs say.
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
      export PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/ms-playwright"
      unset PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD
      export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
    '';
    runScript = "bash";
  };

  # Compares what the project's playwright-core asks for against what the
  # store path actually holds, and explains the gap before a test run turns
  # it into an "Executable doesn't exist" a hundred lines deep.
  browserCheck = pkgs.writeShellScript "playwright-browser-check" ''
    set -u
    [ -n "''${PLAYWRIGHT_BROWSERS_PATH:-}" ] || exit 0
    [ -d node_modules ] || exit 0

    # pnpm keeps playwright-core in its virtual store, npm hoists it; find both.
    BJSON=$(find . -maxdepth 8 -type f \
      -path '*/node_modules/*playwright-core/browsers.json' 2>/dev/null | head -1)
    [ -n "$BJSON" ] || exit 0

    WANT=$(${pkgs.jq}/bin/jq -r \
      '.browsers[] | select(.name == "chromium") | .revision' "$BJSON" 2>/dev/null)
    HAVE=$(ls "$PLAYWRIGHT_BROWSERS_PATH" 2>/dev/null \
      | grep -m1 '^chromium-' | sed 's/^chromium-//')
    [ -n "$WANT" ] && [ -n "$HAVE" ] || exit 0
    [ "$WANT" = "$HAVE" ] && exit 0

    PWVER=$(${pkgs.jq}/bin/jq -r '.version' \
      "$(dirname "$BJSON")/package.json" 2>/dev/null || echo unknown)

    echo "[playwright] Browser revision mismatch:"
    echo "[playwright]   playwright-core $PWVER wants chromium r$WANT"
    echo "[playwright]   this profile provides chromium r$HAVE"
    echo "[playwright] Test runs will fail with \"Executable doesn't exist\"."
    echo "[playwright] Run the suite in the FHS sandbox instead, which fetches"
    echo "[playwright] the browsers this Playwright actually wants:"
    echo "[playwright]   playwright-fhs -c 'npx playwright install chromium && npx playwright test'"
    echo "[playwright] Or pin the project to the packaged Playwright release:"
    echo "[playwright]   nix eval --raw github:NixOS/nixpkgs/nixos-25.05#playwright-driver.version"
  '';

in
{
  inherit browsers fhs browserCheck;
}
