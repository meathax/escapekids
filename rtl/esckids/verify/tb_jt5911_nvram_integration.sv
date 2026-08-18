`timescale 1ns/1ps
module tb_jt5911_nvram_integration;
reg clk=0,rst=1,sclk=0,sdi=0,scs=0,dump_clr=0;
reg [23:0] ioctl_addr=0; reg ioctl_ram=0,ioctl_wr=0;
reg [7:0] ioctl_dout=0;
wire [7:0] ioctl_din,serial_din,nv_q,ram_din;
wire [6:0] serial_addr,ram_addr;
wire serial_we,ram_we,sdo,rdy,dump_flag;
integer i; reg [7:0] value;
always #5 clk=~clk;

jt5911 eeprom(.rst(rst),.clk(clk),.sclk(sclk),.sdi(sdi),.sdo(sdo),
 .rdy(rdy),.scs(scs),.mem_addr(serial_addr),.mem_din(serial_din),
 .mem_we(serial_we),.mem_dout(nv_q),.dump_clr(dump_clr),.dump_flag(dump_flag));
jtframe_ram #(.AW(7),.DW(8),.LATCH_IN(0),.LATCH_OUT(0)) nvram(
 .clk(clk),.cen(1'b1),.addr(ram_addr),.data(ram_din),.we(ram_we),.q(nv_q));
jtframe_ioctl_dump #(.DW0(8),.AW0(7),.AW1(0),.AW2(0),.AW3(0),.AW4(0),.AW5(0)) dump(
 .clk(clk),.dout0(nv_q),.din0(serial_din),.din0_mx(ram_din),
 .addr0(serial_addr),.addr0_mx(ram_addr),.we0(serial_we),.we0_mx(ram_we),
 .dout1(8'd0),.dout2(8'd0),.dout3(8'd0),.dout4(8'd0),.dout5(8'd0),
 .din1(8'd0),.din2(8'd0),.din3(8'd0),.din4(8'd0),.din5(8'd0),
 .addr1(1'b0),.addr2(1'b0),.addr3(1'b0),.addr4(1'b0),.addr5(1'b0),
 .we1(1'b0),.we2(1'b0),.we3(1'b0),.we4(1'b0),.we5(1'b0),
 .ioctl_addr(ioctl_addr),.ioctl_ram(ioctl_ram),.ioctl_wr(ioctl_wr),
 .ioctl_aux(8'd0),.ioctl_dout(ioctl_dout),.ioctl_din(ioctl_din));

task bit_in(input bit v); begin sdi=v;sclk=0;repeat(2)@(posedge clk);sclk=1;repeat(2)@(posedge clk);sclk=0;repeat(2)@(posedge clk);end endtask
task gap; begin scs=0;sdi=0;sclk=0;repeat(5)@(posedge clk);end endtask
task cmd(input[3:0]op,input[6:0]a);integer b;reg[10:0]x;begin gap();scs=1;repeat(5)@(posedge clk);bit_in(0);bit_in(1);x={op,a};for(b=10;b>=0;b=b-1)bit_in(x[b]);end endtask
task wrbyte(input[6:0]a,input[7:0]d);integer b;begin cmd(4'b0100,a);for(b=7;b>=0;b=b-1)bit_in(d[b]);repeat(4)@(posedge clk);gap();end endtask
task rdbyte(input[6:0]a,output[7:0]d);integer b;begin cmd(4'b1000,a);repeat(3)@(posedge clk);d=0;for(b=8;b>=0;b=b-1)begin sdi=0;sclk=0;repeat(2)@(posedge clk);sclk=1;repeat(2)@(posedge clk);#1;if(b<8)d[b]=sdo;sclk=0;repeat(2)@(posedge clk);end gap();end endtask
task restore(input[6:0]a,input[7:0]d);begin ioctl_ram=1;ioctl_addr=a;ioctl_dout=d;ioctl_wr=1;@(posedge clk);#1;if(ram_addr!==a||ram_din!==d||ram_we!==1'b1)$fatal(1,"registered ioctl mux mismatch");@(posedge clk);#1;ioctl_wr=0;@(posedge clk);#1;end endtask
task dumpbyte(input[6:0]a,output[7:0]d);begin ioctl_ram=1;ioctl_wr=0;ioctl_addr=a;repeat(3)@(posedge clk);#1;d=ioctl_din;end endtask

always @(posedge clk) if(ioctl_ram&&serial_we&&ram_we)
 $fatal(1,"serial/ioctl write overlap");

initial begin
 repeat(5)@(posedge clk);rst=0;gap();
 for(i=0;i<128;i=i+1)restore(i[6:0],(i[7:0]^8'h5a));
 ioctl_ram=0;ioctl_wr=0;repeat(5)@(posedge clk);#1;
 if(ram_addr!==serial_addr||ram_din!==serial_din||ram_we!==serial_we)$fatal(1,"serial mux mismatch");
 for(i=0;i<128;i=i+17)begin rdbyte(i[6:0],value);if(value!==(i[7:0]^8'h5a))$fatal(1,"serial restore read mismatch");end
 cmd(4'b0011,0);gap();wrbyte(7'h12,8'ha5);wrbyte(7'h55,8'h3c);
 rst=1;repeat(3)@(posedge clk);rst=0;gap();
 rdbyte(7'h12,value);if(value!==8'ha5)$fatal(1,"reset lost nvram");
 for(i=0;i<128;i=i+1)begin dumpbyte(i[6:0],value);if(value!==((i==7'h12)?8'ha5:(i==7'h55)?8'h3c:(i[7:0]^8'h5a)))$fatal(1,"dump mismatch addr=%0d got=%02h",i,value);end
 $display("JT5911_NVRAM_INTEGRATION_RESULT outcome=pass restore=128 serial_reads=9 serial_writes=2 dump=128 retention=1 mux_overlap=0 latency=3");$finish;
end
endmodule
