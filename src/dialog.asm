default rel
global Dialog.WelcomeDialog, Dialog.Tutorial2Dialog, Dialog.Tutorial3Dialog, Dialog.Day, Dialog.TurnsRemaining, Dialog.DayReport, Dialog.TreesChopped, Dialog.TreesChoppedToday, Dialog.ChooseATree, Dialog.DailyLegalLetter, Dialog.BribeFail, Dialog.BribeSuccess, Dialog.Money, Dialog.Death, Dialog.GameStats, Dialog.DailyLegalLetterL2, Dialog.DailyLegalLetterL3, Dialog.GameComplete

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
    db "You need to walk to the entrance of the shack to sell trees.", 10
    db 10
    db "The shack can be found a little northwes.", 10
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

.DailyLegalLetterL2:
    db "Notice to Cease Logging Operations Immediately", 10
    db "This is your second to last warning to cease and desist all logging operations.", 10
    db "You do not own the land or the trees you are chopping down.", 10
    db "Failure to comply with this notice will result in termination of your life.", 10
    db 10
    db "-We are not joking aroud, Lawyers", 0

.DailyLegalLetterL3:
    db "Final Notice to Cease Logging Operations", 10
    db "We're not joking around! Cease all logging operations immediately", 10
    db "This is the the final notice we're sending you!", 10
    db "You need to stop immediately.", 10
    db 10
    db "-We have knives, Lawyers", 0

.BribeFail:
    db "Lawyers> Lmao no we're not leaving you alone", 10, 0

.BribeSuccess:
    db "Lawyers> Fine we'll leave you alone for a week", 10, 0

.Money db "Money: ", 0

.Death:
    db "The lawyers have gotten quite pissed.", 10
    db "They have decided to take you out.", 10
    db "You have failed to deforest the amazon.", 10
    db 10
    db "Game over", 10
    db "Press escape to exit", 0

.GameStats db "Game Statistics", 10, 10, 0

.GameComplete:
    db "Welp. You've done it.", 10
    db "Every tree has been chopped", 10
    db "Wow it sure is hot around here...", 10
    db "Maybe that was a bad idea, you should plant them back", 10
    db 10
    db "Game Finished, View stats on the Choices panel", 10
    db "Press escape to exit", 0
