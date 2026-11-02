// ============================================================================
// EIE330 FPGA-based System Design - Lab 3-1  Simple VGA Display
// File        : pll.v
// Contents    : divide-by-2 pixel-clock generator
//
// The board clock is 50 MHz.  A 640x480@60 frame needs one pixel clock every
// 800 x 525 x 60 pixel periods, i.e. about 25.175 MHz.  The lecture uses
// 25.000 MHz, obtained by toggling a register on every 50 MHz rising edge.
// The module is named "pll" because it fills the role of a PLL in the lecture
// example; it is a simple clock divider, not a PLL primitive.
// ============================================================================
`timescale 1ns / 1ns

module pll (
    input  wire sys_clk,      // system clock, 50 MHz
    input  wire sys_rst_n,    // asynchronous reset, active low
    output reg  vga_clk       // VGA pixel clock, 25 MHz
);

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            vga_clk <= 1'b0;
        else
            vga_clk <= ~vga_clk;
    end

endmodule
