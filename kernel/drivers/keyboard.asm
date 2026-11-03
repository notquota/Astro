bits 64

keyboard_initialize:
    mov byte [keyboard_shift], 0
    mov byte [keyboard_extended], 0
    ret

keyboard_poll:
    in al, 0x64
    test al, 1
    jz .none

    in al, 0x60
    movzx r8d, al

    cmp r8b, 0xE0
    je .extended

    cmp r8b, 0xE1
    je .extended

    cmp byte [keyboard_extended], 0
    jne .clear_extended

    cmp r8b, 0x2A
    je .shift_on

    cmp r8b, 0x36
    je .shift_on

    cmp r8b, 0xAA
    je .shift_off

    cmp r8b, 0xB6
    je .shift_off

    test r8b, 0x80
    jnz .none

    cmp r8d, 58
    jae .none

    cmp byte [keyboard_shift], 0
    jne .upper

    lea rdx, [keyboard_normal]
    mov al, [rdx + r8]
    ret

.upper:
    lea rdx, [keyboard_upper]
    mov al, [rdx + r8]
    ret

.extended:
    mov byte [keyboard_extended], 1
    jmp .none

.clear_extended:
    mov byte [keyboard_extended], 0
    jmp .none

.shift_on:
    mov byte [keyboard_shift], 1
    jmp .none

.shift_off:
    mov byte [keyboard_shift], 0

.none:
    xor eax, eax
    ret

keyboard_wait:
.wait:
    call keyboard_poll
    test al, al
    jnz .done

    pause
    jmp .wait

.done:
    ret

keyboard_shift:
    db 0

keyboard_extended:
    db 0

keyboard_normal:
    db 0,27
    db "1234567890-="
    db 8,9
    db "qwertyuiop[]"
    db 13,0
    db "asdfghjkl;'`"
    db 0,92
    db "zxcvbnm,./"
    db 0,42,0,32

keyboard_upper:
    db 0,27
    db "!@#$%^&*()_+"
    db 8,9
    db "QWERTYUIOP{}"
    db 13,0
    db 'ASDFGHJKL:"~'
    db 0,124
    db "ZXCVBNM<>?"
    db 0,42,0,32