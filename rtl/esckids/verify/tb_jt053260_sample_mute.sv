module tb_jt053260_sample_mute;
    logic rst = 1'b1;
    logic clk = 1'b0;
    logic cen = 1'b1;
    logic [3:0] ch_mute = 4'b0000;

    wire [7:0] mdin, dout;
    wire [20:0] roma_addr, romb_addr, romc_addr, romd_addr;
    wire roma_cs, romb_cs, romc_cs, romd_cs;
    wire [20:0] ch0_start, ch1_start, ch2_start, ch3_start;
    wire [3:0] channel_sample, channel_bsy, channel_reverse;
    wire signed [15:0] snd_l, snd_r;
    wire sample, tim2;

    jt053260 dut(
        .rst(rst),
        .clk(clk),
        .cen(cen),
        .ma0(1'b0),
        .mrdnw(1'b1),
        .mcs(1'b0),
        .mdout(8'd0),
        .mdin(mdin),
        .addr(6'd0),
        .wr_n(1'b1),
        .rd_n(1'b1),
        .cs(1'b0),
        .din(8'd0),
        .dout(dout),
        .roma_addr(roma_addr),
        .roma_data(8'd0),
        .roma_cs(roma_cs),
        .romb_addr(romb_addr),
        .romb_data(8'd0),
        .romb_cs(romb_cs),
        .romc_addr(romc_addr),
        .romc_data(8'd0),
        .romc_cs(romc_cs),
        .romd_addr(romd_addr),
        .romd_data(8'd0),
        .romd_cs(romd_cs),
        .ch0_start(ch0_start),
        .ch1_start(ch1_start),
        .ch2_start(ch2_start),
        .ch3_start(ch3_start),
        .channel_sample(channel_sample),
        .channel_bsy(channel_bsy),
        .channel_reverse(channel_reverse),
        .aux_l(16'sd0),
        .aux_r(16'sd0),
        .snd_l(snd_l),
        .snd_r(snd_r),
        .sample(sample),
        .tim2(tim2),
        .ch_en(5'b00011),
        .ch_mute(ch_mute)
    );

    always #5 clk = ~clk;

    task automatic check_mix(input signed [15:0] expected_l, input signed [15:0] expected_r, input [3:0] mute, input [127:0] label);
        begin
            ch_mute = mute;
            @(posedge clk);
            @(posedge clk);
            #1;
            if (snd_l !== expected_l || snd_r !== expected_r)
                $fatal(1, "%0s: expected L/R %0d/%0d, got %0d/%0d", label, expected_l, expected_r, snd_l, snd_r);
        end
    endtask

    initial begin
        force dut.ch0_snd_l = 16'sd100;
        force dut.ch0_snd_r = -16'sd100;
        force dut.ch1_snd_l = 16'sd200;
        force dut.ch1_snd_r = -16'sd200;
        force dut.sum_en = 6'b000011;
        force dut.mode[1] = 1'b1;

        repeat (3) @(posedge clk);
        rst = 1'b0;
        check_mix(16'sd300, -16'sd300, 4'b0000, "unmuted");
        check_mix(16'sd100, -16'sd100, 4'b0010, "channel-1 muted");
        check_mix(16'sd200, -16'sd200, 4'b0001, "channel-0 muted");
        check_mix(16'sd300, -16'sd300, 4'b0100, "unrelated channel mute");

        $display("JT053260 SAMPLE MUTE PASS");
        $finish;
    end
endmodule