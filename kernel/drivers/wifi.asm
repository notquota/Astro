bits 64

wifi_initialize:
    call wifi_pci_initialize
    call wifi_manager_initialize
    call qca9377_initialize
    ret

wifi_command:
    push rbx

    mov rbx, rdi

    mov rdi, rbx
    mov rsi, wifi_command_status
    call fs_equal

    test eax, eax
    jnz .status

    mov rdi, rbx
    mov rsi, wifi_command_devices
    call fs_equal

    test eax, eax
    jnz .devices

    mov rdi, rbx
    mov rsi, wifi_command_scan
    call fs_equal

    test eax, eax
    jnz .scan

    mov rdi, rbx
    mov rsi, wifi_command_connect
    call network_prefix

    test eax, eax
    jnz .connect

    mov rdi, rbx
    mov rsi, wifi_command_disconnect
    call fs_equal

    test eax, eax
    jnz .disconnect

    mov rsi, wifi_command_help
    call commands_print
    jmp .done

.status:
    call wifi_pci_scan
    call wifi_manager_status
    jmp .done

.devices:
    call wifi_pci_list
    call qca9377_status

%ifidn __OUTPUT_FORMAT__,elf64
    call qca9377_cprobe_status
%endif

    jmp .done

.scan:
    call wifi_manager_scan

    test eax, eax
    jz .failed

    mov rsi, wifi_command_scan_started
    call commands_print
    jmp .done

.connect:
    cmp byte [rbx + 7], ' '
    jne .usage

    lea rdi, [rbx + 8]

    cmp byte [rdi], 0
    je .usage

    call wifi_manager_connect

    test eax, eax
    jz .failed

    mov rsi, wifi_command_connect_started
    call commands_print
    jmp .done

.disconnect:
    call wifi_manager_disconnect

    test eax, eax
    jz .failed

    mov rsi, wifi_command_disconnect_started
    call commands_print
    jmp .done

.failed:
    cmp byte [wifi_manager_driver_present], 1
    jne .no_driver

    mov rsi, wifi_command_failed
    call commands_error
    jmp .done

.no_driver:
    mov rsi, wifi_command_no_driver
    call commands_error
    jmp .done

.usage:
    mov rsi, wifi_command_connect_usage
    call commands_error

.done:
    pop rbx
    ret

wifi_command_status:
    db "status", 0

wifi_command_devices:
    db "devices", 0

wifi_command_scan:
    db "scan", 0

wifi_command_connect:
    db "connect", 0

wifi_command_disconnect:
    db "disconnect", 0

wifi_command_help:
    db "wlan status | devices | scan | connect <ssid> | disconnect", 0

wifi_command_connect_usage:
    db "Usage: wlan connect <ssid>", 0

wifi_command_scan_started:
    db "Wi-Fi scan requested.", 0

wifi_command_connect_started:
    db "Wi-Fi connection requested.", 0

wifi_command_disconnect_started:
    db "Wi-Fi disconnection requested.", 0

wifi_command_no_driver:
    db "No Wi-Fi driver available for this adapter.", 0

wifi_command_failed:
    db "Wi-Fi operation rejected or unavailable.", 0