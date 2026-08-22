`timescale 1ns/1ps

module escape_kids_hw_debug(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [ 4:0] page,
    input  wire [ 3:0] hist_sel,
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
    input  wire        pal_we,
    input  wire        tilesys_cs,
    input  wire        objsys_cs,
    input  wire        objreg_cs,
    input  wire        pcu_cs,
    input  wire        k053252_cs,
    input  wire        rmrd,
    input  wire        lvbl,
    input  wire        lhbl,
    input  wire        pxl_cen,
    input  wire [ 7:0] red,
    input  wire [ 7:0] green,
    input  wire [ 7:0] blue,
    input  wire        snd_cs,
    input  wire        snd_ok,
    input  wire        snd_irq,
    input  wire [ 3:0] pcm_bsy,
    input  wire [ 3:0] pcm_sample,
    input  wire [ 3:0] pcm_warm,
    input  wire [ 3:0] pcm_underrun,
    input  wire [15:0] snd_l,
    input  wire [15:0] snd_r,
    input  wire        esckids,
    input  wire        cabinet_2p,
    input  wire        rst24,
    input  wire        rst48,
    input  wire        rst96,
    input  wire        irq_n,
    input  wire        firq_n,
    input  wire        nmi_n,
    input  wire        dma_bsy,
    output reg  [ 7:0] debug_view,
    output reg  [ 7:0] video_ever,
    output reg  [ 7:0] sound_ever,
    output reg  [15:0] palette_writes,
    output reg  [15:0] sound_events,
    output reg  [15:0] audio_nonzero
);

reg snd_cs_q, snd_irq_q;

always @(posedge clk) begin
    if (rst) begin
        video_ever    <= 8'd0;
        sound_ever    <= 8'd0;
        palette_writes<= 16'd0;
        sound_events  <= 16'd0;
        audio_nonzero <= 16'd0;
        snd_cs_q      <= 1'b0;
        snd_irq_q     <= 1'b0;
    end else begin
        video_ever <= video_ever | {
            |{red,green,blue}, pxl_cen, ~lvbl, ~lhbl,
            pal_we, tilesys_cs, objsys_cs, k053252_cs
        };
        sound_ever <= sound_ever | {
            |{snd_l,snd_r}, snd_cs, snd_ok, snd_irq,
            |pcm_bsy, |pcm_sample, |pcm_warm, |pcm_underrun
        };
        if (pal_we)
            palette_writes <= palette_writes + 16'd1;
        if ((snd_cs && !snd_cs_q) || (snd_irq && !snd_irq_q) || |pcm_sample)
            sound_events <= sound_events + 16'd1;
        if (|{snd_l,snd_r})
            audio_nonzero <= audio_nonzero + 16'd1;
        snd_cs_q  <= snd_cs;
        snd_irq_q <= snd_irq;
    end
end

always @(*) begin
    if (!enable) begin
        debug_view = 8'd0;
    end else begin
        case (page)
            5'd0: begin
                case (hist_sel)
                    4'h0: debug_view = 8'hD5;
                    4'h1: debug_view = accept_count[7:0];
                    4'h2: debug_view = accept_count[15:8];
                    4'h3: debug_view = palette_writes[7:0];
                    4'h4: debug_view = palette_writes[15:8];
                    4'h5: debug_view = sound_events[7:0];
                    4'h6: debug_view = sound_events[15:8];
                    4'h7: debug_view = audio_nonzero[7:0];
                    4'h8: debug_view = audio_nonzero[15:8];
                    4'h9: debug_view = sound_ever;
                    4'ha: debug_view = {6'd0,objreg_cs,pcu_cs};
                    4'hb: debug_view = {7'd0,dma_bsy};
                    default: debug_view = 8'hD5;
                endcase
            end
            5'd1:  debug_view = {trap_seen,berr_l,buserror,main_cs,
                                  main_ok,main_cpu_ok,dtack,cpu_cen};
            5'd2:  debug_view = live_pc[15:8];
            5'd3:  debug_view = live_pc[7:0];
            5'd4:  debug_view = pcbad[15:8];
            5'd5:  debug_view = pcbad[7:0];
            5'd6:  debug_view = live_addr[15:8];
            5'd7:  debug_view = live_addr[7:0];
            5'd8:  debug_view = last_op;
            5'd9:  debug_view = cpu_din;
            5'd10: debug_view = rom_data;
            5'd11: debug_view = aupper;
            5'd12: debug_view = trap_pc[15:8];
            5'd13: debug_view = trap_pc[7:0];
            5'd14: debug_view = trap_addr[15:8];
            5'd15: debug_view = trap_addr[7:0];
            5'd16: debug_view = trap_op;
            5'd17: debug_view = trap_data;
            5'd18: debug_view = trap_flags;
            5'd19: debug_view = hist_pc[15:8];
            5'd20: debug_view = hist_pc[7:0];
            5'd21: debug_view = hist_addr[15:8];
            5'd22: debug_view = hist_addr[7:0];
            5'd23: debug_view = hist_op;
            5'd24: debug_view = hist_data;
            5'd25: debug_view = hist_flags;
            5'd26: debug_view = {lvbl,lhbl,pxl_cen,|{red,green,blue},
                                  pal_we,tilesys_cs,objsys_cs,k053252_cs};
            5'd27: debug_view = video_ever;
            5'd28: debug_view = {snd_cs,snd_ok,snd_irq,|pcm_bsy,
                                  |pcm_sample,|{snd_l,snd_r},rmrd,eep_rdy};
            5'd29: debug_view = {pcm_underrun,pcm_warm};
            5'd30: debug_view = {esckids,cabinet_2p,rst24,rst48,
                                  rst96,irq_n,firq_n,nmi_n};
            default: debug_view = cpu_reg_byte;
        endcase
    end
end

endmodule
