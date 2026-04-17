#!/bin/bash
# 04-cuda-stack.sh — Verify and fix the CUDA/TensorRT/cuDNN stack
# Run on the Jetson after JetPack is installed

set -e

echo "=== Jetson Flight Setup: CUDA Stack ==="

# Check what's installed
echo "[1/4] Checking installed JetPack components..."
echo ""

echo "L4T version:"
dpkg -l | grep nvidia-l4t-core | awk '{print $3}' || echo "not found"

echo ""
echo "JetPack:"
dpkg -l | grep nvidia-jetpack-runtime | awk '{print $2, $3}' || echo "not found"

echo ""
echo "CUDA directories:"
ls -d /usr/local/cuda* 2>/dev/null || echo "no CUDA found"

echo ""
echo "nvcc:"
nvcc --version 2>/dev/null || echo "nvcc not found (normal for runtime-only install)"

# Install missing CUDA libraries that PyTorch needs
echo ""
echo "[2/4] Installing CUDA runtime libraries..."
sudo apt update
sudo apt install -y \
    cuda-cudart-12-6 \
    cuda-libraries-12-6 \
    libnvtoolsext1 \
    cuda-cupti-12-6

# Verify TensorRT
echo ""
echo "[3/4] TensorRT:"
dpkg -l | grep -i tensorrt | head -5 || echo "TensorRT not found — install nvidia-tensorrt"
dpkg -l | grep libnvinfer | head -3 || true

# Verify OpenCV
echo ""
echo "OpenCV:"
dpkg -l | grep libopencv-dev | awk '{print $2, $3}' || echo "not found"

# Set up environment variables
echo ""
echo "[4/4] Setting CUDA environment variables..."

CUDA_PATH="/usr/local/cuda-12.6"
if [ ! -d "$CUDA_PATH" ]; then
    CUDA_PATH=$(ls -d /usr/local/cuda-* 2>/dev/null | tail -1)
fi

if [ -z "$CUDA_PATH" ]; then
    echo "ERROR: No CUDA installation found!"
    exit 1
fi

# Add to .bashrc if not already there
if ! grep -q "cuda" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << EOF

# CUDA environment
export PATH=${CUDA_PATH}/bin:\$PATH
export LD_LIBRARY_PATH=${CUDA_PATH}/lib64:${CUDA_PATH}/targets/aarch64-linux/lib:\$LD_LIBRARY_PATH
EOF
    echo "Added CUDA paths to ~/.bashrc"
else
    echo "CUDA paths already in ~/.bashrc"
fi

# Source it now
export PATH=${CUDA_PATH}/bin:$PATH
export LD_LIBRARY_PATH=${CUDA_PATH}/lib64:${CUDA_PATH}/targets/aarch64-linux/lib:$LD_LIBRARY_PATH

echo ""
echo "=== CUDA Stack Ready ==="
echo "CUDA path: $CUDA_PATH"
echo ""
echo "Verify with:"
echo "  python3 -c \"import torch; print(torch.cuda.is_available())\""
echo "  python3 -c \"import tensorrt; print(tensorrt.__version__)\""
echo "=== Done ==="
