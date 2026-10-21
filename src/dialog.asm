default rel
global WelcomeDialog

section .rodata
WelcomeDialog:
    db "Welcome to your first day of deforesting the amazon!", 10
    db "Your task is to chop down every tree in the amazon.", 10
    db "You must also avoid protestors and legal consequences while doing so.", 10
    db 10
    db "Please name your logging company on the responses window.", 0