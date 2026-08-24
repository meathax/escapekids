`timescale 1ns/1ps

// The real jtframe_inputs, jtframe_pause and jtframe_toggle are compiled.
// Unrelated peripherals are narrow stubs so this test stays input-focused.
module jtframe_joysticks(
    input rst, clk, vs, locked, rot, rot_ccw,
    input [1:0] joy1_pos,
    input [3:0] board_coin, board_start, key_coin, key_start, joy_coin, joy_start,
    input key_service, key_tilt, key_reset,
    input [15:0] ana1, ana2, board_joy1, board_joy2, board_joy3, board_joy4,
    input [9:0] key_joy1, key_joy2, key_joy3, key_joy4,
    input joy_test, key_test,
    input [2:0] mouse_but_1p, mouse_but_2p,
    output reg [5:0] recjoy1,
    output reg [9:0] game_joy1, game_joy2, game_joy3, game_joy4, lock_joy1,
    output reg [3:0] game_coin, game_start,
    output reg game_test, game_service, game_tilt, soft_rst
);
    always @(posedge clk) begin
        if(rst) begin
            recjoy1 <= 0; game_joy1 <= 10'h3ff; game_joy2 <= 10'h3ff;
            game_joy3 <= 10'h3ff; game_joy4 <= 10'h3ff; lock_joy1 <= 10'h3ff;
            game_coin <= 4'hf; game_start <= 4'hf; game_test <= 1;
            game_service <= 1; game_tilt <= 1; soft_rst <= 0;
        end else begin
            recjoy1 <= 0;
            game_joy1 <= ~(board_joy1[9:0] | key_joy1);
            game_joy2 <= ~(board_joy2[9:0] | key_joy2);
            game_joy3 <= ~(board_joy3[9:0] | key_joy3);
            game_joy4 <= ~(board_joy4[9:0] | key_joy4);
            lock_joy1 <= 10'h3ff;
            game_coin <= ~(board_coin | key_coin);
            game_start <= ~(board_start | key_start);
            game_test <= ~(joy_test | key_test);
            game_service <= ~key_service;
            game_tilt <= ~key_tilt;
            soft_rst <= 0;
        end
    end
endmodule

module jtframe_debug_keys(
    input rst, clk, ctrl, shift, input [12:7] func_key,
    input coin_n, start_n, input [9:0] joy_n, input plus, minus,
    output [3:0] gfx_en, output [5:0] snd_en,
    output reg debug_toggle, output reg [1:0] debug_plus, debug_minus
);
    assign gfx_en = 4'hf; assign snd_en = 6'h3f;
    always @(posedge clk) begin debug_toggle <= 0; debug_plus <= 0; debug_minus <= 0; end
endmodule

module jtframe_dial(
    input rst, clk, lhbl, lvbl, input mouse_st, input [8:0] mouse_dx, mouse_dy,
    input [9:0] joystick1, joystick2, input [8:0] spinner_1, spinner_2,
    input [1:0] sensty, input raw, reverse, output [1:0] dial_x, dial_y
);
    assign dial_x = 0; assign dial_y = 0;
endmodule

module jtframe_paddle(
    input rst, clk, input signed [8:0] mouse_dx, input mouse_st,
    input [7:0] hw_paddle, output reg [7:0] paddle
);
    always @(posedge clk) paddle <= hw_paddle;
endmodule

module jtframe_mouse(
    input rst, clk, lock, input signed [8:0] mouse_dx, mouse_dy,
    input [7:0] mouse_f, input mouse_st, mouse_idx, input [3:0] joyn1, joyn2,
    output reg [15:0] mouse_1p, mouse_2p, output reg [1:0] mouse_strobe,
    output reg [2:0] but_1p, but_2p
);
    always @(posedge clk) begin mouse_1p <= 0; mouse_2p <= 0; mouse_strobe <= 0; but_1p <= 0; but_2p <= 0; end
endmodule

module jtframe_lightgun #(parameter WIDTH=384, HEIGHT=224)(
    input rst, clk, vs, input [7:0] debug_bus, input gun_crossh_en,
    input [1:0] rotate, sensty, input [3:0] game_joy1, game_joy2,
    input [15:0] joyana1, joyana2, mouse_1p, mouse_2p, input [1:0] mouse_strobe,
    output [8:0] gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y, cross1_x, cross1_y, cross2_x, cross2_y,
    output [1:0] cross_disable
);
    assign gun_1p_x=0; assign gun_1p_y=0; assign gun_2p_x=0; assign gun_2p_y=0;
    assign cross1_x=0; assign cross1_y=0; assign cross2_x=0; assign cross2_y=0; assign cross_disable=0;
endmodule

module jtframe_beta_lock(
    input clk, input ioctl_lock, input [1:0] ioctl_addr, input [7:0] ioctl_dout,
    input ioctl_wr, output reg locked
);
    always @(posedge clk) locked <= 0;
endmodule

module jtframe_rec_inputs #(parameter RECAW=13)(
    input rst, clk, input vs, dip_pause, input [3:0] game_start, game_coin,
    input [5:0] joystick, input [12:0] ioctl_addr, input [7:0] ioctl_din,
    output [7:0] ioctl_merged
);
    assign ioctl_merged = ioctl_din;
endmodule

module tb_escape_kids_jtframe_inputs;
    reg rst=0, clk=0, vs=0, lvbl=1, lhbl=1, rot=0, dial_raw_en=0, dial_reverse=0, dip_pause=1;
    reg [1:0] rotate=0, joy1_pos=0, sensty=0;
    reg [15:0] board_joy1=0, board_joy2=0, board_joy3=0, board_joy4=0, ana1=0, ana2=0;
    reg [3:0] board_coin=0, board_start=0, key_start=0, key_coin=0;
    reg [9:0] key_joy1=0, key_joy2=0, key_joy3=0, key_joy4=0;
    reg key_service=0, key_test=0, key_tilt=0, key_ctrl=0, key_shift=0, key_plus=0, key_minus=0;
    reg [12:7] func_key=0; reg key_pause=0, osd_pause=0, key_reset=0;
    reg signed [8:0] bd_mouse_dx=0, bd_mouse_dy=0; reg [7:0] bd_mouse_f=0;
    reg bd_mouse_st=0, bd_mouse_idx=0; reg [7:0] board_paddle_1=0, board_paddle_2=0;
    reg [8:0] spinner_1=0, spinner_2=0; reg gun_crossh_en=0; reg [7:0] debug_bus=0;
    reg ioctl_lock=0; reg [12:0] ioctl_addr=0; reg [7:0] ioctl_din=0, ioctl_dout=0;
    reg ioctl_wr=0, ioctl_rom=0;

    wire soft_rst, game_pause, game_service, game_test, game_tilt, locked;
    wire [9:0] game_joy1, game_joy2, game_joy3, game_joy4;
    wire [3:0] game_coin, game_start; wire [15:0] mouse_1p, mouse_2p;
    wire [1:0] mouse_strobe, dial_x, dial_y, cross_disable;
    wire [7:0] game_paddle_1, game_paddle_2, ioctl_merged;
    wire [8:0] gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y, cross1_x, cross1_y, cross2_x, cross2_y;
    wire [3:0] gfx_en; wire [5:0] snd_en; wire debug_toggle; wire [1:0] debug_plus, debug_minus;

    always #5 clk = ~clk;

    jtframe_inputs #(.BUTTONS(3), .WIDTH(320), .HEIGHT(240)) dut(
        .rst(rst), .clk(clk), .vs(vs), .lvbl(lvbl), .lhbl(lhbl), .rot(rot), .rotate(rotate),
        .joy1_pos(joy1_pos), .dial_raw_en(dial_raw_en), .dial_reverse(dial_reverse), .dip_pause(dip_pause),
        .soft_rst(soft_rst), .game_pause(game_pause), .board_joy1(board_joy1), .board_joy2(board_joy2),
        .board_joy3(board_joy3), .board_joy4(board_joy4), .ana1(ana1), .ana2(ana2), .board_coin(board_coin),
        .board_start(board_start), .key_joy1(key_joy1), .key_joy2(key_joy2), .key_joy3(key_joy3),
        .key_joy4(key_joy4), .key_start(key_start), .key_coin(key_coin), .key_service(key_service),
        .key_test(key_test), .key_tilt(key_tilt), .key_ctrl(key_ctrl), .key_shift(key_shift), .key_plus(key_plus),
        .key_minus(key_minus), .func_key(func_key), .key_pause(key_pause), .osd_pause(osd_pause), .key_reset(key_reset),
        .game_joy1(game_joy1), .game_joy2(game_joy2), .game_joy3(game_joy3), .game_joy4(game_joy4),
        .game_coin(game_coin), .game_start(game_start), .game_service(game_service), .game_test(game_test),
        .game_tilt(game_tilt), .locked(locked), .bd_mouse_dx(bd_mouse_dx), .bd_mouse_dy(bd_mouse_dy),
        .bd_mouse_f(bd_mouse_f), .bd_mouse_st(bd_mouse_st), .bd_mouse_idx(bd_mouse_idx),
        .board_paddle_1(board_paddle_1), .board_paddle_2(board_paddle_2), .sensty(sensty),
        .spinner_1(spinner_1), .spinner_2(spinner_2), .mouse_1p(mouse_1p), .mouse_2p(mouse_2p),
        .mouse_strobe(mouse_strobe), .game_paddle_1(game_paddle_1), .game_paddle_2(game_paddle_2),
        .dial_x(dial_x), .dial_y(dial_y), .gun_1p_x(gun_1p_x), .gun_1p_y(gun_1p_y),
        .gun_2p_x(gun_2p_x), .gun_2p_y(gun_2p_y), .cross1_x(cross1_x), .cross1_y(cross1_y),
        .cross2_x(cross2_x), .cross2_y(cross2_y), .cross_disable(cross_disable), .gun_crossh_en(gun_crossh_en),
        .debug_bus(debug_bus), .ioctl_lock(ioctl_lock), .ioctl_addr(ioctl_addr), .ioctl_din(ioctl_din),
        .ioctl_dout(ioctl_dout), .ioctl_wr(ioctl_wr), .ioctl_merged(ioctl_merged), .gfx_en(gfx_en), .snd_en(snd_en),
        .debug_toggle(debug_toggle), .debug_plus(debug_plus), .debug_minus(debug_minus), .ioctl_rom(ioctl_rom)
    );

    task automatic clocks(input integer count);
        integer i; begin for(i=0; i<count; i=i+1) @(posedge clk); #1; end
    endtask

    task automatic expect_idle;
        begin
            if(game_service !== 1 || game_test !== 1 || game_pause !== 0) begin
                $display("FAIL idle service=%b test=%b pause=%b", game_service, game_test, game_pause); $fatal(1);
            end
        end
    endtask

    initial begin
        rst=1; clocks(3); rst=0; clocks(3); expect_idle();
        board_joy1[9]=1; clocks(3);
        if(game_service !== 0 || game_test !== 1 || game_pause !== 0) begin
            $display("FAIL Service route service=%b test=%b pause=%b", game_service, game_test, game_pause); $fatal(1);
        end
        board_joy1[9]=0; clocks(3); expect_idle();
        board_joy1[10]=1; clocks(3);
        if(game_service !== 1 || game_test !== 0 || game_pause !== 0) begin
            $display("FAIL Test route service=%b test=%b pause=%b", game_service, game_test, game_pause); $fatal(1);
        end
        board_joy1[10]=0; clocks(3); expect_idle();
        board_joy1[10:9]=2'b11; clocks(3);
        if(game_service !== 0 || game_test !== 0 || game_pause !== 0) begin
            $display("FAIL simultaneous route service=%b test=%b pause=%b", game_service, game_test, game_pause); $fatal(1);
        end
        board_joy1[10:9]=0; clocks(3); expect_idle();
        key_pause=1; clocks(2); key_pause=0; clocks(2);
        if(game_pause !== 1) begin $display("FAIL keyboard pause did not toggle pause=%b", game_pause); $fatal(1); end
        $display("ESCAPE KIDS JTFRAME INPUT BUTTON CONTRACT PASS"); $finish;
    end
endmodule