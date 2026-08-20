local n = 0
local f = io.open("D:/Arcade/AI/aCORES/escape kids/.mame_mcp/snapindex.txt","w")
emu.register_frame_done(function()
  n = n + 1
  if n % 10 == 0 and n <= 700 then
    manager.machine.video:snapshot()
    f:write(string.format("frame %d\n", n)); f:flush()
  end
  if n >= 705 then f:close(); manager.machine:exit() end
end)
