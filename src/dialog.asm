default rel
global Dialog.WelcomeDialog, Dialog.Tutorial2Dialog, Dialog.Tutorial3Dialog

section .rodata
Dialog:
.WelcomeDialog:
    db "Welcome to your first day of deforesting the amazon!", 10
    db "Your task is to chop down every tree in the amazon.", 10
    db "You must also avoid protestors and legal consequences while doing so.", 10
    db 10
    db "Please name your logging company on the responses window.", 0

.Tutorial2Dialog:
    db "You can use the W A S D keys to move around the scene.", 10
    db "There are a limit number of turns in a day.", 10
    db "The limit can be seen in the bottom right of the responses window.", 10
    db "Additional options may be provided in the responses window based on context.", 10
    db 10
    db "For example, press 1 to continue to the next tutorial.", 0

.Tutorial3Dialog:
    db "You can always press the escape key to exit the game.", 10
    db "Your game save will NOT be saved!", 10
    db 10
    db "Please, do not cause too much harm to the protesters.", 10
    db "Press 1 to continue to the game.", 0