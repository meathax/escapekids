`timescale 1ns/1ps

module tb_escape_kids_rom_ready;

reg         clk;
reg         rst;
reg         enable;
reg         rom_cs;
reg  [18:0] rom_addr;
reg         rom_ok;
wire        cpu_rom_ok;

always #5 clk = ~clk;

escape_kids_rom_ready dut(
    .clk        ( clk        ),
    .rst        ( rst        ),
    .enable     ( enable     ),
    .rom_cs     ( rom_cs     ),
    .rom_addr   ( rom_addr   ),
    .rom_ok     ( rom_ok     ),
    .cpu_rom_ok ( cpu_rom_ok )
);

task tick;
    begin
        @(posedge clk);
        #1;
    end
endtask

task expect_ok;
    input expected;
    input string label_text;
    begin
        if (cpu_rom_ok !== expected)
            $fatal(1, "%0s: cpu_rom_ok=%b expected=%b", label_text,
                cpu_rom_ok, expected);
    end
endtask

initial begin
    clk = 1'b0;
    rst = 1'b1;
    enable = 1'b1;
    rom_cs = 1'b1;
    rom_addr = 19'h1805a;
    rom_ok = 1'b1;

    tick;
    expect_ok(1'b1, "reset has no stale address identity");

    rst = 1'b0;
    tick;
    expect_ok(1'b1, "first request remains transparent");

    rom_cs = 1'b0;
    tick;
    rom_cs = 1'b1;
    #1;
    expect_ok(1'b1, "same-address reentry remains transparent");
    tick;
    expect_ok(1'b1, "same-address request remains accepted");

    rom_cs = 1'b0;
    tick;
    rom_addr = 19'h18058;
    rom_cs = 1'b1;
    #1;
    expect_ok(1'b0, "805a to 8058 reentry blocks stale same-line lane");
    tick;
    expect_ok(1'b0, "same-line stale ready remains blocked");
    rom_ok = 1'b0;
    tick;
    expect_ok(1'b0, "same-line request observes raw not-ready");
    rom_ok = 1'b1;
    #1;
    expect_ok(1'b1, "8058 accepts only the fresh lane response");
    tick;

    rom_cs = 1'b0;
    tick;
    rom_addr = 19'h01c00;
    rom_ok = 1'b0;
    rom_cs = 1'b1;
    tick;
    expect_ok(1'b0, "incomplete speculative request remains blocked");
    rom_cs = 1'b0;
    tick;
    rom_addr = 19'h18058;
    rom_ok = 1'b1;
    rom_cs = 1'b1;
    #1;
    expect_ok(1'b1, "incomplete request does not replace completed address");
    tick;

    rom_cs = 1'b0;
    tick;
    rom_addr = 19'h1805c;
    rom_cs = 1'b1;
    #1;
    expect_ok(1'b0, "different-line reentry blocks stale ready");
    tick;
    expect_ok(1'b0, "stale ready remains blocked across clocks");

    rom_ok = 1'b0;
    tick;
    expect_ok(1'b0, "raw not-ready remains blocked");
    rom_ok = 1'b1;
    #1;
    expect_ok(1'b1, "fresh ready is forwarded after observed not-ready");

    enable = 1'b0;
    rom_cs = 1'b0;
    rom_addr = 19'h12344;
    rom_ok = 1'b0;
    #1;
    expect_ok(1'b0, "donor bypass forwards raw low");
    rom_ok = 1'b1;
    #1;
    expect_ok(1'b1, "donor bypass forwards raw high");

    tick;
    enable = 1'b1;
    rom_cs = 1'b1;
    rom_addr = 19'h12348;
    #1;
    expect_ok(1'b1, "profile first request has no stale address identity");

    $display("ESCAPE KIDS ROM READY PASS");
    $finish;
end

endmodule
