;This example prints a message from RAM using the text console

;set A to text console id
SET A, 0xFF01

;set B to console access mode(send character)
SET B, 0x0000

;X is the current index for the loop
;Labels can be used as 16-bit literals that are lazy-evaluated in tokens_to_bytes
SET Y, :hello_dat

;here beginns the part that will be repeated in the loop.
;this defines the literal part of the label as this position in bytes in the assembled bytecode
:loop

;set C to data from address pointed at by Y
SET C, Y
SET C, [C]

;perform io_call, sending the character now in C
IOCALL

;increase Y
ADD Y, 0x0001

;test if C(The read character) is not 0(End of string)...
TESTLG C, 0x0000

;... if so, continue loop
IF :loop

;... otherwise trace (dumps registers + flags to console)
TRACE

;end execution
HALT

;store hello world data
:hello_dat
;DAT stores it's literal argument(s) in the bytecode
;one byte padding in front since we read 2 byte from RAM
;(starting at :hello_dat), and the console only cares about the lower byte
DAT 0x0
;double-quotes return multiple bytes
DAT "Hello World!"
;single-quotes can contain an escape sequence, but only return 1 byte
DAT '\n'
;null-terminated
DAT 0x0
;DAT16 could also store a label-pointer
DAT16 :hello_dat
;or a larger number
DAT16 0x1234