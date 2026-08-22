`timescale 1ns/1ps

module tb_escape_kids_hw_debug;

reg clk;
reg rst = 1'b1;
reg enable = 1'b0;
reg [4:0] page = 5'd0;
reg [3:0] hist_sel = 4'd0;
reg [15:0] live_pc = 16'h8058;
reg [15:0] pcbad = 16'h1234;
reg [15:0] live_addr = 16'h5678;
reg [7:0] last_op = 8'hC2;
reg [7:0] cpu_din = 8'hA5;
reg [7:0] rom_data = 8'h5A;
reg [7:0] aupper = 8'h18;
reg [15:0] trap_pc = 16'h9ABC;
reg [15:0] trap_addr = 16'hDEF0;
reg [7:0] trap_op = 8'hE1;
reg [7:0] trap_data = 8'hD2;
reg [7:0] trap_flags = 8'hC3;
reg [15:0] hist_pc = 16'hBEEF;
reg [15:0] hist_addr = 16'hCAFE;
reg [7:0] hist_op = 8'hB4;
reg [7:0] hist_data = 8'hA5;
reg [7:0] hist_flags = 8'h96;
reg [7:0] cpu_reg_byte = 8'h87;
reg [15:0] accept_count = 16'h1234;
reg trap_seen = 1'b1;
reg berr_l = 1'b1;
reg buserror = 1'b0;
reg dtack = 1'b1;
reg eep_rdy = 1'b0;
reg main_cs = 1'b1;
reg main_ok = 1'b0;
reg main_cpu_ok = 1'b1;
reg cpu_cen = 1'b1;
reg pal_we = 1'b0;
reg tilesys_cs = 1'b0;
reg objsys_cs = 1'b0;
reg objreg_cs = 1'b0;
reg pcu_cs = 1'b0;
reg k053252_cs = 1'b0;
reg rmrd = 1'b0;
reg lvbl = 1'b1;
reg lhbl = 1'b1;
reg pxl_cen = 1'b0;
reg [7:0] red = 8'd0;
reg [7:0] green = 8'd0;
reg [7:0] blue = 8'd0;
reg snd_cs = 1'b0;
reg snd_ok = 1'b0;
reg snd_irq = 1'b0;
reg [3:0] pcm_bsy = 4'd0;
reg [3:0] pcm_sample = 4'd0;
reg [3:0] pcm_warm = 4'd0;
reg [3:0] pcm_underrun = 4'd0;
reg [15:0] snd_l = 16'd0;
reg [15:0] snd_r = 16'd0;
reg esckids = 1'b1;
reg cabinet_2p = 1'b0;
reg rst24 = 1'b0;
reg rst48 = 1'b0;
reg rst96 = 1'b0;
reg irq_n = 1'b1;
reg firq_n = 1'b1;
reg nmi_n = 1'b1;
reg dma_bsy = 1'b0;
wire [7:0] debug_view;
wire [7:0] video_ever;
wire [7:0] sound_ever;
wire [15:0] palette_writes;
wire [15:0] sound_events;
wire [15:0] audio_nonzero;

always #5 clk = ~clk;

escape_kids_hw_debug dut(.*);

task check;
    input [7:0] expected;
    begin
        #1;
        if (debug_view !== expected)
            $fatal(1, "page=%0d slot=%0d expected=%02x got=%02x",
                   page, hist_sel, expected, debug_view);
    end
endtask

initial begin
    clk = 1'b0;
    repeat (2) @(posedge clk);
    rst = 1'b0;
    @(posedge clk);
    check(8'h00);

    enable = 1'b1;
    page = 5'd0;
    hist_sel = 4'd0;
    check(8'hD5);
    hist_sel = 4'd1;
    check(8'h34);
    hist_sel = 4'd2;
    check(8'h12);

    page = 5'd1;
    check(8'b11010111);
    page = 5'd8;
    check(8'hC2);
    page = 5'd12;
    check(8'h9A);
    page = 5'd13;
    check(8'hBC);
    page = 5'd23;
    check(8'hB4);

    page = 5'd31;
    check(8'h87);

    @(negedge clk);
    pal_we = 1'b1;
    red = 8'h01;
    snd_cs = 1'b1;
    snd_irq = 1'b1;
    pcm_sample = 4'h1;
    snd_l = 16'h0001;
    @(posedge clk);
    #1;
    pal_we = 1'b0;
    snd_cs = 1'b0;
    snd_irq = 1'b0;
    pcm_sample = 4'd0;
    snd_l = 16'd0;

    page = 5'd27;
    #1;
    if ((debug_view & 8'b10001000) !== 8'b10001000)
        $fatal(1, "video sticky activity missing: %02x", debug_view);
    page = 5'd0;
    hist_sel = 4'h3;
    check(8'h01);
    hist_sel = 4'h5;
    check(8'h01);
    hist_sel = 4'h7;
    check(8'h01);
    hist_sel = 4'h9;
    #1;
    if (debug_view !== 8'hD4)
        $fatal(1, "sound sticky activity missing: %02x", debug_view);
    if (video_ever !== 8'h88)
        $fatal(1, "video output latch mismatch: %02x", video_ever);
    if (sound_ever !== 8'hD4)
        $fatal(1, "sound output latch mismatch: %02x", sound_ever);
    if (palette_writes !== 16'd1 || sound_events !== 16'd1 ||
        audio_nonzero !== 16'd1)
        $fatal(1, "counter mismatch pal=%0d snd=%0d audio=%0d",
               palette_writes, sound_events, audio_nonzero);

    $display("ESCAPE KIDS HARDWARE DEBUG PASS");
    $finish;
end

endmodule
