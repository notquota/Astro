bits 64

%ifidn __OUTPUT_FORMAT__,bin
org 0x20000
%else
section .text
global kernel_header
global kernel_entry
extern __bss_start
extern __bss_end
%endif

%include "kernel/include/bootinfo.inc"
%include "kernel/include/core.inc"

kernel_header:
    db "A5TR0KRN"

kernel_entry:
    cli
    cld

    mov rsp, KERNEL_STACK_ADDRESS
    mov rbp, rsp

%ifidn __OUTPUT_FORMAT__,elf64
    lea rdi, [rel __bss_start]
    lea rcx, [rel __bss_end]
    sub rcx, rdi
    xor eax, eax
    rep stosb
%endif

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
%include "kernel/core/delay.asm"

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

%include "kernel/drivers/keyboard.asm"
%include "kernel/drivers/pci.asm"
%include "kernel/drivers/pcnet.asm"
%include "kernel/drivers/wifi_pci.asm"
%include "kernel/drivers/qca9377.asm"
%include "kernel/drivers/qca9377/cprobe.asm"
%include "kernel/drivers/wifi.asm"

%include "kernel/filesystem/ramfs.asm"

%include "kernel/network/netdev.asm"
%include "kernel/network/ethernet.asm"
%include "kernel/network/arp.asm"
%include "kernel/network/ipv4.asm"
%include "kernel/network/icmp.asm"
%include "kernel/network/dhcp.asm"
%include "kernel/network/tcp.asm"
%include "kernel/network/dns.asm"
%include "kernel/network/wf.asm"
%include "kernel/network/wifi_manager.asm"
%include "kernel/network/terminal.asm"

%include "kernel/shell/shell.asm"
%include "kernel/shell/commands.asm"

%include "kernel/main.asm"