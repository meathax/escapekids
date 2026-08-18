`timescale 1ns/1ps

// Focused falsification bench only. It observes whether the real K053260
// channel consumes a sample while the real JTFRAME block cache says its data
// is invalid; it deliberately does not prescribe a production stall policy.
module tb_k053260_valid_contract;
    reg         clk = 1'b0;
    reg         rst = 1'b1;
    reg         cen = 1'b0;
    reg         run_cen = 1'b0;
    reg  [2:0]  mmr_addr = 3'd0;
    reg  [7:0]  mmr_din = 8'd0;
    reg         mmr_we = 1'b0;
    reg         keyon = 1'b0;
    reg         tst_en = 1'b0;
    reg         tst_nx = 1'b0;
    wire [20:0] rom_addr;
    wire        rom_cs;
    wire [7:0]  rom_data;
    wire        data_ok;
    wire        sample;
    wire        match;
    wire        bsy;
    wire signed [15:0] snd_l;
    wire signed [15:0] snd_r;

    reg  [15:0] cache_din = 16'd0;
    reg         cache_din_ok = 1'b0;
    reg         cache_dst = 1'b0;
    reg         cache_we = 1'b0;
    wire        cache_req;
    wire [21:0] sdram_addr;

    integer response_delay = 0;
    integer cen_div = 0;
    integer wait_count = 0;
    integer sample_count = 0;
    reg     response_pending = 1'b0;
    reg     response_second = 1'b0;
    reg [21:0] response_word_addr = 22'd0;
    reg     monitor_armed = 1'b0;
    reg     saw_byte3 = 1'b0;
    reg     have_last_sample = 1'b0;
    reg [20:0] last_sample_addr = 21'd0;

    always #5 clk = ~clk;

    function [7:0] rom_byte(input [21:0] byte_addr);
        rom_byte = 8'h40 + byte_addr[7:0];
    endfunction

    function [15:0] rom_word(input [21:0] word_addr);
        reg [21:0] byte_addr;
        begin
            byte_addr = word_addr << 1;
            rom_word = {rom_byte(byte_addr + 1'd1), rom_byte(byte_addr)};
        end
    endfunction

    task mmr_write(input [2:0] write_addr, input [7:0] write_data);
        begin
            @(negedge clk);
            mmr_addr = write_addr;
            mmr_din = write_data;
            mmr_we = 1'b1;
            @(negedge clk);
            mmr_we = 1'b0;
        end
    endtask

    jt053260_channel #(.TESTRD(1)) u_channel (
        .rst      ( rst       ),
        .clk      ( clk       ),
        .cen      ( cen       ),
        .swap     ( 1'b0      ),
        .addr     ( mmr_addr  ),
        .din      ( mmr_din   ),
        .we       ( mmr_we    ),
        .keyon    ( keyon     ),
        .tst_en   ( tst_en    ),
        .tst_nx   ( tst_nx    ),
        .loop     ( 1'b0      ),
        .adpcm_en ( 1'b0      ),
        .pan_l    ( 7'h7f     ),
        .pan_r    ( 7'h7f     ),
        .rom_data ( rom_data  ),
        .rom_addr ( rom_addr  ),
        .rom_cs   ( rom_cs    ),
        .snd_l    ( snd_l     ),
        .snd_r    ( snd_r     ),
        .bsy      ( bsy       ),
        .match    ( match     ),
        .sample   ( sample    )
    );

    jtframe_romrq_bcache #(
        .SDRAMW  ( 22 ),
        .AW      ( 21 ),
        .DW      (  8 ),
        .OKLATCH (  1 ),
        .DOUBLE  (  0 ),
        .LATCH   (  0 )
    ) u_cache (
        .rst        ( rst          ),
        .clk        ( clk          ),
        .clr        ( 1'b0         ),
        .offset     ( 22'd0        ),
        .din        ( cache_din    ),
        .din_ok     ( cache_din_ok ),
        .dst        ( cache_dst    ),
        .we         ( cache_we     ),
        .req        ( cache_req    ),
        .sdram_addr ( sdram_addr   ),
        .addr       ( rom_addr     ),
        .addr_ok    ( rom_cs       ),
        .data_ok    ( data_ok      ),
        .dout       ( rom_data     )
    );

    // Seven base clocks per K053260 enable. A zero-wait two-beat response is
    // ready before the next sample; an added 3-5-clock delay is not.
    always @(negedge clk) begin
        if (rst || !run_cen) begin
            cen = 1'b0;
            cen_div = 0;
        end else if (cen_div == 6) begin
            cen = 1'b1;
            cen_div = 0;
        end else begin
            cen = 1'b0;
            cen_div = cen_div + 1;
        end
    end

    // Protocol-correct two-word block response. dst marks only the first
    // accepted word, matching the real JTFRAME burst interface.
    always @(negedge clk) begin
        cache_we = 1'b0;
        cache_din_ok = 1'b0;
        cache_dst = 1'b0;
        if (rst) begin
            response_pending = 1'b0;
            response_second = 1'b0;
            wait_count = 0;
            response_word_addr = 22'd0;
            cache_din = 16'd0;
        end else if (!response_pending && cache_req) begin
            response_word_addr = sdram_addr;
            response_pending = 1'b1;
            response_second = 1'b0;
            wait_count = response_delay;
            if (response_delay == 0) begin
                cache_we = 1'b1;
                cache_din_ok = 1'b1;
                cache_dst = 1'b1;
                cache_din = rom_word(sdram_addr);
                response_second = 1'b1;
            end
        end else if (response_pending && wait_count != 0) begin
            wait_count = wait_count - 1;
        end else if (response_pending && !response_second) begin
            cache_we = 1'b1;
            cache_din_ok = 1'b1;
            cache_dst = 1'b1;
            cache_din = rom_word(response_word_addr);
            response_second = 1'b1;
        end else if (response_pending) begin
            cache_we = 1'b1;
            cache_din_ok = 1'b1;
            cache_dst = 1'b0;
            cache_din = rom_word(response_word_addr + 1'd1);
            response_pending = 1'b0;
            response_second = 1'b0;
        end
    end

    // Sample pre-NBA values: these are the values consumed by u_channel on
    // this edge. The delayed result is evidence sensitivity, not a DUT fatal.
    always @(posedge clk) begin
        if (!rst && monitor_armed && sample && rom_cs) begin
            sample_count = sample_count + 1;
            if (!data_ok) begin
                if (response_delay >= 3 && response_delay <= 5 &&
                    saw_byte3 && have_last_sample &&
                    last_sample_addr == 21'h000003 &&
                    rom_addr == 21'h000004) begin
                    $display("K053260_CONTRACT_RESULT mode=delayed outcome=delayed_violation_observed delay=%0d address=%06h stale_dout=%02h pre_snd=%02h cnt=%0d pitch=%03h adpcm=0 samples=%0d",
                        response_delay, rom_addr, rom_data,
                        u_channel.pre_snd, u_channel.cnt,
                        u_channel.pitch, sample_count);
                    #1 $finish;
                end else begin
                    $fatal(1,
                        "unexpected validity violation delay=%0d addr=%06h last=%06h data=%02h cnt=%0d",
                        response_delay, rom_addr, last_sample_addr,
                        rom_data, u_channel.cnt);
                end
            end
            if (rom_addr == 21'h000003) begin
                saw_byte3 = 1'b1;
                if (!data_ok)
                    $fatal(1, "byte 3 was not a primed cache hit");
            end
            if (response_delay == 0 && rom_addr >= 21'h000008) begin
                $display("K053260_CONTRACT_RESULT mode=control outcome=control_pass delay=0 address=%06h data=%02h pre_snd=%02h cnt=%0d pitch=%03h adpcm=0 samples=%0d",
                    rom_addr, rom_data, u_channel.pre_snd,
                    u_channel.cnt, u_channel.pitch, sample_count);
                #1 $finish;
            end
            have_last_sample = 1'b1;
            last_sample_addr = rom_addr;
        end
    end

    initial begin
        if (!$value$plusargs("RESPONSE_DELAY=%d", response_delay))
            response_delay = 0;
        if (response_delay != 0 &&
            (response_delay < 3 || response_delay > 5))
            $fatal(1, "RESPONSE_DELAY must be 0 or 3 through 5");

        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // Public channel MMR programming: pitch FFF, length 0010 (>8),
        // start 000000, and full PCM level. Register 6 supplies start[20:16].
        mmr_write(3'd0, 8'hff);
        mmr_write(3'd1, 8'h0f);
        mmr_write(3'd2, 8'h10);
        mmr_write(3'd3, 8'h00);
        mmr_write(3'd4, 8'h00);
        mmr_write(3'd5, 8'h00);
        mmr_write(3'd6, 8'h00);
        mmr_write(3'd7, 8'h7f);

        // Use the channel's real read-test request path only to prime line 0;
        // playback itself uses ordinary PCM key-on and public MMR state.
        @(negedge clk);
        tst_en = 1'b1;
        wait (rom_cs && data_ok && rom_addr == 21'd0);
        @(negedge clk);
        if (rom_data !== 8'h40)
            $fatal(1, "primed byte 0 mismatch: %02h", rom_data);
        tst_en = 1'b0;
        keyon = 1'b1;
        monitor_armed = 1'b1;
        run_cen = 1'b1;

        repeat (500) @(posedge clk);
        $fatal(1, "watchdog: no conclusive validity result");
    end
endmodule
