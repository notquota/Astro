bits 64

commands_dispatch:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi

.find_end:
    mov al, [rdi]
    test al, al
    jz .no_arg

    cmp al, ' '
    je .split

    inc rdi
    jmp .find_end

.split:
    mov byte [rdi], 0
    inc rdi

.skip:
    cmp byte [rdi], ' '
    jne .arg_ready

    inc rdi
    jmp .skip

.arg_ready:
    mov r13, rdi
    jmp .dispatch

.no_arg:
    mov r13, rdi

.dispatch:
    mov rsi, cmd_help
    call commands_match
    test eax, eax
    jnz .help

    mov rsi, cmd_version
    call commands_match
    test eax, eax
    jnz .version

    mov rsi, cmd_status
    call commands_match
    test eax, eax
    jnz .status

    mov rsi, cmd_mem
    call commands_match
    test eax, eax
    jnz .mem

    mov rsi, cmd_ps
    call commands_match
    test eax, eax
    jnz .ps

    mov rsi, cmd_services
    call commands_match
    test eax, eax
    jnz .services

    mov rsi, cmd_ls
    call commands_match
    test eax, eax
    jnz .ls

    mov rsi, cmd_cd
    call commands_match
    test eax, eax
    jnz .cd

    mov rsi, cmd_mkdir
    call commands_match
    test eax, eax
    jnz .mkdir

    mov rsi, cmd_touch
    call commands_match
    test eax, eax
    jnz .touch

    mov rsi, cmd_cat
    call commands_match
    test eax, eax
    jnz .cat

    mov rsi, cmd_type
    call commands_match
    test eax, eax
    jnz .type

    mov rsi, cmd_net
    call commands_match
    test eax, eax
    jnz .net

    mov rsi, cmd_wlan
    call commands_match
    test eax, eax
    jnz .wlan

    mov rsi, cmd_ping
    call commands_match
    test eax, eax
    jnz .ping

    mov rsi, cmd_arp
    call commands_match
    test eax, eax
    jnz .arp

    mov rsi, cmd_tcp
    call commands_match
    test eax, eax
    jnz .tcp

    mov rsi, cmd_nslookup
    call commands_match
    test eax, eax
    jnz .nslookup

    mov rsi, cmd_wf
    call commands_match
    test eax, eax
    jnz .wf

    mov rsi, msg_unknown
    call commands_error
    jmp .done

.help:
    mov rsi, msg_help1
    call commands_print

    mov rsi, msg_help2
    call commands_print

    mov rsi, msg_help3
    call commands_print

    mov rsi, msg_help_network
    call commands_print

    mov rsi, msg_help_ping
    call commands_print

    mov rsi, msg_help_tcp
    call commands_print

    mov rsi, msg_help_web
    call commands_print

    mov rsi, msg_help_wifi
    call commands_print
    jmp .done

.version:
    mov rsi, msg_version
    call commands_print
    jmp .done

.status:
    mov rsi, msg_status
    call commands_print

    call kernel_status_get
    call commands_hex
    jmp .done

.mem:
    mov rsi, msg_mem
    call commands_print
    jmp .done

.ps:
    mov rsi, msg_ps
    call commands_print
    jmp .done

.services:
    mov rsi, msg_services
    call commands_print
    jmp .done

.ls:
    xor r14d, r14d
    xor r12d, r12d

.list_next:
    cmp r12d, FS_MAX_ENTRIES
    jae .list_done

    mov rax, r12
    shl rax, 5

    lea rbx, [fs_entries + rax]

    cmp byte [rbx], 1
    jne .list_skip

    mov al, [fs_cwd]
    cmp byte [rbx + 2], al
    jne .list_skip

    lea rsi, [rbx + 4]
    call commands_print

    inc r14d

.list_skip:
    inc r12d
    jmp .list_next

.list_done:
    test r14d, r14d
    jnz .done

    mov rsi, msg_empty
    call commands_print
    jmp .done

.cd:
    cmp byte [r13], 0
    je .missing_arg

    mov rdi, r13
    mov rsi, cmd_home
    call fs_equal
    test eax, eax
    jnz .cd_home

    mov rdi, r13
    mov rsi, cmd_root
    call fs_equal
    test eax, eax
    jnz .cd_root

    mov rdi, r13
    mov rsi, cmd_parent
    call fs_equal
    test eax, eax
    jnz .cd_parent

    mov rdi, r13
    call fs_lookup

    test rax, rax
    jz .not_found

    mov rdi, rax
    call fs_change_dir

    test eax, eax
    jz .not_directory

    mov rsi, msg_directory_changed
    call commands_print
    jmp .done

.cd_home:
    mov byte [fs_cwd], 0
    mov byte [shell_testing_mode], 1

    mov rsi, msg_testing_enabled
    call commands_print
    jmp .done

