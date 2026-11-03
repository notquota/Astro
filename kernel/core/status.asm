
bits 64

%define KSTATUS_GDT 1
%define KSTATUS_IDT 2
%define KSTATUS_CPU 4
%define KSTATUS_SUBSYSTEMS 8

kernel_status_initialize:
    mov qword [kernel_status_flags], 0
    ret

kernel_status_mark:
    or qword [kernel_status_flags], rdi
    ret

kernel_status_has:
    mov rax, [kernel_status_flags]
    and rax, rdi
    cmp rax, rdi
    sete al
    movzx eax, al
    ret

kernel_status_get:
    mov rax, [kernel_status_flags]
    ret

kernel_status_flags:
    dq 0