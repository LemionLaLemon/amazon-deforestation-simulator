default rel
global main

extern printf
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
extern wresize
extern mvwin
extern waddstr
extern werase
extern wnoutrefresh
extern wnoutrefresh
extern doupdate
extern waddch
extern mvwaddnwstr
extern wprintw
extern mvwaddstr

; game assets
%include "src/dialog.inc"
%include "src/choices.inc"

%define TIOCGWINSZ 0x5413
%define ECHO 0x0008

%define TILE_EMPTY 0
%define TILE_TREE (1 << 0)
%define TILE_PROTESTOR (1 << 1)
%define TILE_SHACK (1 << 2)
%define TILE_SHACK_ENTRY (1 << 3)

%define PAIR_TREE 1
%define PAIR_GROUND 2
%define PAIR_PLAYER 3
%define ATTR_COLOR_PAIR(n) ((n) << 8)

section .data
    ; magical ANSI incantations
    BlackScreen:
        db 27, '[40m', 0
        .len equ $ - BlackScreen - 1

    IntegerFormat db "%u", 0

    Tree dd 0x2663, 0

    EmptyString db 0

    ; Error messages
    FailedToAllocateMemory db "Failed to allocate memory of size %d bytes", 0

    ; Game states
    %define STATE_TUTORIAL1 0
    %define STATE_TUTORIAL2 1
    %define STATE_TUTORIAL3 2
    %define STATE_GAME 3
    %define STATE_TREE_SELECTION 4
    %define STATE_DAY_REPORT 5
    %define STATE_DAY_LEGAL_LETTER 6
    %define STATE_LETTER_SHREDDING 7
    %define STATE_LAWYER_RESPONSE 8
    %define STATE_GAME_OVER 9
    %define STATE_GAME_FINISHED 10

    GameState dd STATE_TUTORIAL1

    Shack:
        db '  _______  '
        db ' /  LOG  \ '
        db '/__SHACK__\'
        db ' |       | '
        db ' |   _   | '
        db ' |  | |  | '
    %define ShackX 20
    %define ShackY 23
    %define ShackW 11
    %define ShackH 6
    %define ShackEntryX (ShackX + 5)
    %define ShackEntryY (ShackY + ShackH - 1)

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

    DialogWindowHeight resd 1

    %define TurnsPerDay 100
    DayTurnCount resd 1
    Day resd 1

    ; global statistics
    TreesTotal resd 1
    TreesChopped resd 1
    ; day statistics
    DayTreesChopped resd 1
    TreesInventory resd 1
    TimesBribed resd 1 ; also used for bribe amount calculation
    BribeSuccess resb 1 ; bool and day tracker

    CameraX resd 1
    CameraY resd 1

    LegalLetterY resd 1
    LawyerAggression resd 1

    Money resd 1 ; player would be too broke to require a 64 bit int anyways

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
    ; ncurses setup
    sub rsp, 8
    mov edi, 6 ; LC_ALL
    mov rsi, EmptyString
    call setlocale

    call initscr
    test rax, rax
    jz exit
    
    call cbreak
    call noecho ; stuff inputs dont print to terminal

    mov rdi, [stdscr]
    mov esi, 1
    call keypad

    xor edi, edi
    call curs_set ; hide cursor

    ; very random position to seed the random function
    xor edi, edi
    call time

    mov edi, eax
    call srand

    mov edi, 100
    call timeout

    ; Make new windows
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
    mov [DialogWindowHeight], edi
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

        test eax, eax
        jz .notTree

        inc dword [TreesTotal]
        mov [Map + r12], byte al

        .notTree:
        inc r12
    cmp r12, (MapSize * MapSize)
    jb .loop

    ; clear 31, 31
    mov byte [Map + 31 * MapSize + 31], TILE_EMPTY

    push r12 ; Y counter
    push r13; X counter

    mov r12d, ShackY

    .shackLoopY:
        mov r13d, ShackX

        .shackLoopX:
            mov eax, r12d
            shl eax, 6
            add eax, r13d

            test byte [Map + rax], TILE_TREE
            jz .shackNotTree

            dec dword [TreesTotal]

            .shackNotTree:
                mov byte [Map + rax], TILE_SHACK
                
                inc r13d
                cmp r13d, ShackX + ShackW
                jb .shackLoopX

        inc r12d
        cmp r12d, ShackY + ShackH
        jb .shackLoopY

    pop r13
    pop r12

    mov eax, ShackEntryY
    shl eax, 6
    add eax, ShackEntryX

    mov byte [Map + rax], TILE_SHACK_ENTRY

    ; initial player position
    mov dword [PlayerX], 31
    mov dword [PlayerY], 31

    ; initialize the day turn count so the player can even do anything
    mov dword [DayTurnCount], TurnsPerDay
    mov dword [Day], 1

    ; main program loop
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

        cmp [DayTurnCount], 0
        jnz .dayNotOver
        mov [GameState], STATE_DAY_REPORT

        .dayNotOver:
            mov eax, [GameState]
            cmp eax, STATE_TUTORIAL1
            je tutorial1
            cmp eax, STATE_TUTORIAL2
            je tutorial2
            cmp eax, STATE_TUTORIAL3
            je tutorial3
            cmp eax, STATE_GAME
            je game
            cmp eax, STATE_TREE_SELECTION
            je treeSelection
            cmp eax, STATE_DAY_REPORT
            je dayReport
            cmp eax, STATE_DAY_LEGAL_LETTER
            je dayLegalLetter
            cmp eax, STATE_LETTER_SHREDDING
            je letterShredding
            cmp eax, STATE_LAWYER_RESPONSE
            je lawyerResponse
            cmp eax, STATE_GAME_OVER
            je gameOver
            cmp eax, STATE_GAME_FINISHED
            je gameComplete

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
        ; Day X\n
        mov rdi, [DialogWindow]
        mov rsi, Dialog.Day
        call waddstr

        mov rdi, [DialogWindow]
        mov rsi, IntegerFormat
        mov edx, [Day]
        xor eax, eax
        call wprintw

        mov rdi, [DialogWindow]
        mov esi, 10
        call waddch

        ; X/Y turns remaining this day, 10, 0
        mov rdi, [DialogWindow]
        mov rsi, IntegerFormat
        mov edx, [DayTurnCount]
        xor eax, eax
        call wprintw

        mov rdi, [DialogWindow]
        mov rsi, Dialog.TurnsRemaining
        call waddstr

        mov rdi, [DialogWindow]
        mov rsi, Dialog.Money
        call waddstr

        mov rdi, [DialogWindow]
        mov rsi, IntegerFormat
        mov edx, [Money]
        xor eax, eax
        call wprintw

        call IfNearTree
        test eax, eax
        jz .notNearTree

        AddChoice "1", Choices.ChopTree, treeRoutine

        .notNearTree:
            call IfNearShackEntry
            test eax, eax
            jz .notNearShackEntry

            AddChoice "2", Choices.SellWood, .sellWood

            mov eax, [TreesInventory]
            imul eax, 100
            mov rdi, [ChoicesWindow]
            mov rsi, IntegerFormat
            mov edx, eax
            xor eax, eax
            call wprintw

            mov rdi, [ChoicesWindow]
            mov esi, ")"
            call waddch

        .notNearShackEntry:
            call renderMap
            jmp render


    .sellWood:
        mov eax, [TreesInventory]
        imul eax, 100
        add [Money], eax
        mov dword [TreesInventory], 0

        ret

    gameComplete:
        mov rdi, [DialogWindow]
        mov rsi, Dialog.GameComplete
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, Dialog.GameStats
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, Dialog.TreesChopped
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, IntegerFormat
        mov edx, [TreesChopped]
        xor eax, eax
        call wprintw

        mov rdi, [ChoicesWindow]
        mov esi, "/"
        call waddch

        mov rdi, [ChoicesWindow]
        mov rsi, IntegerFormat
        mov edx, [TreesTotal]
        xor eax, eax
        call wprintw

        mov rdi, [ChoicesWindow]
        mov esi, 10
        call waddch

        mov rdi, [ChoicesWindow]
        mov rsi, Dialog.Money
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, IntegerFormat
        mov edx, [Money]
        call wprintw

        call renderMap
        jmp render
    
    gameOver:
        mov rdi, [DialogWindow]
        mov rsi, Dialog.Death
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, Dialog.GameStats
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, Dialog.TreesChopped
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, IntegerFormat
        mov edx, [TreesChopped]
        xor eax, eax
        call wprintw

        mov rdi, [ChoicesWindow]
        mov esi, "/"
        call waddch

        mov rdi, [ChoicesWindow]
        mov rsi, IntegerFormat
        mov edx, [TreesTotal]
        xor eax, eax
        call wprintw

        mov rdi, [ChoicesWindow]
        mov esi, 10
        call waddch

        mov rdi, [ChoicesWindow]
        mov rsi, Dialog.Money
        call waddstr

        mov rdi, [ChoicesWindow]
        mov rsi, IntegerFormat
        mov edx, [Money]
        call wprintw

        call renderMap
        jmp render
    
    dayReport:
        mov rdi, [DialogWindow]
        mov rsi, Dialog.DayReport
        call waddstr

        mov rdi, [DialogWindow]
        mov rsi, Dialog.TreesChopped
        call waddstr

        mov rdi, [DialogWindow]
        mov rsi, IntegerFormat
        mov edx, [TreesChopped]
        xor eax, eax
        call wprintw

        mov rdi, [DialogWindow]
        mov esi, '/'
        call waddch

        mov rdi, [DialogWindow]
        mov rsi, IntegerFormat
        mov edx, [TreesTotal]
        xor eax, eax
        call wprintw

        mov rdi, [DialogWindow]
        mov rsi, 10
        call waddch

        mov rdi, [DialogWindow]
        mov rsi, Dialog.TreesChoppedToday
        call waddstr

        mov rdi, [DialogWindow]
        mov rsi, IntegerFormat
        mov edx, [DayTreesChopped]
        call wprintw

        AddChoice "n", Choices.Next, .newday

        call renderMap
        jmp render

        .newday:
            inc dword [Day]
            mov [DayTreesChopped], 0
            mov [DayTurnCount], TurnsPerDay

            mov eax, [TreesTotal]
            sub eax, [TreesChopped]
            test eax, eax
            jz .gameComplete

            cmp byte [BribeSuccess], 0
            je .lawyersReturn

            dec [BribeSuccess]
            mov dword [GameState], STATE_GAME
            ret
            .lawyersReturn:
                mov [GameState], STATE_DAY_LEGAL_LETTER
                ret

            .gameComplete:
                mov [GameState], STATE_GAME_FINISHED
                ret

    dayLegalLetter:
        cmp dword [LawyerAggression], 9
        jge .Level3

        cmp dword [LawyerAggression], 8
        jge .Level2

        jmp .Level1

        .Level1:
            mov rdi, [DialogWindow]
            mov rsi, Dialog.DailyLegalLetter
            call waddstr
            jmp .continue

        .Level2:
            mov rdi, [DialogWindow]
            mov rsi, Dialog.DailyLegalLetterL2
            call waddstr
            jmp .continue
        
        .Level3:
            mov rdi, [DialogWindow]
            mov rsi, Dialog.DailyLegalLetterL3
            call waddstr
            jmp .continue

        .continue:
        AddChoice "1", Choices.ShredLegalLetter, .shred

        mov eax, [TimesBribed]
        imul eax, 500
        add eax, 500
        cmp [Money], eax 
        jl .notEnoughMoneyToBribe
        AddChoice "2", Choices.BribeLawyers, .bribe

        mov edx, [TimesBribed]
        mov rdi, [ChoicesWindow]
        mov rsi, IntegerFormat
        imul edx, 500
        add edx, 500 ; adjustment for bribesuccess 0
        xor eax, eax
        call wprintw

        mov rdi, [ChoicesWindow]
        mov rsi, ")"
        call waddch

        .notEnoughMoneyToBribe:
            call renderMap
            jmp render

        .shred:
            mov dword [LegalLetterY], 0
            inc dword [LawyerAggression]
            mov dword [GameState], STATE_LETTER_SHREDDING
            ret

        .bribe:
            mov eax, [TimesBribed]
            inc eax
            imul eax, 500
            sub dword [Money], eax

            inc dword [TimesBribed]
            call rand

            and eax, 1
            mov byte [BribeSuccess], al

            test eax, eax
            jnz .bribeDone

            inc [LawyerAggression]

            .bribeDone:
                mov dword [GameState], STATE_LAWYER_RESPONSE
                ret

    lawyerResponse:
        cmp [BribeSuccess], 0
        jnz .BribeSuccess
        jz .BribeFailed

        .BribeSuccess:
            mov rdi, [DialogWindow]
            mov rsi, Dialog.BribeSuccess
            call waddstr
            mov [BribeSuccess], -1
            mov [LawyerAggression], 0
            jmp .done

        .BribeFailed:
            mov rdi, [DialogWindow]
            mov rsi, Dialog.BribeFail
            call waddstr
            jmp .done

        .done:
            AddChoice "1", Choices.Next, .continue
            call renderMap
            jmp render

        %define LawyerAggressionSetpoint 10
        .continue:
            cmp [LawyerAggression], LawyerAggressionSetpoint
            jg .death

            cmp [BribeSuccess], -1
            jne .end

            mov [BribeSuccess], 7

            .end:
                mov dword [GameState], STATE_GAME
                ret
            
            .death:
                mov [GameState], STATE_GAME_OVER
                ret

    letterShredding:
        mov rdi, [DialogWindow]
        mov rsi, [LegalLetterY]
        xor edx, edx
        mov rcx, Dialog.DailyLegalLetter
        call mvwaddstr

        inc dword [LegalLetterY]

        mov eax, [LegalLetterY]
        cmp eax, [DialogWindowHeight]
        jl .done

        cmp dword [LawyerAggression], LawyerAggressionSetpoint
        jg .dead

        mov dword [GameState], STATE_GAME
        jmp .done

        .dead:
            mov dword [GameState], STATE_GAME_OVER

        .done:
            call renderMap
            jmp render

    treeRoutine:
        mov dword [GameState], STATE_TREE_SELECTION
        ret

    treeSelection:
        mov rdi, [DialogWindow]
        mov rsi, Dialog.ChooseATree
        call waddstr

        AddChoice "1", Choices.CancelTreeSelection, .cancel
        AddChoice "w", Choices.DirUp, .chopUp
        AddChoice "a", Choices.DirL, .chopLeft
        AddChoice "s", Choices.DirDn, .chopDown
        AddChoice "d", Choices.DirR, .chopRight

        call renderMap
        jmp render

        .chopUp:
            xor edi, edi
            mov esi, -1
            jmp chopTree
        .chopDown:
            xor edi, edi
            mov esi, 1
            jmp chopTree
        .chopLeft:
            mov edi, -1
            xor esi, esi
            jmp chopTree
        .chopRight:
            mov edi, 1
            xor esi, esi
            jmp chopTree
        .cancel:
            mov dword [GameState], STATE_GAME
            ret

    ; Chops a tree relative to the player
    ; @param edi delta x
    ; @param esi delta y
    ; @return eax 1 if chopped, 0 if not
    chopTree:
        mov eax, [PlayerX]
        add eax, edi

        mov edx, [PlayerY]
        add edx, esi

        cmp eax, MapSize
        jae .done

        cmp edx, MapSize
        jae .done

        shl edx, 6
        add edx, eax

        mov rcx, Map

        test byte [rcx + rdx], TILE_TREE
        jz .done

        and byte [rcx + rdx], ~TILE_TREE

        mov dword [GameState], STATE_GAME
        mov eax, 1

        ; statistics
        inc dword [DayTreesChopped]
        inc dword [TreesChopped]
        inc dword [TreesInventory]
        dec dword [DayTurnCount]
        ret

        .done:
            xor eax, eax
            ret
    
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

        ; handle other inputs
        cmp eax, 410 ; resize
        je resize

        cmp eax, 27 ; escape
        je exit

        cmp dword [GameState], STATE_TUTORIAL1
        je tutorial1input

        cmp dword [GameState], STATE_GAME
        jne .notMovement

        cmp eax, 'w'
        je .up
        cmp eax, 'a'
        je .left
        cmp eax, 's'
        je .down
        cmp eax, 'd'
        je .right

        .notMovement:
        mov edi, eax
        call handleChoice

    jmp mainloop

    .up:
        xor edi, edi
        mov esi, -1
        jmp playerMove

    .down:
        xor edi, edi
        mov esi, 1
        jmp playerMove

    .left:
        mov edi, -1
        xor esi, esi
        jmp playerMove

    .right:
        mov edi, 1
        xor esi, esi
        jmp playerMove

    ; Checks if the player is next to a tree
    ; @return eax 1 if true, 0 if false
    IfNearTree:
        mov eax, [PlayerY]
        shl eax, 6
        add eax, [PlayerX]

        mov rdx, Map

        ; up
        cmp dword [PlayerY], 0
        je .down
        test byte [rdx + rax - MapSize], TILE_TREE
        jnz .found

        .down:
            cmp dword [PlayerY], MapSize - 1
            jae .left
            test byte [rdx + rax + MapSize], TILE_TREE
            jnz .found
        
        .left:
            cmp dword [PlayerX], 0
            je .right
            test byte [rdx + rax - 1], TILE_TREE
            jnz .found

        .right:
            cmp dword [PlayerX], MapSize - 1
            jae .notFound
            test byte [rdx + rax + 1], TILE_TREE
            jnz .found
        
        .notFound:
            xor eax, eax
            ret

        .found:
            mov eax, 1
            ret

        ; Checks if the player is next to the shack entry
        ; @return eax 1 if true 0 if false
        IfNearShackEntry:
        mov eax, [PlayerY]
        shl eax, 6
        add eax, [PlayerX]

        mov rdx, Map

        ; up
        cmp dword [PlayerY], 0
        je .down
        test byte [rdx + rax - MapSize], TILE_SHACK_ENTRY
        jnz .found

        .down:
            cmp dword [PlayerY], MapSize - 1
            jae .left
            test byte [rdx + rax + MapSize], TILE_SHACK_ENTRY
            jnz .found
        
        .left:
            cmp dword [PlayerX], 0
            je .right
            test byte [rdx + rax - 1], TILE_SHACK_ENTRY
            jnz .found

        .right:
            cmp dword [PlayerX], MapSize - 1
            jae .notFound
            test byte [rdx + rax + 1], TILE_SHACK_ENTRY
            jnz .found
        
        .notFound:
            xor eax, eax
            ret

        .found:
            mov eax, 1
            ret

    ; Moves the player dx
    ; @param esi delta x
    ; @param edi delta y
    ; @return eax 1 if moved 0 if blocked
    playerMove:
        mov eax, [PlayerX]
        add eax, edi

        mov edx, [PlayerY]
        add edx, esi

        cmp eax, MapSize
        jae .blocked

        cmp edx, MapSize
        jae .blocked

        mov ecx, edx
        shl ecx, 6
        add ecx, eax

        test byte [Map + rcx], TILE_TREE | TILE_PROTESTOR | TILE_SHACK | TILE_SHACK_ENTRY
        jnz .blocked

        mov ecx, [DayTurnCount]
        cmp ecx, 0
        jbe .blocked

        dec dword [DayTurnCount]

        mov [PlayerX], eax
        mov [PlayerY], edx

        mov eax, 1
        jmp mainloop

        .blocked: 
            xor eax, eax
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
            ; Calculate cameras
            mov eax, r13d
            shr eax, 1
            mov ebx, [PlayerX]
            sub ebx, eax
            mov [CameraX], ebx

            mov eax, r12d
            shr eax, 1
            mov ebx, [PlayerY]
            sub ebx, eax
            mov [CameraY], ebx

            xor r14d, r14d

        .looprow:
            cmp r14d, r12d
            jae .done
            xor r15d, r15d
        
        .looptile:
            cmp r15d, r13d
            jae .drawRow

            mov eax, r15d
            add eax, [CameraX]

            cmp eax, MapSize
            jae .outsideMap

            mov edx, r14d
            add edx, [CameraY]

            cmp edx, MapSize
            jae .outsideMap

            shl edx, 6
            add edx, eax

            mov rbx, Map
            movzx eax, byte [rbx + rdx]
            jmp .tileLoaded

            .outsideMap:
                xor eax, eax

            .tileLoaded:
                mov edx, ' '
                test al, TILE_TREE
                jz .checkProtestor
                mov edx, Tree ; tree character

            .checkProtestor:
                test al, TILE_PROTESTOR
                jz .checkShack
                mov edx, 'P'

            .checkShack:
                test al, TILE_SHACK | TILE_SHACK_ENTRY
                jz .checkPlayer

                mov eax, r14d
                add eax, [CameraY]
                sub eax, ShackY

                imul eax, ShackW

                mov ecx, r15d
                add ecx, [CameraX]
                sub ecx, ShackX

                add eax, ecx
                movzx edx, byte [Shack + rax]

            .checkPlayer:
                mov eax, r13d
                shr eax, 1
                cmp r15d, eax
                jne .storeTile

                mov eax, r12d
                shr eax, 1
                cmp r14d, eax
                jne .storeTile

                mov edx, '@'

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
        call endwin

        mov eax, 60
        xor edi, edi
        syscall
     