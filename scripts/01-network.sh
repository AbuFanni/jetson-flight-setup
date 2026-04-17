#!/bin/bash
# 01-network.sh — Install NetworkManager and connect WiFi
# Run on the Jetson (ethernet or keyboard+monitor needed for first run)

set -e

echo "=== Jetson Flight Setup: Network ==="

# Install NetworkManager and wpasupplicant
echo "[1/4] Installing NetworkManager..."
sudo apt update
sudo apt install -y network-manager wpasupplicant

# Enable and start NetworkManager
echo "[2/4] Enabling NetworkManager..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Wait for NetworkManager to initialize
sleep 3

# Scan for WiFi networks
echo "[3/4] Available WiFi networks:"
nmcli device wifi list

# Connect to WiFi
echo ""
echo "[4/4] Connect to your WiFi network:"
echo ""
read -p "WiFi SSID: " WIFI_SSID
read -sp "WiFi Password: " WIFI_PASS
echo ""

nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS"

# Verify connection
echo ""
echo "=== Network Status ==="
echo "WiFi IP: $(nmcli -g IP4.ADDRESS device show wlP1p1s0 2>/dev/null || echo 'check with: ip addr')"
echo ""
echo "WiFi will auto-reconnect on every boot."
echo "You can now unplug ethernet and SSH in over WiFi."
echo "=== Done ==="
