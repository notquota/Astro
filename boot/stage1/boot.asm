bits 16
org 0x7C00

%include "boot/include/boot.inc"

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BOOT_STACK
    cld
    sti

    mov [boot_drive], dl

    mov ax, 0x0003
    int 0x10

    mov si, boot_message
    call print

    xor ax, ax
    mov es, ax
    mov bx, STAGE2_ADDR

    mov ah, 0x02
    mov al, STAGE2_SECTORS
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]

    int 0x13
    jc disk_error

    cmp al, STAGE2_SECTORS
    jne disk_error

    mov dl, [boot_drive]
    jmp 0x0000:STAGE2_ADDR

disk_error:
    mov si, error_message
    call print

halt:
    cli
.halt:
    hlt
    jmp .halt

print:
    push ax
    push bx
    push si

.next:
    lodsb
    test al, al
    jz .done

    mov ah, 0x0E
    xor bx, bx
    int 0x10
    jmp .next

.done:
    pop si
    pop bx
    pop ax
    ret

boot_drive db 0

boot_message db "ASTRO / BIOS BOOT", 13, 10, 0
error_message db "BOOT ERROR: STAGE2 READ FAILED", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55