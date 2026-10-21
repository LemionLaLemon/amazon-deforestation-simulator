default rel
global main

extern printf
extern fflush
extern tcgetattr
extern tcsetattr
extern malloc
extern realloc

; ncurses
extern initscr
extern cbreak
extern noecho
extern keypad
extern curs_set
extern stdscr
extern endwin
extern erase
extern refresh
extern getch
extern mvaddch
extern stdscr
extern box
extern LINES
extern COLS
extern timeout
extern mvaddwstr
extern setlocale
extern mvhline
extern mvvline
extern acs_map
extern newwin
extern delwin
extern wresize
extern mvwin
extern waddstr
extern wrefresh
extern werase
extern wnoutrefresh
extern wnoutrefresh
extern doupdate

; game assets
%include "src/dialog.inc"

%define TIOCGWINSZ 0x5413
%define ECHO 0x0008
%define ICANON 0x0002
%define TSANOW 0

section .data
    ; magical ANSI incantations
    CursorMove:
        db 27, '[%d;%dH', 0
        .len equ $ - CursorMove - 1
    CursorHide:
        db 27, '[?25l', 0
        .len equ $ - CursorHide  - 1
    CursorShow:
        db 27, '[?25h', 0
        .len equ $ - CursorShow - 1
    CursorHome:
        db 27, '[H', 0
        .len equ $ - CursorHome - 1
    ClearScreen:
        db 27, '[2J', 0
        .len equ $ - ClearScreen - 1
    EnterAlternateScreen:
        db 27, '[?1049h', 0
        .len equ $ - EnterAlternateScreen - 1
    ExitAlternateScreen:
        db 27, '[?1049l', 0
        .len equ $ - ExitAlternateScreen - 1
    BlackScreen:
        db 27, '[40m', 0
        .len equ $ - BlackScreen - 1
    WhiteScreen:
        db 27, '[47m', 0
        .len equ $ - WhiteScreen - 1
    ResetBackground:
        db 27, '[49m', 0
        .len equ $ - ResetBackground - 1
    space db ' ', 0

    Tree dd 0x2663, 0

    EmptyString db 0
    CursorPrompt db 10, "Name> ", 0

    ChoiceQuit db "0) Quit the game", 0

    ; Error messages
    FailedToAllocateMemory db "Failed to allocate memory of size %d bytes", 0

    ; Game states
    %define STATE_TUTORIAL1 0
    %define STATE_TUTORIAL2 1
    %define STATE_TUTORIAL3 2
    %define STATE_GAME 3

    GameState dd STATE_TUTORIAL1
section .bss
    Window:
        .rows resw 1
        .cols resw 1
        .xpixel resw 1
        .ypixel resw 1

    Key resd 1

    OriginalTermios resb 60
    GameTermios resb 60

    ChoicesWindow resq 1
    DialogWindow resq 1

    CompanyName resb 33
    CompanyNameLength resd 1

section .text
%macro Cprintf 0
    xor eax, eax
    call printf
%endmacro
%macro WriteString 1
    mov eax, 1
    mov edi, 1
    lea rsi, [%1]
    mov edx, %1.len
    syscall
