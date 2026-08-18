`timescale 1ns/1ps
module tb_escape_kids_input_contract;
    logic cabinet_2p, service;
    logic [3:0] cab_start, coin;
    logic [6:0] joystick1, joystick2, joystick3, joystick4;
    logic [7:0] p1,p2,p3,p4,service_byte;
    escape_kids_input_contract dut(.*);
    initial begin
        cabinet_2p=1; service=0; cab_start=4'b0011; coin=4'b0000;
        joystick1=7'b1010101; joystick2=7'b0101010;
        joystick3=7'b1111111; joystick4=7'b0000000; #1;
        if (p1 !== 8'b01010110) $fatal(1,"P1 byte %02h",p1);
        if (p2 !== 8'b00101001) $fatal(1,"P2 byte %02h",p2);
        if (p3 !== 8'hff || p4 !== 8'hff) $fatal(1,"2P inactive ports");
        if (service_byte !== 8'b11101111) $fatal(1,"2P service byte %02h",service_byte);
        cabinet_2p=0; service=1; coin=4'b0101; #1;
        if (p1[7] !== 1'b1 || p2[7] !== 1'b0) $fatal(1,"coin polarity/lane");
        if (service_byte !== 8'b11111111) $fatal(1,"4P service byte %02h",service_byte);
        $display("ESCAPE KIDS INPUT CONTRACT PASS");
        $finish;
    end
endmodule
