bits 16

timing_wait_tick:
    push ax
    push bx
    push cx
    push dx

    mov ah, 0x00
    int 0x1A

    mov bx, dx

.wait:
    mov ah, 0x00
    int 0x1A

    cmp dx, bx
    je .wait

    pop dx
    pop cx
    pop bx
    pop ax
    ret

timing_wait:
    push cx

.loop:
    test cx, cx
    jz .done

    call timing_wait_tick
    dec cx
    jmp .loop

.done:
    pop cx
    ret