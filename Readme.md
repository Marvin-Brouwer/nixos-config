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
│   ├─ hardware-configuration.nix # hardware settings (generate by setup.sh)
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

Clone this repo

```bash
# Install git temporarily (not in base install)
nix-shell -p git
# Clone your config
git clone https://github.com/<your‑user>/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

Run the setup:

```bash
# Make the setup script executable
chmod +x setup.sh
# Run the setup script
bash ./setup.sh
```

The script will:

- Enable flakes in `~/.config/nix/nix.conf`
- Install `nix-direnv` and add the `direnv` hook to your shell rc
- Install `home-manager` and create a minimal `~/.config/nixpkgs/home.nix` that imports the shared `main.nix`
- Generate `hardware-configuration.nix` (if missing)
- Rebuild the WSL‑2 NixOS system (`nixosConfigurations.wsl`)

After the script finishes, restart the WSL VM so the new system takes effect.  
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