nasm -f bin boot1.asm -o boot1.bin
nasm -f bin stage2.asm -o KRNLDR.SYS
nasm -f bin stage3.asm -o KRNL.SYS
