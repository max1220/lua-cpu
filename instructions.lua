-- utility functions

local register_index = {
  "A","B","C","D","X","Y","Z"
}


--[[ instruction generator functions: ]]--

local function set_reg_mem_literal(register)
  -- SET A, [0x0000]
  return function(self)
    local addr = self:get_mem_16(self.registers.PC + 1)
    self.registers[register] = self:get_mem_16(addr)
    return 3
  end
end


local function set_mem_reg_literal(register)
  -- SET [A], 0x0000
  return function(self)
    local value = self:get_mem_16(self.registers.PC + 1)
    self:set_mem_16(self.registers[register], value)
    return 3
  end
end


local function set_mem_reg_reg(register)
  -- SET [A], B
  return function(self)
    local register_i = self:get_mem_8(self.registers.PC + 1) + 1
    local _register = register_index[math.max(math.min(register_i, #register_index),1)]
    self:set_mem_16(self.registers[register], self.registers[_register])
    return 2
  end
end

local function set_reg_mem_self_addr(register)
  -- SET A, [A]
  return function(self)
    local addr = self.registers[register]
    local val = self:get_mem_16(self.registers[register])
    self.registers[register] = val
    return 1
  end
end

local function set_mem_literal_reg(register)
  -- SET [0x0000], A
  return function(self)
    local addr = self:get_mem_16(self.registers.PC + 1)
    self:set_mem_16(addr, self.registers[register])
    return 3
  end
end

local function set_reg_literal(register)
  -- SET A, 0x0000
  return function(self)
    self.registers[register] = self:get_mem_16(self.registers.PC + 1)
    return 3
  end
end

local function set_reg_reg(register)
  -- SET A, B
  return function(self)
    local register_i = self:get_mem_8(self.registers.PC + 1) + 1
    local _register = register_index[math.max(math.min(register_i, #register_index),1)]
    self.registers[register] = self.registers[_register]
    return 2
  end
end

local function add_reg_reg(register)
  -- ADD A, B
  return function(self)
    local register_i = self:get_mem_8(self.registers.PC + 1) + 1
    local _register = register_index[math.max(math.min(register_i, #register_index),1)]
    local res = self.registers[register] + self.registers[_register]
    if res > 0xFFFF then
      self.flags.overflow = true
      res = 0xFFFF
    end
    self.registers[register] = res
    return 2
  end
end

local function sub_reg_reg(register)
  return function(self)
    local register_i = self:get_mem_8(self.registers.PC + 1) + 1
    local _register = register_index[math.max(math.min(register_i, #register_index),1)]
    local res = self.registers[register] - self.registers[_register]
    if res < 0 then
      self.flags.overflow = true
      res = 0
    end
    self.registers[register] = res
    return 2
  end
end

local function and_reg_reg(register)
  return function(self)
    local register_i = self:get_mem_8(self.registers.PC + 1) + 1
    local _register = register_index[math.max(math.min(register_i, #register_index),1)]
    self.registers[register] = self.registers[register] & self.registers[_register]
    return 2
  end
end
local function or_reg_reg(register)
  return function(self)
    local register_i = self:get_mem_8(self.registers.PC + 1) + 1
    local _register = register_index[math.max(math.min(register_i, #register_index),1)]
    self.registers[register] = self.registers[register] | self.registers[_register]
    return 2
  end
end
local function xor_reg_reg(register)
  return function(self)
    local register_i = self:get_mem_8(self.registers.PC + 1) + 1
    local _register = register_index[math.max(math.min(register_i, #register_index),1)]
    self.registers[register] = self.registers[register] ~ self.registers[_register]
    return 2
  end
end
local function jump_reg(register)
  return function(self)
    local addr = self.registers[register]
    self.registers.PC = addr
    return 0
  end
end




--[[ actual instruction functions: ]]--

local function jump_literal(self)
  local addr = self:get_mem_16(self.registers.PC + 1)
  self.registers.PC = addr
  return 0
end

local function halt(self)
  -- HALT
  self.running = false
  return 0
end

local function wait(self)
  -- WAIT (Loops indefinitly waiting for an interrupt)
  return 0
end

local function trace(self)
  -- TRACE (prints debug info)
  print("TRACE instruction")
  self:dump_registers()
  self:dump_flags()
  self:dump_memory(self.registers.PC - 8, 24)
  return 1
end

local function jump_if_test_literal(self)
  if self.flags.test then
    local addr = self:get_mem_16(self.registers.PC + 1)
    self.registers.PC = addr
    return 0
  else
    return 3
  end
end

local function interrupt(self)
  local a_register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local a_register = register_index[math.max(math.min(a_register_i, #register_index),1)]
  local b_register_i = self:get_mem_8(self.registers.PC + 2) + 1
  local b_register = register_index[math.max(math.min(b_register_i, #register_index),1)]
  local c_register_i = self:get_mem_8(self.registers.PC + 3) + 1
  local c_register = register_index[math.max(math.min(c_register_i, #register_index),1)]
  local d_register_i = self:get_mem_8(self.registers.PC + 4) + 1
  local d_register = register_index[math.max(math.min(d_register_i, #register_index),1)]
  local ok = self:interrupt({
    A = self.registers[a_register],
    B = self.registers[b_register],
    C = self.registers[c_register],
    D = self.registers[d_register]
  })
  if ok then
    -- interrupt succeded, pc modified, don't modify PC further
    return 0
  else
    -- interrupt busy
    return 5
  end
end

local function interrupt_restore(self)
  if self.interrupt_state then
    self:interrupt_restore()
    return 0
  else
    return 1
  end
end

local function interrupt_discard(self)
  self:interrupt_discard()
  return 1
end
local function interrupt_addr(self)
  local register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local register = math.max(math.min(register_i, #register_index),1)
  local addr = self.registers[register]
  self.interrupt_addr = addr
  return 1
end

local function test_reg_equal_val(self)
  local register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local _register = register_index[math.max(math.min(register_i, #register_index),1)]
  local value = self:get_mem_16(self.registers.PC + 2)
  if self.registers[_register] == value then
    self.flags.test = true
  else
    self.flags.test = false
  end
  return 4
end

local function test_reg_larger_val(self)
  local register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local _register = register_index[math.max(math.min(register_i, #register_index),1)]
  local value = self:get_mem_16(self.registers.PC + 2)
  if self.registers[_register] > value then
    self.flags.test = true
  else
    self.flags.test = false
  end
  return 4
end

local function test_reg_equal_reg(self)
  local a_register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local a_register = register_index[math.max(math.min(register_i, #register_index),1)]
  local b_register_i = self:get_mem_8(self.registers.PC + 2) + 1
  local b_register = register_index[math.max(math.min(register_i, #register_index),1)]
  if self.registers[a_register] == self.registers[b_register] then
    self.flags.test = true
  else
    self.flags.test = false
  end
  return 3
end

local function test_reg_larger_reg(self)
  local a_register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local a_register = register_index[math.max(math.min(register_i, #register_index),1)]
  local b_register_i = self:get_mem_8(self.registers.PC + 2) + 1
  local b_register = register_index[math.max(math.min(register_i, #register_index),1)]
  if self.registers[a_register] > self.registers[b_register] then
    self.flags.test = true
  else
    self.flags.test = false
  end
  return 3
end

local function add_reg_value(self)
  local register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local register = register_index[math.max(math.min(register_i, #register_index),1)]
  local value = self.registers[register] + self:get_mem_16(self.registers.PC + 2)
  if value > 0xFFFF then
    self.flags.overflow = true
    value = 0xFFFF
  end
  self.registers[register] = value
  return 4
end

local function and_reg_value(self)
  local register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local register = register_index[math.max(math.min(register_i, #register_index),1)]
  local value = self.registers[register] & self:get_mem_16(self.registers.PC + 2)
  self.registers[register] = value
  return 4
end

local function sub_reg_value(self)
  local register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local register = register_index[math.max(math.min(register_i, #register_index),1)]
  local value = self.registers[register] + self:get_mem_16(self.registers.PC + 2)
  if value < 0 then
    self.flags.overflow = true
    value = 0
  end
  self.registers[register] = value
  return 4
end

local function rand_reg(self)
  local register_i = self:get_mem_8(self.registers.PC + 1) + 1
  local register = register_index[math.max(math.min(register_i, #register_index),1)]
  self.registers[register] = math.random(0x0000, 0xFFFF)
  return 2
end

local function io_call(self)
  self:io_call()
  return 1
end

local instructions  = {
  halt, -- 0
  trace,
  jump_literal,
  jump_if_test_literal,
  test_reg_equal_val,
  test_reg_larger_val, -- 5
  test_reg_equal_reg,
  test_reg_larger_reg,
  io_call,
  interrupt,
  interrupt_restore, -- 10
  interrupt_discard,
  interrupt_addr, -- 12
}
local instruction_gens = {
  set_reg_mem_literal,    -- 13 -> 19   SET A, [0x0000]
  set_mem_literal_reg,    -- 20 -> 26   SET [0x0000], A
  set_reg_literal,        -- 27 -> 33   SET A, 0x0000
  set_reg_reg,            -- 34 -> 40   SET A, B
  set_reg_mem_self_addr,  -- 41 -> 47   SET A, [A]
  add_reg_reg,            -- 48 -> 54   ADD A, B
  set_mem_reg_reg,        -- 55 -> 61   SET [A], B
  set_mem_reg_literal,    -- 62 -> 68   SET [A], 0x0000
  sub_reg_reg,
  and_reg_reg,
  or_reg_reg,
  xor_reg_reg
}

local function add_instruction(name, func, index, args)
  
end

-- argument encodings:
-- reg:         register by pc-relative byte (+1 byte)
-- lit:         literal by pc-relative word (+2 byte)
-- reg_instr:   register by instruction index (+0 byte)
-- mem_lit:     memory location by pc-relative word (+2 byte)
-- mem_reg:     memory location by register encoded in pc-relative byte (+1 byte)
add_instruction("set", set_reg_mem_literal, 13, {"reg_instr", "mem_lit"})
add_instruction("set", set_mem_literal_reg, 20, {"mem_lit", "reg_instr"})
add_instruction("set", set_reg_literal, 27, {"reg_instr", "lit"})
add_instruction("set", set_reg_reg, 34, {"reg_instr", "reg"})
add_instruction("set", set_reg_mem_self_addr, 41, {"reg_instr"})

for _, instruction_gen in ipairs(instruction_gens) do
  for _, register in ipairs(register_index) do
    table.insert(instructions, instruction_gen(register))
  end
end

print("add_reg_value:",#instructions)
table.insert(instructions, add_reg_value) -- 98
table.insert(instructions, sub_reg_value)
table.insert(instructions, rand_reg) -- 100
table.insert(instructions, and_reg_value)


--print("div_reg_value", table.insert(instructions, div_reg_value))
--print("mul_reg_value", table.insert(instructions, mul_reg_value))
--print("and_reg_value", table.insert(instructions, and_reg_value))
--print("or_reg_value", table.insert(instructions, or_reg_value))
--print("xor_reg_value", table.insert(instructions, xor_reg_value))
--print("rshift_reg_value", table.insert(instructions, rshift_reg_value))
--print("lshift_reg_value", table.insert(instructions, lshift_reg_value))

print("#instructions:",#instructions)

instructions.doc = instructions_doc

return instructions