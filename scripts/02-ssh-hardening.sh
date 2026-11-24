#!/bin/bash
# 02-ssh-hardening.sh — Secure SSH access with key-only auth
# Run on the Jetson after WiFi is working

set -e

echo "=== Jetson Flight Setup: SSH Hardening ==="

# SSH login gets limited to the user running this script, so root would lock you out
if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not with sudo."
    exit 1
fi

# Install openssh-server if not present
echo "[1/4] Ensuring SSH server is installed..."
sudo apt install -y openssh-server
sudo systemctl enable ssh

# Generate host keys if missing
sudo ssh-keygen -A

# Harden SSH config
echo "[2/4] Hardening SSH configuration..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

sudo tee /etc/ssh/sshd_config.d/hardened.conf > /dev/null << SSHEOF
# Key-only authentication (no passwords over SSH)
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes

# Disable root login
PermitRootLogin no

# Only allow the user who ran the setup script
AllowUsers $USER

# Security hardening
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
SSHEOF

echo ""
echo "[3/4] IMPORTANT: Before restarting SSH, make sure your public key is on this machine."
echo ""
echo "From your Mac/PC, run:"
echo "  ssh-keygen -t ed25519 -C \"your-name-to-jetson\""
echo "  ssh-copy-id -i ~/.ssh/id_ed25519.pub YOUR_USER@JETSON_IP"
echo ""
read -p "Have you copied your public key? (yes/no): " KEY_COPIED

if [ "$KEY_COPIED" != "yes" ]; then
    echo "Aborting. Copy your key first, then re-run this script."
    exit 1
fi

# Restart SSH
echo "[4/4] Restarting SSH service..."
sudo systemctl restart ssh

echo ""
echo "=== SSH Hardened ==="
echo "Password login is now DISABLED."
echo "Only key-based authentication will work."
echo "Only the user '$USER' can log in over SSH."
echo ""
echo "Optional — add to your Mac's ~/.ssh/config:"
echo ""
echo "  Host jetson"
echo "      HostName JETSON_IP"
echo "      User YOUR_USER"
echo "      IdentityFile ~/.ssh/id_ed25519"
echo "      IdentitiesOnly yes"
echo ""
echo "Then just: ssh jetson"
echo "=== Done ==="
