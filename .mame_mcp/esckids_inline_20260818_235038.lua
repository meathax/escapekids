local snapdir = "D:/vibes/fpga/temp/claude/D--Arcade-AI-aCORES-escape-kids/ff753708-9f75-4130-b860-7de4cdf9d38e/scratchpad/esckids_snaps"
emu.subscribe_prewrite = nil
local shots = {60, 120, 180, 240, 300, 420, 600}
local idx = 1
local f = io.open("D:/vibes/fpga/temp/claude/D--Arcade-AI-aCORES-escape-kids/ff753708-9f75-4130-b860-7de4cdf9d38e/scratchpad/snaplog.txt","w")
emu.register_frame_done(function()
  local n = manager.machine.screens[":screen"]:frame_number()
  if idx <= #shots and n >= shots[idx] then
    manager.machine.video:snapshot()
    f:write(string.format("snapshot at frame %d\n", n))
    f:flush()
    idx = idx + 1
  end
  if idx > #shots then
    f:write("done\n"); f:close()
    manager.machine:exit()
  end
end)
