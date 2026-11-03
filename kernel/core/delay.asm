bits 64

kernel_rtc_seconds:
.wait:
    mov al, 0x0A
    out 0x70, al
    in al, 0x71

    test al, 0x80
    jnz .wait

    xor eax, eax
    out 0x70, al
    in al, 0x71

    ret

kernel_wait_three_seconds:
    push rbx
    push rcx

    call kernel_rtc_seconds
    mov bl, al
    mov ecx, 3

.wait:
    call kernel_rtc_seconds

    cmp al, bl
    je .pause

    mov bl, al
    dec ecx
    jz .done

.pause:
    pause
    jmp .wait

.done:
    pop rcx
    pop rbx
    ret