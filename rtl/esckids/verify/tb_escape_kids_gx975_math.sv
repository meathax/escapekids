`timescale 1ns/1ps
module tb_escape_kids_gx975_math;
    logic enable, hw_enable, flip_x;
    logic [15:0] scan_odd;
    logic [11:0] zoom_in;
    logic [9:0] xoffset;
    logic [9:0] x_start;
    logic [11:0] hzoom;
    logic [9:0] xadj;
    integer rtl_screen_x;
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

    // Display-window offset polarity.  screen_x = x_start + xadj - 105, where
    // 105 is the shared jtframe_objdraw pipeline constant (calibrated twice:
    // jt053246_scan HOFFSET 62 against MAME vendetta dx -43, and jt053244_scan
    // 0x66 against the MAME 053244 device constant -96+0x5d with parodius
    // dx 0).  MAME esckids: screen_x = ((ox>>1)+1) - offx + 5.
    task automatic check_off(input logic hw, input [9:0] off, input [9:0] ea);
        begin
            hw_enable=hw; xoffset=off; #1;
            if (xadj !== ea)
                $fatal(1, "GX975 OFFSET hw=%0d offx=%0d -> xadj=%0d expected %0d",
                    hw, off, xadj, ea);
        end
    endtask

    initial begin
        hw_enable=0; xoffset=0;
        check(0,0,16'h0100,12'h020,10'h100,12'h020);
        check(0,1,16'h0100,12'h040,10'h300,12'h040);
        // hzoom = raw<<1 uniformly (special-case raw==0x020 patch removed;
        // see rtl/esckids/verify/tb_esckids_obj_zoom.sv for the full sweep
        // proof against MAME's real reciprocal zoom formula).
        check(1,0,16'h0100,12'h020,10'h081,12'h040);
        check(1,1,16'h0100,12'h020,10'h1ff,12'h040);
        check(1,0,16'h0101,12'h040,10'h081,12'h080);
        check(1,1,16'h01ff,12'h010,10'h180,12'h020);

        // Donor 053244/5 path is unchanged for every offx value.
        check_off(0, 10'd0,   10'd102);
        check_off(0, 10'd102, 10'd204);
        check_off(0, 10'd7,   10'd109);
        // 053246/7 (Escape Kids) subtracts.  offx=0 degenerates to dx=5.
        check_off(1, 10'd0,   10'd110);
        check_off(1, 10'd102, 10'd8);
        check_off(1, 10'd110, 10'd0);
        // Live esckids attract vector: obj header a=0x9500, ox=0x0106,
        // offx=0x66, zoomx=0x0020, size 5 (2x2 tiles).
        //   MAME: (0x106>>1)+1 = 132; 132-102+5 = 35; centre (0x10000*2)>>13
        //         = 16; screen_x = 19.
        //   RTL : x_start 132, xadj 8, hscl zoffset[0x41]=32, zmove(1,32)=16,
        //         hpos = 124; screen_x = 124-105 = 19.
        check_off(1, 10'd102, 10'd8);
        begin
            enable=1; flip_x=0; scan_odd=16'h0106; zoom_in=12'h020; #1;
            rtl_screen_x = x_start + xadj - 16 - 105;
            if (rtl_screen_x !== 19)
                $fatal(1, "GX975 esckids vector screen_x=%0d expected 19", rtl_screen_x);
        end

        $display("ESCAPE KIDS GX975 MATH PASS");
        $finish;
    end
endmodule
