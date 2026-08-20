local hist={}
local cpu=manager.machine.devices[":maincpu"]
local sp=cpu.spaces["program"]
local tap=sp:install_write_tap(0x0000,0x7fff,"wtap",function(offset,data,mask)
  local k=offset & 0xff80
  hist[k]=(hist[k] or 0)+1
  return data
end)
local n=0
emu.register_frame_done(function()
  n=n+1
  if n==25 then
    local f=io.open("D:/Arcade/AI/aCORES/escape kids/.mame_mcp/wr.txt","w")
    local keys={}
    for k in pairs(hist) do keys[#keys+1]=k end
    table.sort(keys)
    for _,k in ipairs(keys) do f:write(string.format("%04X count %d\n",k,hist[k])) end
    f:close(); manager.machine:exit()
  end
end)
