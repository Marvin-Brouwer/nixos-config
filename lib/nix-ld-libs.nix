# -----------------------------------------------------------------
# Shared library set for prebuilt, dynamically-linked binaries.
#
# Load-bearing for the whole toolchain: mise downloads ordinary vendor builds
# (node from nodejs.org, dotnet from Microsoft) that expect an FHS layout
# NixOS does not have, and without nix-ld they fail to start at all with a
# bare "no such file or directory".
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
  # Existence check that does not force the value. That matters: a renamed
  # attribute is a warning wrapped around the real package, so merely comparing
  # it to null is enough to print the deprecation. Checking the path instead
  # means an old spelling is never evaluated while the current one exists.
  exists = name: lib.hasAttrByPath (lib.splitString "." name) pkgs;
  lookup = name: lib.getAttrFromPath (lib.splitString "." name) pkgs;

  # First spelling this channel actually has, or nothing. Names are tried in
  # order, so put the current one first and older aliases after it.
  firstAvailable = names:
    if names == [ ] then [ ]
    else if exists (lib.head names) then [ (lookup (lib.head names)) ]
    else firstAvailable (lib.tail names);

  # Each name independently optional.
  maybe = names: lib.concatMap (n: firstAvailable [ n ]) names;
in
(with pkgs; [
  # libstdc++ etc. -- the first thing a vendor binary trips over
  stdenv.cc.cc.lib

  # Wanted by mise-installed runtimes rather than by browsers. The .NET SDK
  # needs openssl and zlib the moment it opens an https connection, on top of
  # the icu further down this list. krb5 is there for Windows domain auth and
  # has never been exercised here.
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

  # Fonts, or every screenshot renders as tofu
  dejavu_fonts
  liberation_ttf
])
# Renamed between nixpkgs releases. Current name first, old alias second, so
# this evaluates clean on either side of the rename.
++ lib.concatMap firstAvailable [
  [ "libx11" "xorg.libX11" ]
  [ "libxcomposite" "xorg.libXcomposite" ]
  [ "libxcursor" "xorg.libXcursor" ]
  [ "libxdamage" "xorg.libXdamage" ]
  [ "libxext" "xorg.libXext" ]
  [ "libxfixes" "xorg.libXfixes" ]
  [ "libxi" "xorg.libXi" ]
  [ "libxrandr" "xorg.libXrandr" ]
  [ "libxtst" "xorg.libXtst" ]
  [ "libxcb" "xorg.libxcb" ]
  [ "libxshmfence" "xorg.libxshmfence" ]
  [ "enchant_2" "enchant2" ] # webkit spellcheck
]
++ maybe [
  "libgbm" # split out of mesa in newer nixpkgs
  "mesa"
  "libgcc"
  "libnotify"
  "libpulseaudio"
  "libopus"
  "libvpx"
  "enchant" # webkit spellcheck, v1 alongside the v2 above
  "flite" # webkit speech synthesis
  "libgudev"
]
