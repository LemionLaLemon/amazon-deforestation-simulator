default rel

global Choices.Quit, Choices.CursorPrompt, Choices.Next

section .rodata:
Choices:
.Next db "Next", 10, 0
.Quit db "Quit the game", 10, 0
.CursorPrompt db 10, "Name> ", 0