local n=0
emu.register_frame_done(function()
  n=n+1
  if n==5 then
    local f=io.open("D:/Arcade/AI/aCORES/escape kids/.mame_mcp/shares.txt","w")
    for tag,sh in pairs(manager.machine.memory.shares) do f:write(string.format("share %s size=%d width=%d\n", tag, sh.size, sh.bitwidth)) end
    for tag,rg in pairs(manager.machine.memory.regions) do f:write(string.format("region %s size=%d\n", tag, rg.size)) end
    for tag,dev in pairs(manager.machine.devices) do f:write("dev "..tag.."\n") end
    f:close(); manager.machine:exit()
  end
end)
