# My local NixOs setup

I am running NixOs in WSL, I'd like to run multi-profile so I can easily work on different projects without tool version clashes.  
For example, I just want to be able to run a `python`, whether python 2 or 3 is required.  

## Structure

```txt
~/
├─ .config/
│   └─ nix/
│       └─ nix.conf               # enable flakes, etcetera, here
├─ nixos-config/                   
│   ├─ flake.nix                  # the entry point for the whole repo
│   ├─ configuration.nix          # full NixOS system config (WSL‑2 VM)
│   ├─ hardware-configuration.nix # hardware settings
│   ├─ profiles/
│   │   ├─ default/
│   │   │   ├─ profile.nix        # generic shell (e.g. basic tools)
│   │   ├─ typescript/
│   │   │   ├─ profile.nix        # Node / TypeScript‑centric shell
│   │   │   └─ vscode.nix         
│   │   ├─ csharp/
│   │   │   ├─ profile.nix        # C# shell
│   │   │   └─ vscode.nix     
│   │   └─ */
│   │       ├─ profile.nix        # Any additional shell
│   │       └─ vscode.nix
│   └─ templates/
│      ├─ profile.nix            # Extendable base configuration
│      └─ vscode.nix             # Extendable vscode configuration
└─ repos/
    ├─ my‑first‑proj/
    │   └─ .envrc                 # direnv hook (auto‑loads the right profile)
    └─ another‑proj/
        └─ .envrc                 # direnv hook (auto‑loads the right profile)
```

## Setup NixOS

Edit (or create) ` ~/.config/nix/nix.conf`:

```conf
experimental-features = nix-command flakes
``` 

Reload the shell or start a new one.

```bash
nix profile install nixpkgs#nix-direnv
# Add the hook to your shell rc (bash example):
echo 'eval "$(nix-direnv)"' >> ~/.bashrc
source ~/.bashrc
```

Clone this repo

```bash
# Install git temporarily (not in base install)
nix-shell -p git
# Clone your config
git clone https://github.com/<your‑user>/nixos-config.git ~/nixos-config
cd ~/nixos-config
# Deploy the foundation configuration
# This will create your user and set everything up
sudo nixos-rebuild switch --flake .#main
```

Make your interactive shell use ` ~/nixos-config/main.nix`:

```bash
nix profile install nixpkgs#home-manager
```

Create a `home.nix` that imports the `~/nixos-config/main.nix`.
Place it in `~/.config/nixpkgs/home.nix` (or any location you like).

```nix
# ~/.config/nixpkgs/home.nix
{ pkgs, ... }:

let
  # Pull the shared config from your central repo
  shared = import ~/nixos-config/main.nix { inherit pkgs; };
in {
  # Packages that should be installed globally for your user
  home.packages = shared.commonPackages;

  # Environment variables (EDITOR, LANG, etc.)
  home.sessionVariables = shared.env;

  # Example: enable the Zsh module, set a theme, etc.
  programs.zsh.enable = true;
  programs.zsh.promptInit = ''
    PROMPT='%F{green}%n@%m %F{blue}%~ %F{yellow}$ %f'
  '';
}
```

Activate

```bash
home-manager switch
```

Exit WSL and reboot it from the windows terminal (`gitbash`/`cmd`,`pwsh`, shouldn't matter):

```bash
wsl --shutdown
wsl
```

## Using a profile

Inside any directory where you want a particular profile loaded, create a .envrc file:
Run (once per directory):

```bash
echo 'use flake .#typescript' > .envrc
direnv allow
```

> [NOTE]!  
> In this example `typescript` be replaced by any profile.

direnv will:

Detect the use flake … line.
Invoke nix develop .#typescript (or whichever attribute you asked for).
Drop you into a shell where all packages defined in that profile are on $PATH, and the environment variables you exported are set.
You can also combine multiple profiles in a single .envrc by chaining use flake statements, but usually one profile per project is enough.