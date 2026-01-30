#!/bin/bash

# Build and deploy firmware to RP2040 Pico

set -e  # Exit on error

echo "Building firmware..."
zig build

echo "Copying firmware to Pico..."
cp zig-out/firmware/blinky.uf2 /Volumes/RPI-RP2/

echo "✓ Firmware deployed successfully!"
