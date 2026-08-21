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
        else
            // GX975 (Escape Kids) horizontal zoom register is reciprocal in
            // MAME (k053246_k053247_k055673.h,
            // k053247_draw_single_sprite_gxcore): zoomx=(0x400000+(raw>>1))/raw,
            // then halved again unconditionally for Escape Kids
            // (objset1 bit3, == this gx975_path). jtframe_draw's own
            // hz_cnt/HZONE accumulator is independently reciprocal in hzoom
            // (S=HZONE/hzoom), so the two reciprocals compose into a single
            // exact linear map: hzoom = 2*raw, uniformly for every raw code.
            // (Verified: rtl/esckids/verify/tb_esckids_obj_zoom.sv sweeps
            // raw=1..0x3ff against the real MAME formula above.) A prior
            // hard-coded raw==0x020 -> hzoom=0x041 exception broke this
            // uniformity at exactly one raw value, producing a one-frame
            // discontinuity every time the coin-icon animation's zoom
            // register passed through 0x020 - the jagged/notched disc edge.
            hzoom = zoom_in << 1;
    end
endmodule
