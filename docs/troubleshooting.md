# Troubleshooting

Common issues and fixes encountered during Jetson flight setup.

## Network

### WiFi won't connect
```bash
# Check if NetworkManager is running
sudo systemctl status NetworkManager

# Restart it
sudo systemctl restart NetworkManager

# List available networks
nmcli device wifi list

# Reconnect
nmcli device wifi connect "YOUR_SSID" password "YOUR_PASSWORD"
```

### Can't find Jetson IP after WiFi setup
```bash
# On the Jetson (keyboard+monitor):
ip addr show wlP1p1s0

# From your Mac/PC (scan the network):
arp -a | grep -i "192.168"
# or
nmap -sn 192.168.1.0/24
```

### mDNS hostname not resolving (jetson.local)
```bash
# Install avahi for .local discovery
sudo apt install -y avahi-daemon
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# Set a hostname
sudo hostnamectl set-hostname x-flight
```

---

## SSH

### Host key mismatch after switching SSDs
The Jetson has different host keys on each SSD. When you switch boot drives, SSH complains.
```bash
# On your Mac/PC — remove the old key:
ssh-keygen -R 192.168.1.XXX
```

### Permission denied (publickey)
Your public key isn't on the Jetson yet.
```bash
# From your Mac/PC:
ssh-copy-id -i ~/.ssh/id_ed25519.pub YOUR_USER@JETSON_IP
```

### sudo requires password over SSH
```bash
# On the Jetson (keyboard needed once):
echo "YOUR_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/nopasswd
sudo chmod 440 /etc/sudoers.d/nopasswd
```

---

## CUDA / PyTorch

### PyTorch says CUDA is not available
```bash
# Check CUDA libraries are findable
echo $LD_LIBRARY_PATH

# Should include both of these:
#   /usr/local/cuda-12.6/lib64
#   /usr/local/cuda-12.6/targets/aarch64-linux/lib

# If missing, add to ~/.bashrc:
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:/usr/local/cuda-12.6/targets/aarch64-linux/lib:$LD_LIBRARY_PATH
```

### Missing libnvToolsExt.so.1
```bash
sudo apt install -y libnvtoolsext1
```

### Missing libcupti.so.12
```bash
sudo apt install -y cuda-cupti-12-6
```

### Missing libcublas.so
This library lives in a non-standard path on Jetson. Make sure `LD_LIBRARY_PATH` includes:
```
/usr/local/cuda-12.6/targets/aarch64-linux/lib
```

### faiss-gpu won't install
There's no pre-built ARM64 wheel. Use `faiss-cpu` instead — it's fast enough for drone-sized indices (under 1M vectors).

### onnxruntime-gpu won't install
Same issue — no ARM64 wheel. Use `onnxruntime` (CPU) for ONNX testing, and TensorRT for actual GPU inference in production.

---

## Performance

### Jetson throttling / slow performance
```bash
# Check current power mode
sudo nvpmodel -q

# Check if clocks are pinned
sudo jetson_clocks --show

# Check temperature
cat /sys/devices/virtual/thermal/thermal_zone*/temp
# Divide by 1000 for Celsius

# Use jtop for a live dashboard
jtop
```

### Power mode doesn't persist after reboot
Make sure the systemd service is enabled:
```bash
sudo systemctl enable jetson-maxperf.service
sudo systemctl status jetson-maxperf.service
```

---

## Camera

### No /dev/video* after connecting camera
```bash
# Check kernel messages
sudo dmesg | grep -i arducam

# If you see "Reading register 0x103 failed" — the camera sensor
# is not responding. This means:
# 1. Camera is not seated properly — reseat the CSI ribbon cable
# 2. Wrong CSI port — use CAM1 (physical port, not CAM0)
# 3. Camera hardware is defective — contact manufacturer for RMA
```

### v4l2-ctl not found
```bash
sudo apt install -y v4l-utils
```

---

## Boot

### nv-l4t-bootloader-config.service failed
This happens when booting from NVMe instead of eMMC/SD. The service looks for `/etc/nv_boot_control.conf` which only exists after SDK Manager flash.

Safe to disable:
```bash
sudo systemctl disable nv-l4t-bootloader-config.service
sudo systemctl mask nv-l4t-bootloader-config.service
```

The QSPI bootloader works fine without this service.

---

## Backup / Restore

### microSD not detected
```bash
# Check if the card is visible
lsblk | grep mmcblk

# If not showing up, the card may need formatting:
# On your Mac/PC, format as ext4 (Linux) or FAT32
```

### Restore from backup
```bash
# DANGER: This overwrites the target partition completely
zcat jetson-ssd-backup-YYYYMMDD.img.gz | sudo dd of=/dev/nvme1n1p2 bs=4M status=progress
```
