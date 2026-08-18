`timescale 1ns/1ps
module escape_kids_input_contract(
    input  logic       cabinet_2p,
    input  logic       service,
    input  logic [3:0] cab_start,
    input  logic [3:0] coin,
    input  logic [6:0] joystick1, joystick2, joystick3, joystick4,
    output logic [7:0] p1, p2, p3, p4,
    output logic [7:0] service_byte
);
    always_comb begin
        p1 = {coin[0], joystick1[6:2], joystick1[0], joystick1[1]};
        p2 = {coin[1], joystick2[6:2], joystick2[0], joystick2[1]};
        p3 = cabinet_2p ? 8'hff : {coin[2], joystick3[6:2], joystick3[0], joystick3[1]};
        p4 = cabinet_2p ? 8'hff : {coin[3], joystick4[6:2], joystick4[0], joystick4[1]};
        service_byte = cabinet_2p ?
            {3'b111, service, 2'b11, cab_start[1], cab_start[0]} :
            {4'hf, service, 3'b111};
    end
endmodule
