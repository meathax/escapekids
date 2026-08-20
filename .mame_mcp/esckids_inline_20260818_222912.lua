local out = io.open("ccu_writes.log","w")
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local taps = {}
taps[#taps+1] = mem:install_write_tap(0x3fc0,0x3fcf,"ccu",function(offset,data,mask)
  out:write(string.format("f=%d reg=%X data=%02X\n", manager.machine.screens[":screen"]:frame_number(), offset-0x3fc0, data & 0xff))
end)
local n=0
emu.register_frame_done(function()
  n=n+1
  if n>=400 then out:close(); manager.machine:exit() end
end)