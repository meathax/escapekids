`timescale 1ns/1ps

// Real-hierarchy deadline probe. The intact full-smoke harness supplies the
// generated jtsimson_game_sdram hierarchy; this wrapper changes only its
// external SDRAM responder and temporarily drives the public sound MMR bus.
module tb_k053260_deadline_integration;
    tb_escape_kids_full_smoke u_base();

    reg [127:0] deadline_mode = "control";
    integer bank1_wait = 0;
    integer response_state = 0;
    integer response_wait = 0;
    reg [1:0] response_bank = 2'd0;
    reg [21:0] response_addr = 22'd0;
    reg [3:0] model_ack = 4'd0;
    reg [3:0] model_dst = 4'd0;
    reg [3:0] model_rdy = 4'd0;
    reg [15:0] model_data = 16'd0;

    reg [3:0] channel_sample_seen = 4'd0;
    reg [3:0] channel_romcs_seen = 4'd0;
    reg [4:0] slot_req_seen = 5'd0;
    reg [4:0] slot_grant_seen = 5'd0;
    reg [4:0] slot_response_seen = 5'd0;
    reg [4:0] request_active = 5'd0;
    reg [4:0] request_blocked_seen = 5'd0;
    reg [4:0] previous_req = 5'd0;
    reg [20:0] request_addr [0:4];
    integer request_age [0:4];
    integer max_request_age [0:4];
    integer address_change_while_outstanding [0:4];
    integer max_service_cycles [0:4];
    integer slot_dst_count [0:4];
    integer slot_rdy_count [0:4];
    integer i;
    integer j;
    integer prewarm_wait;
    integer cen_count = 0;
    integer sample_count [0:3];
    integer violation_channel = -1;
    reg violation_seen = 1'b0;
    reg stale_consumed = 1'b0;
    reg [20:0] violation_addr = 21'd0;
    reg [7:0] violation_dout = 8'd0;
    reg [7:0] violation_expected = 8'd0;
    reg [7:0] violation_pre_snd = 8'd0;
    reg [7:0] violation_post_snd = 8'd0;
    reg [15:0] violation_cnt = 16'd0;
    reg [11:0] violation_pitch = 12'd0;
    reg violation_invalid = 1'b0;
    reg wrong_data_consumed = 1'b0;
    reg violation_collision = 1'b0;
    reg violation_blocked = 1'b0;
    reg [4:0] violation_req = 5'd0;
    reg [4:0] violation_grant = 5'd0;
    integer violation_age [0:4];
    reg [4:0] response_slot = 5'd0;
    reg response_dst_sent = 1'b0;
    integer response_elapsed = 0;

    wire [4:0] bank1_req = u_base.dut.u_bank1.req;
    wire [4:0] bank1_grant = u_base.dut.u_bank1.slot_sel;
    wire [4:0] bank1_ok = {
        u_base.dut.pcmd_ok, u_base.dut.pcmc_ok,
        u_base.dut.pcmb_ok, u_base.dut.pcma_ok,
        u_base.dut.snd_ok
    };

    function [15:0] response_word;
        input [1:0] bank;
        input [21:0] address;
        reg [20:0] pcm_byte;
        begin
            if (bank != 2'd1)
                response_word = 16'h0000;
            else if (address < 22'h010000)
                // Sequential Z80 NOPs create real slot-0 fetch traffic.
                response_word = 16'h0000;
            else begin
                pcm_byte = (address - 22'h010000) << 1;
                response_word = {
                    8'h40 + pcm_byte[7:0] + 1'd1,
                    8'h40 + pcm_byte[7:0]
                };
            end
        end
    endfunction

    function [7:0] expected_pcm_byte;
        input [20:0] address;
        begin
            expected_pcm_byte = 8'h40 + address[7:0];
        end
    endfunction

    function [20:0] slot_addr_req;
        input integer slot;
        begin
            case (slot)
                0: slot_addr_req = {4'd0, u_base.dut.snd_addr};
                1: slot_addr_req = u_base.dut.pcma_addr;
                2: slot_addr_req = u_base.dut.pcmb_addr;
                3: slot_addr_req = u_base.dut.pcmc_addr;
                4: slot_addr_req = u_base.dut.pcmd_addr;
                default: slot_addr_req = 21'd0;
            endcase
        end
    endfunction

    function [20:0] slot_cache_line;
        input integer slot;
        reg [20:0] address;
        begin
            address = slot_addr_req(slot);
            slot_cache_line = {address[20:2], 2'b00};
        end
    endfunction

    task pcm_write;
        input [5:0] write_addr;
        input [7:0] write_data;
        begin
            @(negedge u_base.clk);
            force u_base.dut.u_game.u_sound.A = {10'd0, write_addr};
            force u_base.dut.u_game.u_sound.cpu_dout = write_data;
            force u_base.dut.u_game.u_sound.wr_n = 1'b0;
            force u_base.dut.u_game.u_sound.pcm_cs = 1'b1;
            @(posedge u_base.clk);
            #1;
            @(negedge u_base.clk);
            release u_base.dut.u_game.u_sound.pcm_cs;
            release u_base.dut.u_game.u_sound.wr_n;
            release u_base.dut.u_game.u_sound.cpu_dout;
            release u_base.dut.u_game.u_sound.A;
            // The real sound CPU cannot issue distinct MMR writes faster
            // than one four-T-state Z80 bus cycle at cen_fm.
            wait_cen_fm();
            wait_cen_fm();
            wait_cen_fm();
            wait_cen_fm();
        end
    endtask

    task automatic wait_cen_fm;
        begin
            @(posedge u_base.clk);
            while (!u_base.dut.cen_fm)
                @(posedge u_base.clk);
        end
    endtask

    task automatic program_channel;
        input [5:0] base;
        input [7:0] start_mid;
        begin
            pcm_write(base + 0, 8'hff);
            pcm_write(base + 1, 8'h0f);
            pcm_write(base + 2, 8'hff);
            pcm_write(base + 3, 8'h00);
            pcm_write(base + 4, 8'h00);
            pcm_write(base + 5, start_mid);
            pcm_write(base + 6, 8'h00);
            pcm_write(base + 7, 8'h7f);
        end
    endtask

    task automatic record_violation;
        input integer channel;
        input [20:0] address;
        input [7:0] dout;
        input [7:0] pre_snd;
        input [15:0] cnt;
        input [11:0] pitch;
        input ok;
        integer k;
        reg [4:0] active_slots;
        begin
            if (!violation_seen) begin
                violation_seen = 1'b1;
                violation_channel = channel;
                violation_addr = address;
                violation_dout = dout;
                violation_expected = expected_pcm_byte(address);
                violation_pre_snd = pre_snd;
                violation_cnt = cnt;
                violation_pitch = pitch;
                violation_invalid = ok !== 1'b1;
                violation_req = bank1_req;
                violation_grant = bank1_grant;
                active_slots = bank1_req | bank1_grant;
                violation_collision =
                    (active_slots[0] && |active_slots[4:1]) ||
                    (active_slots[1] && |active_slots[4:2]) ||
                    (active_slots[2] && |active_slots[4:3]) ||
                    (active_slots[3] && active_slots[4]);
                case (channel)
                    0: violation_blocked = request_blocked_seen[1] ||
                        (bank1_req[1] && !bank1_grant[1] && bank1_grant[0]);
                    1: violation_blocked = request_blocked_seen[2] ||
                        (bank1_req[2] && !bank1_grant[2] &&
                         |bank1_grant[1:0]);
                    2: violation_blocked = request_blocked_seen[3] ||
                        (bank1_req[3] && !bank1_grant[3] &&
                         |bank1_grant[2:0]);
                    3: violation_blocked = request_blocked_seen[4] ||
                        (bank1_req[4] && !bank1_grant[4] &&
                         |bank1_grant[3:0]);
                    default: violation_blocked = 1'b0;
                endcase
                for (k = 0; k < 5; k = k + 1)
                    violation_age[k] = request_age[k];
                #1;
                case (channel)
                    0: violation_post_snd =
                        u_base.dut.u_game.u_sound.u_pcm.u_ch0.pre_snd;
                    1: violation_post_snd =
                        u_base.dut.u_game.u_sound.u_pcm.u_ch1.pre_snd;
                    2: violation_post_snd =
                        u_base.dut.u_game.u_sound.u_pcm.u_ch2.pre_snd;
                    3: violation_post_snd =
                        u_base.dut.u_game.u_sound.u_pcm.u_ch3.pre_snd;
                    default: violation_post_snd = 8'hxx;
                endcase
                stale_consumed = violation_post_snd === dout;
                wrong_data_consumed = stale_consumed &&
                    dout !== violation_expected;
                if (!stale_consumed)
                    $fatal(1, "deadline violation did not capture presented ROM data");
                $fatal(1,
                    "prefetch sample mismatch mode=%0s ch=%0d addr=%06h data=%02h expected=%02h ok=%b cnt=%0d valid=%h tags=%05h,%05h,%05h,%05h fill=%05h/%0d",
                    deadline_mode, channel, address, dout,
                    violation_expected, ok, cnt,
                    u_base.dut.u_game.u_pcm_prefetch.u_ch0.valid,
                    u_base.dut.u_game.u_pcm_prefetch.u_ch0.tag[0],
                    u_base.dut.u_game.u_pcm_prefetch.u_ch0.tag[1],
                    u_base.dut.u_game.u_pcm_prefetch.u_ch0.tag[2],
                    u_base.dut.u_game.u_pcm_prefetch.u_ch0.tag[3],
                    u_base.dut.u_game.u_pcm_prefetch.u_ch0.fill_tag,
                    u_base.dut.u_game.u_pcm_prefetch.u_ch0.active);
            end
        end
    endtask

    // Replace only the harness-side SDRAM response. The generated game,
    // bank caches and fixed-priority bank1 arbiter remain intact.
    initial begin
        force u_base.ba_ack = model_ack;
        force u_base.ba_dst = model_dst;
        force u_base.ba_rdy = model_rdy;
        force u_base.ba_dok = model_rdy;
        force u_base.data_read = model_data;
        // The probe owns only the sound/bank1 path. Keep the unrelated main
        // CPU in reset so its synthetic zero-ROM program cannot terminate the
        // intact base harness with a buserror before the deadline result.
        force u_base.dut.u_game.u_main.u_cpu.rst = 1'b1;
    end

    // One deterministic transaction at a time. Bank1 uses the declared
    // deadline profile; unrelated banks receive the fast control response.
    always @(posedge u_base.clk) begin
        model_ack <= 4'd0;
        model_dst <= 4'd0;
        model_rdy <= 4'd0;
        case (response_state)
            0: begin
                if (u_base.ba_rd[0]) begin
                    response_bank <= 2'd0;
                    response_addr <= u_base.ba0_addr;
                    response_state <= 1;
                end else if (u_base.ba_rd[1]) begin
                    response_bank <= 2'd1;
                    response_addr <= u_base.ba1_addr;
                    response_slot <= bank1_grant;
                    response_dst_sent <= 1'b0;
                    response_elapsed <= 0;
                    if (!(bank1_grant == 5'h01 || bank1_grant == 5'h02 ||
                          bank1_grant == 5'h04 || bank1_grant == 5'h08 ||
                          bank1_grant == 5'h10))
                        $fatal(1, "bank1 request has invalid grant %02h",
                            bank1_grant);
                    response_state <= 1;
                end else if (u_base.ba_rd[2]) begin
                    response_bank <= 2'd2;
                    response_addr <= u_base.ba2_addr;
                    response_state <= 1;
                end else if (u_base.ba_rd[3]) begin
                    response_bank <= 2'd3;
                    response_addr <= u_base.ba3_addr;
                    response_state <= 1;
                end
            end
            1: begin
                model_ack[response_bank] <= 1'b1;
                response_wait <= response_bank == 2'd1 ? bank1_wait : 0;
                if (response_bank == 2'd1)
                    response_elapsed <= response_elapsed + 1;
                response_state <= 2;
            end
            2: begin
                if (response_bank == 2'd1)
                    response_elapsed <= response_elapsed + 1;
                if (response_wait != 0)
                    response_wait <= response_wait - 1;
                else begin
                    model_data <= response_word(response_bank, response_addr);
                    model_dst[response_bank] <= 1'b1;
                    if (response_bank == 2'd1) begin
                        response_dst_sent <= 1'b1;
                        for (j = 0; j < 5; j = j + 1)
                            if (response_slot[j])
                                slot_dst_count[j] <= slot_dst_count[j] + 1;
                    end
                    response_state <= 3;
                end
            end
            3: begin
                if (response_bank == 2'd1 && !response_dst_sent)
                    $fatal(1, "bank1 RDY emitted without preceding DST");
                model_data <= response_word(response_bank, response_addr + 1'd1);
                model_rdy[response_bank] <= 1'b1;
                if (response_bank == 2'd1) begin
                    slot_response_seen <= slot_response_seen | response_slot;
                    response_dst_sent <= 1'b0;
                    for (j = 0; j < 5; j = j + 1)
                        if (response_slot[j]) begin
                            slot_rdy_count[j] <= slot_rdy_count[j] + 1;
                            if (response_elapsed + 1 > max_service_cycles[j])
                                max_service_cycles[j] <= response_elapsed + 1;
                        end
                end
                response_state <= 4;
            end
            4: response_state <= 0;
            default: response_state <= 0;
        endcase
    end

    // Deadline and nonvacuity accounting at the authentic full-hierarchy
    // 48 MHz clock. Sample values here are the pre-NBA values consumed by the
    // K053260 channel on this edge.
    always @(posedge u_base.clk) begin
        if (!u_base.rst && u_base.dut.cen_fm)
            cen_count = cen_count + 1;

        if (!u_base.rst) begin
            slot_req_seen = slot_req_seen | bank1_req;
            slot_grant_seen = slot_grant_seen | bank1_grant;
            for (i = 0; i < 5; i = i + 1) begin
                if (bank1_req[i] &&
                    (!request_active[i] ||
                     slot_cache_line(i) != request_addr[i])) begin
                    if (request_active[i]) begin
                        address_change_while_outstanding[i] =
                            address_change_while_outstanding[i] + 1;
                        if (request_age[i] > max_request_age[i])
                            max_request_age[i] = request_age[i];
                    end
                    request_active[i] = 1'b1;
                    request_blocked_seen[i] = 1'b0;
                    request_age[i] = 0;
                    request_addr[i] = slot_cache_line(i);
                end
                if (request_active[i] && bank1_req[i] &&
                    !bank1_grant[i]) begin
                    case (i)
                        1: if (bank1_grant[0])
                            request_blocked_seen[i] = 1'b1;
                        2: if (|bank1_grant[1:0])
                            request_blocked_seen[i] = 1'b1;
                        3: if (|bank1_grant[2:0])
                            request_blocked_seen[i] = 1'b1;
                        4: if (|bank1_grant[3:0])
                            request_blocked_seen[i] = 1'b1;
                    endcase
                end
                if (request_active[i]) begin
                    request_age[i] = request_age[i] + 1;
                    if (bank1_ok[i]) begin
                        if (request_age[i] > max_request_age[i])
                            max_request_age[i] = request_age[i];
                        request_active[i] = 1'b0;
                    end
                end
            end
            previous_req = bank1_req;

            if (u_base.dut.u_game.u_sound.u_pcm.u_ch0.rom_cs)
                channel_romcs_seen[0] = 1'b1;
            if (u_base.dut.u_game.u_sound.u_pcm.u_ch1.rom_cs)
                channel_romcs_seen[1] = 1'b1;
            if (u_base.dut.u_game.u_sound.u_pcm.u_ch2.rom_cs)
                channel_romcs_seen[2] = 1'b1;
            if (u_base.dut.u_game.u_sound.u_pcm.u_ch3.rom_cs)
                channel_romcs_seen[3] = 1'b1;

            if (u_base.dut.u_game.u_sound.u_pcm.u_ch0.sample &&
                u_base.dut.u_game.u_sound.u_pcm.u_ch0.bsy &&
                u_base.dut.u_game.u_sound.u_pcm.u_ch0.rom_cs) begin
                channel_sample_seen[0] = 1'b1;
                sample_count[0] = sample_count[0] + 1;
                if (u_base.dut.u_game.pcm_prefetch_ok[0] !== 1'b1 ||
                    u_base.dut.u_game.pcm_prefetch_data_a !==
                        expected_pcm_byte(u_base.dut.u_game.pcm_raw_addr_a))
                    record_violation(0, u_base.dut.u_game.pcm_raw_addr_a,
                        u_base.dut.u_game.pcm_prefetch_data_a,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch0.pre_snd,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch0.cnt,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch0.pitch_cnt,
                        u_base.dut.u_game.pcm_prefetch_ok[0]);
            end
            if (u_base.dut.u_game.u_sound.u_pcm.u_ch1.sample &&
                u_base.dut.u_game.u_sound.u_pcm.u_ch1.bsy &&
                u_base.dut.u_game.u_sound.u_pcm.u_ch1.rom_cs) begin
                channel_sample_seen[1] = 1'b1;
                sample_count[1] = sample_count[1] + 1;
                if (u_base.dut.u_game.pcm_prefetch_ok[1] !== 1'b1 ||
                    u_base.dut.u_game.pcm_prefetch_data_b !==
                        expected_pcm_byte(u_base.dut.u_game.pcm_raw_addr_b))
                    record_violation(1, u_base.dut.u_game.pcm_raw_addr_b,
                        u_base.dut.u_game.pcm_prefetch_data_b,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch1.pre_snd,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch1.cnt,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch1.pitch_cnt,
                        u_base.dut.u_game.pcm_prefetch_ok[1]);
            end
            if (u_base.dut.u_game.u_sound.u_pcm.u_ch2.sample &&
                u_base.dut.u_game.u_sound.u_pcm.u_ch2.bsy &&
                u_base.dut.u_game.u_sound.u_pcm.u_ch2.rom_cs) begin
                channel_sample_seen[2] = 1'b1;
                sample_count[2] = sample_count[2] + 1;
                if (u_base.dut.u_game.pcm_prefetch_ok[2] !== 1'b1 ||
                    u_base.dut.u_game.pcm_prefetch_data_c !==
                        expected_pcm_byte(u_base.dut.u_game.pcm_raw_addr_c))
                    record_violation(2, u_base.dut.u_game.pcm_raw_addr_c,
                        u_base.dut.u_game.pcm_prefetch_data_c,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch2.pre_snd,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch2.cnt,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch2.pitch_cnt,
                        u_base.dut.u_game.pcm_prefetch_ok[2]);
            end
            if (u_base.dut.u_game.u_sound.u_pcm.u_ch3.sample &&
                u_base.dut.u_game.u_sound.u_pcm.u_ch3.bsy &&
                u_base.dut.u_game.u_sound.u_pcm.u_ch3.rom_cs) begin
                channel_sample_seen[3] = 1'b1;
                sample_count[3] = sample_count[3] + 1;
                if (u_base.dut.u_game.pcm_prefetch_ok[3] !== 1'b1 ||
                    u_base.dut.u_game.pcm_prefetch_data_d !==
                        expected_pcm_byte(u_base.dut.u_game.pcm_raw_addr_d))
                    record_violation(3, u_base.dut.u_game.pcm_raw_addr_d,
                        u_base.dut.u_game.pcm_prefetch_data_d,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch3.pre_snd,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch3.cnt,
                        u_base.dut.u_game.u_sound.u_pcm.u_ch3.pitch_cnt,
                        u_base.dut.u_game.pcm_prefetch_ok[3]);
            end
        end
    end

    initial begin
        for (i = 0; i < 5; i = i + 1) begin
            request_addr[i] = 21'd0;
            request_age[i] = 0;
            max_request_age[i] = 0;
            address_change_while_outstanding[i] = 0;
            max_service_cycles[i] = 0;
            slot_dst_count[i] = 0;
            slot_rdy_count[i] = 0;
            violation_age[i] = 0;
        end
        for (i = 0; i < 4; i = i + 1)
            sample_count[i] = 0;
        if (!$value$plusargs("K053260_DEADLINE_MODE=%s", deadline_mode))
            deadline_mode = "control";
        if (deadline_mode == "control")
            bank1_wait = 0;
        else if (deadline_mode == "contention")
            bank1_wait = 0;
        else if (deadline_mode == "stress")
            bank1_wait = 6;
        else if (deadline_mode == "mutation")
            bank1_wait = 16;
        else if (deadline_mode == "retrigger")
            bank1_wait = 0;
        else if (deadline_mode == "forward_loop" ||
                 deadline_mode == "reverse_loop")
            bank1_wait = 16;
        else
            $fatal(1, "bad K053260_DEADLINE_MODE=%0s", deadline_mode);

        wait (!u_base.rst && !u_base.dut.rst_h &&
              !u_base.dut.u_game.u_sound.rst_z80);
        pcm_write(6'h28, 8'h00);
        wait_cen_fm();
        wait_cen_fm();
        if (u_base.dut.u_game.u_sound.u_pcm.u_ch0.bsy ||
            u_base.dut.u_game.u_sound.u_pcm.u_ch1.bsy ||
            u_base.dut.u_game.u_sound.u_pcm.u_ch2.bsy ||
            u_base.dut.u_game.u_sound.u_pcm.u_ch3.bsy)
            $fatal(1, "channels did not become idle after key-off");
        channel_sample_seen = 4'd0;
        channel_romcs_seen = 4'd0;
        slot_req_seen = 5'd0;
        slot_grant_seen = 5'd0;
        slot_response_seen = 5'd0;
        for (i = 0; i < 4; i = i + 1)
            sample_count[i] = 0;

        program_channel(6'h08, 8'h01);
        program_channel(6'h10, 8'h02);
        program_channel(6'h18, 8'h03);
        program_channel(6'h20, 8'h04);
        if (deadline_mode == "forward_loop" ||
            deadline_mode == "reverse_loop") begin
            pcm_write(6'h0a, 8'h0f);
            pcm_write(6'h0b, 8'h00);
            pcm_write(6'h2a, 8'h01);
        end else begin
            pcm_write(6'h2a, 8'h00);
        end
        pcm_write(6'h2c, 8'h24);
        pcm_write(6'h2d, 8'h24);
        pcm_write(6'h2f, 8'h02);
        prewarm_wait = 0;
        if (u_base.dut.u_game.pcm_prefetch_warm != 4'hf)
            $fatal(1, "authentic minimum MMR cadence did not warm all current/+/- lines");
        if (deadline_mode == "reverse_loop")
            pcm_write(6'h28, 8'h11);
        else
            pcm_write(6'h28,
                (deadline_mode == "stress" || deadline_mode == "contention") ?
                    8'h0f : 8'h01);

        if (deadline_mode == "retrigger") begin
            while (sample_count[0] < 8)
                @(posedge u_base.clk);
            pcm_write(6'h28, 8'h00);
            wait_cen_fm();
            wait_cen_fm();
            program_channel(6'h08, 8'h10);
            if (u_base.dut.u_game.pcm_bsy[0] !== 1'b0)
                $fatal(1, "retrigger channel remained busy after keyoff");
            if (u_base.dut.u_game.pcm_start_a !== 21'h001000)
                $fatal(1, "retrigger programmed-start export mismatch");
            if (u_base.dut.u_game.pcm_prefetch_warm[0] !== 1'b1)
                $fatal(1, "retrigger start/+/- not warm before keyon");
            pcm_write(6'h28, 8'h01);
        end

        repeat (80000) begin
            @(posedge u_base.clk);
            if ((deadline_mode == "control" || deadline_mode == "mutation" ||
                 deadline_mode == "retrigger" ||
                 deadline_mode == "forward_loop" ||
                 deadline_mode == "reverse_loop") && !violation_seen &&
                sample_count[0] >= ((deadline_mode == "retrigger" ||
                    deadline_mode == "forward_loop" ||
                    deadline_mode == "reverse_loop") ? 40 : 12) &&
                channel_romcs_seen[0] && slot_req_seen[1] &&
                slot_grant_seen[1] && slot_response_seen[1] &&
                u_base.dut.u_game.pcm_prefetch_warm[0] &&
                u_base.dut.u_game.pcm_prefetch_underrun == 4'd0) begin
                $display("K053260_DEADLINE_RESULT mode=%0s outcome=%0s_prefetch_pass prewarm=%0d cen=%0d samples=%0d req=%02h grant=%02h response=%02h max_age=%0d service=%0d miss_seen=%0d",
                    deadline_mode, deadline_mode, prewarm_wait, cen_count,
                    sample_count[0], slot_req_seen, slot_grant_seen,
                    slot_response_seen, max_request_age[1],
                    max_service_cycles[1],
                    |u_base.dut.u_game.pcm_prefetch_underrun);
                $finish;
            end
            if ((deadline_mode == "contention" || deadline_mode == "stress") &&
                !violation_seen && sample_count[0] >= 12 &&
                sample_count[1] >= 12 && sample_count[2] >= 12 &&
                sample_count[3] >= 12 && channel_romcs_seen == 4'hf &&
                slot_req_seen[4:1] == 4'hf &&
                slot_grant_seen[4:1] == 4'hf &&
                slot_response_seen[4:1] == 4'hf &&
                u_base.dut.u_game.pcm_prefetch_warm == 4'hf &&
                u_base.dut.u_game.pcm_prefetch_underrun == 4'd0) begin
                $display("K053260_DEADLINE_RESULT mode=%0s outcome=%0s_prefetch_pass prewarm=%0d cen=%0d samples=%0d,%0d,%0d,%0d req=%02h grant=%02h response=%02h max_age=%0d service=%0d miss_seen=%0d",
                    deadline_mode, deadline_mode, prewarm_wait, cen_count,
                    sample_count[0], sample_count[1], sample_count[2],
                    sample_count[3], slot_req_seen, slot_grant_seen,
                    slot_response_seen, max_request_age[1],
                    max_service_cycles[1],
                    |u_base.dut.u_game.pcm_prefetch_underrun);
                $finish;
            end
            if (deadline_mode == "control" && !violation_seen &&
                sample_count[0] >= 12 && channel_romcs_seen[0] &&
                slot_req_seen[1] && slot_grant_seen[1] &&
                slot_response_seen[1] && slot_dst_count[1] > 0 &&
                slot_dst_count[1] == slot_rdy_count[1]) begin
                $display("K053260_DEADLINE_RESULT mode=control outcome=control_pass cen=%0d samples=%0d req=%02h grant=%02h response=%02h max_age=%0d service=%0d dst=%0d rdy=%0d addr_changes=%0d",
                    cen_count, sample_count[0], slot_req_seen,
                    slot_grant_seen, slot_response_seen, max_request_age[1],
                    max_service_cycles[1], slot_dst_count[1],
                    slot_rdy_count[1],
                    address_change_while_outstanding[1]);
                $finish;
            end
            if (deadline_mode == "contention" &&
                channel_sample_seen == 4'hf && channel_romcs_seen == 4'hf &&
                slot_req_seen == 5'h1f && slot_grant_seen == 5'h1f &&
                slot_response_seen == 5'h1f &&
                slot_dst_count[0] > 0 && slot_dst_count[1] > 0 &&
                slot_dst_count[2] > 0 && slot_dst_count[3] > 0 &&
                slot_dst_count[4] > 0 &&
                slot_dst_count[0] == slot_rdy_count[0] &&
                slot_dst_count[1] == slot_rdy_count[1] &&
                slot_dst_count[2] == slot_rdy_count[2] &&
                slot_dst_count[3] == slot_rdy_count[3] &&
                slot_dst_count[4] == slot_rdy_count[4]) begin
                if (violation_seen) begin
                    if (!violation_collision || !violation_blocked)
                        $fatal(1,
                            "contention mismatch lacks collision/block proof channel=%0d wrong=%0d collision=%0d blocked=%0d req=%02h grant=%02h",
                            violation_channel, wrong_data_consumed,
                            violation_collision, violation_blocked,
                            violation_req, violation_grant);
                    $display("K053260_DEADLINE_RESULT mode=contention outcome=%0s ch=%0d addr=%06h presented=%02h expected=%02h pre_before=%02h pre_after=%02h invalid=%0d wrong_data_consumed=%0d collision=1 blocked=1 violation_req=%02h violation_grant=%02h violation_age=%0d,%0d,%0d,%0d,%0d cen=%0d samples=%0d,%0d,%0d,%0d req=%02h grant=%02h response=%02h service=%0d,%0d,%0d,%0d,%0d",
                        wrong_data_consumed ?
                            "contention_wrong_data_observed" :
                            "contention_invalid_observed",
                        violation_channel, violation_addr, violation_dout,
                        violation_expected, violation_pre_snd,
                        violation_post_snd, violation_invalid,
                        wrong_data_consumed,
                        violation_req, violation_grant, violation_age[0],
                        violation_age[1], violation_age[2], violation_age[3],
                        violation_age[4], cen_count, sample_count[0],
                        sample_count[1], sample_count[2], sample_count[3],
                        slot_req_seen, slot_grant_seen, slot_response_seen,
                        max_service_cycles[0], max_service_cycles[1],
                        max_service_cycles[2], max_service_cycles[3],
                        max_service_cycles[4]);
                    $finish;
                end else if (sample_count[0] >= 12 && sample_count[1] >= 12 &&
                    sample_count[2] >= 12 && sample_count[3] >= 12) begin
                    $display("K053260_DEADLINE_RESULT mode=contention outcome=contention_pass cen=%0d samples=%0d,%0d,%0d,%0d req=%02h grant=%02h response=%02h service=%0d,%0d,%0d,%0d,%0d",
                        cen_count, sample_count[0], sample_count[1],
                        sample_count[2], sample_count[3], slot_req_seen,
                        slot_grant_seen, slot_response_seen,
                        max_service_cycles[0], max_service_cycles[1],
                        max_service_cycles[2], max_service_cycles[3],
                        max_service_cycles[4]);
                    $finish;
                end
            end
            if (deadline_mode == "stress" && violation_seen &&
                stale_consumed && wrong_data_consumed &&
                violation_collision && violation_blocked &&
                channel_sample_seen == 4'hf &&
                channel_romcs_seen == 4'hf && slot_req_seen == 5'h1f &&
                slot_grant_seen == 5'h1f && slot_response_seen == 5'h1f &&
                slot_dst_count[0] > 0 && slot_dst_count[1] > 0 &&
                slot_dst_count[2] > 0 && slot_dst_count[3] > 0 &&
                slot_dst_count[4] > 0 &&
                slot_dst_count[0] == slot_rdy_count[0] &&
                slot_dst_count[1] == slot_rdy_count[1] &&
                slot_dst_count[2] == slot_rdy_count[2] &&
                slot_dst_count[3] == slot_rdy_count[3] &&
                slot_dst_count[4] == slot_rdy_count[4]) begin
                $display("K053260_DEADLINE_RESULT mode=stress outcome=deadline_violation_observed ch=%0d addr=%06h presented=%02h expected=%02h pre_before=%02h pre_after=%02h cnt=%0d pitch=%03h invalid=%0d wrong_data_consumed=1 collision=1 blocked=1 violation_req=%02h violation_grant=%02h violation_age=%0d,%0d,%0d,%0d,%0d cen=%0d samples=%0d,%0d,%0d,%0d req=%02h grant=%02h response=%02h max_age=%0d,%0d,%0d,%0d,%0d service=%0d,%0d,%0d,%0d,%0d dst=%0d,%0d,%0d,%0d,%0d rdy=%0d,%0d,%0d,%0d,%0d addr_changes=%0d,%0d,%0d,%0d,%0d",
                    violation_channel, violation_addr, violation_dout,
                    violation_expected, violation_pre_snd,
                    violation_post_snd, violation_cnt, violation_pitch,
                    violation_invalid, violation_req, violation_grant,
                    violation_age[0], violation_age[1], violation_age[2],
                    violation_age[3], violation_age[4],
                    cen_count, sample_count[0], sample_count[1],
                    sample_count[2], sample_count[3], slot_req_seen,
                    slot_grant_seen, slot_response_seen,
                    max_request_age[0], max_request_age[1],
                    max_request_age[2], max_request_age[3],
                    max_request_age[4], max_service_cycles[0],
                    max_service_cycles[1], max_service_cycles[2],
                    max_service_cycles[3], max_service_cycles[4],
                    slot_dst_count[0], slot_dst_count[1], slot_dst_count[2],
                    slot_dst_count[3], slot_dst_count[4],
                    slot_rdy_count[0], slot_rdy_count[1], slot_rdy_count[2],
                    slot_rdy_count[3], slot_rdy_count[4],
                    address_change_while_outstanding[0],
                    address_change_while_outstanding[1],
                    address_change_while_outstanding[2],
                    address_change_while_outstanding[3],
                    address_change_while_outstanding[4]);
                $finish;
            end
            if (deadline_mode == "mutation" && violation_seen &&
                stale_consumed && wrong_data_consumed &&
                channel_sample_seen[0] &&
                slot_req_seen[1] && slot_grant_seen[1] &&
                slot_response_seen[1] && slot_dst_count[1] > 0 &&
                slot_dst_count[1] == slot_rdy_count[1]) begin
                $display("K053260_DEADLINE_RESULT mode=mutation outcome=mutation_violation_observed ch=%0d addr=%06h presented=%02h expected=%02h pre_before=%02h pre_after=%02h cnt=%0d pitch=%03h invalid=%0d wrong_data_consumed=1 cen=%0d samples=%0d req=%02h grant=%02h response=%02h max_age=%0d service=%0d dst=%0d rdy=%0d addr_changes=%0d",
                    violation_channel, violation_addr, violation_dout,
                    violation_expected, violation_pre_snd,
                    violation_post_snd, violation_cnt, violation_pitch,
                    violation_invalid,
                    cen_count, sample_count[0], slot_req_seen,
                    slot_grant_seen, slot_response_seen, max_request_age[1],
                    max_service_cycles[1], slot_dst_count[1],
                    slot_rdy_count[1],
                    address_change_while_outstanding[1]);
                $finish;
            end
        end
        $fatal(1,
            "deadline watchdog mode=%0s violation=%0d samples=%0d,%0d,%0d,%0d req=%02h grant=%02h",
            deadline_mode, violation_seen, sample_count[0], sample_count[1],
            sample_count[2], sample_count[3], slot_req_seen, slot_grant_seen);
    end
endmodule
