`include "rtl/esckids/jtframe_macros.vh"

// Headless authenticated download-contract bench.  It deliberately stops at
// jtframe_dwnld and a physical four-bank byte model: game execution remains
// covered by the separate smoke bench, while this lane can consume the entire
// validated MRA stream without paying for the CPU/video hierarchy on every
// loader byte.
module tb_escape_kids_loader;
    localparam integer STREAM_END = 26'h6e0000;
    localparam integer BA1 = 26'h080000;
    localparam integer BA2 = 26'h1e0000;
    localparam integer BA3 = 26'h2e0000;
    localparam integer PROM = 26'h6e0000;

    reg clk = 1'b0;
    reg [25:0] ioctl_addr = 0;
    reg [7:0] ioctl_dout = 0;
    reg ioctl_wr = 0, ioctl_rom = 0;
    wire [22:1] prog_addr;
    wire [15:0] prog_data;
    wire [1:0] prog_mask;
    wire prog_we, prog_rd;
    wire [1:0] prog_ba;
    wire prom_we, header;
    wire sdram_ack = prog_we;

    // Exact byte extents of the four logical banks through PROM_START.  The
    // arrays are physical bytes; loader word addresses are shifted by one.
    reg [7:0] bank0 [0:BA1-1];
    reg [7:0] bank1 [0:BA2-BA1-1];
    reg [7:0] bank2 [0:BA3-BA2-1];
    reg [7:0] bank3 [0:PROM-BA3-1];
    integer writes = 0;
    integer fd;
    integer n;
    integer c;
    integer stream_file;
    reg [1023:0] stream_path;
    reg [7:0] hdr0, hdr1, hdr2, hdr3;
    reg [7:0] sample_main, sample_sound, sample_pcm;
    reg [7:0] sample_tiles, sample_sprites, sample_gap;

    jtframe_dwnld #(
        .SDRAMW(23),
        .HEADER(26'd4),
        .BA1_START(BA1),
        .BA2_START(BA2),
        .BA3_START(BA3),
        .PROM_START(PROM),
        .SWAB(26'd1)
    ) dut (
        .clk(clk),
        .ioctl_rom(ioctl_rom),
        .ioctl_addr({1'b0,ioctl_addr}),
        .ioctl_dout(ioctl_dout),
        .ioctl_wr(ioctl_wr),
        .gfx4_en(1'b0), .gfx8_en(1'b0), .gfx16_en(1'b0),
        .gfx16b_en(1'b0), .gfx16c_en(1'b0),
        .prog_addr(prog_addr),
        .prog_data(prog_data),
        .prog_mask(prog_mask),
        .prog_we(prog_we),
        .prog_rd(prog_rd),
        .prog_ba(prog_ba),
        .prom_we(prom_we),
        .header(header),
        .sdram_ack(sdram_ack)
    );

    always #1 clk = ~clk;

    function integer physical_index;
        input [1:0] bank;
        input [22:1] word;
        begin
            physical_index = {word,1'b0};
        end
    endfunction

    task drive_byte;
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

    task write_physical;
        integer idx;
        begin
            idx = physical_index(prog_ba, prog_addr);
            case (prog_ba)
                2'd0: begin
                    if (idx + 1 >= BA1) $fatal(1, "bank0 address overrun %0h", idx);
                    if (!prog_mask[0]) bank0[idx] <= prog_data[7:0];
                    if (!prog_mask[1]) bank0[idx + 1] <= prog_data[15:8];
                end
                2'd1: begin
                    if (idx + 1 >= BA2-BA1) $fatal(1, "bank1 address overrun %0h", idx);
                    if (!prog_mask[0]) bank1[idx] <= prog_data[7:0];
                    if (!prog_mask[1]) bank1[idx + 1] <= prog_data[15:8];
                end
                2'd2: begin
                    if (idx + 1 >= BA3-BA2) $fatal(1, "bank2 address overrun %0h", idx);
                    if (!prog_mask[0]) bank2[idx] <= prog_data[7:0];
                    if (!prog_mask[1]) bank2[idx + 1] <= prog_data[15:8];
                end
                2'd3: begin
                    if (idx + 1 >= PROM-BA3) $fatal(1, "bank3 address overrun %0h", idx);
                    if (!prog_mask[0]) bank3[idx] <= prog_data[7:0];
                    if (!prog_mask[1]) bank3[idx + 1] <= prog_data[15:8];
                end
            endcase
            writes = writes + 1;
        end
    endtask

    always @(posedge clk)
        if (prog_we) write_physical();

    task check_loaded_sample;
        input [1:0] bank;
        input [22:1] word;
        input [7:0] value;
        integer idx;
        reg [7:0] got;
        begin
            idx = physical_index(bank, word);
            case (bank)
                2'd0: got = bank0[idx];
                2'd1: got = bank1[idx];
                2'd2: got = bank2[idx];
                default: got = bank3[idx];
            endcase
            if (got !== value)
                $fatal(1, "physical sample bank=%0d word=%0h got=%02h exp=%02h", bank, word, got, value);
        end
    endtask

    initial begin
        if (!$value$plusargs("SMOKE_AUTH_STREAM=%s", stream_path))
            $fatal(1, "SMOKE_AUTH_STREAM is required");
        if (!$value$plusargs("SMOKE_CABINET_2P=%d", c)) c = 0;
        stream_file = $fopen(stream_path, "rb");
        if (stream_file == 0) $fatal(1, "Cannot open %0s", stream_path);
        hdr0 = $fgetc(stream_file); hdr1 = $fgetc(stream_file);
        hdr2 = $fgetc(stream_file); hdr3 = $fgetc(stream_file);
        if (hdr0 !== 8'h03 || hdr2 !== 0 || hdr3 !== 0 || hdr1 !== (c ? 8'h01 : 8'h00))
            $fatal(1, "profile header mismatch %02h%02h%02h%02h", hdr0,hdr1,hdr2,hdr3);
        drive_byte(0, hdr0); drive_byte(1, hdr1); drive_byte(2, hdr2); drive_byte(3, hdr3);
        for (n = 0; n < STREAM_END; n = n + 1) begin
            c = $fgetc(stream_file);
            if (c < 0) $fatal(1, "stream ended at %0h", n);
            case (n)
                26'h000000: sample_main = c[7:0];
                26'h080000: sample_sound = c[7:0];
                26'h0a0000: sample_pcm = c[7:0];
                26'h1e0000: sample_tiles = c[7:0];
                26'h2e0000: sample_sprites = c[7:0];
                26'h020000: sample_gap = c[7:0];
                default:;
            endcase
            drive_byte(n + 26'd4, c[7:0]);
        end
        if ($fgetc(stream_file) >= 0) $fatal(1, "stream has trailing data");
        $fclose(stream_file);
        // The last ioctl byte is sampled into jtframe_dwnld on a clock edge
        // and the corresponding SDRAM write is visible one edge later.  Do
        // not let a same-time wait observe the pre-NBA value and count one
        // byte too early.
        repeat (4) @(posedge clk);
        wait (!prog_we && !ioctl_rom);
        if (writes != STREAM_END) $fatal(1, "writes=%0d expected=%0d", writes, STREAM_END);
        check_loaded_sample(2'd0, 22'h000000, sample_main);
        check_loaded_sample(2'd1, 22'h000000, sample_sound);
        check_loaded_sample(2'd1, 22'h010000, sample_pcm);
        check_loaded_sample(2'd2, 22'h000000, sample_tiles);
        check_loaded_sample(2'd3, 22'h000000, sample_sprites);
        if (sample_gap !== 0) $fatal(1, "gap sample at 0x020000 is %02h", sample_gap);
        $display("ESCAPE KIDS AUTHENTIC LOADER PASS writes=%0d", writes);
        $finish;
    end
endmodule
