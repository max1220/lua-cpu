local instructions = require("instructions")

function new_cpu()
    local computer = {}
    
    local peripherals = {}
    computer.peripherals = peripherals
    local memory_size = 0xFFFF
    local memory = {}
    for i=0, memory_size do
        memory[i] = 0
    end
    computer.memory = memory
    
    local registers = {
        A = 0,
        B = 0,
        C = 0,
        D = 0,
        X = 0,
        Y = 0,
        Z = 0,
        PC = 0,
    }
    computer.registers = registers
    
    local flags = {
      overflow = false,
      test = false,
      busy = false
    }
    computer.flags = flags
    computer.interrupt_addr = 0x0000
    computer.interrupt_state = interrupt_state
    
    function computer:get_mem_8(addr)
        local addr = math.max(math.min(addr, memory_size), 0)
        return memory[addr]
    end
    
    function computer:get_mem_16(addr)
        local addr = math.max(math.min(addr, memory_size-1), 0)
        local left = memory[addr]
        local right = memory[addr+1]
        local val = (left << 8) + right
        return val
    end
    
    function computer:set_mem_8(addr, val)
        local addr = math.max(math.min(addr, memory_size), 0)
        local val = math.max(math.min(val, 0xFF), 0)
        memory[addr] = math.floor(val)
    end
    
    function computer:set_mem_16(addr, val)
        local addr = math.max(math.min(addr, memory_size-1), 0)
        local val = math.max(math.min(val, 0xFFFF), 0)
        local right = val & 0x00FF
        local left = (val & 0xFF00) >> 8
        memory[addr] = math.floor(left)
        memory[addr+1] = math.floor(right)
    end

    function computer:io_call()
      for _, peripheral in ipairs(self.peripherals) do
        if peripheral.io_call then
          peripheral:io_call()
        end
      end
    end
    
    function computer:step()
        for _, peripheral in ipairs(self.peripherals) do
          if peripheral.update then
            peripheral:update(self)
          end
        end
        local instr = self:get_mem_8(self.registers.PC)
        if instructions[instr + 1] then
          local pc_mod = instructions[instr + 1](self)
          self.registers.PC = self.registers.PC + pc_mod
        else
          error("Unknown instruction: ", instr)
        end
    end
    
    function computer:run(max_steps)
      local max_steps = tonumber(max_steps) or math.huge
      local steps = 0
      self.running = true
      while self.running do
        self:step()
        steps = steps + 1
        if steps <= max_steps then
          return steps
        end
      end
      return steps
    end
    
    function computer:load_string(addr, str)
      for i=1, #str do
        local b = string.byte(str, i)
        computer:set_mem_8(addr + i - 1, b)
      end
    end
    
    function computer:load_bytes(addr, bytes)
      for k,v in pairs(bytes) do
        computer:set_mem_8(addr + k - 1, v)
      end
    end
    
    function computer:interrupt(registers)
      -- TODO
      -- save registers
      -- store interrupt info in registers
      -- goto global interrupt handler
      -- on end_interrupt instruction: restore registers, goto original pc
      if self.interrupt_state then
        -- Another interrupt is still in progress, can't interrupt now
        self.flags.busy = true
        return false
      else
        local interrupt_state = {
          registers = {},
        }
        for k,v in pairs(self.registers) do
          interrupt.registers[k] = v
        end
        for k,v in pairs(registers) do
          self.registers[k] = v
        end
        self.interrupt_state = interrupt_state
        self.registers.PC = self.interrupt_addr
        self.flags.busy = false
        return true
      end
    end
    
    function computer:interrupt_restore()
      if self.interrupt_state then
        for k,v in pairs(interrupt_state.registers) do
          self.registers[k] = v
        end
        self.interrupt_state = false
        return true
      else
        return false
      end
    end
    
    function computer:interrupt_discard()
      self.interrupt_state = false
    end
    
    function computer:dump_registers()
      print("Registers:")
      local registers = {}
      for k,v in pairs(self.registers) do
        table.insert(registers, (" %s:\t 0x%.4X"):format(k,v))
      end
      table.sort(registers)
      local ret = table.concat(registers, "\n")
      print(ret)
      return ret
    end
    
    function computer:dump_flags()
      print("Flags:")
      local flags = {}
      for k,v in pairs(self.flags) do
        table.insert(flags, (" %s:\t %s"):format(k,tostring(v)))
      end
      table.sort(flags)
      local ret = table.concat(flags, "\n")
      print(ret)
      return ret
    end
    
    function computer:dump_memory(start, len)
      local line_width = 8
      local lines_count = math.ceil(len / line_width)
      local lines = {("Memory(Start at 0x%.4X, len 0x%.4X):"):format(start, len)}
      for i=1, lines_count do
        local cline = {
          (" %.4X: "):format(start + (i-1)*line_width)
        }
        for j=1, line_width do
          local addr = start + (i-1) * line_width + (j-1)
          table.insert(cline, ("0x%.2X"):format(self:get_mem_8(addr)))
        end
        table.insert(cline, (" :%.4X"):format(start + (i-1)*line_width + 7))
        table.insert(lines, table.concat(cline, " "))
      end
      local ret = table.concat(lines, "\n")
      print(ret)
      return ret
    end
    
    function computer:dump()
      self:dump_registers()
      self:dump_flags()
      self:dump_memory(0x0000, 128)
    end
    
    return computer
end
  
return {
  new_cpu = new_cpu,
}

