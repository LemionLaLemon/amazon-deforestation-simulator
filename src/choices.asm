default rel

global Choices.Quit, Choices.CursorPrompt, Choices.Next, Choices.DirUp, Choices.DirDn, Choices.DirR, Choices.DirL, Choices.ChopTree, Choices.CancelTreeSelection, Choices.ShredLegalLetter, Choices.BribeLawyers, Choices.SellWood

section .rodata:
Choices:
.Next db "Continue", 10, 0
.Quit db "Quit the game", 10, 0
.CursorPrompt db 10, "Name> ", 0
.ChopTree db "Chop tree", 10, 0
.DirUp db "Up", 10, 0
.DirDn db "Down", 10, 0
.DirL db "Left", 10, 0
.DirR db "Right", 10, 0
.CancelTreeSelection db "Cancel Tree Selection", 10, 0
.ShredLegalLetter db "Shred legal letter", 10, 0
.BribeLawyers db "Bribe the legal team ($", 0
.SellWood db "Sell your wood ($", 0