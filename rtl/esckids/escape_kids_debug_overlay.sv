`timescale 1ns/1ps

module escape_kids_debug_overlay(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [ 3:0] slot,
    input  wire        pxl_cen,
    input  wire        lhbl,
    input  wire        lvbl,
    input  wire [ 7:0] core_red,
    input  wire [ 7:0] core_green,
    input  wire [ 7:0] core_blue,
    input  wire [15:0] live_pc,
    input  wire [15:0] pcbad,
    input  wire [15:0] live_addr,
    input  wire [ 7:0] last_op,
    input  wire [ 7:0] cpu_din,
    input  wire [ 7:0] rom_data,
    input  wire [ 7:0] aupper,
    input  wire [15:0] trap_pc,
    input  wire [15:0] trap_addr,
    input  wire [ 7:0] trap_op,
    input  wire [ 7:0] trap_data,
    input  wire [ 7:0] trap_flags,
    input  wire [15:0] hist_pc,
    input  wire [15:0] hist_addr,
    input  wire [ 7:0] hist_op,
    input  wire [ 7:0] hist_data,
    input  wire [ 7:0] hist_flags,
    input  wire [ 3:0] hist_wr,
    input  wire [ 7:0] cpu_reg_byte,
    input  wire [15:0] accept_count,
    input  wire        trap_seen,
    input  wire        berr_l,
    input  wire        buserror,
    input  wire        dtack,
    input  wire        eep_rdy,
    input  wire        main_cs,
    input  wire        main_ok,
    input  wire        main_cpu_ok,
    input  wire        cpu_cen,
    input  wire [18:0] main_rom_addr,
    input  wire [12:0] ram_addr,
    input  wire        cpu_we,
    input  wire        ram_we,
    input  wire        tilesys_cs,
    input  wire        objsys_cs,
    input  wire        objreg_cs,
    input  wire        pcu_cs,
    input  wire        k053252_cs,
    input  wire        rmrd,
    input  wire        dma_bsy,
    input  wire [ 7:0] video_now,
    input  wire [ 7:0] video_ever,
    input  wire [15:0] palette_writes,
    input  wire [ 7:0] sound_now,
    input  wire [ 7:0] sound_ever,
    input  wire [15:0] sound_events,
    input  wire [15:0] audio_nonzero,
    input  wire        snd_irq,
    input  wire        snd_ok,
    input  wire        snd_cs,
    input  wire [ 3:0] pcm_bsy,
    input  wire [ 3:0] pcm_sample,
    input  wire [ 3:0] pcm_warm,
    input  wire [ 3:0] pcm_underrun,
    input  wire [ 3:0] pcm_fill_cs,
    input  wire [ 3:0] pcm_reverse,
    input  wire [15:0] snd_l,
    input  wire [15:0] snd_r,
    input  wire [20:0] pcm_addr_a,
    input  wire [20:0] pcm_addr_b,
    input  wire [20:0] pcm_addr_c,
    input  wire [20:0] pcm_addr_d,
    input  wire [20:0] pcm_fill_addr_a,
    input  wire [20:0] pcm_fill_addr_b,
    input  wire [20:0] pcm_fill_addr_c,
    input  wire [20:0] pcm_fill_addr_d,
    input  wire        lyrf_cs,
    input  wire        lyra_cs,
    input  wire        lyrb_cs,
    input  wire        lyro_cs,
    input  wire        lyra_ok,
    input  wire        lyro_ok,
    input  wire        objcha_n,
    input  wire        esckids,
    input  wire        cabinet_2p,
    input  wire        init,
    input  wire        rst8,
    input  wire        rst24,
    input  wire        rst48,
    input  wire        rst96,
    input  wire        irq_n,
    input  wire        firq_n,
    input  wire        nmi_n,
    output reg  [ 3:0] hist_index,
    output reg  [ 3:0] reg_index,
    output reg  [ 7:0] red,
    output reg  [ 7:0] green,
    output reg  [ 7:0] blue
);

localparam [383:0] T0  = "ESCAPE KIDS HW DEBUG D5  SLOT:0                 ";
localparam [383:0] T1  = "TRAP:0 BERR:0 BUS:0 CEN:0 DT:0 EEP:0            ";
localparam [383:0] T2  = "PC:0000 BAD:0000 ADDR:0000 OP:00 DIN:00         ";
localparam [383:0] T3  = "TPC:0000 TA:0000 TOP:00 TD:00 TF:00 HWR:0       ";
localparam [383:0] T4  = "ROM:00 BANK:00 CS:0 OK:0 FOK:0 ACC:0000         ";
localparam [383:0] T5  = "A:00 B:00 CC:00 DP:00 X:0000 Y:0000             ";
localparam [383:0] T6  = "U:0000 S:0000 IRQ/F/N:000 RST24/48/96:000       ";
localparam [383:0] T7  = "VIDN:00 VIDE:00 PAL:0000 DMA:0 RM:0 LV/LH:00    ";
localparam [383:0] T8  = "RGB:00/00/00 PXL:0 T/O/R/P/C:00000              ";
localparam [383:0] T9  = "SNDN:00 SNDE:00 EVT:0000 NZ:0000 IRQ/OK/CS:000  ";
localparam [383:0] T10 = "PCM B:0 W:0 U:0 S:0 OUT:0000/0000 PROF:00       ";
localparam [383:0] T11 = "H PC   ADDR OP DT FL | H PC   ADDR OP DT FL     ";
localparam [383:0] T20 = "MAIN A:00000 RAM:0000 WE:0 RWE:0 ROM:00         ";
localparam [383:0] T21 = "PCM BSY:0 SMP:0 WRM:0 UND:0 FILL:0 REV:0        ";
localparam [383:0] T22 = "PCMA:000000 B:000000 C:000000 D:000000          ";
localparam [383:0] T23 = "FILLA:000000 B:000000 C:000000 D:000000         ";
localparam [383:0] T24 = "GFX CS F/A/B/O:0000 OK A/O:00 OBJCHA:0          ";
localparam [383:0] T25 = "PROFILE ESCKIDS:0 CAB2P:0 INIT:0 RST8:0         ";
localparam [383:0] T26 = "PRETRAP ACCEPTED BUS HISTORY; LATEST=HWR-1      ";
localparam [383:0] T27 = "FAULT DATA FROZEN; ACTIVITY COUNTERS ARE LIVE   ";

reg lhbl_d;
reg [5:0] char_col;
reg [2:0] char_x;
reg [4:0] char_row_r;
reg [3:0] glyph_y_r;
wire line_start = lhbl & ~lhbl_d;
wire [4:0] char_row = char_row_r;
wire [2:0] glyph_y = glyph_y_r[2:0];
wire [7:0] char_code;
wire [4:0] glyph_bits;
function automatic glyph_pixel;
    input [4:0] bits;
    input [2:0] x;
    begin
        case(x)
            3'd0: glyph_pixel = bits[4];
            3'd1: glyph_pixel = bits[3];
            3'd2: glyph_pixel = bits[2];
            3'd3: glyph_pixel = bits[1];
            3'd4: glyph_pixel = bits[0];
            default: glyph_pixel = 1'b0;
        endcase
    end
endfunction

wire glyph_on = char_row < 5'd28 && glyph_y_r < 4'd7 &&
                glyph_pixel(glyph_bits, char_x);

always @(posedge clk) begin
    if (rst) begin
        lhbl_d  <= 1'b0;
        char_col<= 6'd0;
        char_x  <= 3'd0;
        char_row_r <= 5'd0;
        glyph_y_r  <= 4'hf;
    end else begin
        lhbl_d <= lhbl;
        if (!lvbl) begin
            char_row_r <= 5'd0;
            glyph_y_r  <= 4'hf;
        end else if (line_start) begin
            if (glyph_y_r == 4'hf) begin
                char_row_r <= 5'd0;
                glyph_y_r  <= 4'd0;
            end else if (glyph_y_r == 4'd7) begin
                char_row_r <= char_row_r + 5'd1;
                glyph_y_r  <= 4'd0;
            end else begin
                glyph_y_r <= glyph_y_r + 4'd1;
            end
        end

        if (!lhbl || line_start) begin
            char_col <= 6'd0;
            char_x   <= 3'd0;
        end else if (pxl_cen) begin
            if (char_x == 3'd7) begin
                char_x   <= 3'd0;
                char_col <= char_col + 6'd1;
            end else begin
                char_x <= char_x + 3'd1;
            end
        end
    end
end

always @(*) begin
    hist_index = slot;
    if (char_row >= 5'd12 && char_row <= 5'd19) begin
        if (char_col < 6'd22)
            hist_index = char_row[3:0] - 4'd12;
        else
            hist_index = char_row[3:0] - 4'd4;
    end

    reg_index = slot;
    if (char_row == 5'd5) begin
        if (char_col >= 6'd2  && char_col <= 6'd3)  reg_index = 4'h0;
        if (char_col >= 6'd7  && char_col <= 6'd8)  reg_index = 4'h1;
        if (char_col >= 6'd13 && char_col <= 6'd14) reg_index = 4'h2;
        if (char_col >= 6'd19 && char_col <= 6'd20) reg_index = 4'h3;
        if (char_col >= 6'd24 && char_col <= 6'd25) reg_index = 4'h4;
        if (char_col >= 6'd26 && char_col <= 6'd27) reg_index = 4'h5;
        if (char_col >= 6'd31 && char_col <= 6'd32) reg_index = 4'h6;
        if (char_col >= 6'd33 && char_col <= 6'd34) reg_index = 4'h7;
    end
    if (char_row == 5'd6) begin
        if (char_col >= 6'd2 && char_col <= 6'd3) reg_index = 4'h8;
        if (char_col >= 6'd4 && char_col <= 6'd5) reg_index = 4'h9;
        if (char_col >= 6'd9 && char_col <= 6'd10) reg_index = 4'ha;
        if (char_col >= 6'd11 && char_col <= 6'd12) reg_index = 4'hb;
    end
end

function automatic [7:0] hexchar;
    input [3:0] value;
    begin
        hexchar = value < 10 ? 8'h30 + {4'd0,value} :
                               8'h41 + {4'd0,value} - 8'd10;
    end
endfunction

function automatic [7:0] bitchar;
    input value;
    begin
        bitchar = value ? "1" : "0";
    end
endfunction

function automatic [7:0] template_char;
    input [4:0] row;
    input [5:0] col;
    reg [383:0] text;
    begin
        case (row)
            5'd0: text=T0;   5'd1: text=T1;   5'd2: text=T2;
            5'd3: text=T3;   5'd4: text=T4;   5'd5: text=T5;
            5'd6: text=T6;   5'd7: text=T7;   5'd8: text=T8;
            5'd9: text=T9;   5'd10:text=T10;  5'd11:text=T11;
            5'd20:text=T20;  5'd21:text=T21;  5'd22:text=T22;
            5'd23:text=T23;  5'd24:text=T24;  5'd25:text=T25;
            5'd26:text=T26;  5'd27:text=T27;
            default:text={48{8'h20}};
        endcase
        template_char = col < 48 ? text[383-col*8 -: 8] : 8'h20;
    end
endfunction

function automatic [7:0] text_char;
    input [4:0] row;
    input [5:0] col;
    reg [7:0] ch;
    begin
        ch = template_char(row,col);
        case (row)
            5'd0: if (col==30) ch=hexchar(slot);
            5'd1: begin
                if(col==5) ch=bitchar(trap_seen); if(col==12) ch=bitchar(berr_l);
                if(col==18) ch=bitchar(buserror); if(col==24) ch=bitchar(cpu_cen);
                if(col==29) ch=bitchar(dtack); if(col==35) ch=bitchar(eep_rdy);
            end
            5'd2: begin
                if(col>=3&&col<=6) ch=hexchar(live_pc[(6-col)*4 +: 4]);
                if(col>=12&&col<=15) ch=hexchar(pcbad[(15-col)*4 +: 4]);
                if(col>=22&&col<=25) ch=hexchar(live_addr[(25-col)*4 +: 4]);
                if(col>=30&&col<=31) ch=hexchar(last_op[(31-col)*4 +: 4]);
                if(col>=37&&col<=38) ch=hexchar(cpu_din[(38-col)*4 +: 4]);
            end
            5'd3: begin
                if(col>=4&&col<=7) ch=hexchar(trap_pc[(7-col)*4 +: 4]);
                if(col>=12&&col<=15) ch=hexchar(trap_addr[(15-col)*4 +: 4]);
                if(col>=21&&col<=22) ch=hexchar(trap_op[(22-col)*4 +: 4]);
                if(col>=27&&col<=28) ch=hexchar(trap_data[(28-col)*4 +: 4]);
                if(col>=33&&col<=34) ch=hexchar(trap_flags[(34-col)*4 +: 4]);
                if(col==40) ch=hexchar(hist_wr);
            end
            5'd4: begin
                if(col>=4&&col<=5) ch=hexchar(rom_data[(5-col)*4 +: 4]);
                if(col>=12&&col<=13) ch=hexchar(aupper[(13-col)*4 +: 4]);
                if(col==18) ch=bitchar(main_cs); if(col==23) ch=bitchar(main_ok);
                if(col==29) ch=bitchar(main_cpu_ok);
                if(col>=35&&col<=38) ch=hexchar(accept_count[(38-col)*4 +: 4]);
            end
            5'd5,5'd6: begin
                if ((row==5'd5 && ((col>=2&&col<=3)||(col>=7&&col<=8)||
                    (col>=13&&col<=14)||(col>=19&&col<=20)||(col>=24&&col<=27)||
                    (col>=31&&col<=34))) ||
                    (row==5'd6 && ((col>=2&&col<=5)||(col>=9&&col<=12))))
                    if (col==2 || col==7 || col==13 || col==19 || col==24 ||
                        col==26 || col==31 || col==33 || col==9 || col==11)
                        ch=hexchar(cpu_reg_byte[7:4]);
                    else
                        ch=hexchar(cpu_reg_byte[3:0]);
                if(row==5'd6 && col==22) ch=bitchar(irq_n);
                if(row==5'd6 && col==23) ch=bitchar(firq_n);
                if(row==5'd6 && col==24) ch=bitchar(nmi_n);
                if(row==5'd6 && col==38) ch=bitchar(rst24);
                if(row==5'd6 && col==39) ch=bitchar(rst48);
                if(row==5'd6 && col==40) ch=bitchar(rst96);
            end
            5'd7: begin
                if(col>=5&&col<=6) ch=hexchar(video_now[(6-col)*4 +: 4]);
                if(col>=13&&col<=14) ch=hexchar(video_ever[(14-col)*4 +: 4]);
                if(col>=20&&col<=23) ch=hexchar(palette_writes[(23-col)*4 +: 4]);
                if(col==29) ch=bitchar(dma_bsy); if(col==34) ch=bitchar(rmrd);
                if(col==42) ch=bitchar(lvbl); if(col==43) ch=bitchar(lhbl);
            end
            5'd8: begin
                if(col>=4&&col<=5) ch=hexchar(core_red[(5-col)*4 +: 4]);
                if(col>=7&&col<=8) ch=hexchar(core_green[(8-col)*4 +: 4]);
                if(col>=10&&col<=11) ch=hexchar(core_blue[(11-col)*4 +: 4]);
                if(col==17) ch=bitchar(pxl_cen); if(col==29) ch=bitchar(tilesys_cs);
                if(col==30) ch=bitchar(objsys_cs); if(col==31) ch=bitchar(objreg_cs);
                if(col==32) ch=bitchar(pcu_cs); if(col==33) ch=bitchar(k053252_cs);
            end
            5'd9: begin
                if(col>=5&&col<=6) ch=hexchar(sound_now[(6-col)*4 +: 4]);
                if(col>=13&&col<=14) ch=hexchar(sound_ever[(14-col)*4 +: 4]);
                if(col>=20&&col<=23) ch=hexchar(sound_events[(23-col)*4 +: 4]);
                if(col>=28&&col<=31) ch=hexchar(audio_nonzero[(31-col)*4 +: 4]);
                if(col==43) ch=bitchar(snd_irq); if(col==44) ch=bitchar(snd_ok);
                if(col==45) ch=bitchar(snd_cs);
            end
            5'd10: begin
                if(col==6) ch=bitchar(|pcm_bsy); if(col==10) ch=bitchar(|pcm_warm);
                if(col==14) ch=bitchar(|pcm_underrun); if(col==18) ch=bitchar(|pcm_sample);
                if(col>=24&&col<=27) ch=hexchar(snd_l[(27-col)*4 +: 4]);
                if(col>=29&&col<=32) ch=hexchar(snd_r[(32-col)*4 +: 4]);
                if(col==39) ch=bitchar(esckids); if(col==40) ch=bitchar(cabinet_2p);
            end
            5'd12,5'd13,5'd14,5'd15,5'd16,5'd17,5'd18,5'd19: begin
                if(col==0||col==23) ch=hexchar(hist_index);
                if((col>=2&&col<=5)||(col>=25&&col<=28))
                    ch=hexchar(hist_pc[((col<22?5:28)-col)*4 +: 4]);
                if((col>=7&&col<=10)||(col>=30&&col<=33))
                    ch=hexchar(hist_addr[((col<22?10:33)-col)*4 +: 4]);
                if((col>=12&&col<=13)||(col>=35&&col<=36))
                    ch=hexchar(hist_op[((col<22?13:36)-col)*4 +: 4]);
                if((col>=15&&col<=16)||(col>=38&&col<=39))
                    ch=hexchar(hist_data[((col<22?16:39)-col)*4 +: 4]);
                if((col>=18&&col<=19)||(col>=41&&col<=42))
                    ch=hexchar(hist_flags[((col<22?19:42)-col)*4 +: 4]);
            end
            5'd20: begin
                if(col>=7&&col<=11) begin
                    if(col==7) ch=hexchar({1'b0,main_rom_addr[18:16]});
                    else ch=hexchar(main_rom_addr[(11-col)*4 +: 4]);
                end
                if(col>=17&&col<=20) begin
                    if(col==17) ch=hexchar({3'b000,ram_addr[12]});
                    else ch=hexchar(ram_addr[(20-col)*4 +: 4]);
                end
                if(col==25) ch=bitchar(cpu_we); if(col==31) ch=bitchar(ram_we);
                if(col>=37&&col<=38) ch=hexchar(rom_data[(38-col)*4 +: 4]);
            end
            5'd21: begin
                if(col==8) ch=hexchar(pcm_bsy); if(col==14) ch=hexchar(pcm_sample);
                if(col==20) ch=hexchar(pcm_warm); if(col==26) ch=hexchar(pcm_underrun);
                if(col==33) ch=hexchar(pcm_fill_cs); if(col==39) ch=hexchar(pcm_reverse);
            end
            5'd22: begin
                if(col>=5&&col<=10) begin
                    if(col==5) ch=hexchar({3'b000,pcm_addr_a[20]});
                    else ch=hexchar(pcm_addr_a[(10-col)*4 +: 4]);
                end
                if(col>=14&&col<=19) begin
                    if(col==14) ch=hexchar({3'b000,pcm_addr_b[20]});
                    else ch=hexchar(pcm_addr_b[(19-col)*4 +: 4]);
                end
                if(col>=23&&col<=28) begin
                    if(col==23) ch=hexchar({3'b000,pcm_addr_c[20]});
                    else ch=hexchar(pcm_addr_c[(28-col)*4 +: 4]);
                end
                if(col>=32&&col<=37) begin
                    if(col==32) ch=hexchar({3'b000,pcm_addr_d[20]});
                    else ch=hexchar(pcm_addr_d[(37-col)*4 +: 4]);
                end
            end
            5'd23: begin
                if(col>=6&&col<=11) begin
                    if(col==6) ch=hexchar({3'b000,pcm_fill_addr_a[20]});
                    else ch=hexchar(pcm_fill_addr_a[(11-col)*4 +: 4]);
                end
                if(col>=15&&col<=20) begin
                    if(col==15) ch=hexchar({3'b000,pcm_fill_addr_b[20]});
                    else ch=hexchar(pcm_fill_addr_b[(20-col)*4 +: 4]);
                end
                if(col>=24&&col<=29) begin
                    if(col==24) ch=hexchar({3'b000,pcm_fill_addr_c[20]});
                    else ch=hexchar(pcm_fill_addr_c[(29-col)*4 +: 4]);
                end
                if(col>=33&&col<=38) begin
                    if(col==33) ch=hexchar({3'b000,pcm_fill_addr_d[20]});
                    else ch=hexchar(pcm_fill_addr_d[(38-col)*4 +: 4]);
                end
            end
            5'd24: begin
                if(col==15) ch=bitchar(lyrf_cs); if(col==16) ch=bitchar(lyra_cs);
                if(col==17) ch=bitchar(lyrb_cs); if(col==18) ch=bitchar(lyro_cs);
                if(col==27) ch=bitchar(lyra_ok); if(col==28) ch=bitchar(lyro_ok);
                if(col==37) ch=bitchar(objcha_n);
            end
            5'd25: begin
                if(col==16) ch=bitchar(esckids); if(col==24) ch=bitchar(cabinet_2p);
                if(col==31) ch=bitchar(init); if(col==38) ch=bitchar(rst8);
            end
            default: ;
        endcase
        text_char = ch;
    end
endfunction

function automatic [4:0] glyph_row;
    input [7:0] ch;
    input [2:0] row;
    reg [34:0] glyph;
    begin
        case (ch)
            "0": glyph=35'b01110_10001_10011_10101_11001_10001_01110;
            "1": glyph=35'b00100_01100_00100_00100_00100_00100_01110;
            "2": glyph=35'b01110_10001_00001_00010_00100_01000_11111;
            "3": glyph=35'b11110_00001_00001_01110_00001_00001_11110;
            "4": glyph=35'b00010_00110_01010_10010_11111_00010_00010;
            "5": glyph=35'b11111_10000_10000_11110_00001_00001_11110;
            "6": glyph=35'b01110_10000_10000_11110_10001_10001_01110;
            "7": glyph=35'b11111_00001_00010_00100_01000_01000_01000;
            "8": glyph=35'b01110_10001_10001_01110_10001_10001_01110;
            "9": glyph=35'b01110_10001_10001_01111_00001_00001_01110;
            "A": glyph=35'b01110_10001_10001_11111_10001_10001_10001;
            "B": glyph=35'b11110_10001_10001_11110_10001_10001_11110;
            "C": glyph=35'b01111_10000_10000_10000_10000_10000_01111;
            "D": glyph=35'b11110_10001_10001_10001_10001_10001_11110;
            "E": glyph=35'b11111_10000_10000_11110_10000_10000_11111;
            "F": glyph=35'b11111_10000_10000_11110_10000_10000_10000;
            "G": glyph=35'b01111_10000_10000_10111_10001_10001_01111;
            "H": glyph=35'b10001_10001_10001_11111_10001_10001_10001;
            "I": glyph=35'b01110_00100_00100_00100_00100_00100_01110;
            "J": glyph=35'b00001_00001_00001_00001_10001_10001_01110;
            "K": glyph=35'b10001_10010_10100_11000_10100_10010_10001;
            "L": glyph=35'b10000_10000_10000_10000_10000_10000_11111;
            "M": glyph=35'b10001_11011_10101_10101_10001_10001_10001;
            "N": glyph=35'b10001_11001_10101_10011_10001_10001_10001;
            "O": glyph=35'b01110_10001_10001_10001_10001_10001_01110;
            "P": glyph=35'b11110_10001_10001_11110_10000_10000_10000;
            "Q": glyph=35'b01110_10001_10001_10001_10101_10010_01101;
            "R": glyph=35'b11110_10001_10001_11110_10100_10010_10001;
            "S": glyph=35'b01111_10000_10000_01110_00001_00001_11110;
            "T": glyph=35'b11111_00100_00100_00100_00100_00100_00100;
            "U": glyph=35'b10001_10001_10001_10001_10001_10001_01110;
            "V": glyph=35'b10001_10001_10001_10001_10001_01010_00100;
            "W": glyph=35'b10001_10001_10001_10101_10101_10101_01010;
            "X": glyph=35'b10001_10001_01010_00100_01010_10001_10001;
            "Y": glyph=35'b10001_10001_01010_00100_00100_00100_00100;
            "Z": glyph=35'b11111_00001_00010_00100_01000_10000_11111;
            ":": glyph=35'b00000_00100_00100_00000_00100_00100_00000;
            "/": glyph=35'b00001_00010_00010_00100_01000_01000_10000;
            "-": glyph=35'b00000_00000_00000_11111_00000_00000_00000;
            "=": glyph=35'b00000_11111_00000_11111_00000_00000_00000;
            "|": glyph=35'b00100_00100_00100_00100_00100_00100_00100;
            ";": glyph=35'b00000_00100_00100_00000_00100_00100_01000;
            default:glyph=35'd0;
        endcase
        case (row)
            3'd0: glyph_row=glyph[34:30];
            3'd1: glyph_row=glyph[29:25];
            3'd2: glyph_row=glyph[24:20];
            3'd3: glyph_row=glyph[19:15];
            3'd4: glyph_row=glyph[14:10];
            3'd5: glyph_row=glyph[9:5];
            3'd6: glyph_row=glyph[4:0];
            default: glyph_row=5'd0;
        endcase
    end
endfunction

assign char_code = text_char(char_row,char_col);
assign glyph_bits = glyph_row(char_code,glyph_y);

always @(*) begin
    red   = core_red;
    green = core_green;
    blue  = core_blue;
    if (enable && lvbl && lhbl) begin
        red   = 8'h00;
        green = 8'h00;
        blue  = 8'h18;
        if (glyph_on) begin
            if (char_row == 0) begin
                red=8'hff; green=8'he0; blue=8'h20;
            end else if (char_row >= 12 && char_row <= 19) begin
                red=8'h40; green=8'hff; blue=8'hd0;
            end else if (trap_seen && char_row >= 1 && char_row <= 4) begin
                red=8'hff; green=8'h70; blue=8'h70;
            end else begin
                red=8'hff; green=8'hff; blue=8'hff;
            end
        end
    end
end

endmodule
