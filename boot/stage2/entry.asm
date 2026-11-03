
bits 16
org 0x8000

%include "boot/include/boot.inc"
%include "boot/include/memory.inc"
%include "boot/include/gdt.inc"
%include "boot/include/kernel.inc"

stage2_entry:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    sti
    cld

    mov [boot_drive], dl

    call video_clear

    mov si, stage2_title
    call video_print

    mov si, stage2_start
    call video_print

    call disk_load_test
    jc stage2_disk_failure

    call disk_load_kernel
    jc stage2_disk_failure

    call disk_verify_kernel
    jc stage2_kernel_failure

    mov si, stage2_kernel_ok
    call video_print

    call memory_detect
    jc stage2_memory_failure

    mov si, stage2_memory_ok
    call video_print

    call a20_enable

    mov si, stage2_a20_ok
    call video_print

    call gdt_initialize
    jc stage2_gdt_failure

    mov si, stage2_gdt_ok
    call video_print

    cli

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp GDT_CODE_SELECTOR:protected_entry

stage2_disk_failure:
    mov si, stage2_disk_error
    jmp stage2_failure

stage2_kernel_failure:
    mov si, stage2_kernel_error
    jmp stage2_failure

stage2_memory_failure:
    mov si, stage2_memory_error
    jmp stage2_failure

stage2_gdt_failure:
    mov si, stage2_gdt_error
    jmp stage2_failure

stage2_failure:
    call video_print
    jmp stage2_halt

stage2_halt:
    cli

.loop:
    hlt
    jmp .loop

boot_drive:
    db 0

stage2_title:
    db "A5TR0 / B00T XV1.1.6", 13, 10, 0

stage2_start:
    db "[ BOOT ] Stage 2 initialized", 13, 10, 0

stage2_kernel_ok:
    db "[  OK  ] Kernel loaded", 13, 10, 0

stage2_memory_ok:
    db "[  OK  ] Memory detected", 13, 10, 0

stage2_a20_ok:
    db "[  OK  ] A20 enabled", 13, 10, 0

stage2_gdt_ok:
    db "[  OK  ] GDT initialized", 13, 10, 0

stage2_disk_error:
    db "[ FAIL ] Disk operation failed", 13, 10, 0

stage2_kernel_error:
    db "[ FAIL ] Kernel verification failed", 13, 10, 0

stage2_memory_error:
    db "[ FAIL ] Memory detection failed", 13, 10, 0

stage2_gdt_error:
    db "[ FAIL ] GDT initialization failed", 13, 10, 0

%include "boot/stage2/disk.asm"
%include "boot/stage2/video.asm"
%include "boot/stage2/memory.asm"
%include "boot/stage2/a20.asm"
%include "boot/stage2/gdt.asm"
%include "boot/stage2/protected.asm"
%include "boot/stage2/longmode.asm"

times 8192 - ($ - $$) db 0
