`timescale 1ns/1ps

module tb_esckids_obj_zbuffer;

reg clk=0, lhbl=1, we=0, rd=0;
reg [2:0] wr_addr=0, rd_addr=0;
reg [15:0] wr_data=0;
reg [7:0] wr_z=0;
reg [4:0] wr_prio=0;
wire [15:0] rd_data;
integer checks=0;

always #5 clk=~clk;

jtframe_obj_buffer #(
    .DW(16),.AW(3),.ALPHAW(4),.ALPHA(0),.BLANK(0),.BLANK_DLY(2),
    .SW(2),.SHADOW_PEN(15),.SHADOW(1),.KEEP_OLD(0),
    .ZMODE(1),.ZW(8),.PRIOW(5)
) dut(
    .clk(clk),.LHBL(lhbl),.flip(1'b0),
    .wr_data(wr_data),.wr_addr(wr_addr),.we(we),
    .rd_addr(rd_addr),.rd(rd),.rd_data(rd_data),
    .wr_z(wr_z),.wr_prio(wr_prio),.z_enable(1'b1)
);

task write_pixel;
    input [2:0] a;
    input [15:0] d;
    input [7:0] z;
    input [4:0] p;
    begin
        @(negedge clk);
        wr_addr=a; wr_data=d; wr_z=z; wr_prio=p; we=1;
        repeat(3) @(negedge clk);
        we=0;
        repeat(3) @(negedge clk);
    end
endtask

task read_pixel;
    input [2:0] a;
    input [15:0] expected;
    begin
        @(negedge clk); rd_addr=a; rd=1;
        @(negedge clk); rd=0;
        repeat(4) @(negedge clk);
        if( rd_data!==expected )
            $fatal(1,"OBJ_ZBUFFER addr=%0d got=%04x expected=%04x",a,rd_data,expected);
        checks=checks+1;
    end
endtask

initial begin
    // Opaque arbitration: lower Z is closer; equal Z keeps the later write.
    write_pixel(3'd1,{2'd0,10'h101,4'h1},8'd200,5'd4);
    write_pixel(3'd1,{2'd0,10'h202,4'h2},8'd10, 5'd4);
    write_pixel(3'd2,{2'd0,10'h303,4'h3},8'd10, 5'd4);
    write_pixel(3'd2,{2'd0,10'h404,4'h4},8'd200,5'd4);
    write_pixel(3'd3,{2'd0,10'h505,4'h5},8'd30, 5'd4);
    write_pixel(3'd3,{2'd0,10'h606,4'h6},8'd30, 5'd4);

    // Shadow arbitration: a closer shadow wins only when it has the more
    // topmost priority (smaller numerical priority).
    write_pixel(3'd4,{2'd0,10'h707,4'h7},8'd100,5'd8);
    write_pixel(3'd4,{2'd1,10'h000,4'hf},8'd200,5'd10);
    write_pixel(3'd4,{2'd2,10'h000,4'hf},8'd50, 5'd20);
    write_pixel(3'd5,{2'd0,10'h808,4'h8},8'd100,5'd8);
    write_pixel(3'd5,{2'd1,10'h000,4'hf},8'd200,5'd10);
    write_pixel(3'd5,{2'd2,10'h000,4'hf},8'd50, 5'd0);

    @(negedge clk); lhbl=0;
    repeat(2) @(negedge clk);
    lhbl=1;
    repeat(2) @(negedge clk);

    read_pixel(3'd1,{2'd0,10'h202,4'h2});
    read_pixel(3'd2,{2'd0,10'h303,4'h3});
    read_pixel(3'd3,{2'd0,10'h606,4'h6});
    read_pixel(3'd4,{2'd1,10'h707,4'h7});
    read_pixel(3'd5,{2'd2,10'h808,4'h8});

    $display("OBJ_ZBUFFER PASS checks=%0d opaque_z=1 shadow_z_prio=1",checks);
    $finish;
end

initial begin
    #200_000 $fatal(1,"OBJ_ZBUFFER timeout");
end

endmodule
