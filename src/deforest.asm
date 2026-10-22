default rel
global main

extern printf
extern fflush
extern tcgetattr
extern tcsetattr
extern malloc
extern realloc
extern rand
extern srand
extern time

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
extern wmove
extern waddch
extern mvwaddnwstr
extern getmaxx
extern getmaxy

; game assets
%include "src/dialog.inc"
%include "src/choices.inc"

%define TIOCGWINSZ 0x5413
%define ECHO 0x0008
%define ICANON 0x0002
%define TSANOW 0

%define TILE_EMPTY 0
%define TILE_TREE (1 << 0)
%define TILE_PROTESTOR (1 << 1)

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
    closeParenthesis db ')', 0

    Tree dd 0x2663, 0

    EmptyString db 0

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
    GameWindow resq 1

    CompanyName resb 33
    CompanyNameLength resd 1

    ChoiceCount resd 1
    ChoiceKeys resb 16
    ChoiceCallbacks resq 16

    PlayerX resd 1
    PlayerY resd 1

    %define MapSize 64 ; 64 x 64
    Map resb MapSize * MapSize
    MapRow resd MapSize + 1
    
    GameWindowHeight resd 1
    GameWindowWidth resd 1

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
%macro AddChoice 3
    mov edi, %1
    mov rsi, %2
    mov rdx, %3
    call addChoice
