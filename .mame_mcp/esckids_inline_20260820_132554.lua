
local cpu = manager.machine.devices[":maincpu"]
local prog = cpu.spaces["program"]
wcount = {}; wlast = {}; wfirst = {}
for i=0,15 do wcount[i]=0; wlast[i]=-1; wfirst[i]=-1 end
curframe = 0
tap = prog:install_write_tap(0x3FC0, 0x3FCF, "ccu", function(offset, data, mask)
  local i = offset - 0x3FC0
  wcount[i] = wcount[i] + 1
  wlast[i] = data
  if wfirst[i] < 0 then wfirst[i] = curframe end
  return data
end)
local pollprev = {}
for i=0,15 do pollprev[i] = -1 end
pollchg = {}
local f=0
sub = emu.add_machine_frame_notifier(function()
  f=f+1; curframe=f
  for i=0,13 do
    local v = prog:read_u8(0x3FC0+i)
    if v ~= pollprev[i] then
      pollchg[#pollchg+1] = string.format("f=%d reg%02X=%02X", f, i, v)
      pollprev[i] = v
    end
  end
  if f==555 then
    local fh=io.open("D:/vibes/fpga/temp/claude/D--Arcade-AI-aCORES-escape-kids/ff753708-9f75-4130-b860-7de4cdf9d38e/scratchpad/esck_ccu.txt","w")
    fh:write("=== TAP (writes to 0x3FC0-0x3FCF) ===\n")
    for i=0,15 do
      fh:write(string.format("reg%02X: writes=%d firstFrame=%d last=%02X\n", i, wcount[i], wfirst[i], (wlast[i]<0 and 0 or wlast[i])))
    end
    fh:write("=== POLL (register value changes) ===\n")
    fh:write(table.concat(pollchg,"\n").."\n")
    fh:close()
  end
end)
