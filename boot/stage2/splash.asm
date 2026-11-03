bits 16

splash_start:
    call video_clear

    mov si, splash_astro
    mov dh, 11
    mov dl, 37
    mov cl, COLOR_WHITE
    call video_write

    mov cx, 14
    call timing_wait

    mov si, splash_glitch1
    mov dh, 11
    mov dl, 37
    mov cl, COLOR_PURPLE
    call video_write

    mov cx, 2
    call timing_wait

    mov si, splash_glitch2
    mov dh, 11
    mov dl, 37
    mov cl, COLOR_CYAN
    call video_write

    mov cx, 2
    call timing_wait

    mov si, splash_glitch3
    mov dh, 11
    mov dl, 37
    mov cl, COLOR_WHITE
    call video_write

    mov cx, 2
    call timing_wait

    mov si, splash_a5tr0
    mov dh, 11
    mov dl, 37
    mov cl, COLOR_CYAN
    call video_write

    mov cx, 24
    call timing_wait

    call video_clear
    call video_reset_cursor

    ret

splash_astro db "ASTRO", 0
splash_glitch1 db "A#TR0", 0
splash_glitch2 db "A5TR?", 0
splash_glitch3 db "ASTR0", 0
splash_a5tr0 db "A5TR0", 0