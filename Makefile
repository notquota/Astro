NASM := nasm
CC := gcc
LD := ld
OBJCOPY := objcopy

BUILD := build
OBJ := $(BUILD)/kernel-obj

IMAGE := $(BUILD)/astro.img
ISO := $(BUILD)/A5TR0.iso

KERNEL_SECTORS := 128
KERNEL_BYTES := 65536

BOOT_SOURCES := $(shell find boot -type f)
KERNEL_ASM_SOURCES := $(shell find kernel -type f \( -name '*.asm' -o -name '*.inc' \))
KERNEL_C_SOURCES := $(wildcard kernel/drivers/qca9377/*.c)

CFLAGS := -std=c11 -O2 -ffreestanding -fno-builtin -fno-stack-protector -fno-pic -fno-pie -fno-asynchronous-unwind-tables -fno-unwind-tables -m64 -mno-red-zone -mgeneral-regs-only -Wall -Wextra -Werror

C_OBJECTS := $(patsubst kernel/drivers/qca9377/%.c,$(OBJ)/%.o,$(KERNEL_C_SOURCES))

.PHONY: all iso clean size run

all: $(IMAGE)

$(BUILD):
	mkdir -p $(BUILD)

$(OBJ):
	mkdir -p $(OBJ)

$(BUILD)/boot.bin: $(BOOT_SOURCES) | $(BUILD)
	$(NASM) -f bin -I ./ boot/stage1/boot.asm -o $@
	test $$(wc -c < $@) -eq 512

$(BUILD)/stage2.bin: $(BOOT_SOURCES) | $(BUILD)
	$(NASM) -f bin -I ./ boot/stage2/entry.asm -o $@
	test $$(wc -c < $@) -le 8192
	truncate -s 8192 $@

$(BUILD)/data.bin: | $(BUILD)
	printf 'A5TR0-DISK-TEST\0' > $@
	truncate -s 512 $@

$(OBJ)/entry.o: $(KERNEL_ASM_SOURCES) | $(OBJ)
	$(NASM) -f elf64 -I ./ kernel/entry.asm -o $@

$(OBJ)/pci_bridge.o: kernel/drivers/qca9377/pci_bridge.asm | $(OBJ)
	$(NASM) -f elf64 $< -o $@

$(OBJ)/%.o: kernel/drivers/qca9377/%.c kernel/drivers/qca9377/qca9377.h | $(OBJ)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/kernel.elf: $(OBJ)/entry.o $(OBJ)/pci_bridge.o $(C_OBJECTS) kernel/linker.ld | $(BUILD)
	$(LD) -m elf_x86_64 -nostdlib --build-id=none -T kernel/linker.ld -o $@ $(OBJ)/entry.o $(OBJ)/pci_bridge.o $(C_OBJECTS)

$(BUILD)/kernel.bin: $(BUILD)/kernel.elf
	$(OBJCOPY) -O binary $< $@
	python3 -c 'from pathlib import Path; p=Path("$@"); d=p.read_bytes(); assert d[:8] == b"A5TR0KRN", "Invalid kernel signature"; assert len(d) <= $(KERNEL_BYTES), "Kernel too large"'
	truncate -s $(KERNEL_BYTES) $@

$(IMAGE): $(BUILD)/boot.bin $(BUILD)/stage2.bin $(BUILD)/data.bin $(BUILD)/kernel.bin
	dd if=/dev/zero of=$@ bs=512 count=2880 status=none
	dd if=$(BUILD)/boot.bin of=$@ bs=512 seek=0 conv=notrunc status=none
	dd if=$(BUILD)/stage2.bin of=$@ bs=512 seek=1 conv=notrunc status=none
	dd if=$(BUILD)/data.bin of=$@ bs=512 seek=17 conv=notrunc status=none
	dd if=$(BUILD)/kernel.bin of=$@ bs=512 seek=18 conv=notrunc status=none

iso: $(ISO)

$(ISO): $(IMAGE)
	mkdir -p $(BUILD)/iso
	cp $(IMAGE) $(BUILD)/iso/astro.img
	xorriso -as mkisofs -quiet -o $@ -b astro.img -c boot.cat $(BUILD)/iso

size: $(IMAGE)
	wc -c $(BUILD)/boot.bin $(BUILD)/stage2.bin $(BUILD)/kernel.bin $(IMAGE)

run: $(IMAGE)
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE),if=floppy -boot a -m 256M

clean:
	rm -rf $(BUILD)