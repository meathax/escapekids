`timescale 1ns/1ps

module tb_esckids_obj_bottom;

reg clk = 0;
reg rst = 1;
reg hs = 0;
reg [8:0] vdump = 9'h1f0;

always #5 clk = ~clk;

wire [11:2] gx_addr, donor_addr;
wire gx_start, donor_start;
wire [7:0] gx_zcode, donor_zcode;

jt053244_scan #(.GX975(1)) u_gx975 (
    .rst(rst), .clk(clk), .code(), .attr(), .hflip(), .vflip(),
    .zcode(gx_zcode),
    .hpos(), .ysub(), .hzoom(), .hz_keep(), .hdump(9'd0),
    .vdump(vdump), .hs(hs), .scan_even(16'd0), .scan_odd(16'd0),
    .xoffset(10'd0), .yoffset(10'd0), .ghf(1'b0), .gvf(1'b0),
    .scan_addr(gx_addr), .shd(), .dr_start(gx_start), .dr_busy(1'b0),
    .gx975(1'b1), .gx975_raw(1'b1), .debug_bus(8'd0)
);

jt053244_scan #(.GX975(1)) u_donor (
    .rst(rst), .clk(clk), .code(), .attr(), .hflip(), .vflip(),
    .zcode(donor_zcode),
    .hpos(), .ysub(), .hzoom(), .hz_keep(), .hdump(9'd0),
    .vdump(vdump), .hs(hs), .scan_even(16'd0), .scan_odd(16'd0),
    .xoffset(10'd0), .yoffset(10'd0), .ghf(1'b0), .gvf(1'b0),
    .scan_addr(donor_addr), .shd(), .dr_start(donor_start), .dr_busy(1'b0),
    .gx975(1'b0), .gx975_raw(1'b0), .debug_bus(8'd0)
);

task pulse_line(input [8:0] line);
    begin
        vdump = line;
        hs = 1;
        repeat (6) @(posedge clk);
        hs = 0;
        repeat (6) @(posedge clk);
    end
endtask

initial begin
    repeat (4) @(posedge clk);
    rst = 0;
    repeat (4) @(posedge clk);

    vdump = 9'h1f0;
    hs = 1;
    wait (u_gx975.scan_obj == 8'hff);
    if (u_donor.scan_obj !== 8'h00)
        $fatal(1, "donor scan did not start at slot 0: %02h", u_donor.scan_obj);
    hs = 0;
    wait (u_gx975.scan_obj == 8'hfe);
    wait (u_donor.scan_obj == 8'h01);

    pulse_line(9'h1f0);
    if (u_gx975.vlatch !== 9'h1f0 || u_donor.vlatch !== 9'h1f0)
        $fatal(1, "control line 1f0 was not accepted gx=%03h donor=%03h",
            u_gx975.vlatch, u_donor.vlatch);

    pulse_line(9'h1f1);
    if (u_gx975.vlatch !== 9'h1f1)
        $fatal(1, "GX975 bottom-line scan stopped early at %03h", u_gx975.vlatch);
    if (u_donor.vlatch !== 9'h1f0)
        $fatal(1, "donor K053244 window changed at 1f1: %03h", u_donor.vlatch);

    pulse_line(9'h1f7);
    if (u_gx975.vlatch !== 9'h1f7)
        $fatal(1, "GX975 last visible sprite line was not scanned: %03h", u_gx975.vlatch);
    if (u_donor.vlatch !== 9'h1f0)
        $fatal(1, "donor K053244 window changed at 1f7: %03h", u_donor.vlatch);

    pulse_line(9'h1f8);
    if (u_gx975.vlatch !== 9'h1f7)
        $fatal(1, "GX975 scanner extended into post-visible line: %03h", u_gx975.vlatch);

    $display("ESCAPE KIDS GX975 BOTTOM SCAN PASS");
    $finish;
end

initial begin
    #100_000;
    $fatal(1, "timeout");
end

endmodule
