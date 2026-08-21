/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 23-7-2023 */

module jtsimson_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

/* verilator tracing_off */
wire [ 7:0] snd2main, video_dump, fm_dout;
wire        cpu_cen, snd_irq, rmrd, rst8, init;
wire        pal_we, pal_bank, fm_irqn,
            cpu_we, tilesys_cs, objsys_cs, pcu_cs, objcha_n;
wire        cpu_rnw, cpu_irqn, cpu_firqn, cpu_nmin, dma_bsy, snd_wrn, mono, objreg_cs, main_fmcs;
wire        video_bank, k053252_cs;
wire [ 7:0] k053252_dout;
wire [ 7:0] tilesys_dout, objsys_dout,
            obj_dout, pal_dout, cpu_dout,
            st_main, st_video, st_snd;
wire        tilesys_rom_dtack;
// TEMPORARY diagnostic taps from jtsimson_main - see its port list
wire        dbg_berr_l, dbg_dtack, dbg_eep_rdy;
wire [15:0] dbg_pcbad;
wire [ 7:0] dbg_aupper;
wire [15:0] cpu_addr;
wire [12:0] ram_addr;
wire [18:0] main_rom_addr;
wire [15:0] video_dumpa;
wire [20:0] pcm_raw_addr_a, pcm_raw_addr_b, pcm_raw_addr_c, pcm_raw_addr_d;
wire [20:0] pcm_start_a, pcm_start_b, pcm_start_c, pcm_start_d;
wire [20:0] pcm_schedule_a, pcm_schedule_b, pcm_schedule_c, pcm_schedule_d;
wire [20:0] pcm_fill_addr_a, pcm_fill_addr_b,
            pcm_fill_addr_c, pcm_fill_addr_d;
wire [ 7:0] pcm_prefetch_data_a, pcm_prefetch_data_b,
            pcm_prefetch_data_c, pcm_prefetch_data_d;
wire [ 3:0] pcm_prefetch_ok, pcm_prefetch_warm,
            pcm_prefetch_underrun, pcm_sample, pcm_bsy, pcm_reverse;
wire        pcm_raw_cs_a, pcm_raw_cs_b, pcm_raw_cs_c, pcm_raw_cs_d;
wire [ 3:0] pcm_fill_cs;
wire [ 6:0] input_joystick1, input_joystick2,
            input_joystick3, input_joystick4;
reg  [ 3:0] pcm_bsy_d;
reg  [ 7:0] debug_mux;
reg         simson, paroda, vendetta, suratk, esckids, cabinet_2p;

`ifdef SIMULATION
// JTFRAME normally delivers the profile header before the game is released
// from reset.  Give the diagnostic harness the same donor-default state during
// the short pre-header interval so ROM requests cannot propagate X values.
initial begin
    simson     = 1'b1;
    paroda     = 1'b0;
    vendetta   = 1'b0;
    suratk     = 1'b0;
    esckids    = 1'b0;
    cabinet_2p = 1'b0;
end
`endif

