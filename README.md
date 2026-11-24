# Jetson Flight Setup

Turn a fresh NVIDIA Jetson Orin Nano into a flight-ready drone companion computer in under an hour.

This guide covers everything needed to run AI-powered autonomous flight software on a Jetson — from first boot to a fully configured headless system with CUDA, TensorRT, PyTorch, and MAVLink.

Built and tested on a real drone project using GPS-denied satellite image matching for return-to-home navigation.

## Hardware

| Component | Details |
|-----------|---------|
| **Compute** | NVIDIA Jetson Orin Nano Super Dev Kit (8GB) |
| **SSD** | 128 GB NVMe 2230 (flight) + 256 GB NVMe 2280 (dev) |
| **Camera** | Arducam B0429 AR0234 (2.3MP global shutter, MIPI CSI-2) |
| **Flight Controller** | ArduPilot-based (Pixhawk class) |
| **OS** | Ubuntu 22.04 LTS, L4T R36.4.7, JetPack 6.2.1 |

## What You Get

After running through this setup, your Jetson will have:

- **Headless Ubuntu 22.04** — no desktop, no wasted RAM
- **WiFi with auto-reconnect** — NetworkManager, boots connected every time
- **SSH key-only auth** — password login disabled, ed25519 keys
- **Max performance on boot** — MAXN_SUPER mode + pinned clocks via systemd
- **Full AI stack** — CUDA 12.6, cuDNN, TensorRT 10.3, OpenCV 4.8 (CUDA-accelerated)
- **Python flight environment** — PyTorch 2.3, FAISS, pymavlink, MAVSDK, onnxruntime
- **Camera driver** — Arducam CSI-2 ready (plug and fly)
- **Monitoring** — jtop dashboard for temps, clocks, memory
- **Backup script** — clone your SSD to microSD before risky changes

## Quick Start

```bash
# Clone the repo
git clone https://github.com/AbuFanni/jetson-flight-setup.git
cd jetson-flight-setup

# Run scripts in order on a fresh Jetson (as your normal user, not root)
chmod +x scripts/*.sh
./scripts/01-network.sh
./scripts/02-ssh-hardening.sh
./scripts/03-performance.sh
./scripts/04-cuda-stack.sh
./scripts/05-python-env.sh
./scripts/06-camera.sh
./scripts/07-backup.sh
```

Each script is independent — if one fails, fix the issue and re-run it. No need to start over.

## Scripts Overview

| Script | What It Does | Time |
|--------|-------------|------|
| `01-network.sh` | Installs NetworkManager, connects WiFi, enables auto-reconnect | 2 min |
| `02-ssh-hardening.sh` | Key-only SSH: disables password and root login, limits login to your user | 1 min |
| `03-performance.sh` | Sets MAXN_SUPER power mode, installs systemd service for boot persistence | 1 min |
| `04-cuda-stack.sh` | Verifies CUDA, installs missing libs, sets LD_LIBRARY_PATH | 3 min |
| `05-python-env.sh` | Creates venv, installs PyTorch (Jetson wheel), FAISS, pymavlink, MAVSDK | 10 min |
| `06-camera.sh` | Installs Arducam CSI-2 driver for AR0234 | 2 min |
| `07-backup.sh` | Clones your SSD to a microSD card (gzip compressed) | 15 min |

## Directory Structure (on the Jetson)

```
~/drone/
├── venv/          # Python virtual environment
├── app/           # Your mission code
├── models/        # Vision model weights (.onnx, .engine)
├── index/         # FAISS index of satellite tiles
└── data/tiles/    # Satellite tile images
```

## Power Modes

The Jetson Orin Nano Super has 4 power modes:

| Mode | ID | CPU | GPU | Power | Use Case |
|------|----|-----|-----|-------|----------|
| 7W | 3 | 4 cores, low clock | Low | 7W | Idle / standby |
| 15W | 0 | 6 cores | Medium | 15W | Flight (good balance) |
| 25W | 1 | 6 cores | High | 25W | Heavy compute |
| MAXN_SUPER | 2 | 6 cores, max clock | Max | ~25W+ | Bench testing / burst |

For flight, **15W is the sweet spot** — good performance without excessive heat in an enclosed shell. MAXN_SUPER is great for bench testing and model optimization.

The module has a 25 W input limit. In a bench test with CPU, memory and GPU all at full load, MAXN_SUPER went over it and the board cut the CPU clock in half. Measured numbers for each mode, and how to check your own workload, are in [docs/measurements.md](docs/measurements.md).

## Thermal Notes

- Dev kit heatsink + fan is adequate for open-air testing
- In an enclosed drone shell, add ventilation slots near the Jetson
- Kernel throttling for heat starts at 99C and shutdown is at 104C (the 70C trip is only a hot-surface warning). Monitor with `jtop`
- Consider Noctua 40mm fan upgrade for quieter, better airflow

## Tested With

- Jetson Orin Nano Super Dev Kit (p3767-0005 / p3768-0000)
- L4T R36.4.7 (JetPack 6.2.1)
- Ubuntu 22.04 LTS
- Kernel 5.15.148-tegra
- NVMe SSDs (both 2230 and 2280 form factors)

Should work with minimal changes on other Jetson Orin variants (Orin NX, AGX Orin) running JetPack 6.x.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues and fixes.

## License

MIT — use it, fork it, fly it.

## Acknowledgments

Built during a GPS-denied autonomous drone project. The drone uses satellite image matching (DSMAC/TERCOM-style fix-and-fly checkpoint navigation) for return-to-home without GPS.
