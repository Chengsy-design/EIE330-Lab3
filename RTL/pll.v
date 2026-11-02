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
