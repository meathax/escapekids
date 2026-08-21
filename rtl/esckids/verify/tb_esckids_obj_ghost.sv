`timescale 1ns/1ps
// Directed OBJ ghost/mirror diagnostic for the GX975 (Escape Kids) sprite path.
// Feeds REAL OBJ RAM entries captured live from MAME 0.289 esckids this session
// (char-select coin sprite e113, TOP PLAYERS mirrored banner pair e0/e1, plus a
// synthetic partial-left clip case) through jt053244_scan + jtframe_objdraw with
// the exact glue used by jtriders_obj.v (esckids path: gx975_unswizzle, linear
// ROM addressing, .hflip(~hflip)).
// The fake ROM encodes pixel identity in the pen value:
//   pen(H,s) = 1 + ((H*8+s) % 14)   (s = MAME screen-order pixel 0..7 in fetch H)
// so the line-buffer write log (address, pen) fully decodes position and order.
// MAME expectation (k053246_k053247_k055673.h, offx=0x66 dx=5, wrapsize 1024):
//   sprite A e113 coin : buf 197..260  pens ascending (flipx=0)
//   sprite B e0 banner : buf 124..155  pens descending (flipx=1)
//   sprite C e1 twin   : buf 374..405  pens ascending (flipx=0)
//   sprite D partial-L : buf  90..122  pens ascending (flipx=0)
// Any write outside/duplicated over these windows, or a reversed pen ramp,
// pinpoints the divergence.
module tb_esckids_obj_ghost;

reg clk=0, rst=1, hs=0, pxl_cen=0;
always #5 clk=~clk;
always @(posedge clk) pxl_cen <= ~pxl_cen;

reg  [8:0] vdump=9'h0F8, hdump=9'h020;

// ---- scan <-> LUT model -------------------------------------------------
wire [15:0] code;
wire [ 6:0] attr;
wire        hflip, vflip, hz_keep, shd, dr_start;
wire [ 9:0] hpos;
wire [ 3:0] ysub;
wire [11:0] hzoom;
wire [11:2] scan_addr;
wire        dr_busy;

reg [15:0] even_mem[0:1023];
reg [15:0] odd_mem [0:1023];
wire [15:0] scan_even = even_mem[scan_addr];
wire [15:0] scan_odd  = odd_mem [scan_addr];

jt053244_scan #(.GX975(1),.HFLIP_OFFSET(10'd134),.SCREEN_WIDTH(384)) u_scan(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .code       ( code      ),
    .attr       ( attr      ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .hpos       ( hpos      ),
    .ysub       ( ysub      ),
    .hzoom      ( hzoom     ),
    .hz_keep    ( hz_keep   ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .hs         ( hs        ),
    .scan_even  ( scan_even ),
    .scan_odd   ( scan_odd  ),
    .xoffset    ( 10'd102   ),  // live MAME kx46 offx=0x66
    .yoffset    ( 10'd761   ),  // live MAME kx46 offy=0x2F9
    .ghf        ( 1'b0      ),
    .gvf        ( 1'b0      ),
    .scan_addr  ( scan_addr ),
    .shd        ( shd       ),
    .dr_start   ( dr_start  ),
    .dr_busy    ( dr_busy   ),
    .gx975      ( 1'b1      ),
    .gx975_raw  ( 1'b1      ),
    .debug_bus  ( 8'd0      )
);

// ---- identity ROM + jtriders_obj esckids glue ---------------------------
wire [22:2] pre_addr;
wire        pre_cs;
wire [15:0] pre_pxl;

// esckids linear address map (jtriders_obj.v)
wire [21:2] rom_addr = { pre_addr[21:7], pre_addr[5:2], pre_addr[6] };

function [15:0] pen8; // pens for H half: {pen(s=3..0)} packed 4x4 helper unused
    input dummy; pen8 = 0;
endfunction

// raw MAME-format dword for fetch: nibble n holds pen of MAME screen pixel s
// with n = {2,3,0,1,6,7,4,5}[s]
function [31:0] raw_rom(input Hbit);
    reg [3:0] pen [0:7];
    integer s;
    reg [31:0] r;
    begin
        for(s=0;s<8;s=s+1) pen[s] = 4'd1 + ((({3'd0,Hbit}*8)+s) % 14);
        r = 0;
        r[11: 8] = pen[0]; // nib2
        r[15:12] = pen[1]; // nib3
        r[ 3: 0] = pen[2]; // nib0
        r[ 7: 4] = pen[3]; // nib1
        r[27:24] = pen[4]; // nib6
        r[31:28] = pen[5]; // nib7
        r[19:16] = pen[6]; // nib4
        r[23:20] = pen[7]; // nib5
        raw_rom = r;
    end
endfunction

// gx975_unswizzle copied verbatim from jtriders_obj.v
function [31:0] gx975_unswizzle(input [31:0] d);
    reg [3:0] p0,p1,p2,p3,p4,p5,p6,p7;
    begin
        p0 = d[11:8];  p1 = d[15:12]; p2 = d[3:0];   p3 = d[7:4];
        p4 = d[27:24]; p5 = d[31:28]; p6 = d[19:16]; p7 = d[23:20];
        gx975_unswizzle[7:0]   = {p0[0],p1[0],p2[0],p3[0],p4[0],p5[0],p6[0],p7[0]};
        gx975_unswizzle[15:8]  = {p0[1],p1[1],p2[1],p3[1],p4[1],p5[1],p6[1],p7[1]};
        gx975_unswizzle[23:16] = {p0[2],p1[2],p2[2],p3[2],p4[2],p5[2],p6[2],p7[2]};
        gx975_unswizzle[31:24] = {p0[3],p1[3],p2[3],p3[3],p4[3],p5[3],p6[3],p7[3]};
    end
endfunction

wire [31:0] rom_data = gx975_unswizzle(raw_rom(rom_addr[2]));

jtframe_objdraw #(
    .SHADOW(1),.SHADOW_PEN(4'd15),.SW(2),
    .AW(10),.CW(16),.PW(4+10+2),.LATCH(1),.SWAPH(1),
    .ZW(12),.ZI(6),.ZENLARGE(1),
    .FLIP_OFFSET(9'h12),.KEEP_OLD(0)
) u_od(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .flip       ( 1'b0          ),
    .hdump      ( {1'b0,hdump}  ),
    .draw       ( dr_start      ),
    .busy       ( dr_busy       ),
    .code       ( code          ),
    .xpos       ( hpos          ),
    .ysub       ( ysub          ),
    .hz_keep    ( hz_keep       ),
    .hzoom      ( hzoom         ),
    .hflip      ( ~hflip        ),
    .vflip      ( vflip         ),
    .pal        ({1'b0,shd, 3'b0, attr}),
    .rom_addr   ( pre_addr      ),
    .rom_cs     ( pre_cs        ),
    .rom_ok     ( 1'b1          ),
    .rom_data   ( rom_data      ),
    .pxl        ( pre_pxl       )
);

// ---- write logging ------------------------------------------------------
integer logline=0;
always @(posedge clk) begin
    if( logline && u_scan.cen2 && u_scan.scan_obj>=1 && u_scan.scan_obj<=4 )
        $display("SC line=%03x obj=%0d sub=%0d%0d y=%0d x=%0d ydiff=%0d ydiff_b=%0d inzone=%b vlatch=%03x",
            vdump, u_scan.scan_obj, u_scan.indr, u_scan.scan_sub,
            u_scan.y, u_scan.x, u_scan.ydiff, u_scan.ydiff_b, u_scan.inzone, u_scan.vlatch);
    if( u_od.u_gate.u_draw.buf_we && logline )
        $display("WR line=%03x addr=%0d pen=%0d attr=%02x",
            vdump, u_od.u_gate.u_draw.buf_addr,
            u_od.u_gate.u_draw.buf_din[3:0],
            u_od.u_gate.u_draw.buf_din[10:4]);
    if( dr_start && logline )
        $display("DR obj=%0d code=%04x hpos=%0d hflip=%b hz_keep=%b hzoom=%03x",
            u_scan.scan_obj, code, hpos, hflip, hz_keep, hzoom);
end

// ---- sprite table -------------------------------------------------------
task set_spr(input [7:0] idx, input [15:0] w0,w1,w2,w3,w4,w5,w6,w7);
    begin
        even_mem[{idx,2'd0}] = w0; odd_mem[{idx,2'd0}] = w1;
        even_mem[{idx,2'd1}] = w2; odd_mem[{idx,2'd1}] = w3;
        even_mem[{idx,2'd2}] = w4; odd_mem[{idx,2'd2}] = w5;
        even_mem[{idx,2'd3}] = w6; odd_mem[{idx,2'd3}] = w7;
    end
endtask

integer i;
task run_line(input [8:0] v, input do_log);
    begin
        vdump = v;
        logline = do_log;
        hs = 1;
        repeat (60) @(posedge clk);
        hs = 0;
        repeat (20000) @(posedge clk);
    end
endtask

initial begin
    for(i=0;i<1024;i=i+1) begin even_mem[i]=0; odd_mem[i]=0; end
    // A: live char-select coin sprite (e113): 4x4 tiles, zx=0x20, no flip
    set_spr(8'd1, 16'h8a71,16'h3360,16'h00c8,16'h01b9,16'h0040,16'h0020,16'h0185,16'h0000);
    // B: live TOP PLAYERS banner left ornament (e0): 2x2, flipx=1, ox=+262
    set_spr(8'd2, 16'h9500,16'h5c90,16'h00dc,16'h0106,16'h0040,16'h0020,16'h002e,16'h0000);
    // C: its raw-wraparound partner (e1): 2x2, flipx=0, ox raw=0x2FA (=762)
    set_spr(8'd3, 16'h8501,16'h5c84,16'h00dc,16'h02fa,16'h0040,16'h0020,16'h002e,16'h0000);
    // D: synthetic partial-left clip: 2x2, flipx=0, ox raw=0xC2 (=194)
    set_spr(8'd4, 16'h8500,16'h1234,16'h00c8,16'h00c2,16'h0040,16'h0020,16'h0000,16'h0000);

    repeat (10) @(posedge clk);
    rst = 0;
    repeat (10) @(posedge clk);

    // warm-up line (no log) then two logged lines inside every sprite's zone
    run_line(9'h127, 0);
    run_line(9'h128, 1);
    run_line(9'h129, 1);
    $display("TB_DONE");
    $finish;
end

initial begin
    #40_000_000 $display("TB_TIMEOUT"); $finish;
end

endmodule
