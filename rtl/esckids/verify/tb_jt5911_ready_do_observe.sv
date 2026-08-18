`timescale 1ns/1ps

module tb_jt5911_ready_do_observe;
reg clk = 0, rst = 1, sclk = 0, sdi = 0, scs = 0;
wire sdo, rdy;
wire [6:0] mem_addr;
wire [7:0] mem_din;
wire mem_we;
reg [7:0] mem [0:127];
integer writes = 0;
integer writes_before_recommand;
integer b;
reg reset_rdy, reset_sdo, standby_rdy, standby_sdo;
reg post_write_rdy, post_write_sdo;

always #5 clk = ~clk;
always @(posedge clk) if (mem_we) begin
    mem[mem_addr] <= mem_din;
    writes = writes + 1;
end

jt5911 dut(
    .rst(rst), .clk(clk), .sclk(sclk), .sdi(sdi), .sdo(sdo), .rdy(rdy),
    .scs(scs), .mem_addr(mem_addr), .mem_din(mem_din), .mem_we(mem_we),
    .mem_dout(mem[mem_addr]), .dump_clr(1'b0), .dump_flag()
);

task serial_bit(input bit value);
begin
    sdi = value; sclk = 0; repeat (2) @(posedge clk);
    sclk = 1; repeat (2) @(posedge clk);
    sclk = 0; repeat (2) @(posedge clk);
end
endtask

task cs_low;
begin
    scs = 0; sdi = 0; sclk = 0; repeat (5) @(posedge clk);
end
endtask

task command(input [3:0] op, input [6:0] address);
reg [10:0] bits;
begin
    cs_low(); scs = 1; repeat (5) @(posedge clk);
    serial_bit(0); serial_bit(1);
    bits = {op,address};
    for (b = 10; b >= 0; b = b-1) serial_bit(bits[b]);
end
endtask

task command_without_cs_release(input [3:0] op, input [6:0] address, input [7:0] value);
reg [10:0] bits;
begin
    serial_bit(0); serial_bit(1);
    bits = {op,address};
    for (b = 10; b >= 0; b = b-1) serial_bit(bits[b]);
    for (b = 7; b >= 0; b = b-1) serial_bit(value[b]);
end
endtask

initial begin
    for (b = 0; b < 128; b = b+1) mem[b] = b[7:0];
    repeat (3) @(posedge clk); #1;
    reset_rdy = rdy;
    reset_sdo = sdo;
    rst = 0;
    cs_low(); #1;
    standby_rdy = rdy;
    standby_sdo = sdo;

    command(4'b0011, 0); // EWEN
    cs_low();
    command(4'b0100, 7'h21);
    for (b = 7; b >= 0; b = b-1) serial_bit((8'h5a >> b) & 1'b1);
    repeat (2) @(posedge clk); #1;
    post_write_rdy = rdy;
    post_write_sdo = sdo;
    if (writes !== 1 || mem[7'h21] !== 8'h5a)
        $fatal(1, "normal write did not commit writes=%0d data=%02h", writes, mem[7'h21]);

    writes_before_recommand = writes;
    command_without_cs_release(4'b0100, 7'h22, 8'ha5);
    repeat (4) @(posedge clk);
    if (writes !== writes_before_recommand || mem[7'h22] !== 8'h22)
        $fatal(1, "WAIT accepted command without CS release");

    $display("JT5911_READY_DO_OBSERVATION reset_rdy=%0d reset_sdo=%0d standby_rdy=%0d standby_sdo=%0d post_write_rdy=%0d post_write_sdo=%0d busy_recommand_writes=%0d functional_write=1",
        reset_rdy, reset_sdo, standby_rdy, standby_sdo,
        post_write_rdy, post_write_sdo, writes-writes_before_recommand);
    $finish;
end
endmodule
