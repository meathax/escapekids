`timescale 1ns/1ps
module tb_escape_kids_map_contract;
    logic video_bank;
    logic [15:0] addr;
    logic ram_cs, banked_cs, prog_cs, tilesys_cs, objsys_cs, pal_cs;
    logic joystk_cs, eeprom_cs, stsw_cs, objreg_cs, pcu_cs;
    logic k053252_cs, snd_irq, snd_cs, objread_cs;
    logic [18:0] rom_addr;
    logic [4:0] selected_count;

    escape_kids_map_contract dut(.*);

    task automatic expect_one(input [15:0] a, input [4:0] expected);
        begin
            addr = a;
            #1;
            if (selected_count != ((expected == 0) ? 0 : 1))
                $fatal(1, "map %04h selected_count=%0d", a, selected_count);
            if (expected[0] && !ram_cs)      $fatal(1, "RAM missing at %04h", a);
            if (expected[1] && !banked_cs)   $fatal(1, "bank ROM missing at %04h", a);
            if (expected[2] && !prog_cs)     $fatal(1, "fixed ROM missing at %04h", a);
            if (expected[3] && !tilesys_cs) $fatal(1, "tile CS missing at %04h", a);
            if (expected[4] && !objsys_cs)   $fatal(1, "object CS missing at %04h", a);
        end
    endtask

    task automatic expect_named(input [15:0] a, input integer which);
        begin
            addr = a;
            #1;
            if (selected_count != 1) $fatal(1, "not one-hot at %04h", a);
            case (which)
                0: if (!joystk_cs)  $fatal(1, "joystick CS missing at %04h", a);
                1: if (!eeprom_cs)  $fatal(1, "EEPROM CS missing at %04h", a);
                2: if (!stsw_cs)    $fatal(1, "service CS missing at %04h", a);
                3: if (!objreg_cs)  $fatal(1, "object register CS missing at %04h", a);
                4: if (!pcu_cs)     $fatal(1, "K053251 CS missing at %04h", a);
                5: if (!k053252_cs)$fatal(1, "K053252 CS missing at %04h", a);
                6: if (!snd_irq)   $fatal(1, "sound IRQ CS missing at %04h", a);
                7: if (!snd_cs)    $fatal(1, "sound CS missing at %04h", a);
                8: if (!objread_cs)$fatal(1, "object read CS missing at %04h", a);
            endcase
        end
    endtask

    integer i;
    initial begin
        video_bank = 1'b0;
        addr = 16'd0;
        #1;
        for (i = 0; i < 65536; i = i + 1) begin
            addr = i[15:0];
            // Advance time so Verilator does not treat the entire exhaustive
            // sweep as one inactive-region convergence window.
            #1;
            if (selected_count > 1) $fatal(1, "overlapping CS at %04h", addr);
        end

        expect_one(16'h0000, 5'b00001);
        expect_one(16'h1fff, 5'b00001);
        expect_one(16'h2000, 5'b01000);
        expect_one(16'h3d80, 5'b01000); // 1D80 selector alias through 2K window
        expect_one(16'h5d80, 5'b01000); // 1D80 selector alias through 4K mirror
        expect_one(16'h3e00, 5'b01000); // 1E00 selector alias through 2K window
        expect_one(16'h5e00, 5'b01000); // 1E00 selector alias through 4K mirror
        expect_one(16'h3f00, 5'b01000); // 1F00 selector alias through 2K window
        expect_one(16'h5f00, 5'b01000); // 1F00 selector alias through 4K mirror
        expect_one(16'h6000, 5'b00010);
        expect_one(16'h7fff, 5'b00010);
        expect_one(16'h8000, 5'b00100);
        expect_one(16'hffff, 5'b00100);
        expect_named(16'h3f80, 0);
        expect_named(16'h3f92, 1);
        expect_named(16'h3f93, 2);
        expect_named(16'h3fa0, 3);
        expect_named(16'h3fb0, 4);
        expect_named(16'h3fc0, 5);
        expect_named(16'h3fd4, 6);
        expect_named(16'h3fd6, 7);
        expect_named(16'h3fd8, 8);

        video_bank = 1'b1;
        expect_one(16'h2000, 5'b10000);
        expect_one(16'h2fff, 5'b10000);
        addr = 16'h4000;
        #1;
        if (!pal_cs || selected_count != 1) $fatal(1, "palette view missing");
        addr = 16'h3000;
        #1;
        if (!tilesys_cs || selected_count != 1) $fatal(1, "tile window lost outside sprite view");

        // 6000-7FFF is the physical four-bank window; 8000-FFFF is fixed 18000.
        addr = 16'h6000; #1;
        if (rom_addr !== 19'h00000) $fatal(1, "unexpected banked ROM address %05h", rom_addr);
        addr = 16'h8000; #1;
        if (rom_addr !== 19'h18000) $fatal(1, "unexpected fixed ROM address %05h", rom_addr);
        $display("ESCAPE KIDS MAP CONTRACT PASS");
        $finish;
    end
endmodule
