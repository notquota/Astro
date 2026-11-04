OUTPUT_FORMAT("elf64-x86-64")
OUTPUT_ARCH(i386:x86-64")
ENTRY(kernel_entry)

SECTIONS
{
    . = 0x20000;
    __kernel_start = .;

    .text : ALIGN(16)
    {
        KEEP(build/kernel-obj/entry.o(.text))
        *(.text)
        *(.text.*)
    }

    .rodata : ALIGN(16)
    {
        *(.rodata)
        *(.rodata.*)
    }

    .data : ALIGN(16)
    {
        *(.data)
        *(.data.*)
    }

    .bss (NOLOAD) : ALIGN(16)
    {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        __bss_end = .;
    }

    __kernel_end = .;

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame)
        *(.eh_frame.*)
        *(.gnu*)
    }
}

ASSERT(__kernel_start == 0x20000, "Invalid kernel address")
ASSERT(__kernel_end <= 0x30000, "Kernel exceeds 64 KiB")