// ===========================================================================
// TEMPORARY paged hardware bring-up diagnostic (Escape Kids boot black-screen)
// ---------------------------------------------------------------------------
// ROOT CAUSE FOUND (see .mister/iteration-log.jsonl
// hw-overlay-pass3-root-cause-cpu-halted-on-latched-buserror): the main KCPU
// is permanently halted by a latched bus error (jtsimson_main.v:413 `berr_l`,
// wired straight into jtkcpu's .halt). berr_l is set by `buserror`, a
// microcode-raised illegal-opcode trap, and never clears. CPU was captured
// frozen at cpu_addr=0x8058, 0x1F bytes past its own reset vector (0x8039),
// with main_cs/main_ok both healthy (memory path fine, CPU just isn't
// advancing) and every video chip select still at "never touched" - hence
// perfect video timing with an all-black picture.
//
// Open question this pass answers: does hardware return different ROM data
// than the file at the trap address (a memory-path/SDRAM bug), or does the
// CPU reach a real illegal opcode in the actual ROM (a jtkcpu ucode gap)?
// Pages 7-A capture the exact PC latched at the trap (pcbad) and B-C the
// live ROM byte the frozen CPU is reading (main_data) - compare that byte
// against the ROM file at the pcbad/cpu_addr location to settle it.
//
// Exports 15 pages of 4 bits through the existing JTFRAME debug_view overlay
// row. Displayed byte = {page[3:0], payload[3:0]}, so the overlay's hex
// readout is literally "PX" - P = page, X = nibble - directly readable from
// a screenshot. Pages advance every ~0.70 s (2^25 clk48); a ~10.5 s capture
// sweeps all 15; no keyboard needed. Pages run 1..F, never 0: the overlay
// hides the row on an all-zero byte, and page 0 with a zero payload is
// exactly the "CPU completely dead" case that must stay visible.
//
//   page 1 : main_cs_act | main_ok_act | main_cs_stuck | cpu_addr_changing
//            main_cs_act=1 with main_ok_act=0 -> CPU wedged waiting on ROM.
//            main_cs_stuck=1 -> chip select held high a whole period, no data.
//            cpu_addr_changing=0 -> CPU is not advancing at all (established).
//   page 2 : berr_l | dtack (live) | eep_rdy (live) | const 1 (readout marker)
//            berr_l=1 confirms the halt mechanism directly.
//   page 3 : cpu_addr[15:12]   page 4 : cpu_addr[11:8]
//   page 5 : cpu_addr[7:4]     page 6 : cpu_addr[3:0]
//   page 7 : pcbad[15:12]      page 8 : pcbad[11:8]
//   page 9 : pcbad[7:4]        page A : pcbad[3:0]
//            PC latched at the trap - pin the exact offending instruction.
//   page B : main_data[7:4]    page C : main_data[3:0]
//            live ROM byte the frozen CPU is reading right now.
//   page D : aupper[7:4]       page E : aupper[3:0]
//            jtkcpu's own bank/page register - confirms it is not the reason
//            the CPU landed in the wrong region.
//   page F : rgb_nz | lvbl_act | lhbl_act | pxl_cen_act      (video sanity)
//
// Restore to `assign debug_view = debug_mux;` before a release build, and
// remove the dbg_* port group from jtsimson_main.v (search "dbg_" there).
localparam DBG_PGW = 25;                 // ~0.70 s per page at 48 MHz

reg  [DBG_PGW-1:0] dbg_pgcnt = 0;
reg  [ 3:0] dbg_page  = 1;              // 1..F, never 0 (see note above)
reg  [ 3:0] dbg_payload;
reg  [15:0] dbg_cpu_addr_l = 0;

// per-period activity accumulators
reg dbg_a_maincs=0, dbg_a_maincs_lo=0, dbg_a_mainok=0, dbg_a_addrchg=0;
reg dbg_a_rgbnz=0,  dbg_a_vblhi=0, dbg_a_vbllo=0, dbg_a_hblhi=0, dbg_a_hbllo=0;
reg dbg_a_pxlcen=0;
// latched-for-display versions
reg dbg_l_maincs=0, dbg_l_mainok=0, dbg_l_stuck=0, dbg_l_addrchg=0;
reg dbg_l_rgbnz=0,  dbg_l_vbl=0,    dbg_l_hbl=0,   dbg_l_pxlcen=0;

wire dbg_pgend    = &dbg_pgcnt;
wire dbg_active_px= LVBL & LHBL & pxl_cen & (|{red,green,blue});

