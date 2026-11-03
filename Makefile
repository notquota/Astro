
ASM = nasm
QEMU = qemu-system-x86_64

BUILD = build
IMAGE = $(BUILD)/astro.img
ISO = $(BUILD)/A5TR0.iso

KERNEL_SECTORS = 64
KERNEL_BYTES = 32768

BOOT_INCLUDES = $(wildcard boot/include/*.inc)
STAGE2_SOURCES = $(wildcard boot/stage2/*.asm)
KERNEL_SOURCES = $(shell find kernel -type f \( -name '*.asm' -o -name '*.inc' \))

.PHONY: all iso run clean

all: $(IMAGE)

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/boot.bin: boot/stage1/boot.asm $(BOOT_INCLUDES) | $(BUILD)
	$(ASM) -f bin -I ./ $< -o $@
	test $$(wc -c < $@) -eq 512

$(BUILD)/stage2.bin: boot/stage2/entry.asm $(STAGE2_SOURCES) $(BOOT_INCLUDES) | $(BUILD)
	$(ASM) -f bin -I ./ $< -o $@
	test $$(wc -c < $@) -le 8192
	truncate -s 8192 $@

$(BUILD)/data.bin: | $(BUILD)
	printf 'A5TR0-DISK-TEST\0' > $@
	truncate -s 512 $@

$(BUILD)/kernel.bin: $(KERNEL_SOURCES) | $(BUILD)
	$(ASM) -f bin -w+error -I ./ kernel/entry.asm -o $@
	test $$(wc -c < $@) -le $(KERNEL_BYTES)
	truncate -s $(KERNEL_BYTES) $@

$(IMAGE): $(BUILD)/boot.bin $(BUILD)/stage2.bin $(BUILD)/data.bin $(BUILD)/kernel.bin
	cat $(BUILD)/boot.bin $(BUILD)/stage2.bin $(BUILD)/data.bin $(BUILD)/kernel.bin > $@
	truncate -s 1474560 $@

iso: $(IMAGE)
	mkdir -p $(BUILD)/iso
	cp $(IMAGE) $(BUILD)/iso/astro.img
	xorriso -as mkisofs -o $(ISO) -b astro.img -c boot.cat $(BUILD)/iso

run: all
	$(QEMU) -drive format=raw,file=$(IMAGE),if=floppy -boot a -m 256M

clean:
	rm -rf $(BUILD)