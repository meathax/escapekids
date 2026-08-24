`timescale 1ns/1ps

module tb_escape_kids_presentation_crop;

    localparam integer TOTAL_H  = 384;
    localparam integer TOTAL_V  = 264;
    localparam integer ACTIVE_H = 321;
    localparam integer ACTIVE_V = 240;
    localparam integer LEFT     = 12;
    localparam integer RIGHT    = 300;
    localparam integer OUT_W    = RIGHT - LEFT;

    reg clk;
    reg reset = 1'b1;
    reg ce_pixel = 1'b0;
    reg de_in = 1'b0;
    wire de_out;

    integer line;
    integer column;
    integer active_samples;
    integer active_lines;
    integer total_samples;

    always #5 clk = ~clk;

    escape_kids_presentation_crop #(
        .LEFT  (LEFT),
        .RIGHT (RIGHT)
    ) dut (
        .clk_video (clk),
        .reset     (reset),
        .ce_pixel  (ce_pixel),
        .de_in     (de_in),
        .de_out    (de_out)
    );

    initial begin
        clk = 1'b0;
        active_lines = 0;
        total_samples = 0;

        repeat (4) @(posedge clk);
        reset = 1'b0;

        for (line = 0; line < TOTAL_V; line = line + 1) begin
            active_samples = 0;
            for (column = 0; column < TOTAL_H; column = column + 1) begin
                @(negedge clk);
                ce_pixel = 1'b1;
                de_in = (line < ACTIVE_V) && (column < ACTIVE_H);

                // Sample the current source pixel before the crop counter
                // advances on its CE_PIXEL edge.
                #1;
                if (de_out !== (line < ACTIVE_V &&
                                column >= LEFT && column < RIGHT))
                    $fatal(1, "presentation DE mismatch line=%0d column=%0d got=%b",
                        line, column, de_out);
                if (de_out)
                    active_samples = active_samples + 1;

                @(posedge clk);
            end

            if (active_samples != (line < ACTIVE_V ? OUT_W : 0))
                $fatal(1, "presentation line width mismatch line=%0d got=%0d",
                    line, active_samples);
            if (active_samples == OUT_W)
                active_lines = active_lines + 1;
            total_samples = total_samples + active_samples;
        end

        ce_pixel = 1'b0;
        de_in = 1'b0;

        if (active_lines != ACTIVE_V)
            $fatal(1, "presentation height mismatch got=%0d", active_lines);
        if (total_samples != ACTIVE_V * OUT_W)
            $fatal(1, "presentation pixel count mismatch got=%0d", total_samples);

        $display("ESCAPE KIDS PRESENTATION CROP PASS width=%0d height=%0d left=%0d right_exclusive=%0d",
            OUT_W, ACTIVE_V, LEFT, RIGHT);
        $finish;
    end

endmodule
