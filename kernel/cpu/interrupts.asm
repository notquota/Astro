
bits 64

cpu_interrupts_initialize:
    cli
    ret

cpu_interrupts_disable:
    cli
    ret

cpu_interrupts_enabled:
    pushfq
    pop rax

    shr rax, 9
    and eax, 1
    ret