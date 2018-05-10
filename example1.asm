;This example echos keyboard entrys

:get
 ;Y is the current position in memory
 SET Y, :input_data

 ;set A to console, receive character
 SET A, 0xFF01

 :get_loop
  ;query character(stored in C)
  IOCALL 

  ;test if C(The read character) is enter
  TESTEQ C, '\n'
  ;... if so, goto :send
  IF :send
 
  ;test if C(The read character) is 0x0000 (No input recived)
  TESTEQ C, 0x00
  ;... if so, goto :get_loop
  IF :get_loop
 
  ;... otherwise, store character in memory
  SET [Y], C
 
  ;increate Y
  ADD Y, 0x0002

  ;and repeat loop
  GOTO :get_loop


:send
 ;add \n
 ADD Y, 0x0002
 SET [Y], 0x000A

 ;add 0-termination
 ADD Y, 0x0002
 SET [Y], 0x0000

 ;set A to console, send character
 SET A, 0xFF00

 ;loop from beginning of input text
 SET Y, :input_data

 :send_loop
  ;load address of current char
  SET C, Y
  SET C, [C]

  ;increase loop vairable
  ADD Y, 0x0002

  ; if current character is 0, go back to getting new characters
  TESTEQ C, 0x0000
  IF :get
 
  ; .. otherwise send character
  IOCALL
 
  ;and continue sending more characters
  GOTO :send_loop


;store input data here
:input_data
;Fill 255 bytes with 0x00
FILL 0xFF, 0x00