.cd_root:
    mov byte [fs_cwd], 0
    mov byte [shell_testing_mode], 0

    mov rsi, msg_directory_changed
    call commands_print
    jmp .done

.cd_parent:
    movzx edi, byte [fs_cwd]
    test edi, edi
    jz .cd_parent_done

    call fs_get
    test rax, rax
    jz .cd_parent_done

    mov al, [rax + 2]
    mov [fs_cwd], al

.cd_parent_done:
    mov rsi, msg_directory_changed
    call commands_print
    jmp .done

.mkdir:
    cmp byte [r13], 0
    je .missing_arg

    mov rdi, r13
    mov esi, FS_TYPE_DIR
    call fs_create

    test rax, rax
    jz .create_failed

    mov rsi, msg_created
    call commands_print
    jmp .done

.touch:
    cmp byte [r13], 0
    je .missing_arg

    mov rdi, r13
    call fs_lookup

    test rax, rax
    jnz .touch_existing

    mov rdi, r13
    mov esi, FS_TYPE_FILE
    call fs_create

    test rax, rax
    jz .create_failed

    jmp .touch_done

.touch_existing:
    mov rdi, rax
    call fs_get

    test rax, rax
    jz .not_found

    cmp byte [rax + 1], FS_TYPE_FILE
    jne .not_file

.touch_done:
    mov rsi, msg_created
    call commands_print
    jmp .done

.cat:
    cmp byte [r13], 0
    je .missing_arg

    mov rdi, r13
    call fs_lookup

    test rax, rax
    jz .not_found

    mov rdi, rax
    call fs_read

    test rax, rax
    jz .not_file

    mov rsi, rax
    call commands_print
    jmp .done

.type:
    cmp byte [r13], 0
    je .missing_arg

    mov rdi, r13
    call fs_lookup

    test rax, rax
    jnz .type_found

    mov rdi, r13
    mov esi, FS_TYPE_FILE
    call fs_create

    test rax, rax
    jz .create_failed

.type_found:
    mov r14, rax

    mov rdi, r14
    call fs_read

    test rax, rax
    jz .not_file

    mov rsi, msg_editor
    call commands_print

    mov rsi, msg_editor_prompt
    call shell_puts

    lea rdi, [shell_line]
    call shell_readline

    mov rdi, r14
    lea rsi, [shell_line]
    call fs_write

    test eax, eax
    jz .create_failed

    mov rsi, msg_saved
    call commands_print
    jmp .done

.net:
    cmp byte [shell_testing_mode], 1
    jne .testing_required

    mov rdi, r13
    call network_command
    jmp .done

.wlan:
    cmp byte [shell_testing_mode], 1
    jne .testing_required

    mov rdi, r13
    call wifi_command
    jmp .done

.ping:
    cmp byte [shell_testing_mode], 1
    jne .testing_required

    cmp byte [r13], 0
    je .missing_arg

    mov rdi, r13
    call icmp_start

    test eax, eax
    jz .ping_failed

    mov rsi, msg_ping_started
    call commands_print
    jmp .done

.ping_failed:
    mov rsi, msg_ping_failed
    call commands_error
    jmp .done

.arp:
    cmp byte [shell_testing_mode], 1
    jne .testing_required

    mov rdi, r13
    mov rsi, cmd_show
    call fs_equal

    test eax, eax
    jz .arp_usage

    cmp byte [arp_found], 1
    jne .arp_empty

    mov rsi, msg_arp_found
    call commands_print

    mov rsi, msg_arp_mac
    call shell_puts

    lea rdi, [arp_peer_mac]
    call network_print_mac_at
    jmp .done

.arp_empty:
    mov rsi, msg_arp_empty
    call commands_print
    jmp .done

.arp_usage:
    mov rsi, msg_arp_usage
    call commands_error
    jmp .done

.tcp:
    cmp byte [shell_testing_mode], 1
    jne .testing_required

    mov rdi, r13
    call tcp_command
    jmp .done

.nslookup:
    cmp byte [shell_testing_mode], 1
    jne .testing_required

    cmp byte [r13], 0
    je .missing_arg

    mov rdi, r13
    call dns_start

    test eax, eax
    jz .dns_failed

    mov rsi, msg_dns_started
    call commands_print
    jmp .done

.wf:
    cmp byte [shell_testing_mode], 1
    jne .testing_required

    cmp byte [r13], 0
    je .missing_arg

    mov rdi, r13
    call wf_start

    test eax, eax
    jz .wf_failed

    mov rsi, msg_wf_started
    call commands_print
    jmp .done

.dns_failed:
    mov rsi, msg_dns_failed
    call commands_error
    jmp .done

.wf_failed:
    mov rsi, msg_wf_failed
    call commands_error
    jmp .done

.testing_required:
    mov rsi, msg_testing_required
    call commands_error
    jmp .done

.missing_arg:
    mov rsi, msg_missing
    call commands_error
    jmp .done