%endmacro
main:
    sub rsp, 8
    mov edi, 6 ; LC_ALL
    mov rsi, EmptyString
    call setlocale

    call initscr
    test rax, rax
    jz exit
    
    call cbreak
    call noecho

    mov rdi, [stdscr]
    mov esi, 1
    call keypad

    xor edi, edi
    call curs_set

    ; very random position to seed the random function
    xor edi, edi
    call time

    mov edi, eax
    call srand

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
    test rax, rax
    jz exit
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
    test rax, rax
    jz exit
    mov [DialogWindow], rax

    mov edi, [LINES]
    shr edi, 1
    dec edi
    mov esi, [COLS]
    sub esi, 2
    mov edx, 1
    mov ecx, 1
    mov [GameWindowHeight], edi
    mov [GameWindowWidth], esi
    call newwin
    test rax, rax
    jz exit
    mov [GameWindow], rax

    ; Generate a map
    xor r12d, r12d

    .loop:
        call rand
        and eax, 1

        mov [Map + r12], byte al

        inc r12
    cmp r12, (MapSize * MapSize)
    jb .loop

    mainloop:
        mov dword [ChoiceCount], 0
        call erase

        mov rdi, [ChoicesWindow]
        call werase

        mov rdi, [DialogWindow]
        call werase

        mov rdi, [GameWindow]
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
        mov rsi, Dialog.WelcomeDialog
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, Choices.CursorPrompt
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, CompanyName
        call waddstr

        jmp render

    tutorial2:
        mov rdi, [DialogWindow]
        mov rsi, Dialog.Tutorial2Dialog
        call waddstr

        AddChoice "1", Choices.Next, .next

        jmp render

        .next:
            mov [GameState], STATE_TUTORIAL3 
            ret
    
    tutorial3:
        mov rdi, [DialogWindow]
        mov rsi, Dialog.Tutorial3Dialog
        call waddstr

        AddChoice "1", Choices.Next, .next

        jmp render

        .next:
            mov [GameState], STATE_GAME
            ret

    game:
        call renderMap
        jmp render
    
    render:
        mov rdi, [stdscr]
        call wnoutrefresh

        mov rdi, [GameWindow]
        call wnoutrefresh

        mov rdi, [DialogWindow]
        call wnoutrefresh

        mov rdi, [ChoicesWindow]
        call wnoutrefresh

        call doupdate

        call getch

        cmp eax, 410 ; resize
        je resize

        cmp eax, 27
        je exit

        cmp dword [GameState], STATE_TUTORIAL1
        je tutorial1input

        mov edi, eax
        call handleChoice

    jmp mainloop

    renderMap:
        push rbx
        push r12
        push r13
        push r14
        push r15
        sub rsp, 16

        mov r12d, [GameWindowHeight]

        mov r13d, [GameWindowWidth]

        sub r12d, 2
        sub r13d, 2

        cmp r12d, MapSize
        jbe .height👍
        mov r12d, MapSize

        .height👍:
            cmp r13d, MapSize
            jbe .width👍
            mov r13d, MapSize

        .width👍:
            xor r14d, r14d

        .looprow:
            cmp r14d, r12d
            jae .done
            xor r15d, r15d
        
        .looptile:
            cmp r15d, r13d
            jae .drawRow

            mov eax, r14d
            shl eax, 6
            add eax, r15d

            mov rbx, Map
            movzx eax, byte [rbx + rax]

            mov edx, ' '
            test al, TILE_TREE
            jz .checkProtestor
            mov edx, 0x2663 ; tree

            .checkProtestor:
                test al, TILE_PROTESTOR
                jz .checkPlayer
                mov edx, 'P'

            .checkPlayer:
                cmp r15d, [PlayerX]
                jne .storeTile
                cmp r14d, [PlayerY]
                jne .storeTile
                mov edx, 'Y'

            .storeTile:
                mov rbx, MapRow
                mov [rbx + r15 * 4], edx

                inc r15d
                jmp .looptile

            .drawRow:
                mov rbx, MapRow
                mov dword [rbx + r15 * 4], 0

                mov rdi, [GameWindow]
                mov esi, [GameWindowHeight]
                sub esi, r12d
                shr esi, 1
                add esi, r14d
                mov edx, [GameWindowWidth]
                sub edx, r13d
                shr edx, 1
                mov rcx, rbx
                mov r8d, r13d
                call mvwaddnwstr

                inc r14d
                jmp .looprow

            .done:
                add rsp, 16
                pop r15
                pop r14
                pop r13
                pop r12
                pop rbx
                ret

    ; @param rdi keyboard key
    ; @param rsi *char choice label
    ; @param rdx *func callback function
    addChoice:
        mov eax, [ChoiceCount]
        cmp eax, 16
        jae .done

        mov rcx, ChoiceKeys
        mov [rcx+rax], dil

        mov rcx, ChoiceCallbacks
        mov [rcx + rax*8], rdx

        inc dword [ChoiceCount]

        push rdi
        push rsi
        sub rsp, 8

        mov rdi, [ChoicesWindow]
        movzx esi, byte [rsp + 16]
        call waddch

        mov rdi, [ChoicesWindow]
        mov esi, ')'
        call waddch

        mov rdi, [ChoicesWindow]
        mov esi, ' '
        call waddch

        mov rdi, [ChoicesWindow]
        mov rsi, [rsp + 8]
        call waddstr

        add rsp, 8
        pop rsi
        pop rdi

        .done:
            ret

    handleChoice:
        xor ecx, ecx
        mov edx, [ChoiceCount]

        mov r8, ChoiceKeys
        mov r9, ChoiceCallbacks

        .loop:
            cmp ecx, edx
            jae .done

            cmp dil, [r8 + rcx]
            je .execute

            inc ecx
            jmp .loop

        .execute:
            mov rax, [r9 + rcx * 8]
            jmp rax
        
        .done:
            ret

    tutorial1input:
        cmp eax, 10 ; enter
        je .submit

        cmp eax, 127 ; backspace
        je .backspace

        cmp eax, 263 ; backspace
        je .backspace

        ; check if keyboard
        cmp eax, ' '
        jb mainloop
        cmp eax, '~'
        ja mainloop

        mov ecx, [CompanyNameLength]
        cmp ecx, 32
        jae mainloop

        mov rdx, CompanyName
        mov [rdx + rcx], al

        inc ecx
        mov [CompanyNameLength], ecx
        mov byte [rdx + rcx], 0

        jmp mainloop

        .submit:
            cmp dword [CompanyNameLength], 0
            je mainloop

            mov dword [GameState], STATE_TUTORIAL2
            jmp mainloop

        .backspace:
            mov ecx, [CompanyNameLength]
            test ecx, ecx
            jz mainloop

            dec ecx
            mov [CompanyNameLength], ecx

            mov rdx, CompanyName
            mov byte [rdx + rcx], 0

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
        test rax, rax
        js exit ; the program bro 😭
        ; stupid name for an instruction tbh "js", "just"

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
        test rax, rax
        js exit

        mov rdi, [DialogWindow]
        mov esi, [LINES]
        shr esi, 1
        inc esi
        mov edx, [COLS]
        shr edx, 1
        inc edx
        call mvwin

        mov edi, [GameWindowHeight]
        mov rdi, [GameWindow]

        mov esi, [LINES]
        shr esi, 1
        dec esi

        mov edx, [COLS]
        sub edx, 2

        mov [GameWindowHeight], esi
        mov [GameWindowWidth], edx
        call wresize
        test rax, rax
        js exit

        mov rdi, [GameWindow]
        mov esi, 1
        mov edx, 1
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
        sub rsp, 8
        call endwin

        mov eax, 60
        xor edi, edi
        syscall
     