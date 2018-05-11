-- generates a new serial device
-- to send a character, set A to mode_offset, and B to the character to send.
-- to get a character, set A to mode_offset+1. If a character is aviable, B is the character, otherwise B is 0.
-- to set extra parameters, set A to mode_offset+2. A, B, C are device-dependant

function new_serial(computer, out_callback, in_callback, parm_callback)
  local serial = {}
  serial.mode_offset = 0xFF00
  function serial:io_call()
    local mode = computer.registers.A - self.mode_offset
    if mode == 0x0000 then
      -- send character
      if char_callback then
        char_callback(computer, computer.registers.B & 0x00FF)
      end
    elseif mode == 0x0001 then
      -- get character
      if input_callback then
        computer.registers.B = (input_callback(computer) or 0) & 0x00FF
      end
    elseif mode == 0x0002 then
      -- reconfigure
      if parm_callback then
        parm_callback(computer)
      end
    end
  end
  return serial
end

return new_serial