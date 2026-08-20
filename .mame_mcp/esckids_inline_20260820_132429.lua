
local cpu = manager.machine.devices[":maincpu"]
local st = cpu.state
local prog = cpu.spaces["program"]
local z80 = manager.machine.devices[":audiocpu"]
local f=0
local last=nil
local lines={}
local firstpass=nil
local inpoll=0
sub = emu.add_machine_frame_notifier(function()
  f=f+1
  local pc = st["PC"].value
  local p6 = prog:read_u8(0x3FD6)
  local p7 = prog:read_u8(0x3FD7)
  local key = string.format("%02X:%02X", p6, p7)
  if key ~= last then
    lines[#lines+1] = string.format("f=%d 3FD6=%02X 3FD7=%02X mainPC=%04X z80PC=%04X", f, p6, p7, pc, z80.state["PC"].value)
    last = key
  end
  if pc>=0x84ad and pc<=0x84c1 then inpoll=inpoll+1 end
  if f==415 then
    local fh=io.open("D:/vibes/fpga/temp/claude/D--Arcade-AI-aCORES-escape-kids/ff753708-9f75-4130-b860-7de4cdf9d38e/scratchpad/esck_snd.txt","w")
    fh:write("framesInPoll="..inpoll.."\n")
    fh:write(table.concat(lines,"\n").."\n")
    fh:close()
  end
end)
