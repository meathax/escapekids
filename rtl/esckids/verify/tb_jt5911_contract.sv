`timescale 1ns/1ps
module tb_jt5911_contract;
reg clk=0, rst=1, sclk=0, sdi=0, scs=0, dump_clr=0;
wire sdo, rdy;
wire [6:0] mem_addr;
wire [7:0] mem_din;
wire mem_we, dump_flag;
reg [7:0] mem [0:127];
wire [7:0] mem_dout = mem[mem_addr];
integer i, writes, unique_writes;
integer first_write;
reg [127:0] written;
reg [7:0] readback;

always #5 clk=~clk;
always @(posedge clk) if (mem_we) begin
    mem[mem_addr] <= mem_din;
    if (writes == 0) first_write = mem_addr;
    writes = writes + 1;
    if (!written[mem_addr]) begin
        written[mem_addr] = 1'b1;
        unique_writes = unique_writes + 1;
    end
end

jt5911 dut(
    .rst(rst),.clk(clk),.sclk(sclk),.sdi(sdi),.sdo(sdo),.rdy(rdy),
    .scs(scs),.mem_addr(mem_addr),.mem_din(mem_din),.mem_we(mem_we),
    .mem_dout(mem_dout),.dump_clr(dump_clr),.dump_flag(dump_flag)
);

task serial_bit(input bit value);
begin
    sdi=value; sclk=0; repeat(2) @(posedge clk);
    sclk=1; repeat(2) @(posedge clk);
    sclk=0; repeat(2) @(posedge clk);
end endtask

task cs_low;
begin
    scs=0; sdi=0; sclk=0; repeat(5) @(posedge clk);
end endtask

task command(input [3:0] op, input [6:0] address);
integer b;
reg [10:0] bits;
begin
    cs_low(); scs=1; repeat(5) @(posedge clk);
    serial_bit(0); serial_bit(1);
    bits={op,address};
    for(b=10;b>=0;b=b-1) serial_bit(bits[b]);
end endtask

task write_byte(input [3:0] op,input [6:0] address,input [7:0] value);
integer b;
begin
    command(op,address);
    for(b=7;b>=0;b=b-1) serial_bit(value[b]);
    repeat(4) @(posedge clk); cs_low();
end endtask

task read_byte(input [6:0] address,output [7:0] value);
integer b;
begin
    command(4'b1000,address); repeat(3) @(posedge clk);
    value=0;
    for(b=8;b>=0;b=b-1) begin
        sdi=0; sclk=0; repeat(2) @(posedge clk);
        sclk=1; repeat(2) @(posedge clk); #1;
        if(b<8) value[b]=sdo;
        sclk=0; repeat(2) @(posedge clk);
    end
    cs_low();
end endtask

initial begin
    writes=0; unique_writes=0; first_write=-1; written=0;
    for(i=0;i<128;i=i+1) mem[i]=i[7:0];
    repeat(5) @(posedge clk); rst=0; cs_low();

    write_byte(4'b0100,7'h12,8'ha5);
    if(writes!=0 || mem[7'h12]!==8'h12) $fatal(1,"locked write changed memory");
    command(4'b0011,0); cs_low();
    write_byte(4'b0100,7'h12,8'ha5);
    if(writes!=1 || mem[7'h12]!==8'ha5) $fatal(1,"enabled opcode01 write failed");
    write_byte(4'b1100,7'h13,8'h5a);
    if(writes!=2 || mem[7'h13]!==8'h5a) $fatal(1,"enabled opcode11 write failed");
    read_byte(7'h12,readback);
    if(readback!==8'ha5) $fatal(1,"readback mismatch %02h",readback);
    command(4'b0000,0); cs_low();
    write_byte(4'b0100,7'h14,8'hc3);
    if(writes!=2 || mem[7'h14]!==8'h14) $fatal(1,"EWDS did not lock write");
    command(4'b0001,7'h55);
    repeat(8) serial_bit(1);
    cs_low();
    if(writes!=2) $fatal(1,"reserved opcode wrote memory");

    command(4'b0011,0); cs_low();
    writes=0; unique_writes=0; first_write=-1; written=0;
    command(4'b0010,7'h55);
    repeat(400) @(posedge clk);
    cs_low();
    if(writes!=128 || unique_writes!=128) begin
        $display("JT5911_CONTRACT_RESULT outcome=eral_address_violation_observed first_addr=%02h writes=%0d unique=%0d dump=%0d",first_write,writes,unique_writes,dump_flag);
        $finish;
    end
    for(i=0;i<128;i=i+1)
        if(mem[i]!==8'hff) begin
            $display("JT5911_CONTRACT_RESULT outcome=eral_data_violation_observed first_addr=%02h data=%02h writes=%0d unique=%0d dump=%0d",i,mem[i],writes,unique_writes,dump_flag);
            $finish;
        end
    $display("JT5911_CONTRACT_RESULT outcome=contract_pass writes=%0d unique=%0d",writes,unique_writes);
    $finish;
end
endmodule
