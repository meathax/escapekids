// Optional mute for the Escape Kids "one, two" character voice samples.
//
// The main CPU sends sound requests as a single byte written to the K053260
// host port at 0x3fd6/0x3fd7, followed by a write to 0x3fd4 that raises the
// sound-CPU IRQ.  Sound-test entries 60 and 62 are the two "one"/"two" voice
// calls, so muting them is a request-level filter: the command byte is
// replaced by 0 and the IRQ that would make the Z80 act on it is withheld.
// Every other request, and all mixing/volume behaviour, is untouched.

`ifndef ESCAPE_KIDS_VOICE_MUTE_INCLUDED
`define ESCAPE_KIDS_VOICE_MUTE_INCLUDED

module escape_kids_voice_mute #(
    parameter [7:0] CODE0 = 8'd60,
    parameter [7:0] CODE1 = 8'd62
)(
    input            clk,
    input            rst,
    input            enable,      // core is Escape Kids and the OSD option is on
    input            snd_wr,      // main CPU write strobe to the K053260 host port
    input      [7:0] din,         // main CPU data bus
    output     [7:0] dout,        // data presented to the sound section
    input            snd_irq_in,
    output           snd_irq_out
);

wire hit = enable && (din == CODE0 || din == CODE1);
reg  pending, irq_l;

assign dout        = (snd_wr && hit) ? 8'h00 : din;
assign snd_irq_out = snd_irq_in && !(enable && pending);

always @(posedge clk) begin
    if( rst ) begin
        pending <= 1'b0;
        irq_l   <= 1'b0;
    end else begin
        irq_l <= snd_irq_in;
        // The request is armed by the command write and consumed by the IRQ
        // pulse that follows it, so a blocked code cannot gate a later one.
        if( snd_wr )                    pending <= hit;
        else if( irq_l && !snd_irq_in ) pending <= 1'b0;
    end
end

endmodule

`endif
