bits 16

%define VGA_SEGMENT  0xB800
%define VGA_COLUMNS  80
%define VGA_ROWS     25
%define VGA_CELLS    2000

video_clear:
    push ax
    push cx
    push di
    push es

    mov ax, VGA_SEGMENT
    mov es, ax

    xor di, di
    mov ax, 0x0720
    mov cx, VGA_CELLS
    rep stosw

    mov word [video_offset], 0

    pop es
    pop di
    pop cx
    pop ax
    ret

video_print:
    push ax
    push si

.next:
    lodsb
    test al, al
    jz .done

    call video_putc
    jmp .next

.done:
    pop si
    pop ax
    ret

video_putc:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    cmp al, 13
    je .done

    cmp al, 10
    je .newline

    mov bx, VGA_SEGMENT
    mov es, bx

    mov di, [video_offset]

    cmp di, VGA_CELLS * 2
    jb .write

    call video_scroll
    mov di, [video_offset]

.write:
    mov ah, [video_color]
    mov [es:di], ax

    add word [video_offset], 2
    jmp .done

.newline:
    mov ax, [video_offset]
    mov bx, VGA_COLUMNS * 2
    xor dx, dx
    div bx
    inc ax
    mul bx

    mov [video_offset], ax

    cmp ax, VGA_CELLS * 2
    jb .done

    call video_scroll

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

video_scroll:
    push ax
    push cx
    push si
    push di
    push ds
    push es

    mov ax, VGA_SEGMENT
    mov ds, ax
    mov es, ax

    mov si, VGA_COLUMNS * 2
    xor di, di
    mov cx, VGA_COLUMNS * (VGA_ROWS - 1)
    cld
    rep movsw

    mov ax, 0x0720
    mov cx, VGA_COLUMNS
    rep stosw

    mov word [cs:video_offset], (VGA_ROWS - 1) * VGA_COLUMNS * 2

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret

video_set_color:
    mov [video_color], al
    ret

video_hex_digit:
    and al, 0x0F
    cmp al, 9
    jbe .number
    add al, 7

.number:
    add al, '0'
    ret

video_hex32:
    pushad

    mov ebx, eax
    mov cx, 8

.next:
    mov eax, ebx
    shr eax, 28

    call video_hex_digit
    call video_putc

    shl ebx, 4
    loop .next

    popad
    ret

video_hex64:
    push eax
    push edx

    mov eax, edx
    call video_hex32

    pop edx
    pop eax

    call video_hex32
    ret

video_offset dw 0
video_color db 0x07