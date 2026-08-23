`timescale 1ns/1ps

module tb_esckids_obj_dma_frame_bank;

reg clk=0, rst=1, dma_trig=0, hs=0, lvbl=0;
wire [13:1] dma_addr;
wire [15:0] dma_data;
wire dma_bsy, dma_weh, dma_wel, dma_wr_bank, scan_bank;
wire [11:1] dma_wr_addr;
wire [15:0] dma_din;
wire flicker;
reg [15:0] source_ram [0:2047];
reg [15:0] private_ram [0:1][0:2047];
integer i, cycles, bank_seen;

always #5 clk=~clk;
assign dma_data = source_ram[dma_addr[11:1]];

always @(posedge clk)
    if( dma_weh || dma_wel ) private_ram[dma_wr_bank][dma_wr_addr] <= dma_din;

jt053246_dma dut(
    .rst(rst),.clk(clk),.pxl2_cen(1'b1),
    .mode8(1'b0),.dma_en(1'b0),.dma_trig(dma_trig),
    .k44_en(1'b1),.lut256(1'b1),.simson(1'b0),
    .hs(hs),.lvbl(lvbl),
    .dma_addr(dma_addr),.dma_data(dma_data),.dma_bsy(dma_bsy),
    .dma_weh(dma_weh),.dma_wel(dma_wel),.dma_wr_addr(dma_wr_addr),
    .dma_wr_bank(dma_wr_bank),.scan_bank(scan_bank),.dma_din(dma_din),
    .flicker(flicker)
);

task run_dma;
    begin
        dma_trig <= 1;
        @(posedge clk);
        dma_trig <= 0;
        cycles=0;
        while(!dma_bsy && cycles<20) begin @(posedge clk); cycles=cycles+1; end
        bank_seen = dma_wr_bank;
        while(dma_bsy && cycles<30000) begin @(posedge clk); cycles=cycles+1; end
        if(dma_bsy) $fatal(1,"OBJ_DMA_FRAME_BANK timeout");
        @(posedge clk);
    end
endtask

task hs_line;
    input blank_state;
    begin
        @(negedge clk); lvbl=blank_state; hs=1;
        @(posedge clk); #1;
        @(negedge clk); hs=0;
        @(posedge clk); #1;
    end
endtask

initial begin
    for(i=0;i<2048;i=i+1) begin
        source_ram[i]=0;
        private_ram[0][i]=16'hdead;
        private_ram[1][i]=16'hdead;
    end
    source_ram[0] = 16'h8004;
    source_ram[1] = 16'h1101;
    source_ram[2] = 16'h1102;
    source_ram[3] = 16'h1103;
    source_ram[4] = 16'h1104;
    source_ram[5] = 16'h1105;
    source_ram[6] = 16'h1106;

    repeat(4) @(posedge clk);
    rst=0;
    run_dma();
    if(bank_seen!==1 || scan_bank!==0)
        $fatal(1,"OBJ_DMA_FRAME_BANK first write/scan bank=%0d/%0d",bank_seen,scan_bank);
    hs_line(1'b0);
    hs_line(1'b1);
    if(scan_bank!==1)
        $fatal(1,"OBJ_DMA_FRAME_BANK first commit bank=%0d",scan_bank);

    source_ram[1]=16'h2201;
    run_dma();
    if(bank_seen!==0 || scan_bank!==1)
        $fatal(1,"OBJ_DMA_FRAME_BANK second write/scan bank=%0d/%0d",bank_seen,scan_bank);
    hs_line(1'b0);
    hs_line(1'b1);
    if(scan_bank!==0)
        $fatal(1,"OBJ_DMA_FRAME_BANK second commit bank=%0d",scan_bank);
    if(private_ram[1][1]!==16'h1101 || private_ram[0][1]!==16'h2201)
        $fatal(1,"OBJ_DMA_FRAME_BANK bank contents mixed old=%04x new=%04x",
            private_ram[1][1],private_ram[0][1]);

    $display("OBJ_DMA_FRAME_BANK PASS commits=2 writes=inactive scan=stable");
    $finish;
end

initial begin
    #2_000_000 $fatal(1,"OBJ_DMA_FRAME_BANK global timeout");
end

endmodule
