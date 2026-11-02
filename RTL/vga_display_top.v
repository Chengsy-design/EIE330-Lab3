// ============================================================================
// EIE330 FPGA-based System Design - Lab 3-1  Simple VGA Display
// File        : vga_display_top.v
// Contents    : top level with the same interface as the lecture example
//
//   sys_clk   50 MHz board clock
//   sys_rst_n active-low reset
//   hsync     line sync
//   vsync     field sync
//   rgb[15:0] RGB565 color
//
// Signal flow:
//   sys_clk -- pll --> vga_clk (25 MHz)
//   vga_ctrl produces pix_x / pix_y one pixel early and accepts pix_data
//   vga_pic turns (pix_x, pix_y) into a registered RGB565 color
//   vga_ctrl gates the color with rgb_valid and drives hsync / vsync / rgb
// ============================================================================
`timescale 1ns / 1ns

module vga_display_top (
    input  wire        sys_clk,       // 50 MHz board clock
    input  wire        sys_rst_n,     // asynchronous reset, active low
    output wire        hsync,         // VGA line sync
    output wire        vsync,         // VGA field sync
    output wire [15:0] rgb            // VGA RGB565 data
);

    wire        vga_clk;              // 25 MHz pixel clock
    wire [9:0]  pix_x;                // current pixel x coordinate
    wire [9:0]  pix_y;                // current pixel y coordinate
    wire [15:0] pix_data;             // color returned by vga_pic

    pll u_pll (
        .sys_clk   (sys_clk),
        .sys_rst_n (sys_rst_n),
        .vga_clk   (vga_clk)
    );

    vga_ctrl u_vga_ctrl (
        .vga_clk   (vga_clk),
        .sys_rst_n (sys_rst_n),
        .pix_data  (pix_data),
        .pix_x     (pix_x),
        .pix_y     (pix_y),
        .hsync     (hsync),
        .vsync     (vsync),
        .rgb       (rgb)
    );

    vga_pic u_vga_pic (
        .vga_clk   (vga_clk),
        .sys_rst_n (sys_rst_n),
        .pix_x     (pix_x),
        .pix_y     (pix_y),
        .pix_data  (pix_data)
    );

endmodule
