#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/Astro

python3 - <<'PY'
from pathlib import Path

kernel = Path("build/mixed/kernel.bin")
original = Path("build/astro.img")

if not kernel.is_file():
    raise SystemExit("Mixed kernel not found")

if not original.is_file():
    raise SystemExit("Original boot image not found")

data = kernel.read_bytes()

if data[:8] != b"A5TR0KRN":
    raise SystemExit("Invalid kernel signature")

if len(data) > 65536:
    raise SystemExit("Kernel exceeds 64 KiB")

if original.stat().st_size != 1474560:
    raise SystemExit("Unexpected boot image size")

print("Mixed kernel verified")
print(f"Kernel size: {len(data)} bytes")
PY

mkdir -p build/mixed/iso

cp build/astro.img build/mixed/astro-test.img

dd if=/dev/zero \
    of=build/mixed/astro-test.img \
    bs=512 seek=18 count=128 \
    conv=notrunc status=none

dd if=build/mixed/kernel.bin \
    of=build/mixed/astro-test.img \
    bs=512 seek=18 \
    conv=notrunc status=none

cp build/mixed/astro-test.img build/mixed/iso/astro.img

xorriso -as mkisofs \
    -quiet \
    -o build/mixed/A5TR0-MIXED.iso \
    -b astro.img \
    -c boot.cat \
    build/mixed/iso

echo "Experimental ISO created:"
echo "build/mixed/A5TR0-MIXED.iso"