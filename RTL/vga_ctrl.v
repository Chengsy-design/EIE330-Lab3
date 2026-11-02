// ============================================================================
// EIE330 FPGA-based System Design - Lab 3-1  Simple VGA Display
// File        : vga_ctrl.v
// Contents    : VGA timing engine for 640x480@60, RGB565 output
//
// This module is reused unchanged from the lecture color-bar example.  It
// owns the two counters and produces hsync, vsync, the addressable-window
// strobe rgb_valid, the one-pixel-early request pix_data_req, and the pixel
// coordinates pix_x / pix_y.
//
// Timing (VESA DMT 640x480@60, 25 MHz pixel clock):
//   line : 96 sync + 40 back porch + 8 left border + 640 video
//          + 8 right border + 8 front porch = 800 pixel clocks
//   field:  2 sync + 25 back porch + 8 top border + 480 video
//          + 8 bottom border + 2 front porch = 525 lines
//
// pix_x / pix_y are REQUEST coordinates: pix_data_req is asserted one pixel
// clock before rgb_valid, so vga_pic can register the color and have it ready
// when the visible window opens.  Outside the request window both are 10'h3ff.
// ============================================================================
`timescale 1ns / 1ns

module vga_ctrl (
    input  wire        vga_clk,       // 25 MHz pixel clock
    input  wire        sys_rst_n,     // asynchronous reset, active low
    input  wire [15:0] pix_data,      // RGB565 color from vga_pic
    output wire [9:0]  pix_x,         // request x coordinate, 0..639
    output wire [9:0]  pix_y,         // request y coordinate, 0..479
    output wire        hsync,         // line sync, high during sync segment
    output wire        vsync,         // field sync, high during sync segment
    output wire [15:0] rgb            // RGB565 to the VGA port
);

    // ------------------------------------------------------------------
    // Horizontal timing, in pixel clocks
    // ------------------------------------------------------------------
    localparam [9:0] H_SYNC   = 10'd96;
    localparam [9:0] H_BACK   = 10'd40;
    localparam [9:0] H_LEFT   = 10'd8;
    localparam [9:0] H_VALID  = 10'd640;
    localparam [9:0] H_RIGHT  = 10'd8;
    localparam [9:0] H_FRONT  = 10'd8;
    localparam [9:0] H_TOTAL  = H_SYNC + H_BACK + H_LEFT + H_VALID
                              + H_RIGHT + H_FRONT;                 // 800

    // First and one-past-last addressable column.
    localparam [9:0] H_START  = H_SYNC + H_BACK + H_LEFT;          // 144
    localparam [9:0] H_END    = H_START + H_VALID;                 // 784

    // ------------------------------------------------------------------
    // Vertical timing, in line periods
    // ------------------------------------------------------------------
    localparam [9:0] V_SYNC   = 10'd2;
    localparam [9:0] V_BACK   = 10'd25;
    localparam [9:0] V_TOP    = 10'd8;
    localparam [9:0] V_VALID  = 10'd480;
    localparam [9:0] V_BOTTOM = 10'd8;
    localparam [9:0] V_FRONT  = 10'd2;
    localparam [9:0] V_TOTAL  = V_SYNC + V_BACK + V_TOP + V_VALID
                              + V_BOTTOM + V_FRONT;                // 525

    // First and one-past-last addressable row.
    localparam [9:0] V_START  = V_SYNC + V_BACK + V_TOP;           // 35
    localparam [9:0] V_END    = V_START + V_VALID;                 // 515

    reg [9:0] cnt_h;                  // pixel counter inside one line
    reg [9:0] cnt_v;                  // line counter inside one field

    wire rgb_valid;
    wire pix_data_req;

    // ------------------------------------------------------------------
    // Horizontal counter: 0 .. 799, wrap at the end of the line
    // ------------------------------------------------------------------
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_h <= 10'd0;
        else if (cnt_h == H_TOTAL - 10'd1)
            cnt_h <= 10'd0;
        else
            cnt_h <= cnt_h + 10'd1;
    end

    // ------------------------------------------------------------------
    // Vertical counter: advances once per completed line
    // ------------------------------------------------------------------
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_v <= 10'd0;
        else if ((cnt_v == V_TOTAL - 10'd1) && (cnt_h == H_TOTAL - 10'd1))
            cnt_v <= 10'd0;
        else if (cnt_h == H_TOTAL - 10'd1)
            cnt_v <= cnt_v + 10'd1;
        else
            cnt_v <= cnt_v;
    end

    // Sync pulses are high during the sync segment of each period.
    assign hsync = (cnt_h < H_SYNC) ? 1'b1 : 1'b0;
    assign vsync = (cnt_v < V_SYNC) ? 1'b1 : 1'b0;

    // ------------------------------------------------------------------
    // Addressable window and the one-pixel-early color request
    // ------------------------------------------------------------------
    assign rgb_valid = ((cnt_h >= H_START) && (cnt_h < H_END) &&
                        (cnt_v >= V_START) && (cnt_v < V_END)) ? 1'b1 : 1'b0;

    assign pix_data_req = ((cnt_h >= H_START - 10'd1) &&
                           (cnt_h <  H_END   - 10'd1) &&
                           (cnt_v >= V_START) &&
                           (cnt_v <  V_END)) ? 1'b1 : 1'b0;

    // The request runs one pixel ahead of the visible window.  Subtracting
    // H_START-1 therefore gives 0 at the first request and 639 at the last.
    assign pix_x = (pix_data_req == 1'b1)
                 ? (cnt_h - (H_START - 10'd1)) : 10'h3ff;
    assign pix_y = (pix_data_req == 1'b1)
                 ? (cnt_v - V_START) : 10'h3ff;

    // Outside the addressable window the monitor must receive black.
    assign rgb = (rgb_valid == 1'b1) ? pix_data : 16'h0000;

endmodule
