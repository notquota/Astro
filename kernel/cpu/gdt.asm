
bits 64

cpu_gdt_initialize:
    lgdt [cpu_gdtr]

    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    ret

align 16

cpu_gdt:
    dq 0x0000000000000000
    dq 0x00AF9A000000FFFF
    dq 0x00CF92000000FFFF

cpu_gdt_end:

cpu_gdtr:
    dw cpu_gdt_end - cpu_gdt - 1
    dq cpu_gdt