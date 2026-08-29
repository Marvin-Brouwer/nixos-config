# -----------------------------------------------------------------
# Shared library set for prebuilt browser binaries.
#
# Two consumers, deliberately the same list:
#
#   * `programs.nix-ld.libraries` in configuration.nix -- makes the browsers
#     npm packages download for themselves runnable, since they are ordinary
#     dynamically-linked ELF binaries expecting an FHS layout NixOS lacks.
#     This is what makes `playwright install` + `playwright test` work with
#     no project-specific configuration.
#
#   * `playwright-fhs` in profiles/typescript/playwright.nix -- the fallback
#     sandbox, for whatever nix-ld turns out not to cover.
#
# Roughly Playwright's own `install-deps` list for Ubuntu, translated to
# nixpkgs. webkit needs a longer tail than chromium and firefox do. To check
# it against reality rather than trusting it, install a browser and look for
# what is still missing:
#
#   pnpm exec playwright install chromium
#   ldd ~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome | grep 'not found'
# -----------------------------------------------------------------

{ pkgs, lib }:

let
  # A few of these have moved between nixpkgs releases. Take whatever this
  # channel actually has instead of failing to evaluate on the ones it lacks.
  maybe = names: lib.filter (p: p != null) (map (n: pkgs.${n} or null) names);
in
(with pkgs; [
  # libstdc++ etc. -- the first thing a vendor binary trips over
  stdenv.cc.cc.lib

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
]