.not_found:
    mov rsi, msg_not_found
    call commands_error
    jmp .done

.not_file:
    mov rsi, msg_not_file
    call commands_error
    jmp .done

.not_directory:
    mov rsi, msg_not_directory
    call commands_error
    jmp .done

.create_failed:
    mov rsi, msg_create_failed
    call commands_error

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

commands_match:
    push rdi

    mov rdi, r12
    call fs_equal

    pop rdi
    ret

commands_print:
    mov byte [shell_color], 0x0F
    call shell_puts
    call shell_newline
    ret

commands_error:
    mov byte [shell_color], 0x0C
    call shell_puts
    call shell_newline
    ret

commands_hex:
    push rax
    push rcx
    push rdx
    push rbx
    push r8

    mov byte [shell_color], 0x0E
    mov rbx, rax
    mov ecx, 16

.next:
    mov rdx, rbx
    shr rdx, 60

    lea r8, [cmd_hex_digits]
    mov al, [r8 + rdx]
    call shell_putc

    shl rbx, 4
    dec ecx
    jnz .next

    call shell_newline

    pop r8
    pop rbx
    pop rdx
    pop rcx
    pop rax
    ret

cmd_hex_digits:
    db "0123456789ABCDEF"

cmd_help:
    db "help", 0

cmd_version:
    db "version", 0

cmd_status:
    db "status", 0

cmd_mem:
    db "mem", 0

cmd_ps:
    db "ps", 0

cmd_services:
    db "services", 0

cmd_ls:
    db "ls", 0

cmd_cd:
    db "cd", 0

cmd_mkdir:
    db "mkdir", 0

cmd_touch:
    db "touch", 0

cmd_cat:
    db "cat", 0

cmd_type:
    db "type", 0

cmd_net:
    db "net", 0

cmd_wlan:
    db "wlan", 0

cmd_ping:
    db "ping", 0

cmd_arp:
    db "arp", 0

cmd_tcp:
    db "tcp", 0

cmd_nslookup:
    db "nslookup", 0

cmd_wf:
    db "wf", 0

cmd_show:
    db "show", 0

cmd_home:
    db "~", 0

cmd_root:
    db "/", 0

cmd_parent:
    db "..", 0

msg_help1:
    db "help version status mem ps services", 0

msg_help2:
    db "ls cd mkdir touch cat type", 0

msg_help3:
    db "type <file> opens the text editor.", 0

msg_help_network:
    db "Testing: cd ~ | net devices | net dhcp | net ip", 0

msg_help_ping:
    db "Testing: arp show | ping <gateway-ip>", 0

msg_help_tcp:
    db "Testing: tcp connect <ip> [port] | tcp fetch <ip> <host>", 0

msg_help_web:
    db "Testing: nslookup <host> | wf <host>", 0

msg_help_wifi:
    db "Testing: wlan status | devices | scan | connect | disconnect", 0

msg_version:
    db "A5TR0 KERNEL / SHELL ALPHA", 0

msg_status:
    db "KERNEL STATUS FLAGS:", 0

msg_mem:
    db "FRAME POOL: 16 PAGES / HEAP: 4096 BYTES", 0

msg_ps:
    db "PROCESS TABLE: 8 SLOTS", 0

msg_services:
    db "SERVICE REGISTRY: 16 SLOTS", 0

msg_unknown:
    db "Unknown command. Type help.", 0

msg_missing:
    db "Missing command argument.", 0

msg_not_found:
    db "File or directory not found.", 0

msg_not_file:
    db "Target is not a file.", 0

msg_not_directory:
    db "Target is not a directory.", 0

msg_create_failed:
    db "Could not create file or directory.", 0

msg_created:
    db "Operation completed.", 0

msg_directory_changed:
    db "Directory changed.", 0

msg_testing_enabled:
    db "Testing terminal enabled.", 0

msg_empty:
    db "Directory is empty.", 0

msg_editor:
    db "Enter one line of text. Press Enter to save.", 0

msg_editor_prompt:
    db "text> ", 0

msg_saved:
    db "File saved.", 0

msg_testing_required:
    db "Enter the testing terminal with cd ~.", 0

msg_ping_started:
    db "Resolving gateway MAC and sending ICMP request.", 0

msg_ping_failed:
    db "Ping failed. Only the configured gateway is supported.", 0

msg_arp_found:
    db "Gateway ARP entry resolved.", 0

msg_arp_mac:
    db "Gateway MAC: ", 0

msg_arp_empty:
    db "No resolved ARP entry.", 0

msg_arp_usage:
    db "Usage: arp show", 0

msg_dns_started:
    db "DNS lookup started.", 0

msg_dns_failed:
    db "Could not start DNS lookup.", 0

msg_wf_started:
    db "Resolving hostname for HTTP fetch...", 0

msg_wf_failed:
    db "Could not start web fetch.", 0