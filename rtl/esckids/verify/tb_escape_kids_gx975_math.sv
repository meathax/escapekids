`timescale 1ns/1ps
module tb_escape_kids_gx975_math;
    logic enable, flip_x;
    logic [15:0] scan_odd;
    logic [11:0] zoom_in;
    logic [9:0] x_start;
    logic [11:0] hzoom;
    escape_kids_gx975_math dut(.*);

    task automatic check(input logic e, input logic f, input [15:0] x,
                         input [11:0] z, input [9:0] ex, input [11:0] ez);
        begin
            enable=e; flip_x=f; scan_odd=x; zoom_in=z; #1;
            if (x_start !== ex || hzoom !== ez)
                $fatal(1, "GX975 e=%0d f=%0d x=%04h z=%03h -> x=%03h/%03h expected %03h/%03h",
                    e,f,x,z,x_start,hzoom,ex,ez);
        end
    endtask

    initial begin
        check(0,0,16'h0100,12'h020,10'h100,12'h020);
        check(0,1,16'h0100,12'h040,10'h300,12'h040);
        check(1,0,16'h0100,12'h020,10'h081,12'h041);
        check(1,1,16'h0100,12'h020,10'h1ff,12'h041);
        check(1,0,16'h0101,12'h040,10'h081,12'h080);
        check(1,1,16'h01ff,12'h010,10'h180,12'h020);
        $display("ESCAPE KIDS GX975 MATH PASS");
        $finish;
    end
endmodule
