# -----------------------------------------------------------------
# Shared library set for prebuilt, dynamically-linked binaries.
#
# This used to be about browsers only. Since tool versions come from mise
# now, it is load-bearing for everything: mise downloads ordinary vendor
# builds (node from nodejs.org, dotnet from Microsoft) that expect an FHS
# layout NixOS does not have, and without nix-ld they fail to start at all
# with a bare "no such file or directory".
#
# Two consumers, deliberately the same list:
#
#   * `programs.nix-ld.libraries` in configuration.nix -- makes everything
#     mise and npm download for themselves runnable, with no per-project
#     configuration.
#
#   * `playwright-fhs` in tools/playwright.nix -- the fallback sandbox, for
#     whatever nix-ld turns out not to cover.
#
# The browser entries are roughly Playwright's own `install-deps` list for
# Ubuntu, translated to nixpkgs. webkit needs a longer tail than chromium
# and firefox do. To check it against reality rather than trusting it,
# install a browser and look for what is still missing:
#
#   pnpm exec playwright install chromium
#   ldd ~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome | grep 'not found'
#
# The same trick works for anything mise installs:
#
#   ldd ~/.local/share/mise/installs/node/*/bin/node | grep 'not found'
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

  # Wanted by mise-installed runtimes rather than by browsers. The .NET SDK
  # is the fussiest of them: it needs openssl and krb5 on top of the icu
  # further down this list.
  openssl
  zlib
  krb5

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
