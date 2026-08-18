`timescale 1ns/1ps
module tb_escape_kids_tile_contract;
    logic [7:0] color;
    logic [12:0] pre;
    logic [19:2] addr;
    logic [2:0] palette;

    escape_kids_tile_contract dut(.*);

    task automatic check(input [12:0] p, input [7:0] c,
                         input [17:0] expected_addr, input [2:0] expected_pal);
        begin
            pre = p;
            color = c;
            #1;
            if (addr !== expected_addr)
                $fatal(1, "tile address pre=%04h color=%02h got=%05h expected=%05h",
                       p, c, addr, expected_addr);
            if (palette !== expected_pal)
                $fatal(1, "tile palette color=%02h got=%0d expected=%0d",
                       c, palette, expected_pal);
        end
    endtask

    initial begin
        check(13'h12d5, 8'hf5, 18'h26ad5, 3'd7);
        check(13'h0552, 8'h1c, 18'h0e552, 3'd0);
        check(13'h1abc, 8'ha7, 18'h35abc, 3'd5);
        $display("ESCAPE KIDS TILE CALLBACK PASS");
        $finish;
    end
endmodule
