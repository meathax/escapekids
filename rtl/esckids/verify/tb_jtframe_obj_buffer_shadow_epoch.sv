`timescale 1ns/1ps

// Adapted from Bucky's cross-project finding:
//   Bucky/cores/bucky/hdl/sim/tb_k053247_buffer_shadow_epoch.sv
// k053247_buffer.v (Bucky, K053246/47 family) had a ping-pong line buffer
// where `line` toggles on LHBL fall, and a shadow-priority write registered
// ONE CLOCK EARLIER than the `line` toggle could land in the WRONG
// ping-pong buffer half.  This testbench checks whether the SAME hazard
// shape exists in jtframe_obj_buffer.v (K053244/45 family, used by
// jtsimson_obj.v / Escape Kids with SHADOW=1), which has a single write
// port instead of Bucky's 4-port quad-bank fork, but the identical
// 1-clock-delayed shadow RMW register chain (shdin/sh_wa/sh_we) gated by
// an UN-registered, current-cycle `line` at the write mux.
`define SIMULATION
module tb_jtframe_obj_buffer_shadow_epoch;
    reg clk=0, LHBL=1, flip=0, rd=0;
    reg [7:0] wr_data=0;
    reg [8:0] wr_addr=0, rd_addr=0;
    reg we=0;
    wire [7:0] rd_data;
    integer failures=0;

    always #5 clk=~clk;

    jtframe_obj_buffer #(
        .DW(8),.AW(9),.ALPHAW(4),.ALPHA(0),.BLANK(0),
        .BLANK_DLY(2),.SW(2),.SHADOW_PEN(15),.SHADOW(1)
    ) dut(
        .clk(clk),.LHBL(LHBL),.flip(flip),
        .wr_data(wr_data),.wr_addr(wr_addr),.we(we),
        .rd_addr(rd_addr),.rd(rd),.rd_data(rd_data)
    );

    task line_flip;
        begin
            @(negedge clk); LHBL=0;
            @(posedge clk); #1;
            @(negedge clk); LHBL=1;
        end
    endtask

    task read_expect;
        input [8:0] a;
        input [1:0] expected_shadow;
        begin
            @(negedge clk); rd_addr=a; rd=1;
            @(negedge clk); rd=0;
            repeat(2) @(posedge clk); #1;
            if(rd_data[7:6]!==expected_shadow) begin
                $display("FAIL addr=%0d expected shadow=%0d actual=%0d data=%02x line=%0d",
                    a,expected_shadow,rd_data[7:6],rd_data,dut.line);
                failures=failures+1;
            end
        end
    endtask

    initial begin
        repeat(2) @(posedge clk);

        // A settled shadow write belongs to the current producer bank and
        // must appear when that bank becomes the displayed line.
        @(negedge clk); wr_addr=9'd4; wr_data=8'h4f; we=1;
        @(negedge clk); we=0;
        repeat(2) @(posedge clk);
        line_flip();
        read_expect(9'd4,2'd1);

        // Present a shadow write on the exact bank-flip edge.  Its one-cycle
        // RMW control (shdin/sh_wa/sh_we, registered off THIS cycle's
        // add_shade/erase_shade) fires the RAM write next cycle gated by
        // `line & sh_we` / `~line & sh_we`, both using the CURRENT (post-
        // flip) `line` rather than the producer epoch.  If `line` toggles in
        // the intervening cycle, the write silently retargets the other
        // ping-pong half instead of being safely dropped or landing in the
        // half it was drawn for.
        @(negedge clk); wr_addr=9'd8; wr_data=8'h4f; we=1; LHBL=0;
        @(posedge clk); #1;
        @(negedge clk); we=0; LHBL=1;
        repeat(2) @(posedge clk);
        line_flip();
        read_expect(9'd8,2'd0);

        if(failures!=0) $fatal(1,"jtframe_obj_buffer shadow epoch failures=%0d",failures);
        $display("PASS tb_jtframe_obj_buffer_shadow_epoch");
        $finish;
    end
endmodule
