local assembler = {}

local registers = {
  "A","B","C","D","X","Y","Z",
  A = 1,
  B = 2,
  C = 3,
  D = 4,
  X = 5,
  Y = 6,
  Z = 7
}


local function lines(str)
  if str:sub(-1)~="\n" then
    str=str.."\n"
  end
  return str:gmatch("(.-)\n")
end


local function trim(str)
  return str:match("^%s*(.*%S)") or ""
end


local function pack(...)
  return {...}
end
local unpack = table.unpack


local function resolve_label(name)
  return function(labels)
    return labels[name]
  end
end


local function parse_literal(literal)
  literal = trim(literal)
  if literal:match("^0x(%x+)$") then
    return assert(tonumber(literal:match("^0x(%x+)$"), 16))
  elseif literal:match("^(%d+)$") then
    return assert(tonumber(literal:match("^(%d+)$")))
  elseif literal:match("^:(.-)$") then
    return resolve_label(literal:match("^:(.-)$"))
  elseif literal:match("^'(..?)'$") then
    local char = literal:match("^'(..?)'$")
    if char == "\\n" then
      return string.byte("\n")
    elseif char == "\\r" then
      return string.byte("\r")
    elseif char == "\\b" then
      return string.byte("\b")
    elseif char == "\'" then
      return string.byte("'")
    else
      return string.byte(char)
    end
  elseif literal:match("^\"(.+)\"$") then
    local str = literal:match("^\"(.+)\"$")
    local ret = {}
    for i=1, #str do
      table.insert(ret, string.byte(str:sub(i,i)))
    end
    return unpack(ret)
  end
  error("Can't parse literal:" .. tostring(literal))
end


local function parse_args(str)
  str = trim(str)
  local args = {}
  for arg in string.gmatch(str,"[^,]+") do
    arg = trim(arg)
    local carg = {}
    if arg:match("%[.+%]") then
      carg.type = "from_memory"
      local target = arg:match("^%[(.+)%]$"):upper()
      if registers[target] then
        carg.register = target
      else
        carg.literal = parse_literal(target)
      end
    elseif registers[arg] then
      carg.type = "register"
      carg.register = arg
    else
      carg.type = "literal"
      carg.literal = parse_literal(arg)
    end
    table.insert(args, carg)
  end
  return args
end


function assembler.tokenize(str)
  local matchers = {
    {
      "^;(.*)$",
      function(line)
        return {
          type = "comment",
          comment = line
        }
      end
    },{
      "^:(.+)$",
      function(line)
        return {
          type = "label",
          name = line
        }
      end
    },{
      "^DAT (.+)$",
      function(line)
        return {
          type = "data",
          data = pack(parse_literal(line)),
          size = 1
        }
      end
    },{
      "^DAT16 (.+)$",
      function(line)
        return {
          type = "data",
          data = pack(parse_literal(line)),
          size = 2
        }
      end
    },{
      "^([%u_]+) (.*)$",
      function(instr, data)
        return {
          type = "instr",
          instr = instr,
          args = parse_args(data)
        }
      end
    },{
      "^([%u_]+)$",
      function(instr)
        return {
          type = "instr",
          instr = instr,
        }
      end
    },{
      "^([%a_]+) (.-)$",
      function(name, arg)
        return {
          type = "macro",
          name = name,
          arg = arg
        }
      end
    }
  }
  local tokens = {}
  local line_num = 1
  for line in lines(str) do
    line = trim(line)
    if line ~= "" then
      local found = false
      for _, matcher in pairs(matchers) do
        if line:match(matcher[1]) then
          found = true
          local token = matcher[2](line:match(matcher[1]))
          token.line = line
          token.line_num = line_num
          table.insert(tokens, token)
          break
        end
      end
      if not found then
        error("Erro in line " .. line_num .. ": " .. line)
      end
    end
    line_num = line_num + 1
  end
  return tokens
end


local function instr_set(args, write_8, write_16)
  if (args[1].type == "register") and (args[2].type == "from_memory") and (args[2].literal) then
    -- SET A, [0x0000]
    -- Instructions 13-19: set_reg_mem_literal (set register(instruction) based on memory(literal))
    write_8(13 + registers[args[1].register] - 1)
    write_16(args[2].literal)
  elseif (args[1].type == "from_memory") and (args[1].literal) and (args[2].type == "register") then
    -- SET [0x0000], A
    -- Instructions 20-26: set_mem_literal_reg (set memory(literal) based on register(instruction))
    write_8(20 + registers[args[2].register] - 1)
    write_16(args[1].literal)
  elseif (args[1].type == "register") and (args[2].type == "literal") then
    -- SET A, 0x0000
    -- Instructions 27-33: set_reg_literal (set register(instruction) based on literal)
    write_8(27 + registers[args[1].register] - 1)
    write_16(args[2].literal)
  elseif (args[1].type == "register") and (args[2].type == "register") then
    -- SET A, B
    -- Instructions 34-40: set_reg_reg (set register(instruction) based on register(literal))
    write_8(34 + registers[args[1].register] - 1)
    write_8(registers[args[2].register] - 1)
  elseif (args[1].type == "register") and (args[2].type == "from_memory") and (args[2].register) then
    -- SET A, [A]
    -- Instructions 41-47: set_reg_mem_self (set register(instruction) based on register(literal))
    write_8(41 + registers[args[1].register] - 1)
  elseif (args[1].type == "from_memory") and (args[1].register) and (args[2].type == "register") then
    -- SET [A], B
    -- Instructions 55-61: set_mem_reg_reg (set memory at location from register(instruction) to register(literal))
    write_8(55 + registers[args[1].register] - 1)
    write_8(registers[args[2].register] - 1)
    
  elseif (args[1].type == "from_memory") and (args[1].register) and (args[2].type == "literal") then
    -- SET [A], 0x0000
    -- Instructions 62-68: set_mem_reg_literal (set memory at location from register(instruction) to literal)
    write_8(62 + registers[args[1].register] - 1)
    write_16(args[2].literal)
  else
    error("Unsupported SET instruction " ..  args[1].type .. " " .. args[2].type)
  end
