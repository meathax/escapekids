
-- Watch CPU writes to the K052109 register page 0x3D00-0x3DFF (esckids mapping)
-- and specifically 0x3D00+2 == REG_INT (0x1D00 in chip terms) bit1 = FIRQ enable.
local out = {}
local cpu = manager.machine.devices[":maincpu"]
local sp = cpu.spaces["program"]
local seen = {}
local firq_set_frames = {}
local reg_writes = 0

local function log(s) out[#out+1] = s end

local wp = sp:install_write_tap(0x3d00, 0x3dff, "k052109regs", function(offset, data, mask)
    reg_writes = reg_writes + 1
    local fr = manager.machine.screens[":screen"]:frame_number()
    local key = string.format("%04x=%02x", offset, data)
    if not seen[key] then
        seen[key] = true
        log(string.format("frame=%d addr=%04X data=%02X", fr, offset, data))
    end
    -- REG_INT is chip register index 2 -> CPU 0x3D02 under this mapping
    if offset == 0x3d02 then
        log(string.format("REG_INT frame=%d data=%02X firq_bit1=%d irq_bit2=%d nmi_bit0=%d",
            fr, data, (data >> 1) & 1, (data >> 2) & 1, data & 1))
        if ((data >> 1) & 1) == 1 then
            firq_set_frames[#firq_set_frames+1] = fr
        end
    end
    return data
end)

emu.add_machine_frame_notifier(function()
    local fr = manager.machine.screens[":screen"]:frame_number()
    if fr >= 650 then
        log(string.format("SUMMARY total_regpage_writes=%d firq_enable_set_count=%d", reg_writes, #firq_set_frames))
        if #firq_set_frames > 0 then
            log("FIRQ_ENABLE_WAS_SET first_frame=" .. tostring(firq_set_frames[1]))
        else
            log("FIRQ_ENABLE_NEVER_SET")
        end
        local f = io.open("D:\\Arcade\\AI\\aCORES\\escape kids\\.mame_mcp\\k052109_int_en.txt", "w")
        f:write(table.concat(out, "\n"))
        f:close()
        manager.machine:exit()
    end
end)
