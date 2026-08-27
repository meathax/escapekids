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
    // download stream tap (checksum A): raw ioctl bytes bound for SDRAM
    input                     ioctl_wr, ioctl_rom, header,
    input        [26:0]       ioctl_addr,
    input        [ 7:0]       ioctl_dout,
    // write-transaction tap (checksum B): what the loader hands the controller
    input                     prog_we, prog_ack,
    input        [21:0]       prog_addr,
    input        [15:0]       prog_data,
    input        [ 1:0]       prog_mask, prog_ba,
    // video pass-through
    input                     LHBL, LVBL,
    input  [COLORW-1:0]       game_r, game_g, game_b,
    output reg [COLORW-1:0]   red, green, blue
);

// PROM boundary: bytes at/above it bypass the SDRAM write path
localparam [26:0] DIAG_HEADER =
    `ifdef JTFRAME_HEADER `JTFRAME_HEADER `else 27'd0 `endif ;
localparam [26:0] DIAG_PROM_END =
    `ifdef JTFRAME_PROM_START (`JTFRAME_PROM_START+DIAG_HEADER) `else ~27'd0 `endif ;

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

// ---------------------------------------------------------------- checksums
// Fletcher-style running sums (mod 2^16), order-sensitive, trivially
// replicated offline:  sum1' = sum1 + w;  sum2' = sum2 + sum1'.
//
// A: every SDRAM-bound download byte at the ioctl boundary (word = the byte,
//    zero-extended). Golden value computable in Python straight from the
//    emitted MRA stream (index0.bin): skip the header bytes and everything at
//    or beyond the PROM offset, fold the rest in order.
// B: every write transaction the loader hands the controller, folded as three
//    16-bit words per accepted transaction (ack cycle):
//      w0 = prog_addr[15:0]
//      w1 = {prog_ba, prog_mask, 6'd0, prog_addr[21:16]}
//      w2 = prog_data
//    Golden value from the validated Icarus loader+controller replay of the
//    same stream.
// Both freeze automatically: A's gate needs ioctl_rom, B's needs prog_we,
// and neither is active after the download completes.
reg [15:0] a_sum1, a_sum2, b_sum1, b_sum2;
reg [15:0] a_count;                 // low 16 bits of SDRAM-bound byte count

wire        a_byte  = ioctl_wr && ioctl_rom && !header &&
                      ioctl_addr >= DIAG_HEADER && ioctl_addr < DIAG_PROM_END;
wire        b_txn   = prog_we && prog_ack;
wire [15:0] b_w1    = {prog_ba, prog_mask, 6'd0, prog_addr[21:16]};

// three-word fold for B, done in one cycle with intermediate carries dropped
// at 16 bits, matching the offline replication exactly
wire [15:0] b_s1a = b_sum1 + prog_addr[15:0];
wire [15:0] b_s2a = b_sum2 + b_s1a;
wire [15:0] b_s1b = b_s1a + b_w1;
wire [15:0] b_s2b = b_s2a + b_s1b;
wire [15:0] b_s1c = b_s1b + prog_data;
wire [15:0] b_s2c = b_s2b + b_s1c;

always @(posedge clk) begin
    if( rst ) begin
        a_sum1 <= 0; a_sum2 <= 0; a_count <= 0;
        b_sum1 <= 0; b_sum2 <= 0;
    end else begin
        if( a_byte ) begin
            a_sum1  <= a_sum1 + {8'd0, ioctl_dout};
            a_sum2  <= a_sum2 + a_sum1 + {8'd0, ioctl_dout};
            a_count <= a_count + 16'd1;
        end
        if( b_txn ) begin
            b_sum1 <= b_s1c;
            b_sum2 <= b_s2c;
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
// X origin is 12 because the presentation crop removes the leftmost 12
// pixels on hardware; blocks at x12..x43 land at screen x0..x31 with all
// eight bits visible (measured on hardware captures, 2026-08-26).
/* verilator lint_off UNUSEDSIGNAL */ // only [4:2] used: block index bits
wire [8:0] xrel     = xcnt - 9'd12;
/* verilator lint_on UNUSEDSIGNAL */
wire       in_block = LVBL && LHBL && xcnt >= 9'd12 && xcnt < 9'd44 &&
                      ycnt >= 9'd4 && ycnt < 9'd124 && ycnt[2];
wire [3:0] blk_row  = ycnt[6:3];          // 0..14 within the block region
wire [2:0] blk_bit  = 3'd7 - xrel[4:2];   // MSB leftmost
reg  [7:0] row_val;
reg  [2:0] row_hue;                       // {r,g,b} enables

always @* begin
    case( blk_row )
        4'd0:    begin row_val = ovfl_cnt;      row_hue = 3'b110; end // yellow
        4'd1:    begin row_val = b_late;        row_hue = 3'b100; end // red
        4'd2:    begin row_val = a_late;        row_hue = 3'b010; end // green
        4'd3:    begin row_val = f_late;        row_hue = 3'b011; end // cyan
        4'd4:    begin row_val = b_maxlat;      row_hue = 3'b101; end // magenta
        // checksum A (stream): white rows, sum2 MSB first
        4'd5:    begin row_val = a_sum2[15:8];  row_hue = 3'b111; end
        4'd6:    begin row_val = a_sum2[ 7:0];  row_hue = 3'b111; end
        4'd7:    begin row_val = a_sum1[15:8];  row_hue = 3'b111; end
        4'd8:    begin row_val = a_sum1[ 7:0];  row_hue = 3'b111; end
        // checksum B (write transactions): yellow rows
        4'd9:    begin row_val = b_sum2[15:8];  row_hue = 3'b110; end
        4'd10:   begin row_val = b_sum2[ 7:0];  row_hue = 3'b110; end
        4'd11:   begin row_val = b_sum1[15:8];  row_hue = 3'b110; end
        4'd12:   begin row_val = b_sum1[ 7:0];  row_hue = 3'b110; end
        // SDRAM-bound byte count, low 16 bits: green rows
        4'd13:   begin row_val = a_count[15:8]; row_hue = 3'b010; end
        default: begin row_val = a_count[ 7:0]; row_hue = 3'b010; end
    endcase
end

wire        bit_on  = row_val[blk_bit];
wire        in_tick = LVBL && LHBL && xcnt >= 9'd12 && xcnt < 9'd18 && ycnt >= 9'd128;
wire [2:0]  tick_hue = xcnt < 9'd14 ? 3'b100 :       // lyrb -> red
                       xcnt < 9'd16 ? 3'b010 :       // lyra -> green
                                      3'b011;        // lyrf -> cyan
wire        tick_on  = xcnt < 9'd14 ? b_disp :
                       xcnt < 9'd16 ? a_disp : f_disp;

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
