local peripherals = {}

function peripherals.new_text_console(computer, char_callback, input_callback, pixel_callback, parm_callback)
  local text_console = {}
  text_console.hardware_id_send = 0xFF00
  text_console.hardware_id_recv = 0xFF01
  function text_console:io_call()
    local hwid = computer.registers.A
    if hwid == self.hardware_id_send then
      -- send character to console
      if char_callback then
        char_callback(computer.registers.C & 0x00FF)
      end
    elseif hwid == self.hardware_id_recv then
      -- get character from console
      if input_callback then
        computer.registers.C = tonumber(input_callback(computer.registers.C)) or 0
      end
    end
  end
  return text_console
end

function peripherals.new_graphics_card(computer, pixel_callback)
  local graphics_card = {}
  graphics_card.hardware_id = 0xFF02
  graphics_card.memory_size = 0x00025800
  graphics_card.pc_mem_addr = 0x0000
  graphics_card.fb_addr = 0x00000000
  graphics_card.mode_offset = 0xFF10
  
  local modes = {}
  local function add_modes(width, height, bpps, direct)
    for _, bpp in ipairs(bpps) do
      table.insert(modes, { width=width, height=height, bpp=bpp, mode=direct, len=(width * height * bpp)/8})
    end
  end
  add_modes(160, 120, {1,2,4,8}, "direct")
  add_modes(320, 240, {1,2,4}, "direct")
  add_modes(640, 480, {1}, "direct")
  add_modes(160, 120, {1,2,4,8}, "indirect")
  add_modes(320, 240, {1,2,4,8}, "indirect")
  add_modes(640, 480, {1,2,4,8}, "indirect")
  add_modes(800, 600, {1,2}, "indirect")
  add_modes(1024, 768, {1}, "indirect")
  
  graphics_card.modes = modes
  graphics_card.mode = graphics_card.modes[1]
  
  
  local pallet = {}
  for i=0, 255 do
    pallet[i] = {0,0,0}
  end
  graphics_card.pallet = pallet
  
  local memory = {}
  for i=0, graphics_card.memory_size-1 do
    memory[i] = 0
  end
  graphics_card.memory = memory
  
  function graphics_card:get_pixel_1(x,y,width)
    local addr = math.floor((y*width + x )/8)
    local sub_addr = (y*width + x )%8
    local val
    if self.mode.mode == "direct" then
      val = computer:get_mem_8(addr + self.pc_mem_addr)
    else
      val = self.memory[addr+1]
    end
    if (val & (2^sub_addr)) > 0 then
      return 1
    else
      return 0
    end
  end
  
  function graphics_card:_draw_simple(get_pixel, empty, set)
    local width = self.mode.width
    local height = self.mode.height
    local empty = "."
    local set = "#"
    for y=0, height-1 do
      local cline = {}
      for x=0, width-1 do
        local px = get_pixel(self, x,y,width)
        if px == 0 then
          cline[#cline + 1] = empty
        else
          cline[#cline + 1] = set
        end
      end
      print(table.concat(cline))
    end
    print("\n")
    io:flush()
  end
  
  function graphics_card:_draw_unicode(get_pixel)
    -- render in unicode braile symbols(1 symbel per 2*x and 4*y)
    local width = self.mode.width
    local height = self.mode.height
    local function _get_pixel(x,y)
      return math.max(math.min(get_pixel(self, x, y, width), 1), 0)
    end
    local values = {}
    for y=0, (height/4)-1 do
      for x=0, (width/2)-1 do
        local rx = x*2
        local ry = y*4
        local char_num = 0
        
        -- left 3
        char_num = char_num | _get_pixel(rx+0, ry+0) 
        char_num = char_num | _get_pixel(rx+0, ry+1) << 1
        char_num = char_num | _get_pixel(rx+0, ry+2) << 2
        
        --right 3
        char_num = char_num | _get_pixel(rx+1, ry+0) << 3
        char_num = char_num | _get_pixel(rx+1, ry+1) << 4
        char_num = char_num | _get_pixel(rx+1, ry+2) << 5
        
        --bottom 2
        char_num = char_num | _get_pixel(rx+0, ry+3) << 6
        char_num = char_num | _get_pixel(rx+1, ry+3) << 7
        
        local unicode_braile = 0x2800 + char_num
        table.insert(values, utf8.char(unicode_braile))
      end
      table.insert(values, "\n") -- \n
    end
    local ret = table.concat(values)
    print(ret)
    return ret
  end
  
  function graphics_card:draw_unicode()
    self:_draw_unicode(self.get_pixel_1)
  end
  
  function graphics_card:draw_simple()
    self:_draw_simple(self.get_pixel_1)
  end
  
  function graphics_card:io_call()
    local mode = computer.registers.A - self.mode_offset
    if mode == 0x0000 then
      -- configure memory layout(B=mode, C=pc start address)
      self.pc_mem_addr = computer.registers.C
      self.mode = self.modes[computer.registers.B + 1]
    elseif mode == 0x0001 then
      -- set framebuffer address
      local addr = computer.registers.B*256 + computer.registers.C
      self.fb_addr = addr
    elseif mode == 0x0002 then
      -- write len bytes to gpu_mem[offset+i] from memory[self.start_addr+i]
      local len = computer.registers.B
      local offset = computer.registers.C*256 + computer.registers.D
      for i=self.pc_mem_addr, self.pc_mem_addr+len-1 do
        self.memory[offset + i] = computer.memory[i]
      end
    elseif mode == 0x0003 then
      -- read len bytes to memory[self.start_addr+i] from gpu_mem[offset+i]
      local len = computer.registers.B
      local offset = computer.registers.C*256 + computer.registers.D
      for i=self.pc_mem_addr, self.pc_mem_addr+len-1 do
        computer.memory[i] = self.memory[offset+i]
      end
    elseif mode == 0x0004 then
      -- set pallet entry
      local i = computer.registers.B
      local r = (computer.registers.C & 0xFF00) >> 8
      local g = computer.registers.C & 0x00FF
      local b = computer.registers.D & 0x00FF
      self.pallet[i] = {r,g,b}
    elseif mode == 0x0005 then
      -- clear screen
      local v = computer.registers.B & 0x00FF
      for i=1, self.mode.len do
        if self.mode.mode == "direct" then
          computer:set_mem_8(self.pc_mem_addr + i - 1, v)
        else
          self.memory[self.fb_addr + i - 1] = v
        end
      end
    elseif mode == 0x0006 then
      -- debug: print current screen as unicode
      self:draw_unicode()
    end
  end
  return graphics_card
end

function peripherals.new_io_call_debugger(computer)
  return {
    io_call = function(self, computer)
      print("Got IOCALL")
      computer:dump()
    end
  }
end

return peripherals