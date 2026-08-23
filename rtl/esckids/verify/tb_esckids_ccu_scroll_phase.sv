`timescale 1ns/1ps

module tb_esckids_ccu_scroll_phase;
reg clk = 0, rst = 1;
wire ccu_lhbl, ccu_lvbl, ccu_hs, ccu_vs, ccu_hld, ccu_vld, ccu_lhbs;
wire [7:0] ccu_dout;
wire [8:0] hdump, vdump, vrender, vrender1;
wire lhbl, lvbl, hs, vs;
wire [7:0] tile_dout, ioctl_din, mmr_dump, st_dout;
wire cpu_rom_dtack, rst8, irq_n, firq_n, nmi_n, flip;
wire [19:2] lyrf_addr, lyra_addr, lyrb_addr;
wire lyrf_cs, lyra_cs, lyrb_cs;
wire lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n;
wire [7:0] lyrf_pxl;
wire [11:0] lyra_pxl, lyrb_pxl;
integer line_count = 0;
reg lhbl_l = 0;
integer active_start_count = 0;
integer active_end_count = 0;

always #5 clk = ~clk;

jtk053252 #(.INIT(128'h000000_73_07_08_07_01_01_00_0D_00_12_00_7F_01)) u_ccu(
    .rst(rst), .clk(clk), .pxl_cen(1'b1), .sel(3'b000),
    .vldi(1'b1), .hldi(1'b1), .cs(1'b0), .addr(4'd0),
    .rnw(1'b1), .din(8'd0), .dout(ccu_dout),
    .lhbl(ccu_lhbl), .lvbl(ccu_lvbl), .hs(ccu_hs), .vs(ccu_vs),
    .int1(), .int2(), .hld(ccu_hld), .vld(ccu_vld), .lhbs(ccu_lhbs),
    .ioctl_addr(4'd0), .ioctl_din()
);

jtsimson_scroll #(.EXT_TIMING(1)) dut(
    .rst(rst), .clk(clk), .pxl_cen(1'b1), .pxl2_cen(1'b0),
    .paroda(1'b0), .simson(1'b0), .esckids(1'b1), .suratk(1'b0),
    .ext_lhbl(ccu_lhbl), .ext_lvbl(ccu_lvbl), .ext_hs(ccu_hs),
    .ext_vs(ccu_vs), .ext_hld(ccu_hld), .ext_vld(ccu_vld),
    .lhbl(lhbl), .lvbl(lvbl), .hs(hs), .vs(vs),
    .hdump(hdump), .vdump(vdump), .vrender(vrender), .vrender1(vrender1),
    .gfx_cs(1'b0), .cpu_we(1'b0), .cpu_addr(16'b0), .cpu_dout(8'b0),
    .tile_dout(tile_dout), .cpu_rom_dtack(cpu_rom_dtack), .rst8(rst8),
    .rmrd(1'b0), .irq_n(irq_n), .firq_n(firq_n), .nmi_n(nmi_n), .flip(flip),
    .lyrf_addr(lyrf_addr), .lyra_addr(lyra_addr), .lyrb_addr(lyrb_addr),
    .lyrf_cs(lyrf_cs), .lyra_cs(lyra_cs), .lyrb_cs(lyrb_cs),
    .lyrf_data(32'b0), .lyra_data(32'b0), .lyrb_data(32'b0), .lyra_ok(1'b1),
    .lyrf_blnk_n(lyrf_blnk_n), .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n), .lyrf_pxl(lyrf_pxl),
    .lyra_pxl(lyra_pxl), .lyrb_pxl(lyrb_pxl),
    .ioctl_addr(15'b0), .ioctl_ram(1'b0), .ioctl_din(ioctl_din),
    .mmr_dump(mmr_dump), .gfx_en(4'b0), .debug_bus(8'b0), .st_dout(st_dout)
);

always @(posedge clk) begin
    if (!rst) begin
        lhbl_l <= ccu_lhbl;
        if (ccu_hld) line_count <= line_count + 1;
        if (line_count >= 2 && line_count <= 4 && !lhbl_l && ccu_lhbl) begin
            if (dut.esc_hdump !== 9'h070)
                $fatal(1, "active start phase=%03h expected=070", dut.esc_hdump);
            active_start_count <= active_start_count + 1;
            $display("CCU_PHASE edge=active_start line=%0d hdump=%03h", line_count, dut.esc_hdump);
        end
        if (line_count >= 2 && line_count <= 4 && lhbl_l && !ccu_lhbl) begin
            if (dut.esc_hdump !== 9'h031)
                $fatal(1, "active end phase=%03h expected=031", dut.esc_hdump);
            active_end_count <= active_end_count + 1;
            $display("CCU_PHASE edge=active_end line=%0d hdump=%03h", line_count, dut.esc_hdump);
        end
        if (line_count == 5) begin
            if (active_start_count != 3 || active_end_count != 3)
                $fatal(1, "edge totals start=%0d end=%0d expected=3", active_start_count, active_end_count);
            $display("CCU_PHASE_RESULT outcome=pass");
            $finish;
        end
    end
end

initial begin
    repeat (8) @(posedge clk);
    @(negedge clk); rst = 0;
    repeat (3000) @(posedge clk);
    $fatal(1, "CCU phase timeout");
end
endmodule

module jt052109 #(
    parameter [8:0] ROWSCR_START=9'h028,
    parameter [8:0] ROWSCR_END=9'h04f
)(
    input rst, clk, pxl_cen, pxl2_cen, lvbl, gfx_cs, cpu_we, rmrd,
    input [15:0] cpu_addr, input [7:0] cpu_dout,
    input [14:0] ioctl_addr, input ioctl_ram, input [7:0] debug_bus,
    output [7:0] cpu_din, output rst8,
    input [8:0] hdump, vdump, output [2:0] hsub_a, hsub_b,
    output irq_n, firq_n, nmi_n, flip, hflip_en,
    output [7:0] lyrf_extra, lyra_extra, lyrb_extra,
    output [12:0] lyrf_addr, lyra_addr, lyrb_addr,
    output [7:0] lyrf_col, lyra_col, lyrb_col,
    output [7:0] ioctl_din, mmr_dump, st_dout, output q, e
);
assign cpu_din=0; assign rst8=0; assign hsub_a=0; assign hsub_b=0;
assign irq_n=1; assign firq_n=1; assign nmi_n=1; assign flip=0; assign hflip_en=0;
assign lyrf_extra=0; assign lyra_extra=0; assign lyrb_extra=0;
assign lyrf_addr=0; assign lyra_addr=0; assign lyrb_addr=0;
assign lyrf_col=0; assign lyra_col=0; assign lyrb_col=0;
assign ioctl_din=0; assign mmr_dump=0; assign st_dout=0; assign q=0; assign e=0;
endmodule

module jt051962 #(
    parameter [8:0] HB_OFFSET=0, parameter EXT_TIMING=0
)(
    input rst, clk, pxl_cen, flip, hflip_en,
    input [1:0] cpu_addr, output [7:0] cpu_din,
    input [31:0] lyrf_data, lyra_data, lyrb_data,
    input [7:0] lyrf_col, lyra_col, lyrb_col,
    input [2:0] hsub_a, hsub_b,
    output [8:0] hdump, vdump, vrender, vrender1,
    output lhbl, lvbl, hs, vs, lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n,
    output [7:0] lyrf_pxl, output [11:0] lyra_pxl, lyrb_pxl,
    input [3:0] gfx_en, input [7:0] debug_bus,
    input [8:0] ext_hdump, ext_vdump,
    input ext_lhbl, ext_lvbl, ext_hs, ext_vs, ext_en
);
assign cpu_din=0; assign hdump=ext_hdump; assign vdump=ext_vdump;
assign vrender=ext_vdump; assign vrender1=ext_vdump+1'b1;
assign lhbl=ext_lhbl; assign lvbl=ext_lvbl; assign hs=ext_hs; assign vs=ext_vs;
assign lyrf_blnk_n=0; assign lyra_blnk_n=0; assign lyrb_blnk_n=0;
assign lyrf_pxl=0; assign lyra_pxl=0; assign lyrb_pxl=0;
endmodule
