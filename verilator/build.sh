#!/usr/bin/env bash
set -euo pipefail

# Build the lpu_sot_top verilator model and the C++ harness.
# Run from repository root or this directory.

VERILATOR=$(which verilator || true)
if [ -z "$VERILATOR" ]; then
  echo "verilator not found. Install via 'brew install verilator' on macOS or your package manager."
  exit 1
fi

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)

RTL_DIR="$ROOT/rtl"
MAIN_CPP="$HERE/main.cpp"

BUILD_DIR="$ROOT/build/verilator"
mkdir -p "$BUILD_DIR"

echo "Running verilator..."
verilator --cc -std=gnu++17 --unrelated-errors -Wall --trace \
  --top-module lpu_sot_top \
  -I$RTL_DIR $RTL_DIR/*.sv --exe $MAIN_CPP

echo "Building C++ model..."
make -C obj_dir -j -f Vlpu_sot_top.mk Vlpu_sot_top

echo "Copying executable to build directory"
cp obj_dir/Vlpu_sot_top $BUILD_DIR/

echo "Build complete. Run with: $BUILD_DIR/Vlpu_sot_top"

