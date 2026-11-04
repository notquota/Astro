#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/mixed

nasm -f elf64 -I ./ \
    kernel/entry.asm \
    -o build/mixed/entry.o

nasm -f elf64 \
    kernel/drivers/qca9377/pci_bridge.asm \
    -o build/mixed/pci_bridge.o

gcc \
    -std=c11 \
    -O2 \
    -ffreestanding \
    -fno-builtin \
    -fno-stack-protector \
    -fno-pic \
    -fno-pie \
    -fno-asynchronous-unwind-tables \
    -fno-unwind-tables \
    -m64 \
    -mno-red-zone \
    -mgeneral-regs-only \
    -Wall \
    -Wextra \
    -Werror \
    -c kernel/drivers/qca9377/qca9377.c \
    -o build/mixed/qca9377.o

ld \
    -m elf_x86_64 \
    -nostdlib \
    --build-id=none \
    -T kernel/linker.ld \
    -o build/mixed/kernel.elf \
    build/mixed/entry.o \
    build/mixed/pci_bridge.o \
    build/mixed/qca9377.o

objcopy \
    -O binary \
    build/mixed/kernel.elf \
    build/mixed/kernel.bin

python3 - <<'PY'
from pathlib import Path

path = Path("build/mixed/kernel.bin")
data = path.read_bytes()

if data[:8] != b"A5TR0KRN":
    raise SystemExit("ERROR: Invalid A5TR0 kernel signature")

if len(data) > 65536:
    raise SystemExit("ERROR: Kernel binary exceeds 64 KiB")

print("A5TR0 mixed kernel build succeeded")
print(f"Kernel bytes: {len(data)}")
print("Signature: A5TR0KRN")
print("Load address: 0x20000")
print("Entry address: 0x20008")
PY

nm build/mixed/kernel.elf | grep -E \
    'kernel_entry|qca9377_probe_pci|qca9377_pci_read32'