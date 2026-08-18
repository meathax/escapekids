`timescale 1ns/1ps

module tb_escape_kids_auto_run;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg enable = 1'b0;
    reg lvbl = 1'b1;
    reg [6:0] joystick1 = 7'b1111111;
    reg [6:0] joystick2 = 7'b1111111;
    reg [6:0] joystick3 = 7'b1111111;
    reg [6:0] joystick4 = 7'b1111111;
    wire [6:0] joystick1_out, joystick2_out, joystick3_out, joystick4_out;

    always #5 clk = ~clk;

    escape_kids_auto_run dut(
        .clk(clk), .rst(rst), .enable(enable), .lvbl(lvbl),
        .joystick1(joystick1), .joystick2(joystick2),
        .joystick3(joystick3), .joystick4(joystick4),
        .joystick1_out(joystick1_out), .joystick2_out(joystick2_out),
        .joystick3_out(joystick3_out), .joystick4_out(joystick4_out)
    );

    task automatic check_equal;
        input [6:0] expected;
        begin
            #1;
            if (joystick1_out !== expected || joystick2_out !== expected ||
                joystick3_out !== expected || joystick4_out !== expected)
                $fatal(1, "unexpected output %b/%b/%b/%b expected %b",
                    joystick1_out, joystick2_out, joystick3_out, joystick4_out,
                    expected);
        end
    endtask

    task automatic falling_frame;
        begin
            @(negedge clk); lvbl = 1'b0;
            @(posedge clk); #1;
            @(negedge clk); lvbl = 1'b1;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        // Reset and disabled pass-through.
        repeat (2) @(posedge clk);
        rst = 1'b0;
        check_equal(7'b1111111);
        joystick1 = 7'b0010111; // Auto Run held, Super Jump pressed, Run up
        joystick2 = joystick1;
        joystick3 = joystick1;
        joystick4 = joystick1;
        check_equal(7'b0010111);

        // Enable Auto Run.  The first phase is released; each LVBL falling
        // edge alternates a synthesized Run press for all players.
        enable = 1'b1;
        check_equal(7'b0010111);
        @(posedge clk); #1; // establish the visible-phase sample
        falling_frame();
        check_equal(7'b0000111); // bit 4 forced low; bits 5/6 unchanged
        falling_frame();
        check_equal(7'b0010111);

        // A physical Run press stays pressed in both phases.
        joystick1 = 7'b0000011;
        joystick2 = joystick1;
        joystick3 = joystick1;
        joystick4 = joystick1;
        falling_frame();
        check_equal(7'b0000011);
        falling_frame();
        check_equal(7'b0000011);

        // Releasing Auto Run immediately restores the raw input.
        joystick1 = 7'b1111111;
        joystick2 = joystick1;
        joystick3 = joystick1;
        joystick4 = joystick1;
        enable = 1'b0;
        falling_frame();
        check_equal(7'b1111111);
        $display("escape_kids_auto_run PASS");
        $finish;
    end
endmodule
