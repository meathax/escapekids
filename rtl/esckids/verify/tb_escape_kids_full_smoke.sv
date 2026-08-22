`include "rtl/esckids/jtframe_macros.vh"

// Project-owned headless smoke harness for the generated JTFRAME game top.
// This is deliberately a functional_transaction external SDRAM model: it
// exercises the real loader, reset, clock-enable, ROM request and video/audio
// boundaries without depending on a GUI or the MiSTer HPS bridge.  The
// acceptance differential lane will replace the synthetic media source with
// an authentic MRA download and retain this same bus contract.
module tb_escape_kids_full_smoke;
    reg rst = 1'b1;
    reg clk = 1'b0;
    reg rst24 = 1'b1, clk24 = 1'b0;
    reg rst48 = 1'b1, clk48 = 1'b0;
    reg rst96 = 1'b1, clk96 = 1'b0;

    wire pxl2_cen, pxl_cen;
    wire [7:0] red, green, blue;
    wire LHBL, LVBL, HS, VS;
    reg [3:0] cab_1p = 4'hf, coin = 4'hf;
    reg [6:0] joystick1 = 7'h7f, joystick2 = 7'h7f,
              joystick3 = 7'h7f, joystick4 = 7'h7f;
    reg [1:0] dial_x = 0, dial_y = 0;
    reg [15:0] joyana_l1 = 0, joyana_l2 = 0, joyana_l3 = 0, joyana_l4 = 0;
    reg [15:0] joyana_r1 = 0, joyana_r2 = 0, joyana_r3 = 0, joyana_r4 = 0;
    reg [5:0] snd_en = 6'h3f;
    reg [7:0] snd_vol = 8'hff;
    reg [31:0] status = 0, dipsw = 0;
    // dip_pause is jtframe_dip's synthesized "not paused" signal
    // (jtframe_dip.v: "dip_pause <= ~game_pause & ~osd_shown; // active low"),
    // i.e. 1 = normal play, 0 = paused/frozen.  This standalone harness has
    // no jtframe_dip instance and must present the same steady-state value
    // jtframe_board delivers once boot/OSD settle in a real integration:
    // dip_pause=1.  Leaving it at its 0 (paused) reset value permanently
    // deasserts jtsimson_main's irq_mx (irq_mx = irqn_ff | ~dip_pause), which
    // holds jtkcpu's active-low irq_n input inactive for the entire run --
    // the self-test sequencer's IRQ-gated screen advance can then never
    // fire, even though irqn_ff/irqen/CC.I are all otherwise correct.
    // dip_test/service/tilt are jtframe_joysticks' "game_*" outputs
    // (jtframe_joysticks.v: "// game signals are active low"; game_test,
    // game_service and game_tilt all reset to 1 and are computed as
    // ~key_*, i.e. 1 = idle/not-pressed, 0 = held).  This standalone
    // harness has no jtframe_joysticks instance and, outside the
    // service-gate/input-scenario branches (which already drive their own
    // correct 1'b1 idle value), never assigns these regs past their
    // declared reset value -- so the declared value IS the steady-state
    // value for the plain default run.  service was left at its 0
    // (held/active) reset value for the whole simulated run: jtsimson_main
    // (esckids branch) folds this bit directly into the eeprom_cs/stsw_cs
    // reads the CPU polls at boot, so a permanently-held service switch
    // routes boot into the interactive "MANUAL TEST" self-test menu
    // instead of MAME's default attract sequence.  A real MiSTer
    // integration's jtframe_joysticks always presents service=1 (idle)
    // unless the operator is actually holding the service key, so real
    // hardware does not exhibit this.  dip_test carries the same active-low
    // idle=1 convention (unused by the esckids branch today, but corrected
    // here too for harness fidelity with jtframe_joysticks/jtframe_board).
    reg dip_pause = 1, dip_test = 1, service = 1, tilt = 0;
    wire dip_flip;
    reg [1:0] dip_fxlevel = 0;
    reg [3:0] gfx_en = 0;
    reg [7:0] debug_bus = 0;
    wire [7:0] debug_view;

    reg [25:0] ioctl_addr = 0;
    reg [7:0] ioctl_dout = 0;
    reg ioctl_wr = 0, ioctl_rom = 0, ioctl_ram = 0, ioctl_cart = 0;
    wire [7:0] ioctl_din;
    wire dwnld_busy;

    wire [15:0] data_read;
    wire [21:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
    wire [3:0] ba_rd, ba_wr;
    wire [3:0] ba_dst, ba_dok, ba_rdy;
    wire [3:0] ba_ack;
    wire [15:0] ba0_din, ba1_din, ba2_din, ba3_din;
    wire [1:0] ba0_dsn, ba1_dsn, ba2_dsn, ba3_dsn;
    wire [15:0] prog_data;
    reg prog_rdy = 1, prog_dst = 1, prog_dok = 1;
    wire [1:0] prog_ba;
    wire prog_we, prog_rd;
    wire prog_ack = prog_we;
    wire [1:0] prog_mask;
    wire [21:0] prog_addr;
    wire signed [15:0] snd_left, snd_right;
    wire [5:0] snd_vu;
    wire snd_peak, sample;

    // JTFRAME_PXLCLK makes the game-level enables inputs.  The real board
    // wrapper drives them from jtframe_board; this standalone harness must
    // instantiate the same pinned divider explicitly.
    jtframe_pxlcen u_smoke_pxlcen(
        .clk      ( clk      ),
        .pxl_cen  ( pxl_cen  ),
        .pxl2_cen ( pxl2_cen )
    );

`ifdef AUTH_MEDIA
    // Authenticated-media mode models the four physical 8 MiB SDRAM banks.
    // The loader exposes 22-bit word addresses, therefore the byte address is
    // {bank,word_address,byte_lane}; this is deliberately not folded into a
    // small diagnostic array.
    reg [7:0] media [0:33554431];
