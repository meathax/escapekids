
local out = {}
local function dump_port(tag)
  local p = manager.machine.ioport.ports[tag]
  if not p then out[#out+1] = tag .. ": NOT FOUND" ; return end
  for name, field in pairs(p.fields) do
    out[#out+1] = string.format("%s | port=%s | mask=0x%X | defvalue=0x%X | type=%s | live=0x%X",
      name, tag, field.mask, field.defvalue or -1, tostring(field.type), field.live and field.live.value or -1)
  end
end
dump_port(":EEPROM")
dump_port(":SERVICE")
local f = io.open("eeprom_ioport_dump.txt","w")
f:write(table.concat(out, "\n"))
f:close()
