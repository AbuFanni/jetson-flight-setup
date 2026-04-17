#!/bin/bash
# 06-camera.sh — Install Arducam CSI-2 camera driver
# Run on the Jetson
# Supports: Arducam B0429 (AR0234), and other Arducam MIPI CSI-2 cameras

set -e

echo "=== Jetson Flight Setup: Camera Driver ==="

# Detect L4T version
L4T_VERSION=$(dpkg -l | grep nvidia-l4t-core | awk '{print $3}' | cut -d'-' -f1)
KERNEL_VERSION=$(uname -r)

echo "L4T: $L4T_VERSION"
echo "Kernel: $KERNEL_VERSION"
echo ""

# Check if Arducam driver is already installed
if dpkg -l | grep -q arducam-nvidia-l4t-kernel; then
    echo "Arducam driver already installed:"
    dpkg -l | grep arducam-nvidia-l4t-kernel | awk '{print $2, $3}'
    echo ""
    echo "To test the camera:"
    echo "  ls /dev/video*"
    echo "  v4l2-ctl --list-devices"
    echo "  sudo dmesg | grep -i arducam"
    exit 0
fi

# Add Arducam apt repository
echo "[1/3] Adding Arducam repository..."
curl -s --compressed "https://www.arducam.com/downloads/Jetson/Jetpack6.x/KEY.gpg" \
    | gpg --dearmor | sudo tee /usr/share/keyrings/arducam.gpg > /dev/null

sudo curl -s --compressed -o /etc/apt/sources.list.d/arducam.list \
    "https://www.arducam.com/downloads/Jetson/Jetpack6.x/arducam.list"

sudo apt update

# Install the driver
echo "[2/3] Installing Arducam driver..."
sudo apt install -y arducam-nvidia-l4t-kernel

# Show what was installed
echo ""
echo "[3/3] Installed:"
dpkg -l | grep arducam-nvidia-l4t-kernel | awk '{print $2, $3}'

echo ""
echo "=== Camera Driver Installed ==="
echo ""
echo "IMPORTANT: Reboot required for the driver to load."
echo ""
echo "After reboot, connect your camera to the CSI CAM1 port and verify:"
echo "  ls /dev/video*"
echo "  sudo dmesg | grep -i arducam"
echo ""
echo "For Arducam B0429 (AR0234), use legacy mode:"
echo "  v4l2-ctl -d /dev/video0 --set-fmt-video=width=1920,height=1200"
echo ""
echo "Capture a test frame with OpenCV:"
echo "  python3 -c \""
echo "  import cv2"
echo "  cap = cv2.VideoCapture(0)"
echo "  ret, frame = cap.read()"
echo "  print(f'Captured: {frame.shape}' if ret else 'FAILED')"
echo "  cap.release()\""
echo "=== Done ==="
