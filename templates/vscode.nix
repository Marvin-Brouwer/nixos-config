{ pkgs }:

# -----------------------------------------------------------------
# Base list of extensions that all profiles inherit.
# -----------------------------------------------------------------
let
  base = [
    pkgs.vscode-extensions.jnoortheen.nix-ide
    pkgs.vscode-extensions.dbaeumer.vscode-eslint
    pkgs.vscode-extensions.esbenp.prettier-vscode
    pkgs.vscode-extensions.streetsidesoftware.code-spell-checker
    pkgs.vscode-extensions.streetsidesoftware.code-spell-checker-dutch
    pkgs.vscode-extensions.mechatroner.rainbow-csv
    pkgs.vscode-extensions.qiaojie.binary-viewer # Maybe also test https://marketplace.visualstudio.com/items?itemName=ms-vscode.hexeditor
    pkgs.vscode-extensions.anseki.vscode-color
    pkgs.vscode-extensions.editorconfig.editorconfig
    pkgs.vscode-extensions.unifiedjs.vscode-remark
    pkgs.vscode-extensions.tomokii207.pdf
    pkgs.vscode-extensions.dotjoshjohnson.xml
    pkgs.vscode-extensions.redhat.vscode-yaml
    pkgs.vscode-extensions.hgent.json-field-filter
    pkgs.vscode-extensions.oliversturm.fix-json
    pkgs.vscode-extensions.richie5um2.vscode-statusbar-json-path
    pkgs.vscode-extensions.motivesoft.vscode-restart
    pkgs.vscode-extensions.anweber.vscdode-httpyac
    # This is very similar to what we want to do:
    # https://marketplace.visualstudio.com/items?itemName=RhaldKhein.vscode-xrest-client
    # We'd like something in between httpyac and xrest-client
    pkgs.vscode-extensions.maattdd.gitless # pkgs.vscode-extensions.eamodio.gitlens
    pkgs.vscode-extensions.dotenv.dotenv-vscode
    pkgs.vscode-extensions.oderwat.indent-rainbow # if this is too much, check https://marketplace.visualstudio.com/items?itemName=tal7aouy.rainbow-bracket
    pkgs.vscode-extensions.Tyriar.sort-lines
    pkgs.vscode-extensions.vscode-icons-team.vscode-icons
    pkgs.vscode-extensions.joshuapoehls.json-escaper
    pkgs.vscode-extensions.ExodiusStudios.comment-anchors # We don't like how in your face todo-tree is, and this saves also having to install todo-highlight
    pkgs.vscode-extensions.stuart.unique-window-colors
    pkgs.vscode-extensions.vincaslt.highlight-matching-tag # This one is a try-out, maybe we don't like it
    pkgs.vscode-extensions.maurer.change-case
    pkgs.vscode-extensions.formulahendry.auto-rename-tag
    pkgs.vscode-extensions.kisstkondoros.vscode-gutter-preview
    pkgs.vscode-extensions.midudev.better-svg # or https://marketplace.visualstudio.com/items?itemName=SimonSiefke.svg-preview
    pkgs.vscode-extensions.mads-hartmann.bash-ide-vscode
    pkgs.vscode-extensions.pomdtr.excalidraw-editor
    pkgs.vscode-extensions.MermaidChart.vscode-mermaid-chart
    pkgs.vscode-extensions.DutchIgor.json-viewer # This one is a try-out, maybe we don't like it
    pkgs.vscode-extensions.Tion.evenbettercomments
    # Maybe? https://marketplace.visualstudio.com/items?itemName=korostylov.gherkin-highlight
    pkgs.vscode-extensions.funkyremi.vscode-google-translate
    pkgs.vscode-extensions.hediet.debug-visualizer
    pkgs.vscode-extensions.heaths.vscode-guid
    # Maybe? https://marketplace.visualstudio.com/items?itemName=HyunKyunMoon.gzipdecompressor
    pkgs.vscode-extensions.lamartire.git-indicators
    pkgs.vscode-extensions.meronz.manpages
  ];
in

{ extra ? [] }:

pkgs.vscode-with-extensions.override {
  vscodeExtensions = base ++ extra;
}
