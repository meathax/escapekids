
local mach = manager.machine
local cpu = mach.devices[":maincpu"]
local st = cpu.state
local prog = cpu.spaces["program"]
local f = 0
local seen = {}
local out = {}
local fh = io.open("D:/vibes/fpga/temp/claude/D--Arcade-AI-aCORES-escape-kids/ff753708-9f75-4130-b860-7de4cdf9d38e/scratchpad/esck_pc.txt","w")
sub = emu.add_machine_frame_notifier(function()
  f = f + 1
  local pc = st["PC"].value
  local b
  if pc >= 0x8400 and pc <= 0x8600 then b = "SELFTEST_84xx_85xx"
  elseif pc >= 0x8780 and pc <= 0x87c0 then b = "MAINLOOP_879x"
  else b = string.format("%04X", pc) end
  seen[b] = (seen[b] or 0) + 1
  if f==20 or f==60 or f==120 or f==200 or f==300 or f==400 or f==500 or f==560 then
    fh:write(string.format("f=%d PC=%04X wram0002=%02X wram0011=%02X wram0112=%04X\n", f, pc, prog:read_u8(0x0002), prog:read_u8(0x0011), prog:read_u16(0x0112)))
    fh:flush()
  end
  if f >= 590 then
    local r = {}
    for k,v in pairs(seen) do r[#r+1] = k.."="..v end
    table.sort(r)
    fh:write("SAMPLES: "..table.concat(r," ").."\n")
    fh:flush()
    fh:close()
    fh = io.open("D:/vibes/fpga/temp/claude/D--Arcade-AI-aCORES-escape-kids/ff753708-9f75-4130-b860-7de4cdf9d38e/scratchpad/esck_pc.txt","a")
  end
end)
