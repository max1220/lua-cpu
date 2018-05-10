;This example draws static content using a GPU device

;access configure memory
SET A, 0xFF10

;use mode 4 (320x240, 1bpp, memory_mapped)
SET B, 0x0004

;set memory mapping address
SET C, :video_mmap

IOCALL

;loop forever
:loop
GOTO :loop


:video_mmap
;each display line is 40 bytes long
FILL 9600, 0xFF