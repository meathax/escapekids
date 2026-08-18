`timescale 1ns/1ps

module tb_jtsimson_scroll_ext_bridge;
reg clk = 0, rst = 1;
reg ext_hld = 0, ext_vld = 0;
wire [8:0] hdump, vdump, vrender, vrender1;
wire [7:0] tile_dout, ioctl_din, mmr_dump, st_dout;
wire cpu_rom_dtack, rst8, irq_n, firq_n, nmi_n, flip;
wire [19:2] lyrf_addr, lyra_addr, lyrb_addr;
wire lyrf_cs, lyra_cs, lyrb_cs;
wire lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n;
wire [7:0] lyrf_pxl;
wire [11:0] lyra_pxl, lyrb_pxl;
wire lhbl, lvbl, hs, vs;
integer frame, line, pixel;
integer pixels_since_hld = 0;
integer hld_count = 0, vld_count = 0;
integer pending_set_count = 0, pending_consume_count = 0;
reg [8:0] pre_h, pre_v;
reg pre_pending;

always #5 clk = ~clk;

jtsimson_scroll dut(
    .rst(rst), .clk(clk), .pxl_cen(1'b1), .pxl2_cen(1'b0),
    .paroda(1'b0), .simson(1'b0), .esckids(1'b1), .suratk(1'b0),
    .ext_lhbl(1'b1), .ext_lvbl(1'b1), .ext_hs(1'b0), .ext_vs(1'b0),
    .ext_hld(ext_hld), .ext_vld(ext_vld),
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

task bridge_tick(input bit hld, input bit vld);
reg [8:0] expected_v;
begin
    @(negedge clk);
    ext_hld = hld;
    ext_vld = vld;
    pre_h = dut.esc_hdump;
    pre_v = dut.esc_vdump;
    pre_pending = dut.esc_vld_pending;
    if (vld && pre_pending)
        $fatal(1, "duplicate V pending before consume frame=%0d line=%0d pixel=%0d", frame, line, pixel);
    @(posedge clk); #1;
    pixels_since_hld = pixels_since_hld + 1;
    if (hld) begin
        hld_count = hld_count + 1;
        if (pixels_since_hld != 384)
            $fatal(1, "H interval=%0d expected384 frame=%0d line=%0d", pixels_since_hld, frame, line);
        pixels_since_hld = 0;
        if (dut.esc_hdump !== 9'h020)
            $fatal(1, "H reset missed/duplicated got=%03h", dut.esc_hdump);
        if (dut.esc_vld_pending !== 1'b0)
            $fatal(1, "V pending not consumed at H load");
        if (vld || pre_pending) begin
            pending_consume_count = pending_consume_count + 1;
            expected_v = 9'h0f8;
        end else begin
            expected_v = pre_v == 9'h1ff ? 9'h0f8 : pre_v + 1'b1;
        end
        if (dut.esc_vdump !== expected_v)
            $fatal(1, "V update mismatch pre=%03h got=%03h expected=%03h", pre_v, dut.esc_vdump, expected_v);
    end else begin
        if (dut.esc_hdump !== pre_h + 1'b1)
            $fatal(1, "H advanced incorrectly pre=%03h got=%03h", pre_h, dut.esc_hdump);
        if (dut.esc_vdump !== pre_v)
            $fatal(1, "V changed without H load pre=%03h got=%03h", pre_v, dut.esc_vdump);
        if (dut.esc_vld_pending !== (pre_pending | vld))
            $fatal(1, "pending capture mismatch pre=%0d vld=%0d got=%0d", pre_pending, vld, dut.esc_vld_pending);
    end
    if (vld) begin
        vld_count = vld_count + 1;
        pending_set_count = pending_set_count + 1;
    end
    if (pending_consume_count > pending_set_count)
        $fatal(1, "pending consumed more than once");
end
endtask

initial begin
    repeat (4) @(posedge clk);
    if (dut.esc_hdump !== 9'h020 || dut.esc_vdump !== 9'h0f8 || dut.esc_vld_pending !== 1'b0)
        $fatal(1, "reset state mismatch");
    @(negedge clk); rst = 0;
    for (frame = 0; frame < 2; frame = frame+1) begin
        for (line = 0; line < 264; line = line+1) begin
            for (pixel = 0; pixel < 384; pixel = pixel+1) begin
`ifdef SCROLL_BRIDGE_INJECT_DUP_HLD
                if (frame == 1 && line == 10 && pixel == 382)
                    bridge_tick(1'b1, 1'b0);
                else
`endif
                bridge_tick(pixel == 383, line == 263 && pixel == 300);
            end
        end
    end
    @(negedge clk); ext_hld = 0; ext_vld = 0;
    if (hld_count != 528 || vld_count != 2 ||
        pending_set_count != 2 || pending_consume_count != 2)
        $fatal(1, "event totals H=%0d V=%0d set=%0d consume=%0d",
            hld_count, vld_count, pending_set_count, pending_consume_count);
    if (pixels_since_hld != 0 || dut.esc_hdump !== 9'h020 ||
        dut.esc_vdump !== 9'h0f8 || dut.esc_vld_pending !== 1'b0)
        $fatal(1, "final bridge state mismatch H=%03h V=%03h pending=%0d px=%0d",
            dut.esc_hdump, dut.esc_vdump, dut.esc_vld_pending, pixels_since_hld);
    $display("JTSIMSON_SCROLL_EXT_BRIDGE_RESULT outcome=pass frames=2 pixels_per_line=384 lines_per_frame=264 h_resets=528 v_sets=2 v_consumes=2 duplicates=0 misses=0");
    $finish;
end
endmodule

module jt052109(
    input rst, clk, pxl_cen, pxl2_cen, lvbl, gfx_cs, cpu_we, rmrd,
    input [15:0] cpu_addr, input [7:0] cpu_dout, input hflip_en,
    input [14:0] ioctl_addr, input ioctl_ram, input [7:0] debug_bus,
    output [7:0] cpu_din, output rst8, output [8:0] hdump, vdump,
    output [2:0] hsub_a, hsub_b, output irq_n, firq_n, nmi_n, flip,
    output [12:0] lyrf_extra, lyra_extra, lyrb_extra,
    output [12:0] lyrf_addr, lyra_addr, lyrb_addr,
    output [7:0] lyrf_col, lyra_col, lyrb_col,
    output [7:0] ioctl_din, mmr_dump, st_dout, output q, e
);
assign cpu_din=0; assign rst8=0; assign hdump=0; assign vdump=0;
assign hsub_a=0; assign hsub_b=0; assign irq_n=1; assign firq_n=1; assign nmi_n=1; assign flip=0;
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
