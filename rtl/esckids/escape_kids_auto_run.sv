// Escape Kids input convenience wrapper.
//
// The original input bus is active low.  Button 1 is the game's Run control
// (bit 4), Button 2 is Super Jump (bit 5), and the project-added Button 3 is
// Auto Run (bit 6).  While Auto Run is held, alternate visible frames expose
// Button 1 as pressed.  A physical Run press always remains pressed.
//
// This is deliberately Escape-only and sits outside the shared JTFRAME input
// machinery.  It adds no clock or CDC boundary: LVBL is produced in the same
// game clock domain and is sampled only as a synchronous falling-edge event.
module escape_kids_auto_run(
    input  wire       clk,
    input  wire       rst,
    input  wire       enable,
    input  wire       lvbl,
    input  wire [6:0] joystick1,
    input  wire [6:0] joystick2,
    input  wire [6:0] joystick3,
    input  wire [6:0] joystick4,
    output wire [6:0] joystick1_out,
    output wire [6:0] joystick2_out,
    output wire [6:0] joystick3_out,
    output wire [6:0] joystick4_out
);

reg lvbl_d;
reg run_phase;

always @(posedge clk) begin
    if (rst) begin
        lvbl_d    <= 1'b0;
        run_phase <= 1'b0;
    end else begin
        lvbl_d <= lvbl;
        if (!enable)
            run_phase <= 1'b0;
        else if (lvbl_d && !lvbl)
            run_phase <= ~run_phase;
    end
end

function [6:0] apply_auto_run;
    input [6:0] joy;
    input       enable_i;
    input       phase_i;
    begin
        apply_auto_run = joy;
        // Button 3 is active low.  On the active phase, synthesize a
        // Button-1 press; on the inactive phase, release it for a new tap.
        if (enable_i && !joy[6] && phase_i)
            apply_auto_run[4] = 1'b0;
    end
endfunction

assign joystick1_out = apply_auto_run(joystick1, enable, run_phase);
assign joystick2_out = apply_auto_run(joystick2, enable, run_phase);
assign joystick3_out = apply_auto_run(joystick3, enable, run_phase);
assign joystick4_out = apply_auto_run(joystick4, enable, run_phase);

endmodule
