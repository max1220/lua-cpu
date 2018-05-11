-- generate a new graphics output. 

function new_graphics_card(computer, _modes, mode_callback)
  local graphics_card = {}
  graphics_card.hardware_id = 0xFF02
  graphics_card.memory_size = 0x00025800
  graphics_card.pc_mem_addr = 0x0000
  graphics_card.fb_addr = 0x00000000
  graphics_card.mode_offset = 0xFF10
  
  -- default modes
  local _modes = (type(_modes) == "table" and _modes) or {
    {160, 120, {1,2,4,8}, "direct"},
    {320, 240, {1,2,4}, "direct"},
    {640, 480, {1}, "direct"},
    {160, 120, {1,2,4,8}, "indirect"},
    {320, 240, {1,2,4,8}, "indirect"},
    {640, 480, {1,2,4,8}, "indirect"},
    {800, 600, {1,2}, "indirect"},
    {1024, 768, {1}, "indirect"},
  }
  
  
  local modes = {}
  for _, mode in ipairs(_modes) do
    for _, bpp in ipairs(mode[3]) do
      local w = mode[1]
      local h = mode[2]
      local mode = mode[4]
      table.insert(modes, { width=w, height=h, bpp=bpp, mode=mode, len=(w*h*bpp)/8})
    end
  end
  graphics_card.modes = modes
  graphics_card.mode = graphics_card.modes[1]
  
  
  local pallet = {}
  for i=0, 255 do
    pallet[i] = {i,i,i}
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
    io:flush()
    return ret
  end
  
  function graphics_card:draw_unicode()
    self:_draw_unicode(self.get_pixel_1)
  end
  
  function graphics_card:draw_simple()
    self:_draw_simple(self.get_pixel_1)
  end
  
  function graphics_card:prepare_fb(fbdev, mode, ox, oy, auto_flush)
    local mode = mode or self.modes
    local lfb = require("lfb")
    local fb = lfb.new_framebuffer(fbdev)
    local info = fb:get_varinfo()
    local db = lfb.new_drawbuffer(self.mode.width, self.mode.height)
    self._fb = {
      lfb = lfb,
      fb = fb,
      info = info,
      db = db,
      ox = ox,
      oy = oy,
      auto_flush = auto_flush
    }
  end
  
  function graphics_card:draw_fb(ox, oy)
    for y=0, height-1 do
      for x=0, width-1 do
        local px = get_pixel(self, x,y,width)
        if px == 0 then
          self._fb.db:set_pixel(x,y,0,0,0,255)
        else
          self._fb.db:set_pixel(x,y,255,255,255,255)
        end
      end
    end
    self._fb.db:draw_to_framebuffer(self._fb.fb, ox,oy)
  end
  
  function graphics_card:io_call()
    local mode = computer.registers.A - self.mode_offset
    if mode == 0x0000 then
      -- change mode(B=mode, C=pc start address)
      self.pc_mem_addr = computer.registers.C
      self.mode = self.modes[computer.registers.B + 1]
      self._fb = nil
      if mode_callback then
        mode_callback(computer)
      end
    elseif mode == 0x0001 then
      -- set framebuffer address
      local addr = computer.registers.B*256 + computer.registers.C
      self.fb_addr = addr
    elseif mode == 0x0002 then
      -- write len bytes to gpu_mem[offset+i] from memory[self.pc_mem_addr+i]
      local len = computer.registers.B
      local offset = computer.registers.C*256 + computer.registers.D
      for i=self.pc_mem_addr, self.pc_mem_addr+len-1 do
        self.memory[offset + i] = computer.memory[i]
      end
    elseif mode == 0x0003 then
      -- read len bytes to memory[self.pc_mem_addr+i] from gpu_mem[offset+i]
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

return new_graphics_card