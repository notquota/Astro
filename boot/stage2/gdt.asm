bits 16

gdt_initialize:
    lgdt [gdt_descriptor]
    clc
    ret

align 8

gdt_start:
    dq 0x0000000000000000

gdt_code32:
    dq 0x00CF9A000000FFFF

gdt_data:
    dq 0x00CF92000000FFFF

gdt_code64:
    dq 0x00AF9A000000FFFF

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start