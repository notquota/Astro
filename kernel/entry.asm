
bits 64
org 0x20000

%include "kernel/include/bootinfo.inc"
%include "kernel/include/core.inc"

kernel_header:
    db "A5TR0KRN"

kernel_entry:
    cli
    cld

    mov rsp, KERNEL_STACK_ADDRESS
    mov rbp, rsp

    call kernel_initialize
    jc kernel_panic_boot

    call kernel_runtime_initialize
    jc kernel_runtime_failure

    call kernel_main

kernel_halt:
    cli

.loop:
    hlt
    jmp .loop

%include "kernel/core/init.asm"
%include "kernel/core/console.asm"
%include "kernel/core/panic.asm"
%include "kernel/core/status.asm"
%include "kernel/core/runtime.asm"

%include "kernel/cpu/gdt.asm"
%include "kernel/cpu/idt.asm"
%include "kernel/cpu/exceptions.asm"
%include "kernel/cpu/interrupts.asm"
%include "kernel/cpu/syscall.asm"

%include "kernel/memory/e820.asm"
%include "kernel/memory/physical.asm"
%include "kernel/memory/virtual.asm"
%include "kernel/memory/paging.asm"
%include "kernel/memory/heap.asm"

%include "kernel/process/process.asm"
%include "kernel/process/thread.asm"
%include "kernel/process/scheduler.asm"
%include "kernel/process/context.asm"
%include "kernel/process/synchronization.asm"

%include "kernel/services/registry.asm"
%include "kernel/services/events.asm"
%include "kernel/services/ipc.asm"

%include "kernel/debug/console.asm"
%include "kernel/debug/diagnostics.asm"
%include "kernel/debug/selftest.asm"

%include "kernel/core/subsystems.asm"
%include "kernel/core/delay.asm"
%include "kernel/drivers/keyboard.asm"
%include "kernel/filesystem/ramfs.asm"
%include "kernel/shell/shell.asm"
%include "kernel/shell/commands.asm"
%include "kernel/main.asm"