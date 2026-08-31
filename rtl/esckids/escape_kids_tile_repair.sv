`timescale 1ns/1ps
// Escape Kids: download-time repair of the tile ROM (SDRAM bank 2).
//
// The defect being corrected
// -------------------------
// The 8x1 strips on the blue background are bytes that are wrong IN the SDRAM
// array once the download has finished: they are stable for a whole boot and
// only change across boots, which a marginal read could not do. Hardware
// measurement over 6 boots (104 corrupted pixels) shows every bad bit forced
// 0->1 and confined to DQ[7:0] of a 16-bit beat - a byte lane that kept its
// power-up 0xFF because its write beat did not store. The bytes handed to the
// controller are provably correct (download checksums match golden), and
// reads are provably correct (bank-0 readback: 128 KiB byte-exact, twice).
//
// Why this sits on the bank-2 port and not on the prog port
// --------------------------------------------------------
// The obvious place to verify a write is the prog port, and that is wrong
// here - measured, not assumed. jtframe_mister_dwnld paces the whole HPS byte
// stream on prog_rdy, so a read-back issued on the prog port raises prog_rdy a
// second time per word and the loader advances two bytes for every one
// written. The loader bench reproduces it exactly (tb_dwnld_credit
// +EXTRA_RDY=1: 32349 of 65536 bytes never reach memory, versus 0 missing
// without the extra pulse), and simply slowing the port instead costs nothing
// (ACK_LAT 1..24, zero loss). So verification must never touch prog.
//
// This engine therefore snoops the prog stream read-only, and does its work
// through the bank-2 read/write port, which the game cannot be using: the core
// is held in reset for the whole download, so u_bank2 is idle and its port is
// free. Requires JTFRAME_BA2_WEN so bank 2 accepts writes.
//
// Coverage is best-effort by construction: if the queue is full when a write
// is snooped, that word is skipped and counted rather than stalling the
// loader. Skipping is safe (it only leaves a word unverified), stalling is
// not (it perturbs the pacing this design exists to avoid).
module escape_kids_tile_repair #(
    parameter AW = 22           // bank word-address width
)(
    input                clk,
    input                rst,
    input                dwnld,          // download in progress: port is ours

    // read-only snoop of the accepted prog stream
    input                prog_we,
    input                prog_ack,
    input      [AW-1:0]  prog_addr,
    input      [15:0]    prog_data,
    input      [ 1:0]    prog_mask,      // active low
    input      [ 1:0]    prog_ba,

    // bank-2 port (muxed in by the wrapper while dwnld is high)
    output reg [AW-1:0]  ba2_addr,
    output reg           ba2_rd,
    output reg           ba2_wr,
    output reg [15:0]    ba2_din,
    output reg [ 1:0]    ba2_dsn,        // active low
    input                ba2_ack,
    input                ba2_dst,
    input                ba2_rdy,
    input      [15:0]    data_read,

    output               busy,           // owns the bank-2 port

    // evidence, all saturating
    output reg [15:0]    repaired,       // words rewritten after a mismatch
    output reg [15:0]    skipped,        // words not checked (queue full)
    output reg [ 7:0]    unfixed         // still wrong after MAX_RETRY
);

// ---------------------------------------------------------------- queue
// 32 entries covers the read latency at the download's write cadence; the
// depth only affects coverage, never correctness.
localparam QAW = 5, QDEPTH = 1<<QAW;

reg [AW-1:0] q_addr[0:QDEPTH-1];
reg [15:0]   q_data[0:QDEPTH-1];
reg [ 1:0]   q_mask[0:QDEPTH-1];
reg [QAW:0]  wptr, rptr;

wire [QAW:0] occup   = wptr - rptr;
wire         q_full  = occup[QAW];
wire         q_empty = wptr == rptr;

// A prog write is accepted on the ack cycle; only bank 2 is of interest.
wire snoop = prog_we && prog_ack && prog_ba==2'd2;

// ---------------------------------------------------------------- checker
localparam [2:0] IDLE = 3'd0, RD = 3'd1, RDW = 3'd2, WR = 3'd3, WRW = 3'd4;
localparam [1:0] MAX_RETRY = 2'd2;

reg [ 2:0] st;
reg [AW-1:0] c_addr;
reg [15:0] c_data;
reg [ 1:0] c_mask, retry;
reg [11:0] wdog;
reg        got, rd_bad;

wire wdog_hit = &wdog;
// Compare only the lanes this word actually wrote.
wire mism = (!c_mask[0] && data_read[ 7:0] != c_data[ 7:0]) ||
            (!c_mask[1] && data_read[15:8] != c_data[15:8]);

assign busy = st != IDLE;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        wptr <= 0; rptr <= 0;
        st   <= IDLE;
        ba2_addr <= 0; ba2_rd <= 0; ba2_wr <= 0; ba2_din <= 0; ba2_dsn <= 2'b11;
        c_addr <= 0; c_data <= 0; c_mask <= 2'b11;
        retry <= 0; wdog <= 0; got <= 0; rd_bad <= 0;
        repaired <= 0; skipped <= 0; unfixed <= 0;
    end else begin
        // ---- snoop side
        if( snoop ) begin
            if( q_full ) begin
                if( !(&skipped) ) skipped <= skipped + 16'd1;
            end else begin
                q_addr[wptr[QAW-1:0]] <= prog_addr;
                q_data[wptr[QAW-1:0]] <= prog_data;
                q_mask[wptr[QAW-1:0]] <= prog_mask;
                wptr <= wptr + 1'd1;
            end
        end

        // ---- checker side
        wdog <= st==IDLE ? 12'd0 : wdog + 12'd1;
        case( st )
            IDLE: begin
                ba2_rd <= 0; ba2_wr <= 0;
                if( !q_empty && dwnld ) begin
                    c_addr <= q_addr[rptr[QAW-1:0]];
                    c_data <= q_data[rptr[QAW-1:0]];
                    c_mask <= q_mask[rptr[QAW-1:0]];
                    rptr   <= rptr + 1'd1;
                    retry  <= 0;
                    st     <= RD;
                end
            end
            RD: begin
                ba2_addr <= c_addr;
                ba2_rd   <= 1;
                got      <= 0;
                rd_bad   <= 0;
                if( ba2_rd && ba2_ack ) begin
                    ba2_rd <= 0;
                    st     <= RDW;
                end else if( wdog_hit ) begin
                    ba2_rd <= 0;
                    st     <= IDLE;
                end
            end
            RDW: begin
                if( ba2_dst && !got ) begin
                    got    <= 1;
                    rd_bad <= mism;
                end
                // BA2_LEN is 64 here: ba2_dst is first beat, ba2_rdy
                // is final beat. Keep the shared bank owner through tail.
                if( ba2_rdy && (got || (ba2_dst && !got)) ) begin
                    if( !(got ? rd_bad : mism) ) begin
                        st <= IDLE;              // stored correctly
                    end else if( retry != MAX_RETRY ) begin
                        retry <= retry + 2'd1;
                        st    <= WR;
                    end else begin
                        if( !(&unfixed) ) unfixed <= unfixed + 8'd1;
                        st <= IDLE;
                    end
                end else if( wdog_hit ) st <= IDLE;
            end
            WR: begin
                ba2_addr <= c_addr;
                ba2_din  <= c_data;
                ba2_dsn  <= c_mask;
                ba2_wr   <= 1;
                if( ba2_wr && ba2_ack ) begin
                    ba2_wr <= 0;
                    if( !(&repaired) && retry==2'd1 ) repaired <= repaired + 16'd1;
                    st <= WRW;
                end else if( wdog_hit ) begin
                    ba2_wr <= 0;
                    st     <= IDLE;
                end
            end
            default: begin // WRW - let the write retire, then re-read
                if( ba2_rdy )       st <= RD;
                else if( wdog_hit ) st <= IDLE;
            end
        endcase
    end
end

endmodule
