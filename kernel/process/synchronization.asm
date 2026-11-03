
bits 64

synchronization_lock:
    mov eax, 1

.try:
    xchg eax, [rdi]
    test eax, eax
    jz .acquired

    pause
    mov eax, 1
    jmp .try

.acquired:
    ret

synchronization_unlock:
    mov dword [rdi], 0
    ret

synchronization_trylock:
    mov eax, 1
    xchg eax, [rdi]
    test eax, eax
    sete al
    movzx eax, al
    ret
