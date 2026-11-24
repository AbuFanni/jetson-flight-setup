#!/bin/bash
# 03-performance.sh — Set max performance mode with boot persistence
# Run on the Jetson

set -e

echo "=== Jetson Flight Setup: Performance ==="

# Show current power mode
echo "[1/3] Current power mode:"
sudo nvpmodel -q

echo ""
echo "Available power modes:"
echo "  0 = 15W (flight sweet spot)"
echo "  1 = 25W (high performance)"
echo "  2 = MAXN_SUPER (max performance)"
echo "  3 = 7W (low power)"
echo ""
read -p "Select power mode [2]: " POWER_MODE
POWER_MODE=${POWER_MODE:-2}

# Set power mode now
echo "[2/3] Setting power mode $POWER_MODE..."
sudo nvpmodel -m "$POWER_MODE"
sudo jetson_clocks

# Create systemd service for boot persistence
echo "[3/3] Creating boot persistence service..."
sudo tee /etc/systemd/system/jetson-maxperf.service > /dev/null << EOF
[Unit]
Description=Set Jetson power mode and pin clocks at boot
After=multi-user.target nvpmodel.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/nvpmodel -m $POWER_MODE
ExecStartPost=/usr/bin/jetson_clocks
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jetson-maxperf.service

# Install jtop for monitoring
echo ""
echo "Installing jtop (Jetson monitoring dashboard)..."
sudo pip3 install -U jetson-stats 2>/dev/null || sudo apt install -y python3-pip && sudo pip3 install -U jetson-stats

echo ""
echo "=== Performance Configured ==="
echo "Power mode $POWER_MODE + jetson_clocks will persist across reboots."
echo ""
echo "Verify with:"
echo "  sudo nvpmodel -q     # check power mode"
echo "  sudo jetson_clocks --show  # check clock speeds"
echo "  jtop                 # live monitoring dashboard"
echo "=== Done ==="
