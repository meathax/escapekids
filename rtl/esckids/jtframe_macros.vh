// JTFRAME configuration for the Escape Kids MiSTer target.
// Keep these definitions in one project-owned file so Verilator, Quartus and
// source-manifest generation use the same effective build contract.
`ifndef ESCAPE_KIDS_JTFRAME_MACROS
`define ESCAPE_KIDS_JTFRAME_MACROS

`define CORENAME EscapeKids
`define GAMETOP jtsimson_game_sdram
`define JTFRAME_MEMGEN
`define JTFRAME_HEADER 4
`define JTFRAME_CLK48
`define JTFRAME_MR_DDRLOAD
`define JTFRAME_STEREO
`define JTFRAME_COLORW 8
`define JTFRAME_PXLCLK 6
`define JTFRAME_WIDTH 320
`define JTFRAME_HEIGHT 240
`define JTFRAME_BUTTONS 3
`define JTFRAME_JOY_DURL
`define JTFRAME_JOY1_POS
`define JTFRAME_RATE 59.19
`define JTFRAME_BA1_START 26'h080000
`define PCM_START 26'h0A0000
`define JTFRAME_BA2_START 26'h1E0000
`define JTFRAME_BA3_START 26'h2E0000
`define JTFRAME_PROM_START 26'h6E0000
`define JTFRAME_IOCTL_RD 128
`define JTFRAME_OSD_TEST
`define JTFRAME_NOMRA_DIP
`define JTFRAME_ARX 5
`define JTFRAME_ARY 4
// Defaults emitted by JTFRAME for non-line-buffer MiSTer targets.
`define JTFRAME_180SHIFT 0
`define JTFRAME_SHIFT 0
`define JTFRAME_LF_HW 9
`define JTFRAME_LF_VW 8
`define JTFRAME_MCLK 48000000
`define JTFRAME_TIMESTAMP 0
`define JTFRAME_MR_FASTIO 0
`define JTFRAME_DEBUG_VPOS 4
`define JTFRAME_DIALEMU_LEFT 5
`define JTKCPU_DEBUG
`define GAME_ROM_LEN 26'h6E0000

`endif