`else
    // Fast diagnostic mode keeps the historical bounded model.  It is not an
    // evidence lane for graphics, sprites, or PCM regions.
    reg [7:0] media [0:1048575];
`endif
    integer i;
    integer loader_writes;
    integer rom_reads;
    integer frames;
    integer samples;
    integer pxl_events;
    integer hs_rises;
    integer hs_falls;
    integer vs_rises;
    integer vs_falls;
    integer lvbl_rises;
    integer lvbl_falls;
    reg hs_prev;
    reg vs_prev;
    reg lvbl_prev;
    reg [1023:0] media_file;
    reg [1023:0] auth_stream_file;
    reg [1023:0] smoke_barrier;
    reg auth_mode;
    reg barrier_frame;
    reg smoke_cabinet_2p;
    reg [1023:0] trace_file;
    integer trace_fd;
    integer trace_seq;
    integer trace_limit;
    integer trace_min_events;
    integer trace_start_frame;
    reg trace_enabled;
    reg trace_phase;
    reg stack_debug;
    reg trace_write_seen;
    reg [15:0] trace_prev_addr;
    reg trace_prev_write;
    integer trace_stale_drop_count;
    // longint (64-bit): a plain 32-bit `integer` caps SMOKE_CYCLES near
    // 2.147e9, which this project's own deep-scenario evidence showed is
    // insufficient to reach native video frame ~3400 (2.1e9 cycles only
    // bought 2588 frames before the watchdog fired at
    // tb_escape_kids_full_smoke.sv:2115). Verification-only widening, no
    // synthesizable RTL touched.
    longint max_cycles;
    // Kept well under Verilator's known-safe 2^31-1 single-repeat-count
    // limit so `repeat (SMOKE_CYCLE_CHUNK) @(posedge clk);` never truncates.
    localparam longint SMOKE_CYCLE_CHUNK = 64'd1_000_000_000;
    longint cyc_chunks;
    longint cyc_remainder;
    integer scenario_cycle;
    // Free-running diagnostic cycle counter, valid across every scenario
    // mode (coin_scenario included, which does not advance scenario_cycle).
    // Observation-only: never read by PASS/FAIL gate logic, only by trace
    // emission below.
    longint unsigned diag_cycle_count;
    integer input_trace_seq;
    integer input_reads;
    integer input_edges;
    integer input_min_reads;
    reg input_scenario;
    reg input_scenario_done;
    reg coin_scenario;
    reg [3:0] coin_prev;
    integer coin_frame;
    integer coin_hold_frames;
    integer coin_release_frame;
    reg [1023:0] input_trace_file;
    integer input_trace_fd;
    reg input_trace_enabled;
    // Diagnostic-only work-RAM byte watch: passively observes CPU accesses
    // to one WRAM address (default 0x0002, the confirmed MAME character-
    // select state byte) and logs an edge whenever the value changes.
    // Never forces the bus, never gates PASS/FAIL.
    reg [1023:0] wram_trace_file;
    integer wram_trace_fd;
    reg wram_trace_enabled;
    integer wram_watch_addr;
    reg [7:0] wram_watch_last;
    reg wram_watch_valid;
    integer wram_trace_seq;
    reg [1023:0] service_gate_scenario;
    reg [2047:0] service_gate_trace_file;
    reg [2047:0] service_gate_final_file;
    integer service_gate_trace_fd;
    integer service_gate_final_fd;
    integer service_gate_seq;
    integer service_gate_reads;
    integer service_gate_stack_writes;
    integer service_gate_target;
    integer service_gate_diag_events;
    reg service_gate_enabled;
    reg service_gate_requested;
    reg service_gate_startup_emitted;
    reg service_gate_done;
    reg service_gate_write_seen;
    reg [15:0] service_gate_s_pre;
    reg [7:0] service_gate_data;
    reg [15:0] service_gate_target_addr;
    reg [15:0] service_gate_target_raw_pc;
    reg [7:0] service_gate_target_data;
    reg [2047:0] raster_trace_file;
    reg [2047:0] raster_final_file;
    integer raster_trace_fd;
    integer raster_final_fd;
    integer raster_seq;
    integer raster_write_count;
    integer raster_interval_pixels;
    integer raster_height;
    integer raster_width;
    integer raster_since_hs;
    integer raster_boundaries;
    reg raster_enabled;
    reg raster_capture_started;
    reg raster_commit_seen;
    reg raster_write_seen;
    reg raster_done;
    reg raster_interval_active;
    reg raster_have_hs;
    reg raster_lvbl_prev;
    reg raster_hs_prev;
    reg [15:0] raster_commit_pc;
    reg [15:0] raster_commit_raw_pc;
    reg [15:0] raster_commit_addr;
    reg [7:0] raster_commit_data;
    reg [7:0] raster_commit_op;
    reg [7:0] raster_shadow [0:12];
    reg workram_contract;
    reg workram_alias_inject;
    // ------------------------------------------------------------------
    // Diagnostic multi-frame K053244/jt053246_dma sprite-DMA trace.
    // Entirely opt-in behind +SMOKE_DMA_TRACE=<path>; nothing below is
    // reachable otherwise, so every pre-existing lane keeps byte-identical
    // behaviour.  Logs dma_trig pulses, dma_bsy start/done edges and, at
    // every dma_bsy-falling (DMA-complete) edge, the header word of the
    // five destination scan-buffer sort-key slots under investigation
    // (1,2,4,8,9) read directly out of jt053244's u_even/u_odd RAM.
    // ------------------------------------------------------------------
    // ------------------------------------------------------------------
    // Diagnostic-only sound register-stream trace (+SMOKE_SND_TRACE=<path>).
    // Logs YM2151 and K053260 sound-CPU register writes, main-CPU mailbox
    // writes and main->Z80 IRQ triggers as JSONL, plus one per-frame summary
    // carrying the NMI and latch-read counts.  Optional
    // +SMOKE_SND_STOP_FRAME=<n> holds the run open past the ordinary
    // cpu_sound barrier until n displayed frames have elapsed, so attract
    // music is reachable.  Observation-only: never drives the DUT and is
    // unreachable without the plusarg, so all existing lanes keep
    // byte-identical behaviour.
    // ------------------------------------------------------------------
    reg [2047:0] snd_trace_file;
    integer snd_trace_fd;
    reg snd_trace_enabled;
    integer snd_stop_frame;
    integer snd_trace_seq;
    reg snd_fm_wr_prev, snd_pcm_wr_prev, snd_nmi_prev, snd_pcm_rd_prev,
        snd_frame_lvbl_prev, snd_pcm_rd_all_prev;
    reg [5:0] snd_pcm_rd_addr;
    integer snd_nmi_count, snd_latch_rd_count, snd_ym_total, snd_pcm_total;
    reg [2047:0] dma_trace_file;
    integer dma_trace_fd;
    reg dma_trace_enabled;
    integer dma_frame_ord;
    reg dma_lvbl_prev;
    reg dma_bsy_prev;
    reg dma_trig_prev;
    reg dma_44_prev;
    integer dma_slot_idx;
    reg [7:0] dma_slot_watch [0:4];
    // Per-frame sprite-pipeline activity counters (diagnostic only).
    integer dma_obj_px, dma_dr_start, dma_inzone_hits, dma_rom_cs;
    reg dma_dr_start_prev, dma_rom_cs_prev;

    task automatic dma_trace_dump_slots(input integer frame_no, input [63:0] tag);
        reg [7:0] slot_no;
        reg [15:0] even_w, odd_w;
        begin
            for (dma_slot_idx = 0; dma_slot_idx < 5; dma_slot_idx = dma_slot_idx + 1) begin
                slot_no = dma_slot_watch[dma_slot_idx];
                // scan_addr = {scan_obj[7:0], scan_sub[1:0]}; header word (sub==0)
                // for object N lives at word index N*4 in u_even/u_odd.
                even_w = { dut.u_game.u_video.u_obj.u_scan.u_even.u_hi.u_ram.mem[slot_no*4],
                           dut.u_game.u_video.u_obj.u_scan.u_even.u_lo.u_ram.mem[slot_no*4] };
                odd_w  = { dut.u_game.u_video.u_obj.u_scan.u_odd.u_hi.u_ram.mem[slot_no*4],
                           dut.u_game.u_video.u_obj.u_scan.u_odd.u_lo.u_ram.mem[slot_no*4] };
                if (dma_trace_fd != 0)
                    $fwrite(dma_trace_fd,
                        "{\"schema\":\"esckids-dma-slot-v1\",\"frame\":%0d,\"event\":\"%0s\",\"slot\":%0d,\"even_hdr\":%0d,\"odd_hdr\":%0d,\"enable\":%0d}\n",
                        frame_no, tag, slot_no, even_w, odd_w, even_w[15]);
            end
        end
    endtask

    // Source-side diagnostic: dump the raw CPU-RAM header word (word 0,
    // 16 bits) of every sprite-table entry in the 120..145 index range so
    // the actual sort-key bytes reaching the DMA scan can be compared
    // directly against what lands (or doesn't) in the destination buffer.
    // Entry N's word 0 lives at source word address N*8.
    task automatic dma_trace_dump_source(input integer frame_no, input [63:0] tag);
        integer src_idx;
        reg [15:0] hdr;
        begin
            for (src_idx = 120; src_idx <= 145; src_idx = src_idx + 1) begin
                hdr = { dut.u_game.u_video.u_obj.u_ram.u_hi.u_dual.u_ram.mem[src_idx*8],
                        dut.u_game.u_video.u_obj.u_ram.u_lo.u_dual.u_ram.mem[src_idx*8] };
                if (dma_trace_fd != 0)
                    $fwrite(dma_trace_fd,
                        "{\"schema\":\"esckids-dma-src-v1\",\"frame\":%0d,\"event\":\"%0s\",\"entry\":%0d,\"hdr\":%0d,\"enable\":%0d,\"sortkey\":%0d}\n",
                        frame_no, tag, src_idx, hdr, hdr[15], hdr[6:0]);
            end
        end
    endtask

    // One-shot wide diagnostic: every source entry 0..255 (full RAMW=12
    // table) and every destination slot 0..127, so the real enabled
    // sort-key population can be seen without guessing which range matters.
    task automatic dma_trace_dump_full(input integer frame_no);
        integer idx;
        reg [15:0] hdr;
        begin
            for (idx = 0; idx <= 255; idx = idx + 1) begin
                hdr = { dut.u_game.u_video.u_obj.u_ram.u_hi.u_dual.u_ram.mem[idx*8],
                        dut.u_game.u_video.u_obj.u_ram.u_lo.u_dual.u_ram.mem[idx*8] };
                if (dma_trace_fd != 0 && hdr[15])
                    $fwrite(dma_trace_fd,
                        "{\"schema\":\"esckids-dma-src-full-v1\",\"frame\":%0d,\"entry\":%0d,\"hdr\":%0d,\"sortkey\":%0d}\n",
                        frame_no, idx, hdr, hdr[6:0]);
            end
            for (idx = 0; idx <= 127; idx = idx + 1) begin
                hdr = { dut.u_game.u_video.u_obj.u_scan.u_even.u_hi.u_ram.mem[idx*4],
                        dut.u_game.u_video.u_obj.u_scan.u_even.u_lo.u_ram.mem[idx*4] };
                if (dma_trace_fd != 0 && hdr[15])
                    $fwrite(dma_trace_fd,
                        "{\"schema\":\"esckids-dma-dst-full-v1\",\"frame\":%0d,\"slot\":%0d,\"hdr\":%0d}\n",
                        frame_no, idx, hdr);
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            dma_frame_ord = 0;
            dma_lvbl_prev = 1'b0;
            dma_bsy_prev  = 1'b0;
            dma_trig_prev = 1'b0;
            dma_44_prev   = 1'b0;
            dma_obj_px = 0;
            dma_dr_start = 0;
            dma_inzone_hits = 0;
            dma_rom_cs = 0;
            dma_dr_start_prev = 1'b0;
            dma_rom_cs_prev = 1'b0;
        end else if (dma_trace_enabled) begin
            if (LVBL && !dma_lvbl_prev) begin
                // Nothing: frame ordinal advances on the falling edge below,
                // matching the existing frame_ord convention (post-blank).
            end
            if (dma_lvbl_prev && !LVBL) begin
                if (dma_trace_fd != 0)
                    $fwrite(dma_trace_fd,
                        "{\"schema\":\"esckids-dma-act-v1\",\"frame\":%0d,\"obj_px\":%0d,\"dr_start\":%0d,\"rom_cs_rises\":%0d}\n",
                        dma_frame_ord, dma_obj_px, dma_dr_start, dma_rom_cs);
                dma_frame_ord = dma_frame_ord + 1;
                dma_obj_px = 0;
                dma_dr_start = 0;
                dma_rom_cs = 0;
            end
            dma_lvbl_prev = LVBL;
            if (pxl_cen && dut.u_game.u_video.lyro_pxl[3:0] != 4'd0)
                dma_obj_px = dma_obj_px + 1;
            if (dut.u_game.u_video.u_obj.u_scan.dr_start && !dma_dr_start_prev)
                dma_dr_start = dma_dr_start + 1;
            dma_dr_start_prev = dut.u_game.u_video.u_obj.u_scan.dr_start;
            if (dut.u_game.u_video.lyro_cs && !dma_rom_cs_prev)
                dma_rom_cs = dma_rom_cs + 1;
            dma_rom_cs_prev = dut.u_game.u_video.lyro_cs;

            if (dut.u_game.u_video.u_obj.u_scan.dma_trig && !dma_trig_prev && dma_trace_fd != 0)
                $fwrite(dma_trace_fd,
                    "{\"schema\":\"esckids-dma-edge-v1\",\"frame\":%0d,\"event\":\"dma_trig\",\"dma_en\":%0d,\"cfg\":%0d}\n",
                    dma_frame_ord, dut.u_game.u_video.u_obj.u_scan.dma_en,
                    dut.u_game.u_video.u_obj.u_scan.cfg);
            dma_trig_prev = dut.u_game.u_video.u_obj.u_scan.dma_trig;

            if (dut.u_game.u_video.u_obj.u_scan.u_dma.dma_44 && !dma_44_prev && dma_trace_fd != 0)
                $fwrite(dma_trace_fd,
                    "{\"schema\":\"esckids-dma-edge-v1\",\"frame\":%0d,\"event\":\"dma_44_set\"}\n",
                    dma_frame_ord);
            dma_44_prev = dut.u_game.u_video.u_obj.u_scan.u_dma.dma_44;

            if (dut.u_game.u_video.u_obj.u_scan.dma_bsy && !dma_bsy_prev && dma_trace_fd != 0)
                $fwrite(dma_trace_fd,
                    "{\"schema\":\"esckids-dma-edge-v1\",\"frame\":%0d,\"event\":\"dma_bsy_start\",\"dma_en\":%0d}\n",
                    dma_frame_ord, dut.u_game.u_video.u_obj.u_scan.dma_en);
            if (!dut.u_game.u_video.u_obj.u_scan.dma_bsy && dma_bsy_prev) begin
                if (dma_trace_fd != 0)
                    $fwrite(dma_trace_fd,
                        "{\"schema\":\"esckids-dma-edge-v1\",\"frame\":%0d,\"event\":\"dma_bsy_done\"}\n",
                        dma_frame_ord);
                dma_trace_dump_slots(dma_frame_ord, "dma_bsy_done");
                if (dma_frame_ord < 100)
                    dma_trace_dump_source(dma_frame_ord, "dma_bsy_done");
                if (dma_frame_ord == 600)
                    dma_trace_dump_full(dma_frame_ord);
            end
            dma_bsy_prev = dut.u_game.u_video.u_obj.u_scan.dma_bsy;
        end
    end
    // ------------------------------------------------------------------
    // Diagnostic native-frame capture.  Entirely opt-in: nothing below is
    // reachable unless +SMOKE_FRAME_DIR is supplied, so every pre-existing
    // lane keeps byte-identical behaviour.  Every completed native frame
    // ordinal is sampled and receipted; PPM emission is presentation-only
    // and may be restricted with first/last/stride.
    // ------------------------------------------------------------------
    localparam integer FRAME_MAX_W = 512;
    localparam integer FRAME_MAX_H = 320;
    reg [2047:0] frame_dir;
    reg [2047:0] frame_path;
    reg [2047:0] frame_receipt_file;
    integer frame_receipt_fd;
    reg frame_capture;
    integer frame_first, frame_last, frame_stride, frame_stop;
    integer frame_ord, frame_x, frame_y, frame_w, frame_h;
    integer frame_fd, frame_idx, frame_nonblack;
    reg [31:0] frame_hash;
    // Escape external-timing bridge observation (diagnostic only).
    integer frame_hld, frame_vld;
    integer frame_vmin, frame_vmax, frame_hmin, frame_hmax, frame_vsteps;
    reg [8:0] frame_vprev;
    reg frame_hld_prev, frame_vld_prev;
    integer tile_cpu_wr, tile_ram_we, tile_gfxcs_wr, pal_cpu_wr;

    // Where do the K052109 tilemap writes go?  Sampled on every clock, not
    // only at pxl_cen, because the CPU write cycle is clk-domain.
    always @(posedge clk) begin
        if (rst) begin
            tile_cpu_wr   = 0;
            tile_ram_we   = 0;
            tile_gfxcs_wr = 0;
            pal_cpu_wr    = 0;
        end else if (frame_capture) begin
            if (dut.u_game.u_main.tilesys_cs && dut.u_game.u_main.cpu_we &&
                dut.u_game.u_main.u_cpu.cen_out && dut.u_game.u_main.dtack)
                tile_cpu_wr = tile_cpu_wr + 1;
            if (dut.u_game.u_main.pal_cs && dut.u_game.u_main.cpu_we &&
                dut.u_game.u_main.u_cpu.cen_out && dut.u_game.u_main.dtack)
                pal_cpu_wr = pal_cpu_wr + 1;
            if (dut.u_game.u_video.u_scroll.u_tilemap.gfx_cs &&
                dut.u_game.u_video.u_scroll.u_tilemap.cpu_we)
                tile_gfxcs_wr = tile_gfxcs_wr + 1;
            if (|dut.u_game.u_video.u_scroll.u_tilemap.we)
                tile_ram_we = tile_ram_we + 1;
        end
    end
    reg frame_lvbl_prev, frame_lhbl_prev;
    reg [7:0] frame_buf [0:FRAME_MAX_W*FRAME_MAX_H*3-1];
    reg [1023:0] buserror_trace_file;
    integer buserror_trace_fd;
    integer buserror_seen;
    integer buserror_ring_count;
    integer buserror_ring_write;
    integer buserror_ring_emit;
    integer buserror_ring_index;
    reg [15:0] buserror_ring_pc [0:15];
    reg [15:0] buserror_ring_addr [0:15];
    reg [7:0] buserror_ring_op [0:15];
    reg [7:0] buserror_ring_data [0:15];
    reg buserror_ring_we [0:15];
    reg buserror_ring_fetch [0:15];
    reg buserror_ring_is_op [0:15];
    reg pending_valid;
    reg pending_phase;
    reg [1:0] pending_bank;
    reg [21:0] pending_addr;
    wire [3:0] request_one = pending_valid ? 4'd0 :
                             ba_rd[0] ? 4'b0001 :
                             ba_rd[1] ? 4'b0010 :
                             ba_rd[2] ? 4'b0100 :
                             ba_rd[3] ? 4'b1000 : 4'd0;
    assign ba_ack = request_one;

    function [31:0] media_index;
        input [1:0] bank;
        input [21:0] address;
        begin
`ifdef AUTH_MEDIA
            media_index = {bank, address, 1'b0};
`else
            media_index = {bank, address[16:0], 1'b0};
`endif
        end
    endfunction

    function [15:0] read_word;
        input [1:0] bank;
        input [21:0] address;
        reg [31:0] idx;
        begin
            idx = media_index(bank, address);
            read_word = {media[idx + 1], media[idx]};
        end
    endfunction

    task automatic service_gate_finalize;
        input ok;
        input [1023:0] reason;
        begin
            if (!service_gate_done) begin
                service_gate_done = 1'b1;
                if (service_gate_trace_fd != 0) begin
                    $fclose(service_gate_trace_fd);
                    service_gate_trace_fd = 0;
                end
                service_gate_final_fd = $fopen(service_gate_final_file, "w");
                if (service_gate_final_fd == 0)
                    $fatal(1, "Cannot open service-gate finalization %0s", service_gate_final_file);
                $fwrite(service_gate_final_fd,
                    "{\"schema\":\"escape-kids-service-gate-finalization-v1\",\"scenario\":\"%0s\",\"events\":%0d,\"service_requested_from_startup\":%s,\"gate_reads\":%0d,\"gate_pc\":33044,\"gate_op\":18,\"gate_data\":%0d,\"stack_pre\":%0d,\"stack_writes\":%0d,\"expected_target\":%0d,\"observed_target\":%0d,\"ok\":%s,\"closed\":true,\"reason\":\"%0s\"}\n",
                    service_gate_scenario, service_gate_seq,
                    service_gate_requested ? "true" : "false",
                    service_gate_reads, service_gate_data, service_gate_s_pre,
                    service_gate_stack_writes,
                    service_gate_requested ? 16'h85f0 : 16'h8281,
                    service_gate_target, ok ? "true" : "false", reason);
                $fclose(service_gate_final_fd);
                if (ok)
                    $display("ESCAPE KIDS SERVICE GATE PASS scenario=%0s gate_reads=%0d stack_writes=%0d target=%04h",
                        service_gate_scenario, service_gate_reads,
                        service_gate_stack_writes, service_gate_target);
                else
                    $fatal(1, "Escape Kids service gate failed: %0s", reason);
                if (ok)
                    $finish;
            end
        end
    endtask

    function automatic [7:0] raster_expected_byte;
        input integer ordinal;
        begin
            case (ordinal)
                0: raster_expected_byte = 8'h01;
                1: raster_expected_byte = 8'h7f;
                2: raster_expected_byte = 8'h00;
                3: raster_expected_byte = 8'h12;
                4: raster_expected_byte = 8'h00;
                5: raster_expected_byte = 8'h0d;
                6: raster_expected_byte = 8'h00;
                7: raster_expected_byte = 8'h01;
                8: raster_expected_byte = 8'h01;
                9: raster_expected_byte = 8'h07;
               10: raster_expected_byte = 8'h08;
               11: raster_expected_byte = 8'h07;
               12: raster_expected_byte = 8'h73;
              default: raster_expected_byte = 8'hxx;
            endcase
        end
    endfunction

    function automatic [3:0] raster_expected_index;
        input integer ordinal;
        begin
            case (ordinal)
                0,1,2,3,4,5: raster_expected_index = ordinal[3:0];
                6: raster_expected_index = 4'd7;
                7: raster_expected_index = 4'd8;
                8: raster_expected_index = 4'd9;
                9: raster_expected_index = 4'd10;
               10: raster_expected_index = 4'd11;
               11: raster_expected_index = 4'd12;
              default: raster_expected_index = 4'hf;
            endcase
        end
    endfunction

    task automatic raster_finalize;
        input ok;
        input [1023:0] reason;
        begin
            if (!raster_done) begin
                raster_done = 1'b1;
                if (raster_trace_fd != 0) begin
                    $fclose(raster_trace_fd);
                    raster_trace_fd = 0;
                end
                raster_final_fd = $fopen(raster_final_file, "w");
                if (raster_final_fd == 0)
                    $fatal(1, "Cannot open raster finalization %0s", raster_final_file);
                $fwrite(raster_final_fd,
                    "{\"schema\":\"escape-kids-raster-finalization-v1\",\"events\":%0d,\"writes\":%0d,\"vector\":\"017F0012000D00010107080773\",\"commit_pc\":%0d,\"commit_raw_pc\":%0d,\"commit_op\":%0d,\"commit_address\":%0d,\"commit_data\":%0d,\"boundaries\":%0d,\"total_h\":%0d,\"total_v\":%0d,\"pixel_ticks\":%0d,\"ok\":%s,\"closed\":true,\"reason\":\"%0s\"}\n",
                    raster_seq, raster_write_count, raster_commit_pc,
                    raster_commit_raw_pc, raster_commit_op,
                    raster_commit_addr, raster_commit_data, raster_boundaries,
                    raster_width, raster_height, raster_interval_pixels,
                    ok ? "true" : "false", reason);
                $fclose(raster_final_fd);
                if (ok) begin
                    $display("ESCAPE KIDS RASTER PASS writes=%0d width=%0d height=%0d pixels=%0d",
                        raster_write_count, raster_width, raster_height,
                        raster_interval_pixels);
                    $finish;
                end else begin
                    $fatal(1, "Escape Kids raster failed: %0s", reason);
                end
            end
        end
    endtask

    // The board-side contract: acknowledge each read request immediately and
    // hold a one-cycle pending response.  Download writes are accepted every
    // cycle and use the active-low byte mask from JTFRAME.
    // A BA0_LEN=32 SDRAM read has two 16-bit data beats.  jtframe_romrq's
    // DOUBLE=1 path consumes the first beat at DST and the second at RDY;
    // presenting only one beat corrupts every four-byte cache line and makes
    // the CPU appear to execute phantom opcodes.
    assign ba_dst = pending_valid && !pending_phase ? (4'b0001 << pending_bank) : 4'b0000;
    assign ba_rdy = pending_valid &&  pending_phase ? (4'b0001 << pending_bank) : 4'b0000;
    assign ba_dok = ba_rdy;
    assign data_read = pending_valid ? read_word(pending_bank, pending_addr + pending_phase) : 16'h0000;

    always @(posedge clk) begin
        if (pending_valid) begin
            if (!pending_phase)
                pending_phase <= 1'b1;
            else begin
                pending_valid <= 1'b0;
                pending_phase <= 1'b0;
                rom_reads <= rom_reads + 1;
            end
        end else if (request_one[0]) begin
            pending_bank <= 2'd0;
            pending_addr <= ba0_addr;
            pending_valid <= 1'b1;
            pending_phase <= 1'b0;
        end else if (request_one[1]) begin
            pending_bank <= 2'd1;
            pending_addr <= ba1_addr;
            pending_valid <= 1'b1;
            pending_phase <= 1'b0;
        end else if (request_one[2]) begin
            pending_bank <= 2'd2;
            pending_addr <= ba2_addr;
            pending_valid <= 1'b1;
            pending_phase <= 1'b0;
        end else if (request_one[3]) begin
            pending_bank <= 2'd3;
            pending_addr <= ba3_addr;
            pending_valid <= 1'b1;
            pending_phase <= 1'b0;
        end

        if (prog_we) begin
            if (!prog_mask[0]) media[media_index(prog_ba, prog_addr)] <= prog_data[7:0];
            if (!prog_mask[1]) media[media_index(prog_ba, prog_addr) + 1] <= prog_data[15:8];
            loader_writes <= loader_writes + 1;
        end
    end

    always #5  clk   = ~clk;
    always #10 clk24 = ~clk24;
    always #5  clk48 = ~clk48;
    always #2  clk96 = ~clk96;

    jtsimson_game_sdram dut (
        .rst(rst), .clk(clk), .rst24(rst24), .clk24(clk24),
        .rst48(rst48), .clk48(clk48), .rst96(rst96), .clk96(clk96),
        .pxl2_cen(pxl2_cen), .pxl_cen(pxl_cen),
        .red(red), .green(green), .blue(blue), .LHBL(LHBL), .LVBL(LVBL),
        .HS(HS), .VS(VS), .cab_1p(cab_1p), .coin(coin),
        .joystick1(joystick1), .joystick2(joystick2),
        .joystick3(joystick3), .joystick4(joystick4),
        .dial_x(dial_x), .dial_y(dial_y),
        .joyana_l1(joyana_l1), .joyana_l2(joyana_l2),
        .joyana_l3(joyana_l3), .joyana_l4(joyana_l4),
        .joyana_r1(joyana_r1), .joyana_r2(joyana_r2),
        .joyana_r3(joyana_r3), .joyana_r4(joyana_r4),
        .snd_en(snd_en), .snd_vol(snd_vol), .status(status), .dipsw(dipsw),
        .dip_pause(dip_pause), .dip_test(dip_test), .service(service), .tilt(tilt),
        .dip_flip(dip_flip), .dip_fxlevel(dip_fxlevel), .gfx_en(gfx_en),
        .debug_bus(debug_bus), .debug_view(debug_view),
        .ioctl_addr(ioctl_addr), .ioctl_dout(ioctl_dout), .ioctl_wr(ioctl_wr),
        .ioctl_rom(ioctl_rom), .ioctl_ram(ioctl_ram), .ioctl_din(ioctl_din),
        .dwnld_busy(dwnld_busy), .data_read(data_read), .ioctl_cart(ioctl_cart),
        .ba0_addr(ba0_addr), .ba1_addr(ba1_addr), .ba2_addr(ba2_addr),
        .ba3_addr(ba3_addr), .ba_rd(ba_rd), .ba_wr(ba_wr), .ba_dst(ba_dst),
        .ba_dok(ba_dok), .ba_rdy(ba_rdy), .ba_ack(ba_ack), .ba0_din(ba0_din),
        .ba1_din(ba1_din), .ba2_din(ba2_din), .ba3_din(ba3_din),
        .ba0_dsn(ba0_dsn), .ba1_dsn(ba1_dsn), .ba2_dsn(ba2_dsn), .ba3_dsn(ba3_dsn),
        .prog_data(prog_data), .prog_rdy(prog_rdy), .prog_ack(prog_ack),
        .prog_dst(prog_dst), .prog_dok(prog_dok), .prog_ba(prog_ba),
        .prog_we(prog_we), .prog_rd(prog_rd), .prog_mask(prog_mask),
        .prog_addr(prog_addr), .snd_left(snd_left), .snd_right(snd_right),
        .snd_vu(snd_vu), .snd_peak(snd_peak), .sample(sample)
    );

    task send_header_byte;
        input [5:0] address;
        input [7:0] value;
        begin
            @(negedge clk);
            ioctl_addr <= address;
            ioctl_dout <= value;
            ioctl_rom <= 1'b1;
            ioctl_wr <= 1'b1;
            @(negedge clk);
            ioctl_wr <= 1'b0;
            ioctl_rom <= 1'b0;
        end
    endtask

    task send_stream_byte;
        input [25:0] address;
        input [7:0] value;
        begin
            @(negedge clk);
            ioctl_addr <= address;
            ioctl_dout <= value;
            ioctl_rom <= 1'b1;
            ioctl_wr <= 1'b1;
            @(negedge clk);
            ioctl_wr <= 1'b0;
        end
    endtask

`ifdef AUTH_MEDIA
    task send_loader_byte;
        input [25:0] address;
        input [7:0] value;
        begin
            @(negedge clk);
            ioctl_addr <= address;
            ioctl_dout <= value;
            ioctl_rom <= 1'b1;
            ioctl_wr <= 1'b1;
            @(negedge clk);
            ioctl_wr <= 1'b0;
            ioctl_rom <= 1'b0;
        end
    endtask

    task automatic load_authenticated_stream;
        input [1023:0] path;
        integer fd;
        integer n;
        integer c;
        reg [7:0] hdr0, hdr1, hdr2, hdr3;
        reg [7:0] sample_main, sample_sound, sample_pcm;
        reg [7:0] sample_tiles, sample_sprites, sample_gap;
        begin
            fd = $fopen(path, "rb");
            if (fd == 0)
                $fatal(1, "Cannot open authenticated MRA stream %0s", path);
            c = $fgetc(fd); hdr0 = c[7:0];
            c = $fgetc(fd); hdr1 = c[7:0];
            c = $fgetc(fd); hdr2 = c[7:0];
            c = $fgetc(fd); hdr3 = c[7:0];
            if (hdr0 !== 8'h03 || hdr2 !== 8'h00 || hdr3 !== 8'h00 ||
                hdr1 !== (smoke_cabinet_2p ? 8'h01 : 8'h00))
                $fatal(1, "Authenticated stream header mismatch %02h%02h%02h%02h",
                    hdr0,hdr1,hdr2,hdr3);
            send_header_byte(6'd0, hdr0);
            send_header_byte(6'd1, hdr1);
            send_header_byte(6'd2, hdr2);
            send_header_byte(6'd3, hdr3);
            for (n = 0; n < 26'h6e0000; n = n + 1) begin
                c = $fgetc(fd);
                if (c < 0)
                    $fatal(1, "Authenticated stream ended at post-header offset %0h", n);
                case (n)
                    26'h000000: sample_main   = c[7:0];
                    26'h080000: sample_sound  = c[7:0];
                    26'h0a0000: sample_pcm    = c[7:0];
                    26'h1e0000: sample_tiles  = c[7:0];
                    26'h2e0000: sample_sprites= c[7:0];
                    26'h020000: sample_gap   = c[7:0];
                    default:;
                endcase
                send_loader_byte(n + 26'd4, c[7:0]);
                if ((n & 26'h0fffff) == 26'h0fffff)
                    $display("AUTH loader progress post_header=%0h writes=%0d", n + 1, loader_writes);
            end
            c = $fgetc(fd);
            if (c >= 0)
                $fatal(1, "Authenticated stream has trailing data after %0h bytes", 26'h6e0000);
            $fclose(fd);
            wait (!dwnld_busy);
            // jtframe_dwnld registers ioctl_wr/dout for one clock before it
            // presents prog_we, so the final stream byte is still in flight
            // when dwnld_busy drops.  Flush the pipeline before sampling.
            repeat (8) @(posedge clk);
            // jtframe_dwnld is instantiated with SWAB=1, so
            // nx_prog_mask = (eff_addr[0]^1) ? 2'b10 : 2'b01 (active low):
            // an even effective byte offset writes the LOW lane
            // (prog_data[7:0] -> media[idx]) and an odd offset writes the
            // high lane.  That matches the fast diagnostic lane, where
            // $readmemh puts the even ROM byte at the even media index.
            // (The previous high-lane expectation here was never exercised:
            // the AUTH_MEDIA full-smoke lane had no successful run.)
            if (media[media_index(2'd0, 22'h000000)] !== sample_main)
                $fatal(1, "main physical lane mismatch got=%02h exp=%02h",
                    media[media_index(2'd0, 22'h000000)], sample_main);
            if (media[media_index(2'd1, 22'h000000)] !== sample_sound)
                $fatal(1, "sound physical lane mismatch got=%02h exp=%02h",
                    media[media_index(2'd1, 22'h000000)], sample_sound);
            if (media[media_index(2'd1, 22'h010000)] !== sample_pcm)
                $fatal(1, "PCM physical lane mismatch got=%02h exp=%02h",
                    media[media_index(2'd1, 22'h010000)], sample_pcm);
            if (media[media_index(2'd2, 22'h000000)] !== sample_tiles)
                $fatal(1, "tile physical lane mismatch got=%02h exp=%02h",
                    media[media_index(2'd2, 22'h000000)], sample_tiles);
            if (media[media_index(2'd3, 22'h000000)] !== sample_sprites)
                $fatal(1, "sprite physical lane mismatch got=%02h exp=%02h",
                    media[media_index(2'd3, 22'h000000)], sample_sprites);
            if (sample_gap !== 8'h00)
                $fatal(1, "alignment gap is non-zero at 0x020000: %02h", sample_gap);
            if (loader_writes !== 26'h6e0000)
                $fatal(1, "loader write count %0d != %0d", loader_writes, 26'h6e0000);
        end
    endtask
`endif

    // Presentation-only: serialise the already-sampled native frame to a
    // binary PPM (P6).  Never called unless frame capture is enabled.
    task automatic frame_emit;
        integer fx, fy, base;
        begin
            $sformat(frame_path, "%0s/frame_%05d.ppm", frame_dir, frame_ord);
            frame_fd = $fopen(frame_path, "wb");
            if (frame_fd == 0)
                $fatal(1, "Cannot open frame file %0s", frame_path);
            $fwrite(frame_fd, "P6\n%0d %0d\n255\n", frame_w, frame_h);
            for (fy = 0; fy < frame_h; fy = fy + 1) begin
                base = fy*FRAME_MAX_W*3;
                for (fx = 0; fx < frame_w*3; fx = fx + 1)
                    $fwrite(frame_fd, "%c", frame_buf[base+fx]);
            end
            $fclose(frame_fd);
            frame_dump_ram;
        end
    endtask

    // Diagnostic: the rendered screen is a single 8x8 tile repeated, which is
    // either uniform tilemap VRAM (a CPU/write-path fault) or a stuck scan
    // address (a video read-path fault).  Dump the raw K052109 code/attr RAM
    // and the palette RAM alongside the frame so the two can be told apart.
    task automatic frame_dump_ram;
        integer fd, k;
        reg [2047:0] path;
        reg [2047:0] mmr_path;
        integer mmr_fd;
        begin
            $sformat(path, "%0s/vram_%05d.bin", frame_dir, frame_ord);
            fd = $fopen(path, "wb");
            if (fd != 0) begin
                for (k = 0; k < 8192; k = k + 1)
                    $fwrite(fd, "%c",
                        dut.u_game.u_video.u_scroll.u_tilemap.u_code.u_dual.u_ram.mem[k]);
                for (k = 0; k < 8192; k = k + 1)
                    $fwrite(fd, "%c",
                        dut.u_game.u_video.u_scroll.u_tilemap.u_attr.u_dual.u_ram.mem[k]);
                for (k = 0; k < 4096; k = k + 1)
                    $fwrite(fd, "%c",
                        dut.u_game.u_video.u_colmix.u_ram.u_dual.u_ram.mem[k]);
                $fclose(fd);
            end
            // Additive debug dump: K053251 (jtcolmix_053251) internal mmr[0:12]
            // register file, one byte per register (6 significant bits each).
            // Used to compare the color-mixer's live colorbase-select register
            // state against MAME's k053251_device internal register array at
            // the same game moment, independent of the (already structurally
            // verified) downstream mixing logic.
            $sformat(mmr_path, "%0s/mmr_%05d.bin", frame_dir, frame_ord);
            mmr_fd = $fopen(mmr_path, "wb");
            if (mmr_fd != 0) begin
                for (k = 0; k < 13; k = k + 1)
                    $fwrite(mmr_fd, "%c",
                        dut.u_game.u_video.u_colmix.u_prio.mmr[k]);
                $fclose(mmr_fd);
            end
        end
    endtask

    // Every completed native frame ordinal gets a receipt line, whether or
    // not a PPM was written for it.  The hash is accumulated per sampled
    // pixel, so it covers the whole active window at pixel-clock-enable.
    task automatic frame_receipt_line;
        begin
            if (frame_receipt_fd != 0)
                $fwrite(frame_receipt_fd,
                    "{\"schema\":\"escape-kids-native-frame-v1\",\"frame\":%0d,\"width\":%0d,\"height\":%0d,\"hash\":%0d,\"nonblack\":%0d,\"hld\":%0d,\"vld\":%0d,\"vdump_min\":%0d,\"vdump_max\":%0d,\"vdump_steps\":%0d,\"hdump_min\":%0d,\"hdump_max\":%0d,\"tile_cpu_wr\":%0d,\"tile_gfxcs_wr\":%0d,\"tile_ram_we\":%0d,\"pal_cpu_wr\":%0d,\"k052109_cfg\":%0d,\"cpu_pc\":%0d,\"emitted\":%s}\n",
                    frame_ord, frame_w, frame_h, frame_hash, frame_nonblack,
                    frame_hld, frame_vld, frame_vmin, frame_vmax, frame_vsteps,
                    frame_hmin, frame_hmax,
                    tile_cpu_wr, tile_gfxcs_wr, tile_ram_we, pal_cpu_wr,
                    dut.u_game.u_video.u_scroll.u_tilemap.cfg,
                    dut.u_game.u_main.u_cpu.pc,
                    (frame_ord >= frame_first && frame_ord <= frame_last &&
                     ((frame_ord - frame_first) % frame_stride) == 0) ? "true" : "false");
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            frame_x = 0;
            frame_y = 0;
            frame_w = 0;
            frame_h = 0;
            frame_nonblack = 0;
            frame_hash = 32'h811c9dc5;
            frame_lvbl_prev = 1'b0;
            frame_lhbl_prev = 1'b0;
        end else if (frame_capture && pxl_cen) begin
            // External-timing bridge observation: the Escape CCU load pulses
            // and the reconstructed 9-bit native counters.  Read-only.
            if (dut.u_game.u_video.u_scroll.ext_hld && !frame_hld_prev)
                frame_hld = frame_hld + 1;
            if (dut.u_game.u_video.u_scroll.ext_vld && !frame_vld_prev)
                frame_vld = frame_vld + 1;
            frame_hld_prev = dut.u_game.u_video.u_scroll.ext_hld;
            frame_vld_prev = dut.u_game.u_video.u_scroll.ext_vld;
            if (dut.u_game.u_video.u_scroll.esc_vdump < frame_vmin)
                frame_vmin = dut.u_game.u_video.u_scroll.esc_vdump;
            if (dut.u_game.u_video.u_scroll.esc_vdump > frame_vmax)
                frame_vmax = dut.u_game.u_video.u_scroll.esc_vdump;
            if (dut.u_game.u_video.u_scroll.esc_hdump < frame_hmin)
                frame_hmin = dut.u_game.u_video.u_scroll.esc_hdump;
            if (dut.u_game.u_video.u_scroll.esc_hdump > frame_hmax)
                frame_hmax = dut.u_game.u_video.u_scroll.esc_hdump;
            if (dut.u_game.u_video.u_scroll.esc_vdump !== frame_vprev)
                frame_vsteps = frame_vsteps + 1;
            frame_vprev = dut.u_game.u_video.u_scroll.esc_vdump;
            if (LVBL && LHBL) begin
                if (frame_x < FRAME_MAX_W && frame_y < FRAME_MAX_H) begin
                    frame_idx = (frame_y*FRAME_MAX_W + frame_x)*3;
                    frame_buf[frame_idx+0] = red;
                    frame_buf[frame_idx+1] = green;
                    frame_buf[frame_idx+2] = blue;
                end
                if (red != 8'd0 || green != 8'd0 || blue != 8'd0)
                    frame_nonblack = frame_nonblack + 1;
                frame_hash = (frame_hash ^ {24'd0, red})   * 32'h01000193;
                frame_hash = (frame_hash ^ {24'd0, green}) * 32'h01000193;
                frame_hash = (frame_hash ^ {24'd0, blue})  * 32'h01000193;
                frame_x = frame_x + 1;
            end
            if (frame_lhbl_prev && !LHBL) begin
                if (frame_x > frame_w) frame_w = frame_x;
                if (frame_x > 0) frame_y = frame_y + 1;
                frame_x = 0;
            end
            if (frame_lvbl_prev && !LVBL) begin
                frame_h = (frame_y > FRAME_MAX_H) ? FRAME_MAX_H : frame_y;
                if (frame_w > FRAME_MAX_W) frame_w = FRAME_MAX_W;
                if (frame_w > 0 && frame_h > 0 &&
                    frame_ord >= frame_first && frame_ord <= frame_last &&
                    ((frame_ord - frame_first) % frame_stride) == 0)
                    frame_emit;
                frame_receipt_line;
                frame_ord = frame_ord + 1;
                frame_x = 0;
                frame_y = 0;
                frame_w = 0;
                frame_nonblack = 0;
                frame_hash = 32'h811c9dc5;
                frame_hld = 0;
                frame_vld = 0;
                frame_vsteps = 0;
                frame_vmin = 1000; frame_vmax = 0;
                frame_hmin = 1000; frame_hmax = 0;
                if (frame_stop > 0 && frame_ord >= frame_stop) begin
                    if (frame_receipt_fd != 0) $fclose(frame_receipt_fd);
                    frame_receipt_fd = 0;
                    if (dma_trace_enabled && dma_trace_fd != 0) begin
                        $fclose(dma_trace_fd);
                        dma_trace_fd = 0;
                        dma_trace_enabled = 1'b0;
                    end
                    $display("ESCAPE KIDS FRAME CAPTURE DONE frames=%0d", frame_ord);
                    $finish;
                end
            end
            frame_lhbl_prev = LHBL;
            frame_lvbl_prev = LVBL;
        end
    end

    // Optional phase-edge diagnostic.  JTKCPU's internal clken is the 1x
    // state-update/memory-consume phase; sampling its rising edge avoids
    // counting the 2x cen_out half-cycle twice.  This path is never used by
    // synthesis.
    task automatic emit_phase_trace;
        reg [7:0] tdata;
        reg [3:0] tdevice;
        begin
            if (trace_enabled && !rst && frame_ord >= trace_start_frame &&
                (trace_limit == 0 || trace_seq < trace_limit) &&
                dut.u_game.u_main.dtack &&
                (dut.u_game.u_main.u_cpu.u_memctrl.mem_en || dut.u_game.u_main.cpu_we)) begin
                // The JTKCPU memory controller retains a just-written stack
                // address for the first fetch request of the next phase.  It
                // is not consumed by the CPU (is_op remains low) and is not
                // an accepted external transaction.  Drop only this
                // source-observable stale sample, retaining a counter in the
                // diagnostic trace contract.
                if (trace_prev_write && !dut.u_game.u_main.cpu_we &&
                    dut.u_game.u_main.u_cpu.fetch &&
                    !dut.u_game.u_main.u_cpu.stack_busy &&
                    dut.u_game.u_main.cpu_addr == trace_prev_addr) begin
                    trace_stale_drop_count = trace_stale_drop_count + 1;
                end else begin
                tdata = dut.u_game.u_main.cpu_we ? dut.u_game.u_main.cpu_dout : dut.u_game.u_main.cpu_din;
                // Decode specific control/register overlays before the broad
                // K052109 window so 0x3f80+ keeps its semantic device ID.
                tdevice = dut.u_game.u_main.rom_cs ? 5 :
                          dut.u_game.u_main.ram_cs ? 1 :
                          dut.u_game.u_main.pal_cs ? 4 :
                          (dut.u_game.u_main.joystk_cs || dut.u_game.u_main.eeprom_cs ||
                           dut.u_game.u_main.stsw_cs || dut.u_game.u_main.objreg_cs ||
                           dut.u_game.u_main.pcu_cs || dut.u_game.u_main.k053252_cs ||
                           dut.u_game.u_main.snd_cs || dut.u_game.u_main.snd_irq ||
                           dut.u_game.u_main.objread_cs ||
                           dut.u_game.u_main.cpu_addr == 16'h3fd0 ||
                           dut.u_game.u_main.cpu_addr == 16'h3fd2 ||
                           dut.u_game.u_main.cpu_addr == 16'h3fda) ? 3 :
                          dut.u_game.u_main.tilesys_cs ? 2 : 0;
                if (^tdata === 1'bx)
                    $fwrite(trace_fd,
                        "{\"schema\":\"mister-bus-jsonl-v1\",\"seq\":%0d,\"cpu\":0,\"event\":\"bus\",\"pc\":%0d,\"rw\":\"%s\",\"address\":%0d,\"data\":0,\"lanes\":1,\"device\":%0d,\"x\":true,\"sample_cpu_we\":%b,\"sample_mem_en\":%b,\"sample_clken\":%b,\"sample_clken2\":%b,\"sample_mem_we\":%b,\"sample_mem_addr\":%0d,\"sample_dtack\":%b,\"sample_stack_busy\":%b,\"sample_psh_dec\":%b,\"sample_fetch\":%b,\"sample_opd\":%b,\"sample_wrq\":%b,\"sample_is_op\":%b,\"sample_mem_busy\":%b,\"cc\":%0d,\"irqn_ff\":%b,\"irqen\":%b,\"irq_mx\":%b,\"dma_bsy\":%b}\n",
                        trace_seq, dut.u_game.u_main.u_cpu.pc,
                        dut.u_game.u_main.cpu_we ? "w" : "r",
                        dut.u_game.u_main.cpu_addr, tdevice,
                        dut.u_game.u_main.cpu_we,
                        dut.u_game.u_main.u_cpu.u_memctrl.mem_en,
                        dut.u_game.u_main.u_cpu.clken,
                        dut.u_game.u_main.u_cpu.clken2,
                        dut.u_game.u_main.u_cpu.u_memctrl.we,
                        dut.u_game.u_main.u_cpu.u_memctrl.addr,
                        dut.u_game.u_main.dtack,
                        dut.u_game.u_main.u_cpu.stack_busy,
                        dut.u_game.u_main.u_cpu.psh_dec,
                        dut.u_game.u_main.u_cpu.fetch,
                        dut.u_game.u_main.u_cpu.opd,
                        dut.u_game.u_main.u_cpu.wrq,
                        dut.u_game.u_main.u_cpu.is_op,
                        dut.u_game.u_main.u_cpu.mem_busy,
                        dut.u_game.u_main.u_cpu.cc,
                        dut.u_game.u_main.irqn_ff,
                        dut.u_game.u_main.irqen,
                        dut.u_game.u_main.irq_mx,
                        dut.u_game.dma_bsy);
                else
                    $fwrite(trace_fd,
                        "{\"schema\":\"mister-bus-jsonl-v1\",\"seq\":%0d,\"cpu\":0,\"event\":\"bus\",\"pc\":%0d,\"rw\":\"%s\",\"address\":%0d,\"data\":%0d,\"lanes\":1,\"device\":%0d,\"x\":false,\"sample_cpu_we\":%b,\"sample_mem_en\":%b,\"sample_clken\":%b,\"sample_clken2\":%b,\"sample_mem_we\":%b,\"sample_mem_addr\":%0d,\"sample_dtack\":%b,\"sample_stack_busy\":%b,\"sample_psh_dec\":%b,\"sample_fetch\":%b,\"sample_opd\":%b,\"sample_wrq\":%b,\"sample_is_op\":%b,\"sample_mem_busy\":%b,\"cc\":%0d,\"irqn_ff\":%b,\"irqen\":%b,\"irq_mx\":%b,\"dma_bsy\":%b}\n",
                        trace_seq, dut.u_game.u_main.u_cpu.pc,
                        dut.u_game.u_main.cpu_we ? "w" : "r",
                        dut.u_game.u_main.cpu_addr, tdata, tdevice,
                        dut.u_game.u_main.cpu_we,
                        dut.u_game.u_main.u_cpu.u_memctrl.mem_en,
                        dut.u_game.u_main.u_cpu.clken,
                        dut.u_game.u_main.u_cpu.clken2,
                        dut.u_game.u_main.u_cpu.u_memctrl.we,
                        dut.u_game.u_main.u_cpu.u_memctrl.addr,
                        dut.u_game.u_main.dtack,
                        dut.u_game.u_main.u_cpu.stack_busy,
                        dut.u_game.u_main.u_cpu.psh_dec,
                        dut.u_game.u_main.u_cpu.fetch,
                        dut.u_game.u_main.u_cpu.opd,
                        dut.u_game.u_main.u_cpu.wrq,
                        dut.u_game.u_main.u_cpu.is_op,
                        dut.u_game.u_main.u_cpu.mem_busy,
                        dut.u_game.u_main.u_cpu.cc,
                        dut.u_game.u_main.irqn_ff,
                        dut.u_game.u_main.irqen,
                        dut.u_game.u_main.irq_mx,
                        dut.u_game.dma_bsy);
                trace_seq = trace_seq + 1;
                trace_prev_addr = dut.u_game.u_main.cpu_addr;
                trace_prev_write = dut.u_game.u_main.cpu_we;
                end
            end
        end
    endtask

`ifndef VERILATOR
    // Directed integration check for the real generated work-BRAM instance.
    // The optional alias injection emulates the pre-fix connection, where
    // every stack byte used one retained program-ROM address.
    task automatic run_workram_contract;
        begin
            force dut.u_game.main_cs = 1'b0;
            force dut.ram_we = 1'b1;
            if (workram_alias_inject)
                force dut.main_addr = 19'h007f3;

            @(negedge clk);
            force dut.u_game.ram_addr = 13'h7f3;
            force dut.ram_din = 8'ha1;
            @(posedge clk); #1;
            @(negedge clk);
            force dut.u_game.ram_addr = 13'h7f4;
            force dut.ram_din = 8'hb2;
            @(posedge clk); #1;
            @(negedge clk);
            force dut.u_game.ram_addr = 13'h7f5;
            force dut.ram_din = 8'hc3;
            @(posedge clk); #1;

            @(negedge clk);
            force dut.ram_we = 1'b0;
            force dut.u_game.ram_addr = 13'h7f3;
            @(posedge clk); #1;
            if (dut.ram_dout !== 8'ha1)
                $fatal(1,"Work RAM adjacent read 07f3=%02h expected=a1",dut.ram_dout);
            @(negedge clk);
            force dut.u_game.ram_addr = 13'h7f4;
            @(posedge clk); #1;
            if (dut.ram_dout !== 8'hb2)
                $fatal(1,"Work RAM adjacent read 07f4=%02h expected=b2",dut.ram_dout);
            @(negedge clk);
            force dut.u_game.ram_addr = 13'h7f5;
            @(posedge clk); #1;
            if (dut.ram_dout !== 8'hc3)
                $fatal(1,"Work RAM adjacent read 07f5=%02h expected=c3",dut.ram_dout);

            release dut.u_game.ram_addr;
            release dut.ram_din;
            release dut.ram_we;
            release dut.u_game.main_cs;
            if (workram_alias_inject)
                release dut.main_addr;
            $display("ESCAPE KIDS WORK RAM CONTRACT PASS addresses=07f3,07f4,07f5 latency=one_clock");
        end
    endtask
`endif

    always @(posedge clk) begin
        // Semantic input scenario.  The edge schedule is intentionally in
        // core-clock cycles, not host time, so it can be replayed by a
        // project-owned Verilator run and aligned to a MAME input journal.
        // Values are active-low at the CPU-visible ports.  Asia has no
        // dedicated MAME Start fields; its four-player presentation aliases
        // start to the corresponding coin controls, while Japan uses the
        // cab_1p[1:0] start bits and keeps P3/P4 inactive.
        if (rst) begin
            diag_cycle_count <= 0;
            scenario_cycle <= 0;
            input_scenario_done <= 1'b0;
            buserror_seen = 0;
            buserror_ring_count = 0;
            buserror_ring_write = 0;
            if (service_gate_enabled || raster_enabled) begin
                cab_1p    <= 4'hf;
                coin      <= 4'hf;
                joystick1 <= 7'h7f;
                joystick2 <= 7'h7f;
                joystick3 <= 7'h7f;
                joystick4 <= 7'h7f;
                service   <= service_gate_enabled && service_gate_requested ? 1'b0 : 1'b1;
            end else if (input_scenario) begin
                cab_1p   <= 4'hf;
                coin     <= 4'hf;
                joystick1 <= 7'h7f;
                joystick2 <= 7'h7f;
                joystick3 <= 7'h7f;
                joystick4 <= 7'h7f;
                service  <= 1'b1;
            end else if (coin_scenario) begin
                cab_1p   <= 4'hf;
                coin     <= 4'hf;
                coin_prev <= 4'hf;
                joystick1 <= 7'h7f;
                joystick2 <= 7'h7f;
                joystick3 <= 7'h7f;
                joystick4 <= 7'h7f;
                service  <= 1'b1;
            end
        end else if (service_gate_enabled) begin
            scenario_cycle <= scenario_cycle + 1;
            cab_1p    <= 4'hf;
            coin      <= 4'hf;
            joystick1 <= 7'h7f;
            joystick2 <= 7'h7f;
            joystick3 <= 7'h7f;
            joystick4 <= 7'h7f;
            service   <= service_gate_requested ? 1'b0 : 1'b1;
            if (!service_gate_startup_emitted) begin
                $fwrite(service_gate_trace_fd,
                    "{\"schema\":\"escape-kids-service-gate-v1\",\"seq\":%0d,\"event\":\"startup_input\",\"service_requested\":%s}\n",
                    service_gate_seq, service_gate_requested ? "true" : "false");
                service_gate_seq = service_gate_seq + 1;
                service_gate_startup_emitted <= 1'b1;
            end
        end else if (raster_enabled) begin
            scenario_cycle <= scenario_cycle + 1;
            cab_1p    <= 4'hf;
            coin      <= 4'hf;
            joystick1 <= 7'h7f;
            joystick2 <= 7'h7f;
            joystick3 <= 7'h7f;
            joystick4 <= 7'h7f;
            service   <= 1'b1;
        end else if (input_scenario) begin
            scenario_cycle <= scenario_cycle + 1;
            case (scenario_cycle)
                100000: begin
                    coin[0] <= 1'b0; joystick1[0] <= 1'b0; joystick1[4] <= 1'b0;
                    if (smoke_cabinet_2p) cab_1p[0] <= 1'b0;
                    input_edges <= input_edges + 1;
                    if (input_trace_enabled)
                        $fwrite(input_trace_fd,
                            "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"input_edge\",\"cycle\":%0d,\"phase\":\"p1_coin_start_move\",\"cab_1p\":%0d,\"coin\":%0d,\"joystick1\":%0d,\"joystick2\":%0d,\"joystick3\":%0d,\"joystick4\":%0d,\"service\":%0d}\n",
                            input_trace_seq, scenario_cycle, cab_1p, coin,
                            joystick1, joystick2, joystick3, joystick4, service);
                    input_trace_seq <= input_trace_seq + 1;
                end
                2500000: begin
                    coin[0] <= 1'b1; joystick1[0] <= 1'b1; joystick1[4] <= 1'b1;
                    if (smoke_cabinet_2p) cab_1p[0] <= 1'b1;
                    input_edges <= input_edges + 1;
                    if (input_trace_enabled)
                        $fwrite(input_trace_fd,
                            "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"input_edge\",\"cycle\":%0d,\"phase\":\"p1_release\",\"cab_1p\":%0d,\"coin\":%0d,\"joystick1\":%0d,\"joystick2\":%0d,\"joystick3\":%0d,\"joystick4\":%0d,\"service\":%0d}\n",
                            input_trace_seq, scenario_cycle, cab_1p, coin,
                            joystick1, joystick2, joystick3, joystick4, service);
                    input_trace_seq <= input_trace_seq + 1;
                end
                3000000: begin
                    coin[1] <= 1'b0; joystick2[1] <= 1'b0; joystick2[5] <= 1'b0;
                    if (smoke_cabinet_2p) cab_1p[1] <= 1'b0;
                    input_edges <= input_edges + 1;
                    if (input_trace_enabled)
                        $fwrite(input_trace_fd,
                            "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"input_edge\",\"cycle\":%0d,\"phase\":\"p2_coin_start_button\",\"cab_1p\":%0d,\"coin\":%0d,\"joystick1\":%0d,\"joystick2\":%0d,\"joystick3\":%0d,\"joystick4\":%0d,\"service\":%0d}\n",
                            input_trace_seq, scenario_cycle, cab_1p, coin,
                            joystick1, joystick2, joystick3, joystick4, service);
                    input_trace_seq <= input_trace_seq + 1;
                end
                5500000: begin
                    coin[1] <= 1'b1; joystick2[1] <= 1'b1; joystick2[5] <= 1'b1;
                    if (smoke_cabinet_2p) cab_1p[1] <= 1'b1;
                    input_edges <= input_edges + 1;
                    if (input_trace_enabled)
                        $fwrite(input_trace_fd,
                            "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"input_edge\",\"cycle\":%0d,\"phase\":\"p2_release\",\"cab_1p\":%0d,\"coin\":%0d,\"joystick1\":%0d,\"joystick2\":%0d,\"joystick3\":%0d,\"joystick4\":%0d,\"service\":%0d}\n",
                            input_trace_seq, scenario_cycle, cab_1p, coin,
                            joystick1, joystick2, joystick3, joystick4, service);
                    input_trace_seq <= input_trace_seq + 1;
                end
                6000000: begin
                    if (!smoke_cabinet_2p) begin
                        coin[2] <= 1'b0; coin[3] <= 1'b0;
                        joystick3[2] <= 1'b0; joystick4[3] <= 1'b0;
                    end
                    input_edges <= input_edges + 1;
                    if (input_trace_enabled)
                        $fwrite(input_trace_fd,
                            "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"input_edge\",\"cycle\":%0d,\"phase\":\"p3_p4_join\",\"cab_1p\":%0d,\"coin\":%0d,\"joystick1\":%0d,\"joystick2\":%0d,\"joystick3\":%0d,\"joystick4\":%0d,\"service\":%0d}\n",
                            input_trace_seq, scenario_cycle, cab_1p, coin,
                            joystick1, joystick2, joystick3, joystick4, service);
                    input_trace_seq <= input_trace_seq + 1;
                end
                8500000: begin
                    coin[2] <= 1'b1; coin[3] <= 1'b1;
                    joystick3[2] <= 1'b1; joystick4[3] <= 1'b1;
                    input_edges <= input_edges + 1;
                    if (input_trace_enabled)
                        $fwrite(input_trace_fd,
                            "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"input_edge\",\"cycle\":%0d,\"phase\":\"p3_p4_release\",\"cab_1p\":%0d,\"coin\":%0d,\"joystick1\":%0d,\"joystick2\":%0d,\"joystick3\":%0d,\"joystick4\":%0d,\"service\":%0d}\n",
                            input_trace_seq, scenario_cycle, cab_1p, coin,
                            joystick1, joystick2, joystick3, joystick4, service);
                    input_trace_seq <= input_trace_seq + 1;
                end
                9000000: begin
                    service <= 1'b0;
                    input_edges <= input_edges + 1;
                    if (input_trace_enabled)
                        $fwrite(input_trace_fd,
                            "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"input_edge\",\"cycle\":%0d,\"phase\":\"service_press\",\"cab_1p\":%0d,\"coin\":%0d,\"joystick1\":%0d,\"joystick2\":%0d,\"joystick3\":%0d,\"joystick4\":%0d,\"service\":%0d}\n",
                            input_trace_seq, scenario_cycle, cab_1p, coin,
                            joystick1, joystick2, joystick3, joystick4, service);
                    input_trace_seq <= input_trace_seq + 1;
                end
                11500000: begin
                    service <= 1'b1;
                    input_edges <= input_edges + 1;
                    if (input_trace_enabled)
                        $fwrite(input_trace_fd,
                            "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"input_edge\",\"cycle\":%0d,\"phase\":\"service_release\",\"cab_1p\":%0d,\"coin\":%0d,\"joystick1\":%0d,\"joystick2\":%0d,\"joystick3\":%0d,\"joystick4\":%0d,\"service\":%0d}\n",
                            input_trace_seq, scenario_cycle, cab_1p, coin,
                            joystick1, joystick2, joystick3, joystick4, service);
                    input_trace_seq <= input_trace_seq + 1;
                end
                14000000: input_scenario_done <= 1'b1;
                default:;
            endcase
        end else if (coin_scenario) begin
            // Long-horizon coin-to-gameplay scenario: hold idle through boot
            // and attract-mode stabilisation, pulse a single P1 coin edge at
            // a VBlank-frame-counted point (frame counter is the existing
            // `frames` reg, incremented later this same cycle -- using its
            // pre-update value here is fine, the coin pulse spans many
            // frames so a one-cycle skew is immaterial), hold it for
            // coin_hold_frames frames, then release and go fully idle again
            // so the DUT free-runs through Konami's character-select
            // auto-timeout, ticket animation and color-assign screens on its
            // own, exactly like the MAME reference scenario documented in
            // .mister/scenario-briefs/coin-to-gameplay.md section 6 (no
            // Start button on esckids4p; a manual confirm input was not
            // determined, so this deliberately relies on the timeout path).
            cab_1p    <= 4'hf;
            joystick1 <= 7'h7f;
            joystick2 <= 7'h7f;
            joystick3 <= 7'h7f;
            joystick4 <= 7'h7f;
            service   <= 1'b1;
            // Gate on lvbl_falls (a genuine once-per-real-video-frame,
            // edge-detected counter, unconditionally maintained a few lines
            // below and NOT gated behind -FrameDir), not the legacy `frames`
            // reg.  `frames` (line ~1291, `!rst && !LVBL && HS`) is a level
            // check evaluated every clock, so it increments many times per
            // real video frame instead of once -- confirmed empirically this
            // session (SMOKE_WRAM_TRACE showed `frames` already past 67000
            // within the first ~13 real frames).  That mismatch meant
            // CoinFrame/CoinHoldFrames fired within the first real frame or
            // two after reset, not at the intended Nth displayed frame, for
            // every prior coin_scenario run this investigation used.  Using
            // lvbl_falls makes CoinFrame/CoinHoldFrames mean what the
            // scenario brief and CLI flags document: real displayed frames.
            if (lvbl_falls >= coin_frame && lvbl_falls < coin_release_frame)
                coin <= 4'b1110;
            else
                coin <= 4'hf;
            // Prove at the DUT port that the scripted pulse actually
            // asserted, independent of whether the CPU ever samples it.
            // Diagnostic-only, emitted at most twice per run.
            if (input_trace_enabled && coin !== coin_prev)
                $fwrite(input_trace_fd,
                    "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"coin_port_edge\",\"cycle\":%0d,\"frame\":%0d,\"coin\":%0d}\n",
                    input_trace_seq, diag_cycle_count, lvbl_falls, coin);
            if (coin !== coin_prev) input_trace_seq <= input_trace_seq + 1;
            coin_prev <= coin;
        end
        if (!rst)
            diag_cycle_count <= diag_cycle_count + 1;
        if (stack_debug && !rst &&
            (dut.u_game.u_main.cpu_addr == 16'h07ff ||
             dut.u_game.u_main.u_cpu.u_memctrl.addr == 16'h07ff))
            $display("STACK_DEBUG edge=posedge t=%0t cpu_addr=%04h mem_addr=%04h cpu_we=%b mem_we=%b clken=%b clken2=%b dtack=%b mem_en=%b dout=%02h din=%02h",
                $time, dut.u_game.u_main.cpu_addr,
                dut.u_game.u_main.u_cpu.u_memctrl.addr,
                dut.u_game.u_main.cpu_we,
                dut.u_game.u_main.u_cpu.u_memctrl.we,
                dut.u_game.u_main.u_cpu.clken,
                dut.u_game.u_main.u_cpu.clken2,
                dut.u_game.u_main.dtack,
                dut.u_game.u_main.u_cpu.u_memctrl.mem_en,
                dut.u_game.u_main.cpu_dout,
                dut.u_game.u_main.cpu_din);
        if (!rst && !LVBL && HS) frames <= frames + 1;
        if (!rst && sample) samples <= samples + 1;
        if (!rst) begin
            if (pxl_cen) pxl_events <= pxl_events + 1;
            if (!hs_prev && HS) hs_rises <= hs_rises + 1;
            if (hs_prev && !HS) hs_falls <= hs_falls + 1;
            if (!vs_prev && VS) vs_rises <= vs_rises + 1;
            if (vs_prev && !VS) vs_falls <= vs_falls + 1;
            if (!lvbl_prev && LVBL) lvbl_rises <= lvbl_rises + 1;
            if (lvbl_prev && !LVBL) lvbl_falls <= lvbl_falls + 1;
            hs_prev <= HS;
            vs_prev <= VS;
            lvbl_prev <= LVBL;
        end
        // Permanent integration invariant: on every accepted work-RAM cycle,
        // the address physically presented to the generated BRAM must be the
        // CPU's low 13 address bits.  This fails on the former main-ROM alias.
        if (!rst && dut.u_game.u_main.ram_cs &&
            dut.u_game.u_main.u_cpu.cen_out && dut.u_game.u_main.dtack &&
            dut.main_addr[12:0] !== dut.u_game.u_main.cpu_addr[12:0])
            $fatal(1,"Accepted work RAM address mismatch bram=%04h cpu=%04h",
                dut.main_addr[12:0],dut.u_game.u_main.cpu_addr[12:0]);
        // Diagnostic-only WRAM byte watch (see wram_trace_enabled declaration):
        // passively observes accepted CPU work-RAM cycles at wram_watch_addr
        // and emits an edge line whenever the byte value changes.  Read-only
        // tap, no bus forcing, cannot affect PASS/FAIL.
        if (wram_trace_enabled && !rst && dut.u_game.u_main.ram_cs &&
            dut.u_game.u_main.u_cpu.cen_out && dut.u_game.u_main.dtack &&
            dut.main_addr[12:0] == wram_watch_addr[12:0]) begin
            reg [7:0] wram_watch_now;
            wram_watch_now = dut.u_game.u_main.cpu_we ?
                dut.u_game.u_main.cpu_dout : dut.u_game.u_main.cpu_din;
            if (!wram_watch_valid || wram_watch_now !== wram_watch_last) begin
                $fwrite(wram_trace_fd,
                    "{\"schema\":\"mister-wram-jsonl-v1\",\"seq\":%0d,\"event\":\"wram_edge\",\"cycle\":%0d,\"frame\":%0d,\"address\":%0d,\"value\":%0d,\"write\":%0d}\n",
                    wram_trace_seq, diag_cycle_count, lvbl_falls, wram_watch_addr,
                    wram_watch_now, dut.u_game.u_main.cpu_we);
                wram_trace_seq <= wram_trace_seq + 1;
                wram_watch_last <= wram_watch_now;
                wram_watch_valid <= 1'b1;
            end
        end
        if (input_trace_enabled && !rst && dut.u_game.u_main.u_cpu.cen_out &&
            dut.u_game.u_main.dtack && !dut.u_game.u_main.cpu_we &&
            ((dut.u_game.u_main.cpu_addr >= 16'h3f80 &&
              dut.u_game.u_main.cpu_addr <= 16'h3f83) ||
             dut.u_game.u_main.cpu_addr == 16'h3f92 ||
             dut.u_game.u_main.cpu_addr == 16'h3f93)) begin
            $fwrite(input_trace_fd,
                "{\"schema\":\"mister-input-jsonl-v1\",\"seq\":%0d,\"event\":\"input_read\",\"cycle\":%0d,\"address\":%0d,\"data\":%0d,\"cab_1p\":%0d,\"coin\":%0d,\"joystick1\":%0d,\"joystick2\":%0d,\"joystick3\":%0d,\"joystick4\":%0d,\"service\":%0d}\n",
                input_trace_seq, diag_cycle_count, dut.u_game.u_main.cpu_addr,
                dut.u_game.u_main.cpu_din, cab_1p, coin, joystick1,
                joystick2, joystick3, joystick4, service);
            input_trace_seq <= input_trace_seq + 1;
            input_reads <= input_reads + 1;
        end
        // Preserve a bounded history of accepted CPU cycles and emit it once
        // at the first JTKCPU decode failure.  This is observation-only: the
        // production bus, CPU state, clocks and reset are not altered.
        if (!rst && dut.u_game.u_main.u_cpu.cen_out &&
            dut.u_game.u_main.dtack &&
            (dut.u_game.u_main.u_cpu.u_memctrl.mem_en || dut.u_game.u_main.cpu_we)) begin
            buserror_ring_pc[buserror_ring_write] = dut.u_game.u_main.u_cpu.pc;
            buserror_ring_addr[buserror_ring_write] = dut.u_game.u_main.cpu_addr;
            buserror_ring_op[buserror_ring_write] = dut.u_game.u_main.u_cpu.op;
            buserror_ring_data[buserror_ring_write] = dut.u_game.u_main.cpu_we ?
                dut.u_game.u_main.cpu_dout : dut.u_game.u_main.cpu_din;
            buserror_ring_we[buserror_ring_write] = dut.u_game.u_main.cpu_we;
            buserror_ring_fetch[buserror_ring_write] = dut.u_game.u_main.u_cpu.fetch;
            buserror_ring_is_op[buserror_ring_write] = dut.u_game.u_main.u_cpu.is_op;
            buserror_ring_write = (buserror_ring_write + 1) & 15;
            if (buserror_ring_count < 16)
                buserror_ring_count = buserror_ring_count + 1;
        end
        if (!rst && dut.u_game.u_main.u_cpu.buserror && !buserror_seen) begin
            buserror_seen = 1;
            if (buserror_trace_file != "") begin
                buserror_trace_fd = $fopen(buserror_trace_file, "w");
                if (buserror_trace_fd == 0)
                    $fatal(1, "Cannot open buserror trace %0s", buserror_trace_file);
                buserror_ring_index = (buserror_ring_write - buserror_ring_count) & 15;
                for (buserror_ring_emit = 0;
                     buserror_ring_emit < buserror_ring_count;
                     buserror_ring_emit = buserror_ring_emit + 1) begin
                    $fwrite(buserror_trace_fd,
                        "{\"schema\":\"escape-kids-buserror-v1\",\"event\":\"history\",\"ordinal\":%0d,\"pc\":%0d,\"address\":%0d,\"op\":%0d,\"data\":%0d,\"write\":%0d,\"fetch\":%0d,\"is_op\":%0d}\n",
                        buserror_ring_emit,
                        buserror_ring_pc[buserror_ring_index],
                        buserror_ring_addr[buserror_ring_index],
                        buserror_ring_op[buserror_ring_index],
                        buserror_ring_data[buserror_ring_index],
                        buserror_ring_we[buserror_ring_index],
                        buserror_ring_fetch[buserror_ring_index],
                        buserror_ring_is_op[buserror_ring_index]);
                    buserror_ring_index = (buserror_ring_index + 1) & 15;
                end
                $fwrite(buserror_trace_fd,
                    "{\"schema\":\"escape-kids-buserror-v1\",\"event\":\"fingerprint\",\"cycle\":%0d,\"pc\":%0d,\"pcbad\":%0d,\"address\":%0d,\"op\":%0d,\"data\":%0d,\"dtack\":%0d,\"irq_n\":%0d,\"firq_n\":%0d,\"fetch\":%0d,\"is_op\":%0d}\n",
                    scenario_cycle, dut.u_game.u_main.u_cpu.pc,
                    dut.u_game.u_main.u_cpu.u_ctrl.pcbad,
                    dut.u_game.u_main.cpu_addr, dut.u_game.u_main.u_cpu.op,
                    dut.u_game.u_main.cpu_din, dut.u_game.u_main.dtack,
                    dut.u_game.u_main.u_cpu.irq_n,
                    dut.u_game.u_main.u_cpu.firq_n,
                    dut.u_game.u_main.u_cpu.fetch,
                    dut.u_game.u_main.u_cpu.is_op);
                $fclose(buserror_trace_fd);
            end
            $display("CPU-BUSERROR-FINGERPRINT cycle=%0d pc=%h pcbad=%h addr=%h op=%h din=%h dtack=%b irq_n=%b firq_n=%b",
                scenario_cycle, dut.u_game.u_main.u_cpu.pc,
                dut.u_game.u_main.u_cpu.u_ctrl.pcbad,
                dut.u_game.u_main.cpu_addr, dut.u_game.u_main.u_cpu.op,
                dut.u_game.u_main.cpu_din, dut.u_game.u_main.dtack,
                dut.u_game.u_main.u_cpu.irq_n, dut.u_game.u_main.u_cpu.firq_n);
        end
        // Diagnostic-only normalized main-CPU bus stream.  This samples the
        // JTKCPU accepted-cycle enable, not a host timestamp.  It is not an
        // equivalence result because this Icarus lane does not yet expose the
        // complete sound/video stream.
        if (!trace_phase && trace_enabled && !rst && dut.u_game.u_main.u_cpu.cen_out &&
            (trace_limit == 0 || trace_seq < trace_limit) &&
            dut.u_game.u_main.dtack && !dut.u_game.u_main.cpu_we &&
            dut.u_game.u_main.u_cpu.u_memctrl.mem_en) begin
            if ((dut.u_game.u_main.cpu_we ? ^dut.u_game.u_main.cpu_dout :
                 ^dut.u_game.u_main.cpu_din) === 1'bx)
                $fwrite(trace_fd,
                    "{\"schema\":\"mister-bus-jsonl-v1\",\"seq\":%0d,\"cpu\":0,\"event\":\"bus\",\"pc\":%0d,\"rw\":\"%s\",\"address\":%0d,\"data\":0,\"lanes\":1,\"device\":%0d,\"x\":true}\n",
                    trace_seq, dut.u_game.u_main.u_cpu.pc,
                    dut.u_game.u_main.cpu_we ? "w" : "r",
                    dut.u_game.u_main.cpu_addr,
                    dut.u_game.u_main.rom_cs ? 5 :
                    dut.u_game.u_main.ram_cs ? 1 :
                    dut.u_game.u_main.pal_cs ? 4 :
                    (dut.u_game.u_main.joystk_cs || dut.u_game.u_main.eeprom_cs ||
                     dut.u_game.u_main.stsw_cs || dut.u_game.u_main.objreg_cs ||
                     dut.u_game.u_main.pcu_cs || dut.u_game.u_main.k053252_cs ||
                     dut.u_game.u_main.snd_cs || dut.u_game.u_main.snd_irq ||
                     dut.u_game.u_main.objread_cs ||
                     dut.u_game.u_main.cpu_addr == 16'h3fd0 ||
                     dut.u_game.u_main.cpu_addr == 16'h3fd2 ||
                     dut.u_game.u_main.cpu_addr == 16'h3fda) ? 3 :
                    dut.u_game.u_main.tilesys_cs ? 2 : 0);
            else
                $fwrite(trace_fd,
                    "{\"schema\":\"mister-bus-jsonl-v1\",\"seq\":%0d,\"cpu\":0,\"event\":\"bus\",\"pc\":%0d,\"rw\":\"%s\",\"address\":%0d,\"data\":%0d,\"lanes\":1,\"device\":%0d,\"x\":false}\n",
                    trace_seq, dut.u_game.u_main.u_cpu.pc,
                    dut.u_game.u_main.cpu_we ? "w" : "r",
                    dut.u_game.u_main.cpu_addr,
                    dut.u_game.u_main.cpu_we ? dut.u_game.u_main.cpu_dout : dut.u_game.u_main.cpu_din,
                    dut.u_game.u_main.rom_cs ? 5 :
                    dut.u_game.u_main.ram_cs ? 1 :
                    dut.u_game.u_main.pal_cs ? 4 :
                    (dut.u_game.u_main.joystk_cs || dut.u_game.u_main.eeprom_cs ||
                     dut.u_game.u_main.stsw_cs || dut.u_game.u_main.objreg_cs ||
                     dut.u_game.u_main.pcu_cs || dut.u_game.u_main.k053252_cs ||
                     dut.u_game.u_main.snd_cs || dut.u_game.u_main.snd_irq ||
                     dut.u_game.u_main.objread_cs ||
                     dut.u_game.u_main.cpu_addr == 16'h3fd0 ||
                     dut.u_game.u_main.cpu_addr == 16'h3fd2 ||
                     dut.u_game.u_main.cpu_addr == 16'h3fda) ? 3 :
                    dut.u_game.u_main.tilesys_cs ? 2 : 0);
            trace_seq = trace_seq + 1;
        end
`ifdef TRACE_SMOKE
        if ($time < 500000)
            $display("SMOKE t=%0t rd=%b ack=%b rdy=%b addr=%h data=%h main=%h/%h ok=%b pend=%b/%b:%h prog=%b/%b:%h", $time, ba_rd, ba_ack, ba_rdy, ba0_addr, data_read, dut.main_addr, dut.main_data, dut.main_ok, pending_valid, pending_bank, pending_addr, prog_we, prog_ba, prog_addr);
        if (dut.u_game.u_main.u_cpu.buserror)
            $display("CPU-BUSERROR t=%0t pc=%h addr=%h op=%h din=%h dtack=%b", $time, dut.u_game.u_main.u_cpu.pc, dut.u_game.u_main.u_cpu.addr, dut.u_game.u_main.u_cpu.op, dut.u_game.u_main.cpu_din, dut.u_game.u_main.u_cpu.dtack);
`endif
        // Frame capture owns the stop condition when it is enabled; the
        // ordinary barrier would terminate long before the boot self-test
        // screens are reachable.  Default-off, so no existing lane changes.
        if (!rst && !frame_capture &&
            !(snd_trace_enabled && snd_stop_frame > 0 && lvbl_falls < snd_stop_frame) &&
            ((input_scenario && input_scenario_done && input_reads >= input_min_reads &&
              frames > 2 && samples > 8 && rom_reads > 8) ||
             (!service_gate_enabled && !raster_enabled && !input_scenario && barrier_frame &&
              frames > 2 && samples > 8 && rom_reads > 8) ||
             (!service_gate_enabled && !raster_enabled && !barrier_frame &&
              loader_writes >= 6 && rom_reads >= 50 && samples >= 8)) &&
            (trace_min_events == 0 || trace_seq >= trace_min_events)) begin
            if (barrier_frame)
                $display("ESCAPE KIDS FULL SMOKE PASS loader_writes=%0d rom_reads=%0d frames=%0d samples=%0d input_reads=%0d input_edges=%0d trace_stale_drops=%0d", loader_writes, rom_reads, frames, samples, input_reads, input_edges, trace_stale_drop_count);
            else
                $display("ESCAPE KIDS CPU/SOUND SELFTEST PASS loader_writes=%0d rom_reads=%0d frames=%0d samples=%0d trace_stale_drops=%0d", loader_writes, rom_reads, frames, samples, trace_stale_drop_count);
            if (trace_enabled) begin
                $fclose(trace_fd);
                trace_enabled = 1'b0;
            end
            if (input_trace_enabled) begin
                $fclose(input_trace_fd);
                input_trace_enabled = 1'b0;
            end
            if (wram_trace_enabled) begin
                $fclose(wram_trace_fd);
                wram_trace_enabled = 1'b0;
            end
            if (dma_trace_enabled && dma_trace_fd != 0) begin
                $fclose(dma_trace_fd);
                dma_trace_fd = 0;
                dma_trace_enabled = 1'b0;
            end
            $finish;
        end
    end

    always @(posedge clk) begin
        if (trace_phase && dut.u_game.u_main.u_cpu.clken &&
            trace_enabled)
            #1 if (!dut.u_game.u_main.cpu_we)
                emit_phase_trace();
    end

    // Semantic service-gate sampling uses the CPU's accepted state-update
    // phase. Raw PC is evidence only; instruction_pc/op identify the pinned
    // program barrier and are the cross-lane alignment contract.
    always @(posedge clk) begin
        if (service_gate_enabled && !rst &&
            dut.u_game.u_main.u_cpu.clken) begin
            #1;
            if (service_gate_reads == 0 &&
                dut.u_game.u_main.dtack && !dut.u_game.u_main.cpu_we &&
                dut.u_game.u_main.cpu_addr == 16'h3f92 &&
                dut.u_game.u_main.u_cpu.op == 8'h12) begin
                service_gate_reads = service_gate_reads + 1;
                service_gate_s_pre = dut.u_game.u_main.u_cpu.s;
                service_gate_data = dut.u_game.u_main.cpu_din;
                $fwrite(service_gate_trace_fd,
                    "{\"schema\":\"escape-kids-service-gate-v1\",\"seq\":%0d,\"event\":\"gate_read\",\"instruction_pc\":33044,\"op\":18,\"raw_pc\":%0d,\"address\":16274,\"data\":%0d,\"stack_pre\":%0d,\"service_pin\":%0d,\"service_bit\":%0d}\n",
                    service_gate_seq, dut.u_game.u_main.u_cpu.pc,
                    dut.u_game.u_main.cpu_din, dut.u_game.u_main.u_cpu.s,
                    service, dut.u_game.u_main.cpu_din[2]);
                service_gate_seq = service_gate_seq + 1;
            end
        end
    end

    // jtkcpu_memctrl.is_op marks the address/data phase that will be captured
    // into the opcode register on this accepted CPU update. Sample it before
    // the nonblocking state transition; a post-edge address can already name
    // the following transaction. The bounded diagnostic rows are deliberately
    // excluded by the semantic comparator.
    always @(posedge clk) begin
        if (service_gate_enabled && !rst && service_gate_reads == 1 &&
            dut.u_game.u_main.u_cpu.clken2 && dut.u_game.u_main.dtack) begin
            if (service_gate_diag_events < 64) begin
                $fwrite(service_gate_trace_fd,
                    "{\"schema\":\"escape-kids-service-gate-v1\",\"seq\":%0d,\"event\":\"post_gate_accepted\",\"raw_pc\":%0d,\"address\":%0d,\"data\":%0d,\"current_op\":%0d,\"write\":%0d,\"is_op\":%0d,\"fetch\":%0d,\"mem_en\":%0d}\n",
                    service_gate_seq, dut.u_game.u_main.u_cpu.pc,
                    dut.u_game.u_main.cpu_addr,
                    dut.u_game.u_main.cpu_we ? dut.u_game.u_main.cpu_dout :
                                               dut.u_game.u_main.cpu_din,
                    dut.u_game.u_main.u_cpu.op, dut.u_game.u_main.cpu_we,
                    dut.u_game.u_main.u_cpu.is_op,
                    dut.u_game.u_main.u_cpu.fetch,
                    dut.u_game.u_main.u_cpu.u_memctrl.mem_en);
                service_gate_seq = service_gate_seq + 1;
                service_gate_diag_events = service_gate_diag_events + 1;
            end
            if (!dut.u_game.u_main.cpu_we &&
                dut.u_game.u_main.u_cpu.is_op &&
                (dut.u_game.u_main.cpu_addr == 16'h8281 ||
                 dut.u_game.u_main.cpu_addr == 16'h85f0)) begin
                service_gate_target_addr = dut.u_game.u_main.cpu_addr;
                service_gate_target_raw_pc = dut.u_game.u_main.u_cpu.pc;
                service_gate_target_data = dut.u_game.u_main.cpu_din;
                #1;
                service_gate_target = service_gate_target_addr;
                $fwrite(service_gate_trace_fd,
                    "{\"schema\":\"escape-kids-service-gate-v1\",\"seq\":%0d,\"event\":\"target\",\"instruction_pc\":%0d,\"raw_pc\":%0d,\"address\":%0d,\"data\":%0d,\"opcode_fetch\":true}\n",
                    service_gate_seq, service_gate_target_addr,
                    service_gate_target_raw_pc, service_gate_target_addr,
                    service_gate_target_data);
                service_gate_seq = service_gate_seq + 1;
                if (service_gate_target_data != 8'h80 ||
                    dut.u_game.u_main.u_cpu.op != 8'h80)
                    service_gate_finalize(1'b0, "target opcode was not 80");
                else if (service_gate_requested &&
                    service_gate_target_addr != 16'h85f0)
                    service_gate_finalize(1'b0, "wrong service target");
                else if (!service_gate_requested &&
                    service_gate_target_addr != 16'h8281)
                    service_gate_finalize(1'b0, "wrong ordinary target");
                else if (service_gate_requested && service_gate_stack_writes != 2)
                    service_gate_finalize(1'b0, "missing LBSR stack writes");
                else if (!service_gate_requested && service_gate_stack_writes != 0)
                    service_gate_finalize(1'b0, "ordinary path wrote stack");
                else
                    service_gate_finalize(1'b1, "first service gate matched");
            end
        end
    end

    // JTKCPU holds a write request across the falling edge after its state
    // update.  Capture that asserted phase explicitly; sampling only the
    // preceding read phase turns a real stack write into a false read.
    always @(negedge clk) begin
        if (!dut.u_game.u_main.cpu_we)
            trace_write_seen <= 1'b0;
        else if (trace_enabled && !rst && !trace_write_seen &&
            dut.u_game.u_main.dtack &&
            (trace_limit == 0 || trace_seq < trace_limit))
            begin
                emit_phase_trace();
                trace_write_seen <= 1'b1;
            end
    end


    always @(negedge clk) begin
        if (!dut.u_game.u_main.cpu_we)
            service_gate_write_seen <= 1'b0;
        else if (service_gate_enabled && service_gate_requested &&
            service_gate_data[2] == 1'b0 && !rst && !service_gate_write_seen &&
            service_gate_reads == 1 && dut.u_game.u_main.dtack &&
            (dut.u_game.u_main.cpu_addr == service_gate_s_pre - 16'd1 ||
             dut.u_game.u_main.cpu_addr == service_gate_s_pre - 16'd2)) begin
            $fwrite(service_gate_trace_fd,
                "{\"schema\":\"escape-kids-service-gate-v1\",\"seq\":%0d,\"event\":\"stack_write\",\"ordinal\":%0d,\"address\":%0d,\"data\":%0d}\n",
                service_gate_seq, service_gate_stack_writes,
                dut.u_game.u_main.cpu_addr, dut.u_game.u_main.cpu_dout);
            service_gate_seq = service_gate_seq + 1;
            service_gate_stack_writes = service_gate_stack_writes + 1;
            service_gate_write_seen <= 1'b1;
            if (service_gate_stack_writes == 1 &&
                (dut.u_game.u_main.cpu_addr != service_gate_s_pre - 16'd1 ||
                 dut.u_game.u_main.cpu_dout != 8'h20))
                service_gate_finalize(1'b0, "bad LBSR low write");
            else if (service_gate_stack_writes == 2 &&
                (dut.u_game.u_main.cpu_addr != service_gate_s_pre - 16'd2 ||
                 dut.u_game.u_main.cpu_dout != 8'h81))
                service_gate_finalize(1'b0, "bad LBSR high write");
            else if (service_gate_stack_writes > 2)
                service_gate_finalize(1'b0, "extra LBSR stack write");
        end
    end

    // Capture one semantic CCU write per held CPU transaction. The CCU itself
    // may observe the asserted bus on multiple clocks; the falling-edge latch
    // prevents those electrical hold phases from becoming duplicate events.
    always @(negedge clk) begin
        if (rst || !dut.u_game.u_main.cpu_we)
            raster_write_seen <= 1'b0;
        else if (raster_enabled && !raster_done && !raster_write_seen &&
            dut.u_game.u_main.dtack && dut.u_game.u_main.k053252_cs) begin
            raster_write_seen <= 1'b1;
            if (!raster_capture_started) begin
                if (dut.u_game.u_main.cpu_addr == 16'h3fc0 &&
                    dut.u_game.u_main.cpu_dout == 8'h01) begin
                    raster_capture_started = 1'b1;
                    raster_write_count = 1;
                    raster_shadow[0] = 8'h01;
                    $fwrite(raster_trace_fd,
                        "{\"schema\":\"escape-kids-raster-v1\",\"seq\":%0d,\"event\":\"ccu_write\",\"ordinal\":0,\"register_index\":0,\"raw_pc\":%0d,\"op\":%0d,\"address\":16320,\"data\":1}\n",
                        raster_seq, dut.u_game.u_main.u_cpu.pc,
                        dut.u_game.u_main.u_cpu.op);
                    raster_seq = raster_seq + 1;
                end
            end else if (!raster_commit_seen) begin
                if (raster_write_count > 11 ||
                    dut.u_game.u_main.cpu_addr != 16'h3fc0 + raster_expected_index(raster_write_count) ||
                    dut.u_game.u_main.cpu_dout != raster_expected_byte(raster_expected_index(raster_write_count))) begin
                    raster_finalize(1'b0, "CCU vector mismatch");
                end else begin
                    $fwrite(raster_trace_fd,
                        "{\"schema\":\"escape-kids-raster-v1\",\"seq\":%0d,\"event\":\"ccu_write\",\"ordinal\":%0d,\"register_index\":%0d,\"raw_pc\":%0d,\"op\":%0d,\"address\":%0d,\"data\":%0d}\n",
                        raster_seq, raster_write_count,
                        raster_expected_index(raster_write_count),
                        dut.u_game.u_main.u_cpu.pc,
                        dut.u_game.u_main.u_cpu.op,
                        dut.u_game.u_main.cpu_addr,
                        dut.u_game.u_main.cpu_dout);
                    raster_seq = raster_seq + 1;
                    raster_shadow[raster_expected_index(raster_write_count)] =
                        dut.u_game.u_main.cpu_dout;
                    raster_write_count = raster_write_count + 1;
                    if (raster_write_count == 12) begin
                        raster_commit_pc = 16'h80b7;
                        raster_commit_raw_pc = dut.u_game.u_main.u_cpu.pc;
                        raster_commit_op = dut.u_game.u_main.u_cpu.op;
                        raster_commit_addr = dut.u_game.u_main.cpu_addr;
                        raster_commit_data = dut.u_game.u_main.cpu_dout;
                        if ({raster_shadow[0],raster_shadow[1],raster_shadow[2],
                             raster_shadow[3],raster_shadow[4],raster_shadow[5],
                             raster_shadow[6],raster_shadow[7],raster_shadow[8],
                             raster_shadow[9],raster_shadow[10],raster_shadow[11],
                             raster_shadow[12]} != 104'h017F0012000D00010107080773)
                            raster_finalize(1'b0, "CCU shadow vector mismatch");
                        else if (raster_commit_raw_pc != 16'h80bb ||
                            raster_commit_op != 8'h3a ||
                            raster_commit_addr != 16'h3fcc ||
                            raster_commit_data != 8'h73) begin
                            raster_finalize(1'b0, "CCU commit identity mismatch");
                        end else begin
                            raster_commit_seen = 1'b1;
                            $fwrite(raster_trace_fd,
                                "{\"schema\":\"escape-kids-raster-v1\",\"seq\":%0d,\"event\":\"commit\",\"instruction_pc\":32951,\"raw_pc\":%0d,\"op\":58,\"address\":16332,\"data\":115,\"vector\":\"017F0012000D00010107080773\"}\n",
                                raster_seq, raster_commit_raw_pc);
                            raster_seq = raster_seq + 1;
                        end
                    end
                end
            end
        end
    end

    // Observe CCU outputs after their nonblocking update on an asserted pixel
    // enable. This avoids sampling the prior pixel or missing an edge on the
    // following base-clock cycle. The first boundary is included; the closing
    // boundary is excluded from the 101376-pixel interval.
    always @(posedge clk) begin
        if (rst) begin
            raster_lvbl_prev = LVBL;
            raster_hs_prev = HS;
        end else if (raster_enabled && !raster_done && pxl_cen) begin
            #1;
            if (raster_commit_seen && raster_lvbl_prev && !LVBL) begin
                if (!raster_interval_active) begin
                    raster_interval_active = 1'b1;
                    raster_interval_pixels = 1;
                    raster_height = 0;
                    raster_width = 0;
                    raster_since_hs = 0;
                    raster_have_hs = 1'b0;
                    raster_boundaries = 1;
                    if (!raster_hs_prev && HS) begin
                        raster_have_hs = 1'b1;
                        raster_height = 1;
                    end
                    $fwrite(raster_trace_fd,
                        "{\"schema\":\"escape-kids-raster-v1\",\"seq\":%0d,\"event\":\"first_post_commit_frame_boundary\",\"edge\":\"LVBL_fall\"}\n",
                        raster_seq);
                    raster_seq = raster_seq + 1;
                end else begin
                    raster_boundaries = raster_boundaries + 1;
                    $fwrite(raster_trace_fd,
                        "{\"schema\":\"escape-kids-raster-v1\",\"seq\":%0d,\"event\":\"full_frame_interval\",\"total_h\":%0d,\"total_v\":%0d,\"pixel_ticks\":%0d,\"start_inclusive\":true,\"end_exclusive\":true,\"measurement_source\":\"pxl_cen/LVBL/HS\"}\n",
                        raster_seq, raster_width, raster_height,
                        raster_interval_pixels);
                    raster_seq = raster_seq + 1;
                    if (raster_interval_pixels != 101376)
                        raster_finalize(1'b0, "raster pixel interval mismatch");
                    else if (raster_width != 384)
                        raster_finalize(1'b0, "raster line width mismatch");
                    else if (raster_height != 264)
                        raster_finalize(1'b0, "raster line count mismatch");
                    else
                        raster_finalize(1'b1, "native raster interval matched");
                end
            end else if (raster_interval_active) begin
                raster_interval_pixels = raster_interval_pixels + 1;
                if (raster_have_hs)
                    raster_since_hs = raster_since_hs + 1;
                if (!raster_hs_prev && HS) begin
                    if (raster_have_hs && raster_since_hs != 384)
                        raster_finalize(1'b0, "nonuniform raster line width");
                    raster_width = raster_since_hs;
                    raster_since_hs = 0;
                    raster_have_hs = 1'b1;
                    raster_height = raster_height + 1;
                end
            end
            raster_lvbl_prev = LVBL;
            raster_hs_prev = HS;
        end
    end

    always @(negedge clk) begin
        if (stack_debug && !rst &&
            (dut.u_game.u_main.cpu_addr == 16'h07ff ||
             dut.u_game.u_main.u_cpu.u_memctrl.addr == 16'h07ff))
            $display("STACK_DEBUG edge=negedge t=%0t cpu_addr=%04h mem_addr=%04h cpu_we=%b mem_we=%b clken=%b clken2=%b dtack=%b mem_en=%b dout=%02h din=%02h",
                $time, dut.u_game.u_main.cpu_addr,
                dut.u_game.u_main.u_cpu.u_memctrl.addr,
                dut.u_game.u_main.cpu_we,
                dut.u_game.u_main.u_cpu.u_memctrl.we,
                dut.u_game.u_main.u_cpu.clken,
                dut.u_game.u_main.u_cpu.clken2,
                dut.u_game.u_main.dtack,
                dut.u_game.u_main.u_cpu.u_memctrl.mem_en,
                dut.u_game.u_main.cpu_dout,
                dut.u_game.u_main.cpu_din);
    end

    // Sound register-stream trace (see declarations above). Every event is
    // qualified either by an accepted-cycle enable (main CPU side) or a
    // rising-edge detector (Z80 strobes), so each hardware access logs once.
    wire snd_fm_wr  = dut.u_game.u_sound.fm_cs  && !dut.u_game.u_sound.wr_n;
    wire snd_pcm_wr = dut.u_game.u_sound.pcm_cs && !dut.u_game.u_sound.wr_n;
    wire snd_pcm_rd_all = dut.u_game.u_sound.pcm_cs && !dut.u_game.u_sound.rd_n;
    wire snd_pcm_rd = snd_pcm_rd_all && dut.u_game.u_sound.A[5:1] == 5'd0;
    wire snd_main_acc = dut.u_game.u_main.u_cpu.cen_out &&
                        dut.u_game.u_main.dtack;
    always @(posedge clk) begin
        if (snd_trace_enabled && !rst) begin
            if (snd_fm_wr && !snd_fm_wr_prev) begin
                $fwrite(snd_trace_fd,
                    "{\"schema\":\"esckids-snd-v1\",\"seq\":%0d,\"e\":\"ym\",\"frame\":%0d,\"cyc\":%0d,\"a0\":%0d,\"d\":%0d}\n",
                    snd_trace_seq, lvbl_falls, diag_cycle_count,
                    dut.u_game.u_sound.A[0], dut.u_game.u_sound.cpu_dout);
                snd_trace_seq = snd_trace_seq + 1;
                snd_ym_total = snd_ym_total + 1;
            end
            if (snd_pcm_wr && !snd_pcm_wr_prev) begin
                $fwrite(snd_trace_fd,
                    "{\"schema\":\"esckids-snd-v1\",\"seq\":%0d,\"e\":\"pcm\",\"frame\":%0d,\"cyc\":%0d,\"a\":%0d,\"d\":%0d}\n",
                    snd_trace_seq, lvbl_falls, diag_cycle_count,
                    dut.u_game.u_sound.A[5:0], dut.u_game.u_sound.cpu_dout);
                snd_trace_seq = snd_trace_seq + 1;
                snd_pcm_total = snd_pcm_total + 1;
            end
            if (snd_main_acc && dut.u_game.u_main.snd_cs &&
                dut.u_game.u_main.cpu_we) begin
                $fwrite(snd_trace_fd,
                    "{\"schema\":\"esckids-snd-v1\",\"seq\":%0d,\"e\":\"m2s\",\"frame\":%0d,\"cyc\":%0d,\"a0\":%0d,\"d\":%0d}\n",
                    snd_trace_seq, lvbl_falls, diag_cycle_count,
                    dut.u_game.u_main.cpu_addr[0], dut.u_game.u_main.cpu_dout);
                snd_trace_seq = snd_trace_seq + 1;
            end
            if (snd_main_acc && dut.u_game.u_main.snd_irq) begin
                $fwrite(snd_trace_fd,
                    "{\"schema\":\"esckids-snd-v1\",\"seq\":%0d,\"e\":\"irq\",\"frame\":%0d,\"cyc\":%0d,\"rw\":\"%s\"}\n",
                    snd_trace_seq, lvbl_falls, diag_cycle_count,
                    dut.u_game.u_main.cpu_we ? "w" : "r");
                snd_trace_seq = snd_trace_seq + 1;
            end
            if (!dut.u_game.u_sound.nmi_n && snd_nmi_prev)
                snd_nmi_count = snd_nmi_count + 1;
            if (snd_pcm_rd && !snd_pcm_rd_prev)
                snd_latch_rd_count = snd_latch_rd_count + 1;
            // Log individual Z80-side K053260 reads of the low registers
            // (0-3: main->sub mailbox and sub->main echo) with the data the
            // chip returned; logged at strobe end so pcm_dout is settled.
            if (!snd_pcm_rd_all && snd_pcm_rd_all_prev &&
                snd_pcm_rd_addr <= 6'd3) begin
                $fwrite(snd_trace_fd,
                    "{\"schema\":\"esckids-snd-v1\",\"seq\":%0d,\"e\":\"pcr\",\"frame\":%0d,\"cyc\":%0d,\"a\":%0d,\"d\":%0d}\n",
                    snd_trace_seq, lvbl_falls, diag_cycle_count,
                    snd_pcm_rd_addr, dut.u_game.u_sound.pcm_dout);
                snd_trace_seq = snd_trace_seq + 1;
            end
            if (snd_pcm_rd_all) snd_pcm_rd_addr <= dut.u_game.u_sound.A[5:0];
            snd_pcm_rd_all_prev <= snd_pcm_rd_all;
            if (snd_frame_lvbl_prev && !LVBL) begin
                $fwrite(snd_trace_fd,
                    "{\"schema\":\"esckids-snd-v1\",\"seq\":%0d,\"e\":\"frame\",\"frame\":%0d,\"nmi\":%0d,\"latch_rd\":%0d,\"ym_total\":%0d,\"pcm_total\":%0d}\n",
                    snd_trace_seq, lvbl_falls, snd_nmi_count,
                    snd_latch_rd_count, snd_ym_total, snd_pcm_total);
                snd_trace_seq = snd_trace_seq + 1;
                snd_nmi_count = 0;
                snd_latch_rd_count = 0;
            end
            snd_fm_wr_prev  <= snd_fm_wr;
            snd_pcm_wr_prev <= snd_pcm_wr;
            snd_pcm_rd_prev <= snd_pcm_rd;
            snd_nmi_prev    <= dut.u_game.u_sound.nmi_n;
            snd_frame_lvbl_prev <= LVBL;
            if (snd_stop_frame > 0 && lvbl_falls >= snd_stop_frame) begin
                $fclose(snd_trace_fd);
                snd_trace_enabled = 1'b0;
                $display("ESCAPE KIDS SND TRACE DONE frames=%0d ym=%0d pcm=%0d",
                    lvbl_falls, snd_ym_total, snd_pcm_total);
                $finish;
            end
        end
    end

    initial begin
        loader_writes = 0;
        rom_reads = 0;
        frames = 0;
        samples = 0;
        pxl_events = 0;
        hs_rises = 0;
        hs_falls = 0;
        vs_rises = 0;
        vs_falls = 0;
        lvbl_rises = 0;
        lvbl_falls = 0;
        hs_prev = 1'b0;
        vs_prev = 1'b0;
        lvbl_prev = 1'b0;
        pending_valid = 1'b0;
        pending_phase = 1'b0;
        pending_bank = 2'd0;
        pending_addr = 22'd0;
        trace_file = "";
        trace_fd = 0;
        trace_seq = 0;
        trace_limit = 0;
        trace_min_events = 0;
        trace_enabled = 1'b0;
        trace_phase = 1'b0;
        stack_debug = $test$plusargs("SMOKE_STACK_DEBUG");
        trace_write_seen = 1'b0;
        trace_prev_addr = 16'd0;
        trace_prev_write = 1'b0;
        trace_stale_drop_count = 0;
        scenario_cycle = 0;
        input_trace_seq = 0;
        input_reads = 0;
        input_edges = 0;
        input_min_reads = 0;
        input_scenario = $test$plusargs("SMOKE_INPUT_SCENARIO");
        input_scenario_done = 1'b0;
        coin_scenario = $test$plusargs("SMOKE_COIN_SCENARIO");
        if (!$value$plusargs("SMOKE_COIN_FRAME=%d", coin_frame))
            coin_frame = 620;
        if (!$value$plusargs("SMOKE_COIN_HOLD_FRAMES=%d", coin_hold_frames))
            coin_hold_frames = 10;
        coin_release_frame = coin_frame + coin_hold_frames;
        input_trace_file = "";
        input_trace_fd = 0;
        input_trace_enabled = 1'b0;
        wram_trace_fd = 0;
        wram_trace_enabled = 1'b0;
        service_gate_scenario = "";
        service_gate_trace_file = "";
        service_gate_final_file = "";
        service_gate_trace_fd = 0;
        service_gate_final_fd = 0;
        service_gate_seq = 0;
        service_gate_reads = 0;
        service_gate_stack_writes = 0;
        service_gate_target = -1;
        service_gate_diag_events = 0;
        service_gate_enabled = 1'b0;
        service_gate_requested = 1'b0;
        service_gate_startup_emitted = 1'b0;
        service_gate_done = 1'b0;
        service_gate_write_seen = 1'b0;
        service_gate_s_pre = 16'd0;
        service_gate_data = 8'd0;
        service_gate_target_addr = 16'd0;
        service_gate_target_raw_pc = 16'd0;
        service_gate_target_data = 8'd0;
        raster_trace_file = "";
        raster_final_file = "";
        raster_trace_fd = 0;
        raster_final_fd = 0;
        raster_seq = 0;
        raster_write_count = 0;
        raster_interval_pixels = 0;
        raster_height = 0;
        raster_width = 0;
        raster_since_hs = 0;
        raster_boundaries = 0;
        raster_enabled = 1'b0;
        raster_capture_started = 1'b0;
        raster_commit_seen = 1'b0;
        raster_write_seen = 1'b0;
        raster_done = 1'b0;
        raster_interval_active = 1'b0;
        raster_have_hs = 1'b0;
        raster_lvbl_prev = 1'b0;
        raster_hs_prev = 1'b0;
        raster_commit_pc = 16'd0;
        raster_commit_raw_pc = 16'd0;
        raster_commit_addr = 16'd0;
        raster_commit_data = 8'd0;
        raster_commit_op = 8'd0;
        raster_shadow[0] = 8'd0; raster_shadow[1] = 8'd0;
        raster_shadow[2] = 8'd0; raster_shadow[3] = 8'd0;
        raster_shadow[4] = 8'd0; raster_shadow[5] = 8'd0;
        raster_shadow[6] = 8'd0; raster_shadow[7] = 8'd0;
        raster_shadow[8] = 8'd0; raster_shadow[9] = 8'd0;
        raster_shadow[10] = 8'd0; raster_shadow[11] = 8'd0;
        raster_shadow[12] = 8'd0;
        workram_contract = $test$plusargs("SMOKE_WORKRAM_CONTRACT");
        workram_alias_inject = $test$plusargs("SMOKE_WORKRAM_ALIAS_INJECT");
        dma_trace_file = "";
        dma_trace_fd = 0;
        dma_trace_enabled = 1'b0;
        snd_trace_file = "";
        snd_trace_fd = 0;
        snd_trace_enabled = 1'b0;
        snd_stop_frame = 0;
        snd_trace_seq = 0;
        snd_fm_wr_prev = 1'b0;
        snd_pcm_wr_prev = 1'b0;
        snd_pcm_rd_prev = 1'b0;
        snd_nmi_prev = 1'b1;
        snd_frame_lvbl_prev = 1'b0;
        snd_pcm_rd_all_prev = 1'b0;
        snd_pcm_rd_addr = 6'd0;
        snd_nmi_count = 0;
        snd_latch_rd_count = 0;
        snd_ym_total = 0;
        snd_pcm_total = 0;
        frame_capture = 1'b0;
        frame_dir = "";
        frame_path = "";
        frame_receipt_file = "";
        frame_receipt_fd = 0;
        frame_first = 0;
        frame_last = 0;
        frame_stride = 1;
        frame_stop = 0;
        frame_ord = 0;
        frame_x = 0;
        frame_y = 0;
        frame_w = 0;
        frame_h = 0;
        frame_fd = 0;
        frame_idx = 0;
        frame_nonblack = 0;
        frame_hash = 32'h811c9dc5;
        frame_lvbl_prev = 1'b0;
        frame_lhbl_prev = 1'b0;
        frame_hld = 0;
        frame_vld = 0;
        frame_vsteps = 0;
        frame_vmin = 1000; frame_vmax = 0;
        frame_hmin = 1000; frame_hmax = 0;
        frame_vprev = 9'h1ff;
        frame_hld_prev = 1'b0;
        frame_vld_prev = 1'b0;
        buserror_trace_file = "";
        buserror_trace_fd = 0;
        buserror_seen = 0;
        buserror_ring_count = 0;
        buserror_ring_write = 0;
        buserror_ring_emit = 0;
        buserror_ring_index = 0;
        auth_mode = 1'b0;
        auth_stream_file = "";
`ifndef VERILATOR
        if (workram_contract) begin
            repeat (8) @(posedge clk);
            run_workram_contract();
            $finish;
        end
`endif
        if ($value$plusargs("SMOKE_AUTH_STREAM=%s", auth_stream_file))
            auth_mode = 1'b1;
`ifdef AUTH_MEDIA
        // The physical four-bank model must start fully defined, otherwise
        // any read outside the loaded MRA stream returns X (Icarus) or an
        // --x-initial pattern (Verilator) and poisons the video path.
        for (i = 0; i < 33554432; i = i + 1) media[i] = 8'h00;
`else
        for (i = 0; i < 1048576; i = i + 1) media[i] = 8'h00;
`endif
        if (!$value$plusargs("SMOKE_MAIN=%s", media_file))
            media_file = ".mister/mame/main.hex";
        if (!$value$plusargs("SMOKE_CYCLES=%d", max_cycles))
            max_cycles = 5000;
        $display("ESCAPE KIDS SMOKE_CYCLES_PARSED max_cycles=%0d", max_cycles);
        if (!$value$plusargs("SMOKE_BARRIER=%s", smoke_barrier))
            smoke_barrier = "cpu_sound";
        if (!$value$plusargs("SMOKE_CABINET_2P=%d", smoke_cabinet_2p))
            smoke_cabinet_2p = 1'b0;
        if ($value$plusargs("SMOKE_TRACE=%s", trace_file)) begin
            trace_fd = $fopen(trace_file, "w");
            if (trace_fd == 0)
                $fatal(1, "Cannot open smoke trace %0s", trace_file);
            trace_enabled = 1'b1;
        end
        if (!$value$plusargs("SMOKE_TRACE_EVENTS=%d", trace_limit))
            trace_limit = 0;
        if (!$value$plusargs("SMOKE_TRACE_MIN=%d", trace_min_events))
            trace_min_events = 0;
        if (!$value$plusargs("SMOKE_TRACE_START_FRAME=%d", trace_start_frame))
            trace_start_frame = 0;
        if (!$value$plusargs("SMOKE_INPUT_MIN=%d", input_min_reads))
            input_min_reads = 0;
        if ($value$plusargs("SMOKE_INPUT_TRACE=%s", input_trace_file)) begin
            input_trace_fd = $fopen(input_trace_file, "w");
            if (input_trace_fd == 0)
                $fatal(1, "Cannot open smoke input trace %0s", input_trace_file);
            input_trace_enabled = 1'b1;
        end
        wram_watch_addr = 16'h0002;
        if ($value$plusargs("SMOKE_WRAM_ADDR=%d", wram_watch_addr)) ;
        if ($value$plusargs("SMOKE_WRAM_TRACE=%s", wram_trace_file)) begin
            wram_trace_fd = $fopen(wram_trace_file, "w");
            if (wram_trace_fd == 0)
                $fatal(1, "Cannot open smoke WRAM trace %0s", wram_trace_file);
            wram_trace_enabled = 1'b1;
            wram_watch_valid = 1'b0;
            wram_trace_seq = 0;
        end
        if ($value$plusargs("SMOKE_SERVICE_GATE_SCENARIO=%s", service_gate_scenario)) begin
            service_gate_enabled = 1'b1;
            if (service_gate_scenario == "ordinary")
                service_gate_requested = 1'b0;
            else if (service_gate_scenario == "service")
                service_gate_requested = 1'b1;
            else
                $fatal(1, "Bad SMOKE_SERVICE_GATE_SCENARIO=%0s", service_gate_scenario);
            if (input_scenario)
                $fatal(1, "ServiceGateScenario and legacy InputScenario are mutually exclusive");
            if (!$value$plusargs("SMOKE_SERVICE_GATE_TRACE=%s", service_gate_trace_file))
                $fatal(1, "SMOKE_SERVICE_GATE_TRACE is required");
            if (!$value$plusargs("SMOKE_SERVICE_GATE_FINAL=%s", service_gate_final_file))
                $fatal(1, "SMOKE_SERVICE_GATE_FINAL is required");
            service_gate_trace_fd = $fopen(service_gate_trace_file, "w");
            if (service_gate_trace_fd == 0)
                $fatal(1, "Cannot open service-gate trace %0s", service_gate_trace_file);
            service = service_gate_requested ? 1'b0 : 1'b1;
        end
        if ($value$plusargs("SMOKE_RASTER_TRACE=%s", raster_trace_file)) begin
            raster_enabled = 1'b1;
            if (input_scenario || service_gate_enabled)
                $fatal(1, "Raster, ServiceGateScenario and legacy InputScenario are mutually exclusive");
            if (!$value$plusargs("SMOKE_RASTER_FINAL=%s", raster_final_file))
                $fatal(1, "SMOKE_RASTER_FINAL is required with SMOKE_RASTER_TRACE");
            raster_trace_fd = $fopen(raster_trace_file, "w");
            if (raster_trace_fd == 0)
                $fatal(1, "Cannot open raster trace %0s", raster_trace_file);
            cab_1p = 4'hf;
            coin = 4'hf;
            joystick1 = 7'h7f;
            joystick2 = 7'h7f;
            joystick3 = 7'h7f;
            joystick4 = 7'h7f;
            service = 1'b1;
        end
        if ($value$plusargs("SMOKE_FRAME_DIR=%s", frame_dir)) begin
            frame_capture = 1'b1;
            if (!$value$plusargs("SMOKE_FRAME_FIRST=%d", frame_first))
                frame_first = 0;
            if (!$value$plusargs("SMOKE_FRAME_LAST=%d", frame_last))
                frame_last = 1000000;
            if (!$value$plusargs("SMOKE_FRAME_STRIDE=%d", frame_stride))
                frame_stride = 1;
            if (frame_stride < 1) frame_stride = 1;
            if (!$value$plusargs("SMOKE_FRAME_STOP=%d", frame_stop))
                frame_stop = 0;
            if ($value$plusargs("SMOKE_FRAME_RECEIPT=%s", frame_receipt_file)) begin
                frame_receipt_fd = $fopen(frame_receipt_file, "w");
                if (frame_receipt_fd == 0)
                    $fatal(1, "Cannot open frame receipt %0s", frame_receipt_file);
            end
        end
        // jtframe_debug_keys drives gfx_en=4'hf on real hardware whenever the
        // debug key path is not compiled in, so every layer is enabled.  The
        // harness historically tied it to 0, which force-blanks lyrf/lyra/
        // lyrb and the sprite layer and makes any video observation useless.
        // Existing lanes keep the historical 0 unless they ask otherwise.
        if ($value$plusargs("SMOKE_GFX_EN=%d", i))
            gfx_en = i[3:0];
        else if (frame_capture)
            gfx_en = 4'hf;
        if (!$value$plusargs("SMOKE_BUSERROR_TRACE=%s", buserror_trace_file))
            buserror_trace_file = "";
        if ($value$plusargs("SMOKE_DMA_TRACE=%s", dma_trace_file)) begin
            dma_trace_fd = $fopen(dma_trace_file, "w");
            if (dma_trace_fd == 0)
                $fatal(1, "Cannot open smoke DMA trace %0s", dma_trace_file);
            dma_trace_enabled = 1'b1;
            dma_slot_watch[0] = 8'd1;
            dma_slot_watch[1] = 8'd2;
            dma_slot_watch[2] = 8'd4;
            dma_slot_watch[3] = 8'd8;
            dma_slot_watch[4] = 8'd9;
        end
        if ($value$plusargs("SMOKE_SND_TRACE=%s", snd_trace_file)) begin
            snd_trace_fd = $fopen(snd_trace_file, "w");
            if (snd_trace_fd == 0)
                $fatal(1, "Cannot open smoke sound trace %0s", snd_trace_file);
            snd_trace_enabled = 1'b1;
        end
        if (!$value$plusargs("SMOKE_SND_STOP_FRAME=%d", snd_stop_frame))
            snd_stop_frame = 0;
        if ($test$plusargs("SMOKE_TRACE_PHASE"))
            trace_phase = 1'b1;
        if ($test$plusargs("SMOKE_HW_DEBUG"))
            status[11] = 1'b1;
        barrier_frame = smoke_barrier == "frame";
        repeat (16) @(posedge clk);
        if (auth_mode) begin
`ifdef AUTH_MEDIA
            load_authenticated_stream(auth_stream_file);
`else
            $fatal(1, "SMOKE_AUTH_STREAM requires an AUTH_MEDIA build");
`endif
        end else begin
            $readmemh(media_file, media, 0, 131071);
            // Escape Kids profile header: GX975, Asia four-player.
            send_header_byte(6'd0, 8'h03);
            send_header_byte(6'd1, smoke_cabinet_2p ? 8'h01 : 8'h00);
            send_header_byte(6'd2, 8'h00);
            send_header_byte(6'd3, 8'h00);
            // A small deterministic stream exercises the bank-zero download path
            // and leaves all unspecified alignment gaps at zero.
            send_stream_byte(26'h000004, 8'h12);
            send_stream_byte(26'h000005, 8'hc4);
            send_stream_byte(26'h000006, 8'h79);
            send_stream_byte(26'h000007, 8'h73);
            send_stream_byte(26'h080004, 8'h00);
            send_stream_byte(26'h080005, 8'h00);
        end
        repeat (20) @(posedge clk);
        rst <= 1'b0;
        rst24 <= 1'b0;
        rst48 <= 1'b0;
        rst96 <= 1'b0;
        // Not a bare `repeat (max_cycles)`: Verilator's repeat-count
        // implementation truncates a longint expression to 32 bits
        // internally, so any SMOKE_CYCLES value above 2^32 silently wraps
        // (measured: requesting 6,000,000,000 actually ran only
        // 1,705,032,704 cycles == 6e9 mod 2^32, landing the deep coin400
        // capture 487 native frames short of its target).
        //
        // A single explicit `for (cyc_i=0; cyc_i<max_cycles; ...)
        // @(posedge clk);` loop was tried and measured to change behavior:
        // it desynchronized the concurrent raster/service-gate completion
        // checkers from this main sequencer (regression ladder went from
        // full_smoke_pass/service_gate_pass/raster_pass to
        // timeout_or_failure on every "frame"-barrier lane, both sets).
        // Root cause not pinned down, so instead of an unproven equivalent
        // construct, nested `repeat` is used: each individual repeat count
        // stays under 2^31-1 (Verilator's known-safe range) by chunking, so
        // every repeat call site keeps the exact original, already-proven
        // `repeat (N) @(posedge clk);` scheduling behavior; only the
        // chunk/remainder bookkeeping is new.
        cyc_chunks    = max_cycles / SMOKE_CYCLE_CHUNK;
        cyc_remainder = max_cycles % SMOKE_CYCLE_CHUNK;
        repeat (cyc_chunks) repeat (SMOKE_CYCLE_CHUNK) @(posedge clk);
        repeat (cyc_remainder) @(posedge clk);
        if (service_gate_enabled)
            service_gate_finalize(1'b0, "timeout before target");
        if (raster_enabled)
            raster_finalize(1'b0, "timeout before complete raster interval");
        if (auth_mode) begin
            if (rom_reads < 50)
                $fatal(1, "Authenticated media smoke did not reach main ROM reads: %0d", rom_reads);
            $display("ESCAPE KIDS AUTHENTIC MEDIA PASS loader_writes=%0d rom_reads=%0d samples=%0d",
                loader_writes, rom_reads, samples);
            $finish;
        end
        $display("ESCAPE KIDS VIDEO DIAG pxl_events=%0d HS=%b/%b VS=%b/%b LVBL=%b/%b transitions hs=%0d/%0d vs=%0d/%0d lvbl=%0d/%0d", pxl_events, HS, hs_prev, VS, vs_prev, LVBL, lvbl_prev, hs_rises, hs_falls, vs_rises, vs_falls, lvbl_rises, lvbl_falls);
        $fatal(1, "Escape Kids full smoke timeout loader_writes=%0d rom_reads=%0d frames=%0d samples=%0d", loader_writes, rom_reads, frames, samples);
    end
endmodule
