`timescale 1ns/1ps
// Strip-diagnostic overlay for the Escape Kids 8x1 blue-background strips.
//
// Purpose: separate, in a single on-hardware screenshot, the two remaining
// root-cause classes for the strips:
//   write-side - the ROM download dropped words, so SDRAM tile data is
//                corrupt (reported by jtframe_dwnld's ovfl_cnt);
//   read-side  - a tilemap layer fetch missed the K051962's fixed 64-clk48
//                pixel-load deadline at runtime, displaying a stale word
//                (detected here per layer, per scanline).
//
// A layer fetch is counted "late" only when its address advances to the next
// tile group while the previous request NEVER reached ok - that fetch
// definitively displayed stale data; there is no softer interpretation.
// Purely observational: nothing here loads the SDRAM slots or the video
// pipeline; the overlay is a mux on the final RGB output.
//
// On-screen readout (no keyboard, no OSD dependency):
//  - Left-edge scanline ticks, drawn on the line AFTER the event (one-line
//    offset, keeps the logic trivial): x0-1 red = lyrb late, x2-3 green =
//    lyra late, x4-5 cyan = lyrf late.
//  - Top-left binary counter block, five rows of 8 bits, MSB leftmost,
//    each bit a 4x4px block (bright = 1, dim = 0), one hue per row:
//      row0 y4-7   yellow  : download FIFO drops (ovfl_cnt)
//      row1 y12-15 red     : lyrb late-fetch count
//      row2 y20-23 green   : lyra late-fetch count (advisory: also counts
//                            CPU rmrd tile-ROM reads during service tests)
//      row3 y28-31 cyan    : lyrf late-fetch count
//      row4 y36-39 magenta : lyrb worst-case addr->ok latency in clk48
//                            cycles (saturating; the hardware budget is 64,
//                            so any value < 64 exonerates lyrb timing)
// All counters saturate and are sticky until reset.
module escape_kids_strip_diag #(parameter COLORW=8)(
    input                     clk,      // 48 MHz game clock
    input                     rst,
    input                     pxl_cen,
    input                     ena,      // count enable: download finished
    // layer ROM fetch taps (observed only)
    input        [19:2]       lyrf_addr, lyra_addr, lyrb_addr,
    input                     lyrf_cs, lyra_cs, lyrb_cs,
    input                     lyrf_ok, lyra_ok, lyrb_ok,
    // download drop count from jtframe_dwnld
    input        [ 7:0]       ovfl_cnt,
    // video pass-through
    input                     LHBL, LVBL,
    input  [COLORW-1:0]       game_r, game_g, game_b,
    output reg [COLORW-1:0]   red, green, blue
);

localparam [COLORW-1:0] BRT = {COLORW{1'b1}},
                        DIM = {COLORW{1'b1}} >> 3; // dim placeholder for 0 bits

// ---------------------------------------------------------------- detectors
// One tracker per layer: remember the address of the outstanding request and
// whether it ever reached ok. When the address moves on without ok having
// been seen, that fetch displayed stale data -> late event.
reg [19:2] f_addr_l, a_addr_l, b_addr_l;
reg        f_got,    a_got,    b_got;
reg [ 7:0] f_late,   a_late,   b_late;
reg        f_line,   a_line,   b_line;   // event seen on current line
reg        f_disp,   a_disp,   b_disp;   // marker for the following line

wire f_new = lyrf_cs && (lyrf_addr != f_addr_l);
wire a_new = lyra_cs && (lyra_addr != a_addr_l);
wire b_new = lyrb_cs && (lyrb_addr != b_addr_l);

// lyrb service-latency high-water mark, in clk48 cycles
reg [7:0] b_lat, b_maxlat;
reg       LHBL_d; // full-rate delay for the line handover edge

always @(posedge clk) begin
    if( rst ) begin
        f_addr_l <= 0; a_addr_l <= 0; b_addr_l <= 0;
        f_got    <= 1; a_got    <= 1; b_got    <= 1;
        f_late   <= 0; a_late   <= 0; b_late   <= 0;
        f_line   <= 0; a_line   <= 0; b_line   <= 0;
        f_disp   <= 0; a_disp   <= 0; b_disp   <= 0;
        b_lat    <= 0; b_maxlat <= 0;
        LHBL_d   <= 0;
    end else begin
        // layer F
        if( f_new ) begin
            if( ena && !f_got ) begin
                if( f_late != 8'hff ) f_late <= f_late + 8'd1;
                f_line <= 1;
            end
            f_addr_l <= lyrf_addr;
            f_got    <= 0;
        end else if( lyrf_ok ) f_got <= 1;
        // layer A
        if( a_new ) begin
            if( ena && !a_got ) begin
                if( a_late != 8'hff ) a_late <= a_late + 8'd1;
                a_line <= 1;
            end
            a_addr_l <= lyra_addr;
            a_got    <= 0;
        end else if( lyra_ok ) a_got <= 1;
        // layer B + latency high-water mark
        if( b_new ) begin
            if( ena && !b_got ) begin
                if( b_late != 8'hff ) b_late <= b_late + 8'd1;
                b_line <= 1;
            end
            b_addr_l <= lyrb_addr;
            b_got    <= 0;
            b_lat    <= 0;
        end else begin
            if( lyrb_ok && !b_got ) begin
                b_got <= 1;
                if( ena && b_lat > b_maxlat ) b_maxlat <= b_lat;
            end
            if( !b_got && b_lat != 8'hff ) b_lat <= b_lat + 8'd1;
        end
        // per-line marker handover at the start of horizontal blanking,
        // edge-detected at the full clock rate so it fires exactly once
        LHBL_d <= LHBL;
        if( LHBL_d && !LHBL ) begin
            f_disp <= f_line; a_disp <= a_line; b_disp <= b_line;
            f_line <= 0;      a_line <= 0;      b_line <= 0;
        end
    end
end

// ---------------------------------------------------------------- position
reg [8:0] xcnt;
reg [8:0] ycnt;
reg       LHBL_l;

always @(posedge clk) if( pxl_cen ) begin
    LHBL_l <= LHBL;
    if( !LHBL ) xcnt <= 0;
    else        xcnt <= xcnt + 9'd1;
    if( !LVBL )              ycnt <= 0;
    else if( LHBL && !LHBL_l ) ycnt <= ycnt + 9'd1;
end

// ---------------------------------------------------------------- overlay
// Row select for the counter block: 4px-tall rows on an 8px pitch.
wire       in_block = LVBL && LHBL && xcnt < 9'd32 && ycnt >= 9'd4 && ycnt < 9'd40 && ycnt[2];
wire [2:0] blk_row  = ycnt[5:3];          // 0..4 within the block region
wire [2:0] blk_bit  = 3'd7 - xcnt[4:2];   // MSB leftmost
reg  [7:0] row_val;
reg  [2:0] row_hue;                       // {r,g,b} enables

always @* begin
    case( blk_row )
        3'd0:    begin row_val = ovfl_cnt; row_hue = 3'b110; end // yellow
        3'd1:    begin row_val = b_late;   row_hue = 3'b100; end // red
        3'd2:    begin row_val = a_late;   row_hue = 3'b010; end // green
        3'd3:    begin row_val = f_late;   row_hue = 3'b011; end // cyan
        default: begin row_val = b_maxlat; row_hue = 3'b101; end // magenta
    endcase
end

wire        bit_on  = row_val[blk_bit];
wire        in_tick = LVBL && LHBL && xcnt < 9'd6 && ycnt >= 9'd44;
wire [2:0]  tick_hue = xcnt < 9'd2 ? 3'b100 :        // lyrb -> red
                       xcnt < 9'd4 ? 3'b010 :        // lyra -> green
                                     3'b011;         // lyrf -> cyan
wire        tick_on  = xcnt < 9'd2 ? b_disp :
                       xcnt < 9'd4 ? a_disp : f_disp;

always @* begin
    red   = game_r;
    green = game_g;
    blue  = game_b;
    if( in_block ) begin
        red   = row_hue[2] ? (bit_on ? BRT : DIM) : {COLORW{1'b0}};
        green = row_hue[1] ? (bit_on ? BRT : DIM) : {COLORW{1'b0}};
        blue  = row_hue[0] ? (bit_on ? BRT : DIM) : {COLORW{1'b0}};
    end else if( in_tick && tick_on ) begin
        red   = tick_hue[2] ? BRT : {COLORW{1'b0}};
        green = tick_hue[1] ? BRT : {COLORW{1'b0}};
        blue  = tick_hue[0] ? BRT : {COLORW{1'b0}};
    end
end

endmodule
