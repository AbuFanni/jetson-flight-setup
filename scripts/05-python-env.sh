#!/bin/bash
# 05-python-env.sh — Create Python venv with flight stack packages
# Run on the Jetson after CUDA stack is verified

set -e

echo "=== Jetson Flight Setup: Python Environment ==="

DRONE_DIR="$HOME/drone"

# Create directory structure
echo "[1/5] Creating drone directory structure..."
mkdir -p "$DRONE_DIR"/{app,models,index,data/tiles}

# Create virtual environment with system site packages
# (needed to access system-installed TensorRT, OpenCV, etc.)
echo "[2/5] Creating Python virtual environment..."
python3 -m venv "$DRONE_DIR/venv" --system-site-packages

# Activate venv
source "$DRONE_DIR/venv/bin/activate"

# Upgrade pip
pip install --upgrade pip

# Install PyTorch (Jetson-specific wheel)
echo ""
echo "[3/5] Installing PyTorch for Jetson..."
echo ""
echo "PyTorch for Jetson requires a special wheel from NVIDIA."
echo "Check the latest URL at: https://forums.developer.nvidia.com/t/pytorch-for-jetson"
echo ""

# PyTorch 2.3.0 for JetPack 6.x (L4T R36.x)
TORCH_URL="https://nvidia.box.com/shared/static/mp164asf3ta01z39rfnqf1a8csz2z3di.whl"
TORCH_WHL="torch-2.3.0-cp310-cp310-linux_aarch64.whl"

echo "Downloading PyTorch 2.3.0 wheel..."
wget -q --show-progress -O "/tmp/$TORCH_WHL" "$TORCH_URL"
pip install "/tmp/$TORCH_WHL"
rm "/tmp/$TORCH_WHL"

# Verify PyTorch CUDA
echo ""
python3 -c "
import torch
print(f'PyTorch {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
"

# Install flight stack packages
echo ""
echo "[4/5] Installing flight stack packages..."
pip install \
    numpy \
    scipy \
    faiss-cpu \
    onnxruntime \
    pymavlink \
    mavsdk

# Verify installations
echo ""
echo "[5/5] Verifying installations..."
python3 -c "
packages = {
    'torch': 'PyTorch',
    'faiss': 'FAISS',
    'onnxruntime': 'ONNXRuntime',
    'pymavlink': 'pymavlink',
    'mavsdk': 'MAVSDK',
    'numpy': 'NumPy',
    'scipy': 'SciPy',
}
for module, name in packages.items():
    try:
        m = __import__(module)
        ver = getattr(m, '__version__', 'ok')
        print(f'  {name}: {ver}')
    except ImportError:
        print(f'  {name}: MISSING')
"

# Check TensorRT (from system packages)
python3 -c "
try:
    import tensorrt
    print(f'  TensorRT: {tensorrt.__version__}')
except ImportError:
    print('  TensorRT: not found (install python3-libnvinfer)')
"

echo ""
echo "=== Python Environment Ready ==="
echo "Activate with: source ~/drone/venv/bin/activate"
echo ""
echo "Directory structure:"
echo "  ~/drone/app/        — your mission code"
echo "  ~/drone/models/     — model weights (.onnx, .engine)"
echo "  ~/drone/index/      — FAISS index files"
echo "  ~/drone/data/tiles/ — satellite tile images"
echo "=== Done ==="
