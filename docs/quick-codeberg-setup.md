# GPG Key Generation Guide for WSL + Nix Shell

This guide resolves the `gpg: agent_genkey failed: No pinentry` error in WSL by forcing GPG to use the terminal-based `pinentry-curses` instead of the GUI-based `pinentry-gnome3`.

## Prerequisites
- Running inside a `nix-shell` (or WSL environment)
- Access to `gpg` and `nix-shell`

## Step 1: Kill Existing GPG Agent
The default agent may be configured for a GUI that doesn't exist in WSL.
gpgconf --kill gpg-agent

## Step 2: Locate `pinentry-curses`
We need the full path to the terminal-based pinentry program.
CURSE_PATH=$(nix-shell -p pinentry-curses --run "which pinentry-curses")
echo "Using pinentry at: $CURSE_PATH"

## Step 3: Start Agent with Explicit Pinentry
Start a new GPG agent instance, explicitly telling it to use the curses binary found in Step 2.
gpg-agent --daemon --pinentry-program "$CURSE_PATH"

## Step 4: Generate the Key
Now you can generate the key. You should see a text prompt in your terminal for the passphrase.
gpg --full-generate-key
(Follow the prompts to select key type (RSA/EdDSA), size, and expiration.)

## Step 5: Configure Git for Signing
Once the key is generated, configure Git to use it automatically.

1. Find your Key ID (last 8 chars of the fingerprint):
   gpg --list-keys --keyid-format LONG
   (Copy the ID, e.g., A1B2C3D4)

2. Set Git config:
   git config --global user.signingkey YOUR_KEY_ID
   git config --global commit.gpgsign true

## Step 6: Add Public Key to Codeberg
1. Export the public key:
   gpg --armor --export YOUR_KEY_ID

2. Copy the output (including -----BEGIN PGP PUBLIC KEY BLOCK----- and -----END ...).

3. Go to Codeberg Profile Settings > GPG Keys and paste it.

## Troubleshooting
- "No pinentry" error persists: Ensure you ran `gpgconf --kill gpg-agent` *after* setting the `CURSE_PATH`.
- GUI popup fails: This is expected in WSL without X11 forwarding. The `pinentry-curses` method ensures a terminal prompt instead.
- Agent not starting: If `gpg-agent` fails to start, check permissions on `~/.gnupg` (`chmod 700 ~/.gnupg`).