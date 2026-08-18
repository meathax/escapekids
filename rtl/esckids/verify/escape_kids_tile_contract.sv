// Executable Escape Kids K052109 callback contract.
// pre={CAB[1:0],VC[7:0],raster_row[2:0]} is the JT052109 address output.
// The result is a 32-bit tile-ROM word address (packed [19:2]).
module escape_kids_tile_contract(
    input  logic [7:0]  color,
    input  logic [12:0] pre,
    output logic [19:2] addr,
    output logic [2:0]  palette
);
    always_comb begin
        // vendetta.cpp esckids_tile_callback:
        // code |= (color&03)<<8 | (color&10)<<6 |
        //         (color&0c)<<9 | (bank<<13)
        addr = { pre[12:11], color[3:2], color[4], color[1:0],
                 pre[10:0] };
        palette = color[7:5];
    end
endmodule
