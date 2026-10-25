default rel
global Dialog.WelcomeDialog, Dialog.Tutorial2Dialog, Dialog.Tutorial3Dialog, Dialog.Day, Dialog.TurnsRemaining, Dialog.DayReport, Dialog.TreesChopped, Dialog.TreesChoppedToday, Dialog.ChooseATree, Dialog.DailyLegalLetter, Dialog.BribeFail, Dialog.BribeSuccess

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
    db "The limit will be displayed at the top of this window", 10
    db "Additional options may be provided in the responses window based on context.", 10
    db 10
    db "For example, press 1 to continue to the next tutorial.", 0

.Tutorial3Dialog:
    db "You can always press the escape key to exit the game.", 10
    db "Your game save will NOT be saved!", 10
    db "Protestors will spawn at the beginning of each day", 10
    db 10
    db "Please, do not cause too much harm to the protesters.", 10
    db "Press 1 to continue to the game.", 0

.Day db "Day ", 0
.TurnsRemaining db "/100 turns remaining this day", 10, 0
.DayReport db "DAY REPORT", 10, 0
.TreesChopped db "Trees Chopped: ", 0
.TreesChoppedToday db "   Today: ", 0
.ChooseATree db "Choose a direction to chop in", 10, 0

.DailyLegalLetter:
    db "Notice to Cease Logging Operations", 10
    db "You are formally ordered to cease and desist all logging operations.", 10
    db 10
    db "Failure to comply will result in immediate termination of your life.", 10
    db 10
    db "-Lawyers", 0

.BribeFail:
    db "Lmao no we're not leaving you alone", 10, 0

.BribeSuccess:
    db "Fine we'll leave you alone for a week", 10, 0