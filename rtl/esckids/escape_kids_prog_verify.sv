`timescale 1ns/1ps
// Escape Kids: read-back verification of every SDRAM download write.
//
// Why: the 8x1 background strips are bytes that are wrong IN the SDRAM array
// after the download - stable within a boot, random across boots, always a
// byte lane forced to 0xFF (power-up cell content), while the data handed to
// the controller is proven correct by the download checksums and reads are
// proven reliable by the bank-0 scanner (128 KiB byte-perfect, twice).
// Whatever the physical trigger is (the MiSTer module shares DQM with
// A[12:11], so a masked write beat stores nothing for that byte), the robust
// correction is to close the loop: after each word is written, read it back
// through the same controller and rewrite it until it matches.
//
// Sits between jtframe_dwnld and the controller's prog port:
//   downloader -> [this module] -> prog port
// The downloader holds its request until acknowledged, so withholding dl_ack
// during verification back-pressures it naturally; its FIFO absorbs the HPS
// stream in the meantime. Every state carries a watchdog: a handshake that
// never completes releases the word instead of hanging the boot (a frozen
// boot is worse than an unverified word).
module escape_kids_prog_verify #(
    parameter AW = 22   // prog word-address width (SDRAMW-1)
)(
    input             clk,
    input             rst,
    // downloader side (request held until dl_ack)
    input             dl_we,
    input  [AW-1:0]   dl_addr,
    input  [15:0]     dl_data,
    input  [ 1:0]     dl_mask,   // active low
    input  [ 1:0]     dl_ba,
    output            dl_ack,
    // controller prog port
    output            pv_we,
    output reg        pv_rd,
    output [AW-1:0]   pv_addr,
    output [15:0]     pv_data,
    output [ 1:0]     pv_mask,
    output [ 1:0]     pv_ba,
    input             prog_ack,
    input             prog_rdy,
    input             prog_dst,
    input  [15:0]     data_read,
    // evidence counters (saturating)
    output reg [ 7:0] fix_cnt,   // words that needed at least one rewrite
    output reg [ 7:0] fail_cnt   // words given up on (retries or watchdog)
);

// The simulation lane's SDRAM is a functional model that cannot reproduce a
// masked write beat, so verification there only costs cycles - and it costs
// ~6x the download time, which outruns the smoke harness's budget (that
// harness releases the CPU before the transfer ends, unlike the real core,
// which holds it in reset). Verify on hardware, pass through in sim.
// DISABLED pending a redesign, and the reason is measured, not guessed:
// jtframe_mister_dwnld paces the HPS byte stream on prog_rdy. A read-back on
// the prog port raises prog_rdy a second time per word, so the loader
// advances two bytes for every one actually written. The loader bench
// (.mister/tb/tb_dwnld_credit.sv, +EXTRA_RDY=1) reproduces it exactly:
// 32349 of 65536 bytes never reach memory, against 0 missing without the
// extra pulse - and slowing the port instead (ACK_LAT 1..24) loses nothing.
// The correct form verifies bank 2 through a game-side bank slot (and
// rewrites through a writable bank port, JTFRAME_BA2_WEN), so the prog port
// and the loader's pacing are never touched.
`define ESCKIDS_NO_PROG_VERIFY

localparam [2:0] PASS   = 3'd0,  // forward downloader writes
                 WRWAIT = 3'd1,  // wait for write completion
                 RDREQ  = 3'd2,  // issue the read-back
                 RDWAIT = 3'd3,  // wait for read data
                 REWR   = 3'd4,  // re-issue the write
                 FIN    = 3'd5;  // acknowledge the downloader

localparam [1:0] MAX_RETRY = 2'd3;

reg [ 2:0] st;
reg [AW-1:0] l_addr;
reg [15:0] l_data, rbuf;
reg [ 1:0] l_mask, l_ba, retry;
reg [11:0] wdog;             // 4095 clk48 ~ 85us, far past any refresh burst
reg        fixed, got_dst, dl_ack_i;
`ifdef SIMULATION
integer    dbg_words = 0;
`endif

