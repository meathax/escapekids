`timescale 1ns/1ps

module tb_esckids_obj_dma_zcode;

reg         rst = 1;
reg         clk = 0;
reg         dma_trig = 0;
wire [13:1] dma_addr;
wire [15:0] dma_data;
wire        dma_bsy;
wire        dma_weh, dma_wel;
wire [11:1] dma_wr_addr;
wire        dma_wr_bank, scan_bank;
wire [15:0] dma_din;
wire        flicker;

reg [15:0] source_ram  [0:2047];
reg [15:0] private_ram [0:2047];
integer i, k, cycles;

always #5 clk = ~clk;
assign dma_data = source_ram[dma_addr[11:1]];

always @(posedge clk) begin
    if( dma_weh || dma_wel ) private_ram[dma_wr_addr] <= dma_din;
end

task clear_source;
    begin
        for( i=0; i<2048; i=i+1 ) source_ram[i] = 0;
    end
endtask

task set_sprite;
    input [7:0] src;
    input [7:0] z;
    input       enable;
    input [7:0] tag;
    begin
        source_ram[{src,3'd0}] = {enable,7'd0,z};
        for( k=1; k<7; k=k+1 )
            source_ram[{src,k[2:0]}] = {tag,k[7:0]};
        source_ram[{src,3'd7}] = 16'hffff;
    end
endtask

task run_dma;
    begin
        dma_trig <= 1;
        @(posedge clk);
        dma_trig <= 0;
        cycles = 0;
        while( !dma_bsy && cycles<20 ) begin
            @(posedge clk);
            cycles = cycles+1;
        end
        while( dma_bsy && cycles<30000 ) begin
            @(posedge clk);
            cycles = cycles+1;
        end
        if( dma_bsy ) $fatal(1,"OBJ_DMA_ZCODE DMA timeout cycles=%0d",cycles);
        @(posedge clk);
    end
endtask

task check_slot;
    input [7:0] slot;
    input [7:0] z;
    input [7:0] tag;
    begin
        if( private_ram[{slot,3'd0}] !== {1'b1,7'd0,z} )
            $fatal(1,"OBJ_DMA_ZCODE slot%0d header=%04x",slot,private_ram[{slot,3'd0}]);
        for( k=1; k<7; k=k+1 )
            if( private_ram[{slot,k[2:0]}] !== {tag,k[7:0]} )
                $fatal(1,"OBJ_DMA_ZCODE slot%0d word%0d=%04x",slot,k,private_ram[{slot,k[2:0]}]);
        if( private_ram[{slot,3'd7}] !== 0 )
            $fatal(1,"OBJ_DMA_ZCODE slot%0d word7=%04x",slot,private_ram[{slot,3'd7}]);
    end
endtask

jt053246_dma dut(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .pxl2_cen   ( 1'b1        ),
    .mode8      ( 1'b0        ),
    .dma_en     ( 1'b0        ),
    .dma_trig   ( dma_trig    ),
    .k44_en     ( 1'b1        ),
    .lut256     ( 1'b1        ),
    .simson     ( 1'b0        ),
    .hs         ( 1'b0        ),
    .lvbl       ( 1'b0        ),
    .dma_addr   ( dma_addr    ),
    .dma_data   ( dma_data    ),
    .dma_bsy    ( dma_bsy     ),
    .dma_weh    ( dma_weh     ),
    .dma_wel    ( dma_wel     ),
    .dma_wr_addr( dma_wr_addr ),
    .dma_wr_bank( dma_wr_bank ),
    .scan_bank  ( scan_bank   ),
    .dma_din    ( dma_din     ),
    .flicker    ( flicker     )
);

initial begin
    clear_source();
    for( i=0; i<2048; i=i+1 ) private_ram[i] = 16'hdead;

    repeat(4) @(posedge clk);
    rst <= 0;
    @(posedge clk);

    // Consecutive active entries with different keys exercise the synchronous
    // count-RAM address latency.  Each key must contribute exactly one slot.
    set_sprite(8'd0, 8'h70, 1'b1, 8'ha0);
    set_sprite(8'd1, 8'h71, 1'b1, 8'ha1);
    set_sprite(8'd2, 8'h72, 1'b1, 8'ha2);
    set_sprite(8'd3, 8'h73, 1'b1, 8'ha3);
    run_dma();
    check_slot(8'd0,8'h70,8'ha0);
    check_slot(8'd1,8'h71,8'ha1);
    check_slot(8'd2,8'h72,8'ha2);
    check_slot(8'd3,8'h73,8'ha3);

    clear_source();
    set_sprite(8'd0,   8'h81, 1'b1, 8'h10);
    set_sprite(8'd17,  8'hff, 1'b1, 8'h30);
    set_sprite(8'd18,  8'hff, 1'b1, 8'h40);
    set_sprite(8'd19,  8'hff, 1'b0, 8'hee);
    set_sprite(8'd80,  8'hff, 1'b1, 8'h50);
    set_sprite(8'd128, 8'h01, 1'b1, 8'h20);
    run_dma();

    check_slot(8'd0,8'h01,8'h20);
    check_slot(8'd1,8'h81,8'h10);
    check_slot(8'd2,8'hff,8'h30);
    check_slot(8'd3,8'hff,8'h40);
    check_slot(8'd4,8'hff,8'h50);
    if( private_ram[{8'd5,3'd0}] !== 0 )
        $fatal(1,"OBJ_DMA_ZCODE disabled/unused slot not clear");

    source_ram[{8'd128,3'd1}] = 16'h9911;
    repeat(100) @(posedge clk);
    if( private_ram[{8'd0,3'd1}] !== 16'h2001 )
        $fatal(1,"OBJ_DMA_ZCODE private buffer followed live source RAM");
    run_dma();
    if( private_ram[{8'd0,3'd1}] !== 16'h9911 )
        $fatal(1,"OBJ_DMA_ZCODE second DMA did not latch source update");

    clear_source();
    for( i=0; i<256; i=i+1 ) set_sprite(i[7:0],8'haa,1'b1,i[7:0]);
    run_dma();
    for( i=0; i<256; i=i+1 ) begin
        if( private_ram[{i[7:0],3'd0}] !== 16'h80aa )
            $fatal(1,"OBJ_DMA_ZCODE all-same slot%0d header=%04x",i,private_ram[{i[7:0],3'd0}]);
        if( private_ram[{i[7:0],3'd1}] !== {i[7:0],8'h01} )
            $fatal(1,"OBJ_DMA_ZCODE all-same slot%0d word1=%04x",i,private_ram[{i[7:0],3'd1}]);
    end

    $display("OBJ_DMA_ZCODE PASS adjacent_distinct=4 stable_duplicates=3 all_same=256 cycles=%0d",cycles);
    $finish;
end

initial begin
    #2_000_000 $fatal(1,"OBJ_DMA_ZCODE global timeout");
end

endmodule
