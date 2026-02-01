# My local NixOs setup

I am running NixOs in WSL, I'd like to run multi-profile so I can easily work on different projects without tool version clashes.  
For example, I just want to be able to run a `python`, whether python 2 or 3 is required.  

## Structure

```txt
nixos-config/
├─ flake.nix                # the entry point for the whole repo
├─ main.nix                 # shared system‑wide settings (optional)
├─ profiles/
│  ├─ default/
│  │   └─ profile.nix       # generic shell (e.g. basic tools)
│  └─ typescript/
│      └─ profile.nix       # Node / TypeScript‑centric shell
│  └─ csharp/
│      └─ profile.nix       # C# shell
│  └─ */
│      └─ profile.nix       # Any additional shell
│
└─ .envrc                   # top‑level direnv hook
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

Make your interactive shell use ` ~/nixos-config/main.nix` by adding the following to your `~/.bashrc` (and/or `~/.zshrc`):

```bash
# ~/.bashrc  (run once at the start of an interactive session)
if [ -z "$IN_NIX_SHELL" ]; then
  # Enter a temporary shell that contains the shared packages and env vars.
  # The `--pure` flag makes sure we start from a clean environment,
  # then we re‑inject the variables we actually want.
  exec nix develop "$HOME/nixos-config#default" "$@"
fi
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