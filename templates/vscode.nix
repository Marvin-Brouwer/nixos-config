{ pkgs }:

# -----------------------------------------------------------------
# Base list of extensions that all profiles inherit.
#
# Extensions from nixpkgs use: pkgs.vscode-extensions.<publisher>.<name>
# Extensions from the marketplace use: pkgs.vscode-marketplace.<publisher>.<name>
# (provided by the nix-vscode-extensions overlay in flake.nix)
# -----------------------------------------------------------------
let
  base = [
    # --- Available in nixpkgs ---
    pkgs.vscode-extensions.jnoortheen.nix-ide
    pkgs.vscode-extensions.dbaeumer.vscode-eslint
    pkgs.vscode-extensions.esbenp.prettier-vscode
    pkgs.vscode-extensions.streetsidesoftware.code-spell-checker
    pkgs.vscode-extensions.mechatroner.rainbow-csv
    pkgs.vscode-extensions.editorconfig.editorconfig
    pkgs.vscode-extensions.tomoki1207.pdf
    pkgs.vscode-extensions.dotjoshjohnson.xml
    pkgs.vscode-extensions.redhat.vscode-yaml
    pkgs.vscode-extensions.anweber.vscode-httpyac
    pkgs.vscode-extensions.dotenv.dotenv-vscode
    pkgs.vscode-extensions.oderwat.indent-rainbow
    pkgs.vscode-extensions.tyriar.sort-lines
    pkgs.vscode-extensions.vscode-icons-team.vscode-icons
    pkgs.vscode-extensions.vincaslt.highlight-matching-tag
    pkgs.vscode-extensions.wmaurer.change-case
    pkgs.vscode-extensions.formulahendry.auto-rename-tag
    pkgs.vscode-extensions.mads-hartmann.bash-ide-vscode
    pkgs.vscode-extensions.funkyremi.vscode-google-translate

    # --- From marketplace (via nix-vscode-extensions overlay) ---
    pkgs.vscode-marketplace.streetsidesoftware.code-spell-checker-dutch
    pkgs.vscode-marketplace.qiaojie.binary-viewer # Maybe also test ms-vscode.hexeditor
    pkgs.vscode-marketplace.anseki.vscode-color
    pkgs.vscode-marketplace.unifiedjs.vscode-remark
    pkgs.vscode-marketplace.hgent.json-field-filter
    pkgs.vscode-marketplace.oliversturm.fix-json
    pkgs.vscode-marketplace.richie5um2.vscode-statusbar-json-path
    pkgs.vscode-marketplace.motivesoft.vscode-restart
    pkgs.vscode-marketplace.maattdd.gitless # pkgs.vscode-extensions.eamodio.gitlens
    pkgs.vscode-marketplace.joshuapoehls.json-escaper
    pkgs.vscode-marketplace.exodiusstudios.comment-anchors
    pkgs.vscode-marketplace.stuart.unique-window-colors
    pkgs.vscode-marketplace.kisstkondoros.vscode-gutter-preview
    pkgs.vscode-marketplace.midudev.better-svg
    pkgs.vscode-marketplace.pomdtr.excalidraw-editor
    pkgs.vscode-marketplace.mermaidchart.vscode-mermaid-chart
    pkgs.vscode-marketplace.dutchigor.json-viewer
    pkgs.vscode-marketplace.tion.evenbettercomments
    pkgs.vscode-marketplace.hediet.debug-visualizer
    pkgs.vscode-marketplace.heaths.vscode-guid
    pkgs.vscode-marketplace.lamartire.git-indicators
    pkgs.vscode-marketplace.meronz.manpages
  ];
in

{ extra ? [] }:

pkgs.vscode-with-extensions.override {
  vscodeExtensions = base ++ extra;
}