%endmacro
main:
    mov edi, 6 ; LC_ALL
    mov rsi, EmptyString
    call setlocale

    sub rsp, 8
    call initscr
    call cbreak
    call noecho

    mov rdi, [stdscr]
    mov esi, 1
    call keypad

    xor edi, edi
    call curs_set

    mov edi, 100
    call timeout

    ; Windows
    mov edi, [LINES]
    shr edi, 1
    sub edi, 2
    mov esi, [COLS]
    shr esi, 1
    sub esi, 2
    mov edx, [LINES]
    shr edx, 1
    inc edx
    mov ecx, 1
    call newwin
    mov [ChoicesWindow], rax

    mov edi, [LINES]
    mov eax, edi
    shr eax, 1
    sub edi, eax
    sub edi, 2
    mov esi, [COLS]
    mov eax, esi
    shr eax, 1
    sub esi, eax
    sub esi, 2
    mov edx, [LINES]
    shr edx, 1
    inc edx
    mov ecx, [COLS]
    shr ecx, 1
    inc ecx
    call newwin
    mov [DialogWindow], rax

    mainloop:
        call erase

        mov rdi, [ChoicesWindow]
        call werase

        mov rdi, [DialogWindow]
        call werase

        call draw3Regions

        ; temporary tree
        mov eax, [LINES]
        shr eax, 2
        mov edi, eax

        mov eax, [COLS]
        shr eax, 1
        mov esi, eax

        mov rdx, Tree
        call mvaddwstr

        mov eax, [GameState]
        cmp eax, STATE_TUTORIAL1
        je tutorial1
        cmp eax, STATE_TUTORIAL2
        je tutorial2
        cmp eax, STATE_TUTORIAL3
        je tutorial3
        cmp eax, STATE_GAME
        je game

        jmp render

    jmp mainloop

    tutorial1:
        mov rdi, [DialogWindow]
        mov rsi, WelcomeDialog
        call waddstr

        jmp render

    tutorial2:
        mov rdi, [ChoicesWindow]
        call werase

        mov rdi, [ChoicesWindow]
        mov rsi, ChoiceQuit
        call waddstr

        jmp render
    
    tutorial3:
        jmp render

    game:
        jmp render
    
    render:
        mov rdi, [stdscr]
        call wnoutrefresh

        mov rdi, [DialogWindow]
        call wnoutrefresh

        mov rdi, [ChoicesWindow]
        call wnoutrefresh

        call doupdate

        call getch

        cmp eax, 410 ; resize
        je resize

        cmp eax, "0"
        je exit

    jmp mainloop

    resize:
        mov esi, [LINES]
        mov eax, esi
        shr eax, 1
        sub esi, eax
        sub esi, 2

        mov edx, [COLS]
        shr edx, 1
        dec edx

        mov rdi, [ChoicesWindow]
        call wresize

        mov rdi, [ChoicesWindow]
        mov esi, [LINES]
        shr esi, 1
        inc esi
        mov edx, 1
        call mvwin

        mov rdi, [DialogWindow]
        mov esi, [LINES]
        mov eax, esi
        shr eax, 1
        sub esi, eax
        sub esi, 2
        mov edx, [COLS]
        mov eax, edx
        shr eax, 1
        sub edx, eax
        sub edx, 2
        call wresize

        mov rdi, [DialogWindow]
        mov esi, [LINES]
        shr esi, 1
        inc esi
        mov edx, [COLS]
        shr edx, 1
        inc edx
        call mvwin

    jmp mainloop    

    draw3Regions:
        sub rsp, 8

        call draw1Region

        mov edi, [LINES]
        shr edi, 1
        mov esi, 1
        xor edx, edx
        mov ecx, [COLS]
        sub ecx, 2
        call mvhline

        mov edi, [LINES]
        shr edi, 1
        inc edi
        mov esi, [COLS]
        shr esi, 1
        xor edx, edx
        mov ecx, [LINES]
        shr ecx, 1
        dec ecx
        call mvvline

        mov edi, [LINES]
        shr edi, 1
        xor esi, esi
        mov edx, [acs_map + "t"*4]
        call mvaddch

        mov edi, [LINES]
        shr edi, 1
        mov esi, [COLS]
        dec esi
        mov edx, [acs_map + "u"*4]
        call mvaddch

        mov edi, [LINES]
        shr edi, 1
        mov esi, [COLS]
        shr esi, 1
        mov edx, [acs_map + "w"*4]
        call mvaddch

        mov edi, [LINES]
        dec edi
        mov esi, [COLS]
        shr esi, 1
        mov edx, [acs_map + "v"*4]
        call mvaddch

        add rsp, 8
        ret

    draw1Region:
        sub rsp, 8

        mov rdi, [stdscr]
        xor esi, esi
        xor edx, edx
        call box

        add rsp, 8
        ret

    getWindowSize:
        mov eax, 16
        mov edi, 1
        mov esi, TIOCGWINSZ
        lea rdx, Window
        syscall
        ret

        .exit:
            WriteString BlackScreen

            add rsp, 8
            ret

    exit:
        call endwin
        xor eax, eax
        add rsp, 8
        ret
     