always @(posedge clk48) begin
    dbg_cpu_addr_l <= cpu_addr;
    dbg_pgcnt      <= dbg_pgcnt + { {DBG_PGW-1{1'b0}}, 1'b1 };

    if(  main_cs   ) dbg_a_maincs    <= 1'b1;
    if( !main_cs   ) dbg_a_maincs_lo <= 1'b1;
    if(  main_ok   ) dbg_a_mainok    <= 1'b1;
    if( cpu_addr!=dbg_cpu_addr_l ) dbg_a_addrchg <= 1'b1;
    if( dbg_active_px ) dbg_a_rgbnz  <= 1'b1;
    if(  LVBL ) dbg_a_vblhi <= 1'b1;
    if( !LVBL ) dbg_a_vbllo <= 1'b1;
    if(  LHBL ) dbg_a_hblhi <= 1'b1;
    if( !LHBL ) dbg_a_hbllo <= 1'b1;
    if( pxl_cen ) dbg_a_pxlcen <= 1'b1;

    if( dbg_pgend ) begin
        dbg_page      <= dbg_page==4'hf ? 4'h1 : dbg_page + 4'd1;
        // main_cs held high for a whole period with no data returned
        dbg_l_stuck   <= dbg_a_maincs & ~dbg_a_maincs_lo & ~dbg_a_mainok;
        dbg_l_maincs  <= dbg_a_maincs;   dbg_l_mainok <= dbg_a_mainok;
        dbg_l_addrchg <= dbg_a_addrchg;  dbg_l_rgbnz  <= dbg_a_rgbnz;
        dbg_l_vbl     <= dbg_a_vblhi & dbg_a_vbllo;
        dbg_l_hbl     <= dbg_a_hblhi & dbg_a_hbllo;
        dbg_l_pxlcen  <= dbg_a_pxlcen;

        {dbg_a_maincs,dbg_a_maincs_lo,dbg_a_mainok,dbg_a_addrchg} <= 4'd0;
        {dbg_a_rgbnz,dbg_a_vblhi,dbg_a_vbllo,dbg_a_hblhi}         <= 4'd0;
        {dbg_a_hbllo,dbg_a_pxlcen}                                <= 2'd0;
    end
end

always @(*) begin
    case( dbg_page )
        4'h1: dbg_payload = { dbg_l_maincs, dbg_l_mainok,   dbg_l_stuck,  dbg_l_addrchg };
        4'h2: dbg_payload = { dbg_berr_l,   dbg_dtack,      dbg_eep_rdy,  1'b1          };
        4'h3: dbg_payload = cpu_addr[15:12];
        4'h4: dbg_payload = cpu_addr[11: 8];
        4'h5: dbg_payload = cpu_addr[ 7: 4];
        4'h6: dbg_payload = cpu_addr[ 3: 0];
        4'h7: dbg_payload = dbg_pcbad[15:12];
        4'h8: dbg_payload = dbg_pcbad[11: 8];
        4'h9: dbg_payload = dbg_pcbad[ 7: 4];
        4'ha: dbg_payload = dbg_pcbad[ 3: 0];
        4'hb: dbg_payload = main_data[ 7: 4];
        4'hc: dbg_payload = main_data[ 3: 0];
        4'hd: dbg_payload = dbg_aupper[ 7: 4];
        4'he: dbg_payload = dbg_aupper[ 3: 0];
        4'hf: dbg_payload = { dbg_l_rgbnz,  dbg_l_vbl,      dbg_l_hbl,    dbg_l_pxlcen  };
        default: dbg_payload = 4'd0;
    endcase
end

assign debug_view = { dbg_page, dbg_payload };
assign ram_din    = cpu_dout;
assign ioctl_din  = video_dump;
assign video_dumpa= ioctl_addr[15:0]-16'h80;
// The generated memory wrapper shares main_addr between the program-ROM
// request slot and work BRAM.  Present the ROM address only for an active ROM
// request; all other CPU cycles expose the physical 13-bit work-RAM address.
// This preserves the ROM request path while preventing stack accesses from
// aliasing to the last program fetch address.
assign main_addr  = main_cs ? main_rom_addr : { 6'd0, ram_addr };
assign pcma_addr  = esckids ? pcm_fill_addr_a : pcm_raw_addr_a;
assign pcmb_addr  = esckids ? pcm_fill_addr_b : pcm_raw_addr_b;
assign pcmc_addr  = esckids ? pcm_fill_addr_c : pcm_raw_addr_c;
assign pcmd_addr  = esckids ? pcm_fill_addr_d : pcm_raw_addr_d;
assign pcma_cs    = esckids ? pcm_fill_cs[0] : pcm_raw_cs_a;
assign pcmb_cs    = esckids ? pcm_fill_cs[1] : pcm_raw_cs_b;
assign pcmc_cs    = esckids ? pcm_fill_cs[2] : pcm_raw_cs_c;
assign pcmd_cs    = esckids ? pcm_fill_cs[3] : pcm_raw_cs_d;
assign pcm_schedule_a = pcm_bsy_d[0] ? pcm_raw_addr_a : pcm_start_a;
assign pcm_schedule_b = pcm_bsy_d[1] ? pcm_raw_addr_b : pcm_start_b;
assign pcm_schedule_c = pcm_bsy_d[2] ? pcm_raw_addr_c : pcm_start_c;
assign pcm_schedule_d = pcm_bsy_d[3] ? pcm_raw_addr_d : pcm_start_d;

// Escape Kids maps the three OSD action buttons to Run, Super Jump and
// Auto Run.  Keep the convenience behavior in a project-owned wrapper so
// all other JTCORES profiles retain their donor input path unchanged.
escape_kids_auto_run u_auto_run(
    .clk          ( clk48          ),
    .rst          ( rst48          ),
    .enable       ( esckids         ),
    .lvbl         ( LVBL            ),
    .joystick1    ( joystick1       ),
    .joystick2    ( joystick2       ),
    .joystick3    ( joystick3       ),
    .joystick4    ( joystick4       ),
    .joystick1_out( input_joystick1 ),
    .joystick2_out( input_joystick2 ),
    .joystick3_out( input_joystick3 ),
    .joystick4_out( input_joystick4 )
);

`ifdef SIMULATION
always @(posedge clk48) begin
    if( !rst48 && !main_cs && main_addr[12:0] !== ram_addr )
        $error("Work RAM address bridge mismatch ram=%04h main=%04h",ram_addr,main_addr[12:0]);
    // Check each channel's own schedule/start relationship against its own
    // keyon edge only. The four PCM channels are independent (separate MMR
    // start-address registers per K053260 channel; schematic p8/p20 show no
    // shared bsy/address gating across channels). A channel that is already
    // mid-playback naturally has schedule==raw_addr while its own start
    // register can independently hold a different (already-advanced, or
    // already-reprogrammed-for-next-sound) address; that mismatch is normal
    // and must not be blamed on a different channel's unrelated keyon edge.
    // Regression coverage before this fix only ever key-on'd all four
    // channels in the same cycle (single 0x0F write to reg 0x28), so the
    // any-channel-OR/check-all-channels form never saw a staggered keyon
    // while a sibling channel was already playing; real gameplay audio
    // (background loop + independent one-shot SFX) does exactly that.
    if( !rst48 && esckids ) begin
        if( pcm_bsy[0] && !pcm_bsy_d[0] && pcm_schedule_a !== pcm_start_a )
            $error("PCM keyon schedule left programmed start before address phase settled (ch A)");
        if( pcm_bsy[1] && !pcm_bsy_d[1] && pcm_schedule_b !== pcm_start_b )
            $error("PCM keyon schedule left programmed start before address phase settled (ch B)");
        if( pcm_bsy[2] && !pcm_bsy_d[2] && pcm_schedule_c !== pcm_start_c )
            $error("PCM keyon schedule left programmed start before address phase settled (ch C)");
        if( pcm_bsy[3] && !pcm_bsy_d[3] && pcm_schedule_d !== pcm_start_d )
            $error("PCM keyon schedule left programmed start before address phase settled (ch D)");
    end
end
`endif

escape_kids_pcm_prefetch u_pcm_prefetch(
    .clk        ( clk48                 ),
    .rst        ( rst48                 ),
    .enable     ( esckids               ),
    .ch0_addr   ( pcm_raw_addr_a        ),
    .ch1_addr   ( pcm_raw_addr_b        ),
    .ch2_addr   ( pcm_raw_addr_c        ),
    .ch3_addr   ( pcm_raw_addr_d        ),
    .ch0_schedule ( pcm_schedule_a         ),
    .ch1_schedule ( pcm_schedule_b         ),
    .ch2_schedule ( pcm_schedule_c         ),
    .ch3_schedule ( pcm_schedule_d         ),
    .ch0_pin     ( pcm_start_a           ),
    .ch1_pin     ( pcm_start_b           ),
    .ch2_pin     ( pcm_start_c           ),
    .ch3_pin     ( pcm_start_d           ),
    .ch_cs      ( {pcm_raw_cs_d,pcm_raw_cs_c,
                   pcm_raw_cs_b,pcm_raw_cs_a} ),
    .ch_sample  ( pcm_sample             ),
    .ch_bsy     ( pcm_bsy                ),
    .ch_reverse ( pcm_reverse            ),
    .ch0_data   ( pcm_prefetch_data_a   ),
    .ch1_data   ( pcm_prefetch_data_b   ),
    .ch2_data   ( pcm_prefetch_data_c   ),
    .ch3_data   ( pcm_prefetch_data_d   ),
    .ch_ok      ( pcm_prefetch_ok       ),
    .warm       ( pcm_prefetch_warm     ),
    .mem0_addr  ( pcm_fill_addr_a       ),
    .mem1_addr  ( pcm_fill_addr_b       ),
    .mem2_addr  ( pcm_fill_addr_c       ),
    .mem3_addr  ( pcm_fill_addr_d       ),
    .mem_cs     ( pcm_fill_cs           ),
    .mem0_data  ( pcma_data             ),
    .mem1_data  ( pcmb_data             ),
    .mem2_data  ( pcmc_data             ),
    .mem3_data  ( pcmd_data             ),
    .mem_ok     ( {pcmd_ok,pcmc_ok,pcmb_ok,pcma_ok} ),
    .underrun   ( pcm_prefetch_underrun )
);

always @(posedge clk48) begin
    if( rst48 ) pcm_bsy_d <= 4'd0;
    else        pcm_bsy_d <= pcm_bsy;
end

always @(posedge clk) begin
    if( header && prog_we ) begin
        if( prog_addr[1:0]==0 ) begin
            simson   <= prog_data[2:0]==0;
            paroda   <= prog_data[2:0]==1;
            vendetta <= prog_data[2:0]==2;
            esckids  <= prog_data==8'h03;
            suratk   <= prog_data[2:0]==4;
        end
        if( prog_addr[1:0]==1 )
            cabinet_2p <= esckids && prog_data[0];
`ifdef SIMULATION
        if( prog_addr[1:0]==0 && prog_data!=8'h03 &&
                prog_data[2:0]!=0 && prog_data[2:0]!=1 &&
                prog_data[2:0]!=2 && prog_data[2:0]!=4 )
            $error("Unsupported JTFRAME profile header byte %02X",prog_data);
        if( esckids && prog_addr[1:0]==1 && prog_data[7:1]!=0 )
            $error("Escape Kids header reserved bits are non-zero: %02X",prog_data);
        if( esckids && prog_addr[1:0]>1 && prog_data!=0 )
            $error("Escape Kids reserved header byte %0d is non-zero: %02X",prog_addr[1:0],prog_data);
`endif
    end
    case( debug_bus[7:6] )
        0: debug_mux <= st_main;
        1: debug_mux <= st_video;
        2: debug_mux <= st_snd;
        3: debug_mux <= {init,rmrd, 6'd0 };
    endcase
end

/* verilator tracing_off */
jtsimson_main u_main(
    .rst            ( rst48         ),
    .clk            ( clk48         ),
    .cen_ref        ( cen24         ), // should it be cen12?
    .cpu_cen        ( cpu_cen       ),

    .simson         ( simson        ),
    .paroda         ( paroda        ),
    .vendetta       ( vendetta      ),
    .esckids        ( esckids       ),
    .cabinet_2p     ( cabinet_2p    ),
    .suratk         ( suratk        ),
    // YM2151 (only suratk)
    .fm_cs          ( main_fmcs     ),
    .fm_dout        ( fm_dout       ),
    .fm_irqn        ( fm_irqn       ),

    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_we         ( cpu_we        ),

    .rom_addr       ( main_rom_addr ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_addr       ( ram_addr      ),
    .ram_we         ( ram_we        ),
    .ram_dout       ( ram_dout      ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( input_joystick1 ),
    .joystick2      ( input_joystick2 ),
    .joystick3      ( input_joystick3 ),
    .joystick4      ( input_joystick4 ),
    .service        ( service       ),

    // From video
    .rst8           ( rst8          ),
    .LVBL           ( LVBL          ),
    .irq_n          ( cpu_irqn      ),
    .dma_bsy        ( dma_bsy       ),

    .tilesys_dout   ( tilesys_dout  ),
    .tilesys_rom_dtack ( tilesys_rom_dtack ),
    .objsys_dout    ( objsys_dout   ),
    .pal_dout       ( pal_dout      ),
    // To video
    .objsys_cs      ( objsys_cs     ),
    .objreg_cs      ( objreg_cs     ),
    .tilesys_cs     ( tilesys_cs    ),
    .pcu_cs         ( pcu_cs        ),
    .init           ( init          ),
    .rmrd           ( rmrd          ),
    .pal_bank       ( pal_bank      ),
    .pal_we         ( pal_we        ),
    .objcha_n       ( objcha_n      ),
    .video_bank     ( video_bank    ),
    .k053252_cs     ( k053252_cs    ),
    .k053252_dout   ( k053252_dout  ),
    // To sound
    .snd_irq        ( snd_irq       ),
    .snd2main       ( snd2main      ),
    .snd_wrn        ( snd_wrn       ),
    .mono           ( mono          ),
    // EEPROM
    .nv_addr        ( nvram_addr    ),
    .nv_dout        ( nvram_dout    ),
    .nv_din         ( nvram_din     ),
    .nv_we          ( nvram_we      ),
    // DIP switches
    .dip_test       ( dip_test      ),
    .dip_pause      ( dip_pause     ),
    .dipsw          ( dipsw[23:0]   ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_main       ),
    // TEMPORARY diagnostic taps - see jtsimson_main.v port list
    .dbg_berr_l     ( dbg_berr_l    ),
    .dbg_dtack      ( dbg_dtack     ),
    .dbg_eep_rdy    ( dbg_eep_rdy   ),
    .dbg_pcbad      ( dbg_pcbad     ),
    .dbg_aupper     ( dbg_aupper    )
);

/* verilator tracing_off */
jtsimson_sound u_sound(
    .rst        ( rst48         ),
    .clk        ( clk48         ),
    .cen_fm     ( cen_fm        ),
    .cen_fm2    ( cen_fm2       ),

    .simson     ( simson        ),
    .suratk     ( suratk        ),
    // communication with main CPU
    .snd_irq    ( snd_irq       ),
    .main_dout  ( cpu_dout      ),
    .main_din   ( snd2main      ),
    .main_addr  ( cpu_addr[0]   ),
    .main_rnw   ( snd_wrn       ),
    .mono       ( mono          ),
    // YM2151 (only suratk)
    .main_fmcs  ( main_fmcs     ),
    .fm_dout    ( fm_dout       ),
    .fm_irqn    ( fm_irqn       ),
    // ROM
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),
    // ADPCM ROM
    .pcma_addr  ( pcm_raw_addr_a ),
    .pcma_dout  ( esckids ? pcm_prefetch_data_a : pcma_data ),
    .pcma_cs    ( pcm_raw_cs_a   ),
    .pcma_ok    ( esckids ? pcm_prefetch_ok[0] : pcma_ok ),

    .pcmb_addr  ( pcm_raw_addr_b ),
    .pcmb_dout  ( esckids ? pcm_prefetch_data_b : pcmb_data ),
    .pcmb_cs    ( pcm_raw_cs_b   ),
    .pcmb_ok    ( esckids ? pcm_prefetch_ok[1] : pcmb_ok ),

    .pcmc_addr  ( pcm_raw_addr_c ),
    .pcmc_dout  ( esckids ? pcm_prefetch_data_c : pcmc_data ),
    .pcmc_cs    ( pcm_raw_cs_c   ),
    .pcmc_ok    ( esckids ? pcm_prefetch_ok[2] : pcmc_ok ),

    .pcmd_addr  ( pcm_raw_addr_d ),
    .pcmd_dout  ( esckids ? pcm_prefetch_data_d : pcmd_data ),
    .pcmd_cs    ( pcm_raw_cs_d   ),
    .pcmd_ok    ( esckids ? pcm_prefetch_ok[3] : pcmd_ok ),
    .pcm_sample ( pcm_sample    ),
    .pcm_bsy    ( pcm_bsy       ),
    .pcm_reverse( pcm_reverse   ),
    .pcma_start ( pcm_start_a   ),
    .pcmb_start ( pcm_start_b   ),
    .pcmc_start ( pcm_start_c   ),
    .pcmd_start ( pcm_start_d   ),
    // Sound output
    .snd_l      ( snd_l         ),
    .snd_r      ( snd_r         ),
    // Debug
    .snd_en     ( snd_en        ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_snd        )
);

/* verilator tracing_on */
jtsimson_video #(
    .GX975      ( 1 ),
    .EXT_TIMING ( 1 )
) u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),

    .simson         ( simson        ),
    .paroda         ( paroda        ),
    .esckids        ( esckids       ),
    .suratk         ( suratk        ),
    .video_bank     ( video_bank    ),
    .k053252_cs     ( k053252_cs    ),
    .k053252_dout   ( k053252_dout  ),

    // base video
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),

    // GFX - CPU interface
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_we         ( cpu_we        ),

    .pal_dout       ( pal_dout      ),
    .tilesys_dout   ( tilesys_dout  ),
    .tilesys_rom_dtack ( tilesys_rom_dtack ),
    .objsys_dout    ( objsys_dout   ),

    .pal_bank       ( pal_bank      ),
    .pal_we         ( pal_we        ),
    .pcu_cs         ( pcu_cs        ),
    .tilesys_cs     ( tilesys_cs    ),
    .objsys_cs      ( objsys_cs     ),
    .objreg_cs      ( objreg_cs     ),

    // control
    .rmrd           ( rmrd          ),
    .objcha_n       ( objcha_n      ),
    .cpu_irqn       ( cpu_irqn      ),
    .cpu_firqn      ( cpu_firqn     ),
    .cpu_nmin       ( cpu_nmin      ),
    .dma_bsy        ( dma_bsy       ),

    // SDRAM
    .lyra_addr      ( lyra_addr     ),
    .lyrb_addr      ( lyrb_addr     ),
    .lyrf_addr      ( lyrf_addr     ),
    .lyro_addr      ( lyro_addr     ),
    .lyra_data      ( lyra_data     ),
    .lyrb_data      ( lyrb_data     ),
    .lyro_data      ( lyro_data     ),
    .lyrf_data      ( lyrf_data     ),
    .lyrf_cs        ( lyrf_cs       ),
    .lyra_cs        ( lyra_cs       ),
    .lyrb_cs        ( lyrb_cs       ),
    .lyro_cs        ( lyro_cs       ),
    .lyra_ok        ( lyra_ok       ),
    .lyro_ok        ( lyro_ok       ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .ioctl_addr     ( video_dumpa   ),
    .ioctl_din      ( video_dump    ),
    .ioctl_ram      ( ioctl_ram     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

endmodule
