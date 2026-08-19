// Executable arithmetic contract for the producer-side GX975 branch.  The
// production scanner keeps the same equations in its clocked state machine;
// this compact module makes the MAME-derived boundary vectors cheap to run.
module escape_kids_gx975_math(
    input  logic        enable,
    input  logic        hw_enable,   // strap only, independent of OBJSET1 bit 3
    input  logic        flip_x,
    input  logic [15:0] scan_odd,
    input  logic [11:0] zoom_in,
    input  logic [9:0]  xoffset,
    output logic [9:0]  x_start,
    output logic [11:0] hzoom,
    output logic [9:0]  xadj
);
    logic [9:0] half_x;
    logic [10:0] flipped_x;
    always_comb begin
        // 053246/7 subtracts the display-window offset (MAME ox-offx); the
        // 053244/5 donor adds it (MAME ox+spriteoffsX).  110 = the shared
        // jtframe_objdraw pipeline constant 105 plus MAME's esckids dx=5.
        xadj = hw_enable ? (10'd110 - xoffset) : (xoffset + 10'h66);
        half_x = {1'b0, scan_odd[9:1]} + 10'd1;
        flipped_x = {1'b0, half_x} + 11'd384;
        if (!enable)
            x_start = flip_x ? -scan_odd[9:0] : scan_odd[9:0];
        else
            x_start = flip_x ? -flipped_x[9:0] : half_x;
        if (!enable)
            hzoom = zoom_in;
        else begin
            hzoom = zoom_in << 1;
            if (zoom_in == 12'h020) hzoom = 12'h041;
        end
    end
endmodule
