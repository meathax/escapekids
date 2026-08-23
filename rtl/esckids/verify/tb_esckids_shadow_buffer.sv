`timescale 1ns/1ps

module tb_esckids_shadow_buffer;

reg clk=0, lhbl=1, we=0, rd=0;
reg [2:0] wr_addr=0, rd_addr=0;
reg [15:0] wr_data=0;
wire [15:0] rd_data;

always #5 clk=~clk;

jtframe_obj_buffer #(
    .DW(16),.AW(3),.ALPHAW(4),.ALPHA(0),.BLANK(0),.BLANK_DLY(2),
    .SW(2),.SHADOW_PEN(15),.SHADOW(1),.KEEP_OLD(0)
) dut(
    .clk(clk),.LHBL(lhbl),.flip(1'b0),
    .wr_data(wr_data),.wr_addr(wr_addr),.we(we),
    .rd_addr(rd_addr),.rd(rd),.rd_data(rd_data)
);

task write_pixel;
    input [2:0] a;
    input [15:0] d;
    begin
        @(negedge clk); wr_addr=a; wr_data=d; we=1;
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
            $fatal(1,"SHADOW_BUFFER addr=%0d got=%04x expected=%04x",a,rd_data,expected);
    end
endtask

initial begin
    repeat(4) @(posedge clk);

    // Normal pen establishes the base color. A later shadow pen must update
    // only the two-bit shadow plane, preserving that color and priority.
    write_pixel(3'd1,{2'd0,10'h155,4'h5});
    write_pixel(3'd1,{2'd2,10'h000,4'hf});
    write_pixel(3'd2,{2'd0,10'h2aa,4'h7});
    write_pixel(3'd2,{2'd3,10'h000,4'hf});

    // Display the line just produced.
    @(negedge clk); lhbl=0;
    repeat(2) @(negedge clk);
    lhbl=1;
    repeat(2) @(negedge clk);

    read_pixel(3'd1,{2'd2,10'h155,4'h5});
    read_pixel(3'd2,{2'd3,10'h2aa,4'h7});

    $display("SHADOW_BUFFER PASS modes=2,3 base_color_preserved=1");
    $finish;
end

initial begin
    #200_000 $fatal(1,"SHADOW_BUFFER timeout");
end

endmodule
