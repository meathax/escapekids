// Contract-level decoder used by the focused map test.  The production
// decoder is in jtsimson_main.v; this module makes the locked MAME ranges and
// one-hot invariant executable without instantiating the complete CPU.
`timescale 1ns/1ps
module escape_kids_map_contract(
    input  logic        video_bank,
    input  logic [15:0] addr,
    output logic        ram_cs,
    output logic        banked_cs,
    output logic        prog_cs,
    output logic        tilesys_cs,
    output logic        objsys_cs,
    output logic        pal_cs,
    output logic        joystk_cs,
    output logic        eeprom_cs,
    output logic        stsw_cs,
    output logic        objreg_cs,
    output logic        pcu_cs,
    output logic        k053252_cs,
    output logic        snd_irq,
    output logic        snd_cs,
    output logic        objread_cs,
    output logic [18:0] rom_addr,
    output logic [4:0]  selected_count
);
    logic tile_window;

    always_comb begin
        ram_cs      = addr[15:13] == 3'b000;
        banked_cs   = addr[15:13] == 3'b011;
        prog_cs     = addr[15];
        tile_window = addr >= 16'h2000 && addr <= 16'h5fff;
        objsys_cs   = video_bank && addr[15:12] == 4'h2;
        pal_cs      = video_bank && addr[15:12] == 4'h4;
        joystk_cs   = addr >= 16'h3f80 && addr <= 16'h3f83;
        eeprom_cs   = addr == 16'h3f92;
        stsw_cs     = addr == 16'h3f93;
        objreg_cs   = addr >= 16'h3fa0 && addr <= 16'h3fa7;
        pcu_cs      = addr[15:4] == 12'h3fb;
        k053252_cs  = addr[15:4] == 12'h3fc;
        snd_irq     = addr == 16'h3fd4;
        snd_cs      = addr >= 16'h3fd6 && addr <= 16'h3fd7;
        objread_cs  = addr >= 16'h3fd8 && addr <= 16'h3fd9;
        tilesys_cs  = tile_window && !objsys_cs && !pal_cs &&
                      !(joystk_cs || eeprom_cs || stsw_cs ||
                      objreg_cs || pcu_cs || k053252_cs || snd_irq ||
                      snd_cs || objread_cs);

        if (banked_cs)
            rom_addr = {2'b00, 4'b0000, addr[12:0]};
        else if (prog_cs)
            rom_addr = {4'b0011, addr[14:0]};
        else
            rom_addr = 19'd0;
        selected_count = {4'd0,ram_cs} + {4'd0,banked_cs} + {4'd0,prog_cs} +
            {4'd0,tilesys_cs} + {4'd0,objsys_cs} + {4'd0,pal_cs} +
            {4'd0,joystk_cs} + {4'd0,eeprom_cs} + {4'd0,stsw_cs} +
            {4'd0,objreg_cs} + {4'd0,pcu_cs} + {4'd0,k053252_cs} +
            {4'd0,snd_irq} + {4'd0,snd_cs} + {4'd0,objread_cs};
    end
endmodule
