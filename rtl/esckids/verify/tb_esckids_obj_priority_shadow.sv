`timescale 1ns/1ps

module tb_esckids_obj_priority_shadow;

reg clk=0, rst=1, pxl_cen=0, cs=0;
reg [3:0] addr=0;
reg [5:0] din=0;
reg [5:0] pri1=0;
reg [8:0] ci1=0, ci2=0;
reg [7:0] ci3=0, ci4=0;
reg [1:0] shd_in=0;
wire [10:0] cout;
wire [1:0] shd_out;
wire [7:0] ioctl_din;
integer checks=0;

always #5 clk=~clk;

jtcolmix_053251 dut(
    .rst(rst),.clk(clk),.pxl_cen(pxl_cen),
    .cs(cs),.addr(addr),.din(din),
    .sel(1'b0),.pri0(6'h3f),.pri1(pri1),.pri2(6'h3f),
    .ci0(9'd0),.ci1(ci1),.ci2(ci2),.ci3(ci3),.ci4(ci4),
    .shd_in(shd_in),.shd_out(shd_out),
    .ioctl_addr(4'd0),.ioctl_din(ioctl_din),
    .cout(cout),.brit(),.col_n()
);

task wr;
    input [3:0] a;
    input [5:0] d;
    begin
        @(negedge clk); addr=a; din=d; cs=1;
        @(negedge clk); cs=0;
    end
endtask

task pulse_pixel;
    begin
        @(negedge clk); pxl_cen=1;
        @(posedge clk); #1;
        @(negedge clk); pxl_cen=0;
    end
endtask

task eval_pixel;
    input [5:0] op;
    input [8:0] obj, fix;
    input [7:0] la, lb;
    input [1:0] shade;
    input [10:0] exp_color;
    input [1:0] exp_shade;
    begin
        pri1=op; ci1=obj; ci2=fix; ci3=la; ci4=lb; shd_in=shade;
        pulse_pixel();
        ci1=0; ci2=0; ci3=0; ci4=0; shd_in=0;
        repeat(6) @(posedge clk);
        pulse_pixel();
        if( cout!==exp_color || shd_out!==exp_shade )
            $fatal(1,"OBJ_PRIORITY_SHADOW got color=%03x shd=%0d expected=%03x/%0d",
                cout,shd_out,exp_color,exp_shade);
        checks=checks+1;
        repeat(6) @(posedge clk);
    end
endtask

initial begin
    repeat(4) @(posedge clk);
    rst=0;

    // K053251 layer priorities and three shadow-preset thresholds.
    wr(4'd2,6'd12);
    wr(4'd3,6'd20);
    wr(4'd4,6'd28);
    wr(4'd6,6'd9);
    wr(4'd7,6'd25);
    wr(4'd8,6'd41);
    wr(4'd12,6'b000100); // CI2 uses MMR2; object uses explicit attribute priority

    repeat(6) @(posedge clk);

    // Smaller number wins; object wins an equal-priority comparison.
    eval_pixel(6'd10,9'h011,9'h022,8'h33,8'h44,2'd0,11'h011,2'd0);
    eval_pixel(6'd14,9'h011,9'h022,8'h33,8'h44,2'd0,11'h022,2'd0);
    eval_pixel(6'd12,9'h011,9'h022,8'h33,8'h44,2'd0,11'h011,2'd0);

    // Transparent high-priority layers must not mask the object.
    eval_pixel(6'd50,9'h011,9'h000,8'h00,8'h00,2'd0,11'h011,2'd0);

    // The same tie/win rule against each independently transparent layer.
    eval_pixel(6'd20,9'h011,9'h000,8'h33,8'h00,2'd0,11'h011,2'd0);
    eval_pixel(6'd22,9'h011,9'h000,8'h33,8'h00,2'd0,11'h033,2'd0);
    eval_pixel(6'd28,9'h011,9'h000,8'h00,8'h44,2'd0,11'h011,2'd0);
    eval_pixel(6'd30,9'h011,9'h000,8'h00,8'h44,2'd0,11'h044,2'd0);

    // A shadow pen leaves the winning color intact and selects its preset
    // only when that preset's threshold is above the winning layer.
    eval_pixel(6'h3f,9'h000,9'h000,8'h33,8'h00,2'd1,11'h033,2'd1);
    eval_pixel(6'h3f,9'h000,9'h000,8'h33,8'h00,2'd2,11'h033,2'd0);
    wr(4'd3,6'd30);
    eval_pixel(6'h3f,9'h000,9'h000,8'h33,8'h00,2'd2,11'h033,2'd2);
    eval_pixel(6'h3f,9'h000,9'h000,8'h33,8'h00,2'd3,11'h033,2'd0);
    wr(4'd3,6'd50);
    eval_pixel(6'h3f,9'h000,9'h000,8'h33,8'h00,2'd3,11'h033,2'd3);

    $display("OBJ_PRIORITY_SHADOW PASS checks=%0d",checks);
    $finish;
end

initial begin
    #1_000_000 $fatal(1,"OBJ_PRIORITY_SHADOW timeout");
end

endmodule
