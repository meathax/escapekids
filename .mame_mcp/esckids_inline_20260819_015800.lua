local log={}
local sp=manager.machine.devices[":maincpu"].spaces["program"]
local tap=sp:install_write_tap(0x6000,0x7fff,"wtap",function(offset,data,mask)
  log[#log+1]=string.format("%04X <= %02X pc=%04X", offset, data, manager.machine.devices[":maincpu"].state["PC"].value)
  return data
end)
local n=0
emu.register_frame_done(function()
  n=n+1
  if n==25 then
    local f=io.open("D:/Arcade/AI/aCORES/escape kids/.mame_mcp/wr2.txt","w")
    for i=1,math.min(#log,40) do f:write(log[i].."\n") end
    f:write("total "..#log.."\n")
    f:close(); manager.machine:exit()
  end
end)
