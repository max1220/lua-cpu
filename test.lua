#!/usr/bin/env lua5.3
local time = require("time")
local assembler = require("assembler")
-- local instructions = require("instructions")
local cpu = require("cpu")
local peripherals = require("peripherals")


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

io.write("Initializing text console... ")
local function on_char(char)
  io.write(string.char(char))
  --print("got char:", char, "'"..string.char(char).."'")
end

local bytes_left = {"H","e","l","l","o","\n"}
local function on_input()
  
  io.write("\n>")
  local line = io.read("*l")
  if line:match("^0x(%x+)") then
    return tonumber(line:match("^0x(%x+)"), 16)
  elseif #line == 1 then
    return string.byte(line)
  elseif line == "#dump" then
    pc:dump()
  elseif line == "" then
    return 10
  else
    return 0
  end
  io.write("\n")
  --[[
  local key = table.remove(bytes_left, 1)
  if not key then pc.running = false; return 0 end
  key = string.byte(key)
  --print(("Simulating key 0x%.2x (%d)"):format(key, key))
  return key
  --]]
end
local text_console = peripherals.new_text_console(pc, on_char, on_input)
table.insert(pc.peripherals, text_console)

print(" ok")

io.write("Initializing GPU... ")
local gpu = peripherals.new_graphics_card(pc)
table.insert(pc.peripherals, gpu)
print(" ok")

-- os.exit(0)

print("Running...")
local steps = 0
local csteps = 0
local step_size = 100000
repeat
  steps = steps + pc:run(step_size)
  if csteps + step_size < steps then
    -- print("Drawing at step " .. steps)
    print("sleeping after " .. steps .. " cycles")
    time.sleep(0.1)
    csteps = steps
  end
until not pc.running
print("\nHalted")
pc:dump_registers()
pc:dump_memory(0x0000, 128)