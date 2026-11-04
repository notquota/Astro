bits 64

network_initialize:
    call netdev_initialize
    call pci_network_scan
    call ipv4_initialize
    call arp_initialize
    call dhcp_initialize
    call icmp_initialize
    call tcp_initialize
    call dns_initialize
    call wf_initialize
    call wifi_initialize
    call pcnet_initialize
    ret

network_command:
    push rbx

    mov rbx, rdi

    mov rdi, rbx
    mov rsi, network_devices_name
    call fs_equal
    test eax, eax
    jnz .devices

    mov rdi, rbx
    mov rsi, network_status_name
    call fs_equal
    test eax, eax
    jnz .status

    mov rdi, rbx
    mov rsi, network_ip_name
    call fs_equal
    test eax, eax
    jnz .ip

    mov rdi, rbx
    mov rsi, network_dhcp_name
    call fs_equal
    test eax, eax
    jnz .dhcp

    mov rdi, rbx
    mov rsi, network_poll_name
    call fs_equal
    test eax, eax
    jnz .poll

    mov rdi, rbx
    mov rsi, network_tcp_name
    call fs_equal
    test eax, eax
    jnz .tcp

    mov rdi, rbx
    mov rsi, network_udp_name
    call fs_equal
    test eax, eax
    jnz .udp

    mov rsi, network_help_message
    call commands_print
    jmp .done

.devices:
    cmp byte [pci_ethernet_found], 1
    jne .no_device

    mov rsi, network_device_message
    call commands_print

    mov eax, [pci_ethernet_id]
    call commands_hex

    cmp byte [pcnet_ready], 1
    jne .driver_failed

    mov rsi, network_mac_message
    call shell_puts

    call network_print_mac
    jmp .done

.driver_failed:
    mov rsi, network_driver_error
    call commands_error

    mov eax, [pcnet_error]
    call commands_hex
    jmp .done

.status:
    cmp byte [pcnet_ready], 1
    jne .not_ready

    mov rsi, network_driver_ready
    call commands_print

    mov rsi, network_mac_message
    call shell_puts
    call network_print_mac

    mov rsi, network_dhcp_message
    call shell_puts

    movzx eax, byte [dhcp_state]
    call network_print_dhcp_state

    mov rsi, network_tcp_message
    call shell_puts

    mov rdi, tcp_command_status
    call tcp_command
    jmp .done

.ip:
    cmp byte [dhcp_state], 3
    jne .no_ip

    mov rsi, network_ip_address_message
    call shell_puts

    lea rdi, [ipv4_address]
    call network_print_ipv4

    mov rsi, network_mask_message
    call shell_puts

    lea rdi, [ipv4_netmask]
    call network_print_ipv4

    mov rsi, network_gateway_message
    call shell_puts

    lea rdi, [ipv4_gateway]
    call network_print_ipv4

    mov rsi, network_dns_message
    call shell_puts

    lea rdi, [ipv4_dns]
    call network_print_ipv4
    jmp .done

.dhcp:
    cmp byte [pcnet_ready], 1
    jne .not_ready

    call dhcp_start
    test eax, eax
    jz .dhcp_failed

    mov rsi, network_dhcp_started
    call commands_print
    jmp .done

.poll:
    call pcnet_poll
    call icmp_poll
    call dns_poll
    call tcp_poll
    call wf_poll
    call wifi_manager_poll

    mov rsi, network_dhcp_message
    call shell_puts

    movzx eax, byte [dhcp_state]
    call network_print_dhcp_state
    jmp .done

.tcp:
    mov rdi, tcp_command_status
    call tcp_command
    jmp .done

.udp:
    mov rsi, network_udp_message
    call commands_print
    jmp .done

.no_device:
    mov rsi, network_no_device
    call commands_error
    jmp .done

.not_ready:
    mov rsi, network_not_ready
    call commands_error
    jmp .done

.no_ip:
    mov rsi, network_no_ip
    call commands_error
    jmp .done

.dhcp_failed:
    mov rsi, network_dhcp_failed
    call commands_error

.done:
    pop rbx
    ret

wlan_command:
    jmp wifi_command

network_prefix:
.compare:
    mov al, [rsi]
    test al, al
    jz .boundary

    cmp al, [rdi]
    jne .failed

    inc rsi
    inc rdi
    jmp .compare

