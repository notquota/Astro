bits 64

%define WIFI_DOWN 0
%define WIFI_SCANNING 1
%define WIFI_CONNECTING 2
%define WIFI_CONNECTED 3
%define WIFI_DISCONNECTING 4
%define WIFI_ERROR 5

wifi_manager_initialize:
    mov byte [wifi_manager_state], WIFI_DOWN
    mov byte [wifi_manager_driver_present], 0
    mov byte [wifi_manager_ssid], 0

    mov qword [wifi_manager_scan_fn], 0
    mov qword [wifi_manager_connect_fn], 0
    mov qword [wifi_manager_disconnect_fn], 0
    mov qword [wifi_manager_poll_fn], 0
    mov qword [wifi_manager_send_fn], 0
    ret

wifi_manager_register:
    test rdi, rdi
    jz .failed

    test rsi, rsi
    jz .failed

    test rdx, rdx
    jz .failed

    test rcx, rcx
    jz .failed

    test r8, r8
    jz .failed

    mov [wifi_manager_scan_fn], rdi
    mov [wifi_manager_connect_fn], rsi
    mov [wifi_manager_disconnect_fn], rdx
    mov [wifi_manager_poll_fn], rcx
    mov [wifi_manager_send_fn], r8

    mov byte [wifi_manager_driver_present], 1
    mov byte [wifi_manager_state], WIFI_DOWN

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

wifi_manager_scan:
    cmp byte [wifi_manager_driver_present], 1
    jne .failed

    cmp byte [wifi_manager_state], WIFI_DOWN
    je .start

    cmp byte [wifi_manager_state], WIFI_ERROR
    jne .failed

.start:
    mov byte [wifi_manager_state], WIFI_SCANNING

    call qword [wifi_manager_scan_fn]

    test eax, eax
    jz .error

    mov eax, 1
    ret

.error:
    mov byte [wifi_manager_state], WIFI_ERROR

.failed:
    xor eax, eax
    ret

wifi_manager_connect:
    push r12

    mov r12, rdi

    cmp byte [wifi_manager_driver_present], 1
    jne .failed

    cmp byte [wifi_manager_state], WIFI_DOWN
    je .validate

    cmp byte [wifi_manager_state], WIFI_ERROR
    jne .failed

.validate:
    test r12, r12
    jz .failed

    xor ecx, ecx

.check:
    mov al, [r12 + rcx]

    test al, al
    jz .valid

    cmp ecx, 32
    jae .failed

    cmp al, 32
    jb .failed

    cmp al, 126
    ja .failed

    inc ecx
    jmp .check

.valid:
    test ecx, ecx
    jz .failed

    mov rdi, wifi_manager_ssid
    mov rsi, r12

.copy:
    mov al, [rsi]
    mov [rdi], al

    test al, al
    jz .begin

    inc rdi
    inc rsi
    jmp .copy

.begin:
    mov byte [wifi_manager_state], WIFI_CONNECTING

    mov rdi, wifi_manager_ssid
    call qword [wifi_manager_connect_fn]

    test eax, eax
    jz .error

    mov eax, 1
    jmp .done

.error:
    mov byte [wifi_manager_state], WIFI_ERROR

.failed:
    xor eax, eax

.done:
    pop r12
    ret

wifi_manager_disconnect:
    cmp byte [wifi_manager_driver_present], 1
    jne .failed

    cmp byte [wifi_manager_state], WIFI_CONNECTED
    je .begin

    cmp byte [wifi_manager_state], WIFI_CONNECTING
    jne .failed

.begin:
    mov byte [wifi_manager_state], WIFI_DISCONNECTING

    call qword [wifi_manager_disconnect_fn]

    test eax, eax
    jz .error

    mov eax, 1
    ret

.error:
    mov byte [wifi_manager_state], WIFI_ERROR

.failed:
    xor eax, eax
    ret

wifi_manager_poll:
    cmp byte [wifi_manager_driver_present], 1
    jne .done

    call qword [wifi_manager_poll_fn]

.done:
    ret

wifi_manager_report_scan_complete:
    cmp byte [wifi_manager_state], WIFI_SCANNING
    jne .done

    mov byte [wifi_manager_state], WIFI_DOWN

.done:
    ret

wifi_manager_report_connected:
    cmp byte [wifi_manager_driver_present], 1
    jne .done

    cmp byte [wifi_manager_state], WIFI_CONNECTING
    jne .done

    mov byte [wifi_manager_state], WIFI_CONNECTED

.done:
    ret

wifi_manager_report_disconnected:
    mov byte [wifi_manager_state], WIFI_DOWN
    ret

wifi_manager_report_error:
    mov byte [wifi_manager_state], WIFI_ERROR
    ret

wifi_manager_send_frame:
    cmp byte [wifi_manager_driver_present], 1
    jne .failed

    cmp byte [wifi_manager_state], WIFI_CONNECTED
    jne .failed

    test rdi, rdi
    jz .failed

    cmp rsi, 14
    jb .failed

    cmp rsi, 1514
    ja .failed

    call qword [wifi_manager_send_fn]
    ret

.failed:
    xor eax, eax
    ret

wifi_manager_status:
    cmp byte [wifi_manager_driver_present], 1
    jne .no_driver

    mov rsi, wifi_manager_driver_ready
    call commands_print

    movzx eax, byte [wifi_manager_state]

    cmp eax, WIFI_DOWN
    je .down

    cmp eax, WIFI_SCANNING
    je .scanning

    cmp eax, WIFI_CONNECTING
    je .connecting

    cmp eax, WIFI_CONNECTED
    je .connected

    cmp eax, WIFI_DISCONNECTING
    je .disconnecting

    mov rsi, wifi_manager_error
    jmp commands_error

.down:
    mov rsi, wifi_manager_down
    jmp commands_print

.scanning:
    mov rsi, wifi_manager_scanning
    jmp commands_print

.connecting:
    mov rsi, wifi_manager_connecting
    jmp commands_print

.connected:
    mov rsi, wifi_manager_connected
    jmp commands_print

.disconnecting:
    mov rsi, wifi_manager_disconnecting
    jmp commands_print

.no_driver:
    mov rsi, wifi_manager_no_driver
    jmp commands_print

wifi_manager_state:
    db WIFI_DOWN

wifi_manager_driver_present:
    db 0

align 8

wifi_manager_scan_fn:
    dq 0

wifi_manager_connect_fn:
    dq 0

wifi_manager_disconnect_fn:
    dq 0

wifi_manager_poll_fn:
    dq 0

wifi_manager_send_fn:
    dq 0

wifi_manager_ssid:
    times 33 db 0

wifi_manager_no_driver:
    db "No native Wi-Fi driver registered.", 0

wifi_manager_driver_ready:
    db "Native Wi-Fi driver registered.", 0

wifi_manager_down:
    db "Wi-Fi disconnected.", 0

wifi_manager_scanning:
    db "Wi-Fi scan in progress.", 0

wifi_manager_connecting:
    db "Wi-Fi association in progress.", 0

wifi_manager_connected:
    db "Wi-Fi link established.", 0

wifi_manager_disconnecting:
    db "Wi-Fi disconnecting.", 0

wifi_manager_error:
    db "Wi-Fi operation failed.", 0