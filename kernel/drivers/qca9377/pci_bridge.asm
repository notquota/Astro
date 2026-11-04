bits 64

section .text

global qca9377_pci_read32

qca9377_pci_read32:
    push rdx

    mov eax, edi
    and eax, 0xFFFFFFFC
    or eax, 0x80000000

    mov dx, 0x0CF8
    out dx, eax

    mov dx, 0x0CFC
    in eax, dx

    pop rdx
    ret