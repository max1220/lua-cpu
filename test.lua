#!/usr/bin/env lua5.3
local time = require("time")
local assembler = require("assembler")
-- local instructions = require("instructions")
local cpu = require("cpu")


io.write("Reading input file... ")
local input_f = assert(io.open(arg[1], "rb"))
str = input_f:read("*a")
print(#str .. " bytes")


io.write("Tokenizing... ")
local tokens = assembler.tokenize(str)
print(#tokens .. " tokens")
  
  
io.write("Assembling... ")
local bytes = assembler.tokens_to_bytes(tokens)  
print(#bytes .. " bytes")


io.write("Initializing CPU... ")
local pc = cpu.new_cpu()
print(" ok")


io.write("Loading programm... ")
pc:load_bytes(0x0000, bytes)
print(" ok")


io.write("Initializing serial... ")
local function on_char(char)
  io.write(string.char(char))
end
local input_que = {}
local function on_input()
  local key = table.remove(bytes_left, 1)
  return string.byte(key)
end
local serial = require("peripherals.serial")(pc, on_char, on_input)
table.insert(pc.peripherals, serial)
print(" ok")


io.write("Initializing GPU... ")
local gpu = require("peripherals.gpu")(pc)
table.insert(pc.peripherals, gpu)
print(" ok")


print("Running...")
local steps = 0
local step_size = 10000
repeat
  steps = steps + pc:run(step_size)
  gpu:draw_unicode()
  print("steps:", steps)
until not pc.running
print("\nHalted")
pc:dump_registers()
pc:dump_memory(0x0000, 128)