end


local function instr_test_eq(args, write_8, write_16)
  local register_num = registers[args[1].register] - 1
  if args[2].type == "literal" then
    -- TESTEQ A, 0xFFFF
    write_8(4) -- instruction test_reg_equal_val
    write_8(register_num) -- register to use
    write_16(args[2].literal) -- value to compare to
  elseif args[2].type == "register" then
    -- TESTEQ A, B
    write_8(6) -- instruction test_reg_equal_reg
    write_8(registers[args[1].register]) -- first register to use
    write_8(registers[args[1].register]) -- second register to use
  else
    error("Unsupportd TESTEQ instruction")
  end
end


local function instr_test_lg(args, write_8, write_16)
  local register_num = registers[args[1].register] - 1
  if args[2].type == "literal" then
    -- TESTLG A, 0xFFFF
    write_8(5) -- instruction test_reg_equal_val
    write_8(register_num) -- register to use
    write_16(args[2].literal) -- value to compare to
  elseif args[2].type == "register" then
    -- TESTLG A, B
    write_8(7) -- instruction test_reg_equal_reg
    write_8(register_num) -- first register to use
    write_8(register_num) -- second register to use
  else
    error("Unsupportd TESTLG instruction")
  end
end


local function instr_add(args, write_8, write_16)
  local register_num = registers[args[1].register] - 1
  if args[2].type == "literal" then
    -- ADD A, 0x0000
    write_8(98)
    write_8(register_num) -- register to use
    write_16(args[2].literal) -- value add to register
  elseif args[2].type == "register" then
    -- ADD A, B
    write_8(48 + registers[args[1].register] - 1) -- register encoded in instruction
    write_8(registers[args[2].register] - 1) -- second register encoded as byte
  else
    error("Unsupportd TESTLG instruction")
  end
end


local function instr_sub(args, write_8, write_16)
  local register_num = assert(registers[args[1].register] - 1)
  if args[2].type == "literal" then
    -- SUB A, 0x0000
    write_8(99)
    write_8(register_num) -- register to use
    write_16(args[2].literal) -- value subtract register with
  elseif args[2].type == "register" then
    -- ADD A, B
    write_8(48 + registers[args[1].register] - 1) -- register encoded in instruction
    write_8(registers[args[2].register] - 1) -- second register encoded as byte
  else
    error("Unsupportd TESTLG instruction")
  end
end


function assembler.tokens_to_bytes(tokens, offset)
  local bytes = {}
  local offset = offset or 0
  
  local function write_8(num)
    assert((num >= 0) and (num < 2^8), "Invalid byte")
    table.insert(bytes, num)
  end
  local function write_16(num)
    if type(num) == "function" then -- Called to write a 16-bit resolved label, but can't resolve the label yet
      -- write the byte-position dependent function to the list of bytes
      table.insert(bytes, num)
      -- and reserve an extra byte
      table.insert(bytes, 0)
      return
    end
    assert((num >= 0) and (num < 2^16), "Invalid word")
    local right = num & 0x00FF
    local left = (num & 0xFF00) >> 8
    table.insert(bytes, left)
    table.insert(bytes, right)
  end
  
  -- generate bytecode, note label locations
  local labels = {}
  for _, token in ipairs(tokens) do
    if token.type == "instr" then
      if token.instr == "SET" then
        instr_set(token.args, write_8, write_16)
      elseif token.instr == "ADD" then
        instr_add(token.args, write_8, write_16)
      elseif token.instr == "ADD" then
        instr_sub(token.args, write_8, write_16)
      elseif token.instr == "IOCALL" then
        write_8(8)
      elseif token.instr == "TRACE" then
        write_8(1)
      elseif token.instr == "FILL" then
        assert(token.args[1].type == "literal")
        local len = assert(tonumber(token.args[1].literal), "Invalid fill lenght")
        local char = tonumber(token.args[2].literal) or 0
        for i=1, len do
          write_8(char)
        end
      elseif token.instr == "GOTO" then
        assert(token.args[1].type == "literal")
        write_8(2)
        write_16(token.args[1].literal)
      elseif token.instr == "TESTEQ" then
        instr_test_eq(token.args, write_8, write_16)
      elseif token.instr == "TESTLG" then
        instr_test_lg(token.args, write_8, write_16)
      elseif token.instr == "IF" then
        if token.args[1].type == "literal" then
          write_8(3)
          write_16(token.args[1].literal)
        end
      elseif token.instr == "HALT" then
        write_8(0)
      else
        error("Unknown instruction: " .. token.line .. " (Line: " .. token.line_num .. ")")
      end
    elseif token.type == "data" then
      for _, data in ipairs(token.data) do
        if token.size == 1 then
          write_8(data)
        elseif token.size == 2 then
          write_16(data)
        end
      end
    elseif token.type == "label" then
      labels[token.name] = #bytes
    elseif token.type == "macro" then
      
    end
  end
  
  -- resolve label locations in code
  for i, byte in ipairs(bytes) do
    if type(byte) == "function" then
      local var = byte(labels) + offset
      local right = var & 0x00FF
      local left = (var & 0xFF00) >> 8
      bytes[i] = left
      bytes[i+1] = right
    end
  end
  
  return bytes
end


return assembler
