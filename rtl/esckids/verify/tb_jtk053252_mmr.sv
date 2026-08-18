`timescale 1ns/1ps
module tb_jtk053252_mmr;
    logic rst = 1'b1;
    logic clk = 1'b0;
    logic cs = 1'b0;
    logic [3:0] addr = 4'd0;
    logic rnw = 1'b1;
    logic [7:0] din = 8'd0;
    logic [7:0] dout;
    logic [9:0] hcnt0;
    logic [8:0] hbstart, hb2cnt0, vcnt0;
    logic [2:0] nhbs_dly;
    logic [1:0] fcnt_out;
    logic hcnt_dis;
    logic [7:0] vbstart, vbcnt0, int2cnt0;
    logic [3:0] vswidth, hswidth;
    logic set_int2en, int1ack, int2ack;
    logic [3:0] ioctl_addr = 4'd0;
    logic [7:0] ioctl_din, debug_bus = 8'd0, st_dout;

    always #5 clk = ~clk;

    // Furrtek reset model: registers 0/4/8 are 03/01/01, others zero.
    jtk053252_mmr #(.INIT(128'h00000000000000010000000100000003)) dut(.*);

    task automatic write_reg(input [3:0] a, input [7:0] d);
        begin
            @(negedge clk); addr = a; din = d; rnw = 1'b0; cs = 1'b1;
            @(negedge clk); cs = 1'b0; rnw = 1'b1;
        end
    endtask

    task automatic read_reg(input [3:0] a, input [7:0] expected);
        begin
            @(negedge clk); addr = a; rnw = 1'b1; cs = 1'b1;
            @(negedge clk); cs = 1'b0;
            #1;
            if (dout !== expected) $fatal(1, "MMR read %0d=%02h expected %02h", a, dout, expected);
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst = 1'b0;
        #1;
        if (hcnt0 !== 10'h300) $fatal(1, "Furrtek reset hcnt0=%03h", hcnt0);
        if (hb2cnt0 !== 9'h100) $fatal(1, "Furrtek reset hb2cnt0=%03h", hb2cnt0);
        if (vcnt0 !== 9'h100) $fatal(1, "Furrtek reset vcnt0=%03h", vcnt0);
        write_reg(4'd0, 8'h02);
        write_reg(4'd1, 8'h34);
        write_reg(4'd2, 8'h01);
        write_reg(4'd3, 8'h56);
        write_reg(4'd4, 8'h01);
        write_reg(4'd5, 8'h78);
        write_reg(4'd6, 8'h05);
        write_reg(4'd7, 8'h82);
        write_reg(4'd8, 8'h01);
        write_reg(4'd9, 8'h9a);
        write_reg(4'd10, 8'hbc);
        write_reg(4'd11, 8'hde);
        write_reg(4'd12, 8'h43);
        write_reg(4'd13, 8'hf0);
        if (!set_int2en) $fatal(1, "MMR register 13 event missing");
        write_reg(4'd14, 8'he1);
        if (!int1ack) $fatal(1, "MMR register 14 event missing");
        write_reg(4'd15, 8'hd2);
        if (!int2ack) $fatal(1, "MMR register 15 event missing");

        read_reg(4'd0, 8'h02);
        read_reg(4'd3, 8'h56);
        read_reg(4'd12, 8'h43);
        if (hcnt0 !== 10'h234) $fatal(1, "hcnt0 assembly %03h", hcnt0);
        if (hbstart !== 9'h156) $fatal(1, "hbstart assembly %03h", hbstart);
        if (hb2cnt0 !== 9'h178) $fatal(1, "hb2cnt0 assembly %03h", hb2cnt0);
        if (vcnt0 !== 9'h19a) $fatal(1, "vcnt0 assembly %03h", vcnt0);
        if (vswidth !== 4'h4 || hswidth !== 4'h3) $fatal(1, "width assembly");
        ioctl_addr = 4'd11;
        @(posedge clk); #1;
        if (ioctl_din !== 8'hde) $fatal(1, "MMR ioctl readback %02h", ioctl_din);
        $display("K053252 MMR CONTRACT PASS");
        $finish;
    end
endmodule
