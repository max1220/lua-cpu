;This example draws static content using a GPU device

;hwid=0xFF10(gpu), mode=0x00(set_mode)
SET A, 0xFF10
;use mode 4 (320x240, 1bpp, memory_mapped)
SET B, 0x0004
;set memory mapping address
SET C, :video_mmap
IOCALL

:loop

;set a random memory address to random value
SET B, :video_mmap
RAND C
;C maximum value: 8191
AND C, 0x1FFF
ADD B, C
RAND D
SET [B], D

;loop forever
GOTO :loop


:video_mmap
;total 0x2580 bytes
FILL 0x1FFF, 0xFF
FILL 0x0581, 0xFF
