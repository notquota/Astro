bits 64

%macro CPU_EXCEPTION_NOERR 1
cpu_exception_%1:
    push 0
    push %1
    jmp cpu_exception_common
%endmacro

%macro CPU_EXCEPTION_ERR 1
cpu_exception_%1:
    push %1
    jmp cpu_exception_common
%endmacro

CPU_EXCEPTION_NOERR 0
CPU_EXCEPTION_NOERR 1
CPU_EXCEPTION_NOERR 2
CPU_EXCEPTION_NOERR 3
CPU_EXCEPTION_NOERR 4
CPU_EXCEPTION_NOERR 5
CPU_EXCEPTION_NOERR 6
CPU_EXCEPTION_NOERR 7
CPU_EXCEPTION_ERR 8
CPU_EXCEPTION_NOERR 9
CPU_EXCEPTION_ERR 10
CPU_EXCEPTION_ERR 11
CPU_EXCEPTION_ERR 12
CPU_EXCEPTION_ERR 13
CPU_EXCEPTION_ERR 14
CPU_EXCEPTION_NOERR 15
CPU_EXCEPTION_NOERR 16
CPU_EXCEPTION_ERR 17
CPU_EXCEPTION_NOERR 18
CPU_EXCEPTION_NOERR 19
CPU_EXCEPTION_NOERR 20
CPU_EXCEPTION_ERR 21
CPU_EXCEPTION_NOERR 22
CPU_EXCEPTION_NOERR 23
CPU_EXCEPTION_NOERR 24
CPU_EXCEPTION_NOERR 25
CPU_EXCEPTION_NOERR 26
CPU_EXCEPTION_NOERR 27
CPU_EXCEPTION_NOERR 28
CPU_EXCEPTION_ERR 29
CPU_EXCEPTION_ERR 30
CPU_EXCEPTION_NOERR 31

cpu_exception_common:
    cli
    cld

    mov word [0xB8F10], 0x4F58

.halt:
    hlt
    jmp .halt

align 8

cpu_exception_table:
    dq cpu_exception_0
    dq cpu_exception_1
    dq cpu_exception_2
    dq cpu_exception_3
    dq cpu_exception_4
    dq cpu_exception_5
    dq cpu_exception_6
    dq cpu_exception_7
    dq cpu_exception_8
    dq cpu_exception_9
    dq cpu_exception_10
    dq cpu_exception_11
    dq cpu_exception_12
    dq cpu_exception_13
    dq cpu_exception_14
    dq cpu_exception_15
    dq cpu_exception_16
    dq cpu_exception_17
    dq cpu_exception_18
    dq cpu_exception_19
    dq cpu_exception_20
    dq cpu_exception_21
    dq cpu_exception_22
    dq cpu_exception_23
    dq cpu_exception_24
    dq cpu_exception_25
    dq cpu_exception_26
    dq cpu_exception_27
    dq cpu_exception_28
    dq cpu_exception_29
    dq cpu_exception_30
    dq cpu_exception_31