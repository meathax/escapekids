local log = assert(io.open("D:/Arcade/AI/aCORES/escape kids/.mame_mcp/esckids_ioports_20260819_152749.log", "w"))
local function w(s) log:write(s .. "\n"); log:flush() end
w("# mame_mcp ioport list")
for tag, port in pairs(manager.machine.ioport.ports) do
  for fname, field in pairs(port.fields) do
    w(string.format("PORT\t%s\tFIELD\t%s", tostring(tag), tostring(fname)))
  end
end
log:close()
manager.machine:exit()