wire wdog_hit = &wdog;
`ifdef ESCKIDS_NO_PROG_VERIFY
assign dl_ack = prog_ack;
`else
assign dl_ack = dl_ack_i;
`endif
// Compare the data beat as it arrives: dst and rdy are separate pulses and
// may not overlap, so waiting for both is what stalls the transfer.
wire mism = (!l_mask[0] && data_read[ 7:0] != l_data[ 7:0]) ||
            (!l_mask[1] && data_read[15:8] != l_data[15:8]);

// In PASS the downloader's request goes straight through; outside PASS the
// controller sees only this module's own transactions.
assign pv_we   = st==PASS ? dl_we : st==REWR;
assign pv_addr = st==PASS ? dl_addr : l_addr;
assign pv_data = st==PASS ? dl_data : l_data;
assign pv_mask = st==PASS ? dl_mask : l_mask;
assign pv_ba   = st==PASS ? dl_ba   : l_ba;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st      <= PASS;
        dl_ack_i<= 0;
        pv_rd   <= 0;
        retry   <= 0;
        wdog    <= 0;
        fixed   <= 0;
        got_dst <= 0;
        fix_cnt <= 0;
        fail_cnt<= 0;
        l_addr  <= 0; l_data <= 0; l_mask <= 2'b11; l_ba <= 0; rbuf <= 0;
    end else begin
        dl_ack_i <= 0;
        wdog   <= st==PASS ? 12'd0 : wdog + 12'd1;
        case( st )
            PASS: begin
                pv_rd <= 0;
`ifdef ESCKIDS_NO_PROG_VERIFY
                if( dl_we && prog_ack ) begin
                    dl_ack_i <= 1;
                end
`else
                if( dl_we && prog_ack ) begin
                    { l_addr, l_data, l_mask, l_ba } <=
                        { dl_addr, dl_data, dl_mask, dl_ba };
                    retry <= 0;
                    fixed <= 0;
                    // writes can complete on the acknowledge cycle itself
                    st <= prog_rdy ? RDREQ : WRWAIT;
                end
`endif
            end
            WRWAIT: begin
                if( prog_rdy )      st <= RDREQ;
                else if( wdog_hit ) begin
                    if( !(&fail_cnt) ) fail_cnt <= fail_cnt + 8'd1;
                    st <= FIN;
                end
            end
            RDREQ: begin
                pv_rd   <= 1;
                got_dst <= 0;
                if( pv_rd && prog_ack ) begin
                    pv_rd <= 0;
                    st    <= RDWAIT;
                end else if( wdog_hit ) begin
                    pv_rd <= 0;
                    if( !(&fail_cnt) ) fail_cnt <= fail_cnt + 8'd1;
                    st <= FIN;
                end
            end
            RDWAIT: begin
                // PROG_LEN=32 returns two beats, the addressed word first;
                // only that beat is compared.
                if( prog_dst && !got_dst ) begin
                    rbuf    <= data_read;
                    got_dst <= 1;
                    if( !mism ) begin
                        if( fixed && !(&fix_cnt) ) fix_cnt <= fix_cnt + 8'd1;
                        st <= FIN;
                    end else if( retry != MAX_RETRY ) begin
                        retry <= retry + 2'd1;
                        fixed <= 1;
                        st    <= REWR;
                    end else begin
                        if( !(&fail_cnt) ) fail_cnt <= fail_cnt + 8'd1;
                        st <= FIN;
                    end
                end else if( wdog_hit ) begin
                    if( !(&fail_cnt) ) fail_cnt <= fail_cnt + 8'd1;
                    st <= FIN;
                end
            end
            REWR: begin
                if( prog_ack )      st <= prog_rdy ? RDREQ : WRWAIT;
                else if( wdog_hit ) begin
                    if( !(&fail_cnt) ) fail_cnt <= fail_cnt + 8'd1;
                    st <= FIN;
                end
            end
            default: begin // FIN
                dl_ack_i <= 1;
                st     <= PASS;
`ifdef SIMULATION
                if( dbg_words < 8 )
                    $display("PVRFY word=%0d addr=%h ba=%0d data=%h retry=%0d fixed=%0d fail=%0d",
                             dbg_words, l_addr, l_ba, l_data, retry, fixed, fail_cnt);
                dbg_words <= dbg_words + 1;
`endif
            end
        endcase
    end
end

endmodule
