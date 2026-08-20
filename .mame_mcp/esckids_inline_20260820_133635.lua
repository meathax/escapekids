
local path = "D:\\Arcade\\AI\\aCORES\\escape kids\\.mame_mcp\\k052109_int_en2.txt"
local f = io.open(path, "w")
f:write("start\n")
f:flush()

local ok, err = pcall(function()
  local cpu = manager.machine.devices[":maincpu"]
  f:write("maincpu ok\n")
  local sp = cpu.spaces["program"]
  f:write("space ok\n")
  local seen = {}
  local firq_count = 0
  local regpage_writes = 0

  sp:install_write_tap(0x3d00, 0x3dff, "k052109regs", function(offset, data, mask)
      regpage_writes = regpage_writes + 1
      local key = string.format("%04x=%02x", offset, data)
      if not seen[key] then
        seen[key] = true
        f:write(string.format("W addr=%04X data=%02X\n", offset, data))
        f:flush()
      end
      if offset == 0x3d02 then
        if ((data >> 1) & 1) == 1 then firq_count = firq_count + 1 end
        f:write(string.format("REG_INT data=%02X nmi0=%d firq1=%d irq2=%d\n",
            data, data & 1, (data >> 1) & 1, (data >> 2) & 1))
        f:flush()
      end
      return data
  end)
  f:write("tap installed\n")
  f:flush()

  emu.add_machine_stop_notifier(function()
      f:write(string.format("SUMMARY regpage_writes=%d firq_enable_writes=%d\n", regpage_writes, firq_count))
      if firq_count > 0 then f:write("FIRQ_ENABLE_WAS_SET\n") else f:write("FIRQ_ENABLE_NEVER_SET\n") end
      f:flush(); f:close()
  end)
end)

if not ok then
  f:write("ERROR: " .. tostring(err) .. "\n")
  f:flush(); f:close()
end