.boundary:
    cmp byte [rdi], 0
    je .matched

    cmp byte [rdi], ' '
    je .matched

.failed:
    xor eax, eax
    ret

.matched:
    mov eax, 1
    ret

network_print_mac:
    lea rdi, [pcnet_mac]
    jmp network_print_mac_at

network_print_mac_at:
    push rbx
    push r12
    push r13

    mov r12, rdi
    xor r13d, r13d

.next:
    movzx ebx, byte [r12 + r13]

    mov eax, ebx
    shr eax, 4

    lea rdx, [network_hex_chars]
    mov al, [rdx + rax]
    call shell_putc

    mov eax, ebx
    and eax, 15

    lea rdx, [network_hex_chars]
    mov al, [rdx + rax]
    call shell_putc

    inc r13d
    cmp r13d, 6
    jae .done

    mov al, ':'
    call shell_putc
    jmp .next

.done:
    call shell_newline

    pop r13
    pop r12
    pop rbx
    ret

network_print_ipv4:
    push r12
    push r13

    mov r12, rdi
    xor r13d, r13d

.next:
    movzx eax, byte [r12 + r13]
    call network_print_decimal

    inc r13d
    cmp r13d, 4
    jae .done

    mov al, '.'
    call shell_putc
    jmp .next

.done:
    call shell_newline

    pop r13
    pop r12
    ret

network_print_decimal:
    push rbx
    push rdx
    push r8
    push r9
    push r10
    push r11

    xor edx, edx
    mov ebx, 100
    div ebx

    mov r8d, eax
    mov r9d, edx

    test r8d, r8d
    jz .tens

    add al, '0'
    call shell_putc

.tens:
    mov eax, r9d
    xor edx, edx
    mov ebx, 10
    div ebx

    mov r10d, eax
    mov r11d, edx

    test r8d, r8d
    jnz .print_tens

    test r10d, r10d
    jz .units

.print_tens:
    mov eax, r10d
    add al, '0'
    call shell_putc

.units:
    mov eax, r11d
    add al, '0'
    call shell_putc

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rbx
    ret

network_print_dhcp_state:
    cmp eax, 0
    je .idle

    cmp eax, 1
    je .discover

    cmp eax, 2
    je .request

    cmp eax, 3
    je .bound

    mov rsi, network_state_error
    jmp commands_error

.idle:
    mov rsi, network_state_idle
    jmp commands_print

.discover:
    mov rsi, network_state_discover
    jmp commands_print

.request:
    mov rsi, network_state_request
    jmp commands_print

.bound:
    mov rsi, network_state_bound
    jmp commands_print

network_hex_chars:
    db "0123456789ABCDEF"

network_devices_name:
    db "devices", 0

network_status_name:
    db "status", 0

network_ip_name:
    db "ip", 0

network_dhcp_name:
    db "dhcp", 0

network_poll_name:
    db "poll", 0

network_tcp_name:
    db "tcp", 0

network_udp_name:
    db "udp", 0

network_help_message:
    db "net devices | status | dhcp | poll | ip | tcp | udp", 0

network_device_message:
    db "PCI network device ID:", 0

network_mac_message:
    db "MAC: ", 0

network_driver_ready:
    db "PCnet driver initialized.", 0

network_driver_error:
    db "PCnet initialization failed. Error code:", 0

network_no_device:
    db "No PCI Ethernet controller detected.", 0

network_not_ready:
    db "PCnet controller is not ready.", 0

network_ip_address_message:
    db "IPv4: ", 0

network_mask_message:
    db "Mask: ", 0

network_gateway_message:
    db "Gateway: ", 0

network_dns_message:
    db "DNS: ", 0

network_no_ip:
    db "No DHCP lease acquired.", 0

network_dhcp_message:
    db "DHCP: ", 0

network_tcp_message:
    db "TCP: ", 0

network_dhcp_started:
    db "DHCP discovery sent. Use net status or net ip.", 0

network_dhcp_failed:
    db "Could not send DHCP discovery.", 0

network_udp_message:
    db "UDP supports DHCP and DNS queries.", 0

network_state_idle:
    db "Not started", 0

network_state_discover:
    db "Waiting for offer", 0

network_state_request:
    db "Waiting for acknowledgement", 0

network_state_bound:
    db "IPv4 lease acquired", 0

network_state_error:
    db "Error", 0