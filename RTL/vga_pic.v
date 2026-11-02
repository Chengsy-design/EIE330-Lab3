// ============================================================================
// EIE330 FPGA-based System Design - Lab 3-1  Simple VGA Display
// File        : vga_pic.v
// Contents    : character pixel source for "M U S T" on a 640x480 screen
//
// Font format
//   Every glyph is an 8x8 bitmap.  One 8-bit parameter holds one bitmap row,
//   MSB = leftmost pixel, 1 = paint with the character color, 0 = background.
//   The 8x8 bitmap is enlarged by 8 in both directions, so one bitmap pixel
//   becomes an 8x8 block on screen and one character occupies 64x64 pixels.
//
// Screen layout (pixel coordinates, origin at the top-left of the active area)
//   M box: x = 144..207, y = 208..271, red
//   U box: x = 240..303, y = 208..271, green
//   S box: x = 336..399, y = 208..271, cyan
//   T box: x = 432..495, y = 208..271, yellow
//   background: dark navy
//   The four 64-pixel boxes and three 32-pixel gaps form a 352-pixel row,
//   centred with 144-pixel left and right margins.
//
// Bit selection
//   char_x[5:3] is the bitmap column 0..7; the parameter is written MSB-first,
//   so the bit index is 7 - char_x[5:3].  char_y[5:3] selects the bitmap row.
//
// The lookup is inside the clocked block, exactly like the lecture color-bar
// example: the case statement becomes a multiplexer of constants and the
// selected color passes through the single register pix_data.  Every branch
// assigns pix_data, so no latch can be inferred.
// ============================================================================
`timescale 1ns / 1ns

module vga_pic (
    input  wire        vga_clk,       // 25 MHz pixel clock
    input  wire        sys_rst_n,     // asynchronous reset, active low
    input  wire [9:0]  pix_x,         // request x coordinate
    input  wire [9:0]  pix_y,         // request y coordinate
    output reg  [15:0] pix_data       // RGB565 color for this pixel
);

    // ------------------------------------------------------------------
    // Colors, RGB565: RRRRR GGGGGG BBBBB
    // ------------------------------------------------------------------
    localparam [15:0] BG_COLOR = 16'h0088;   // dark navy background
    localparam [15:0] M_COLOR  = 16'hF800;   // red
    localparam [15:0] U_COLOR  = 16'h07E0;   // green
    localparam [15:0] S_COLOR  = 16'h07FF;   // cyan
    localparam [15:0] T_COLOR  = 16'hFFE0;   // yellow

    // ------------------------------------------------------------------
    // Character boxes: origin and size on the active screen
    // ------------------------------------------------------------------
    localparam [9:0] CHAR_Y0 = 10'd208;      // top edge of every box
    localparam [9:0] BOX_W   = 10'd64;       // 8 bitmap pixels x scale 8

    localparam [9:0] M_X0 = 10'd144;
    localparam [9:0] U_X0 = 10'd240;
    localparam [9:0] S_X0 = 10'd336;
    localparam [9:0] T_X0 = 10'd432;

    // ------------------------------------------------------------------
    // 8x8 bitmaps, one parameter per row, MSB = leftmost pixel
    // ------------------------------------------------------------------
    // "M": the bitmap given in the lab handout
    localparam [7:0] M_ROW_0 = 8'b1100_0011;
    localparam [7:0] M_ROW_1 = 8'b1110_0111;
    localparam [7:0] M_ROW_2 = 8'b1111_1111;
    localparam [7:0] M_ROW_3 = 8'b1101_1011;
    localparam [7:0] M_ROW_4 = 8'b1100_0011;
    localparam [7:0] M_ROW_5 = 8'b1100_0011;
    localparam [7:0] M_ROW_6 = 8'b1100_0011;
    localparam [7:0] M_ROW_7 = 8'b1100_0011;

    // "U": two vertical strokes joined by a rounded bottom
    localparam [7:0] U_ROW_0 = 8'b1100_0011;
    localparam [7:0] U_ROW_1 = 8'b1100_0011;
    localparam [7:0] U_ROW_2 = 8'b1100_0011;
    localparam [7:0] U_ROW_3 = 8'b1100_0011;
    localparam [7:0] U_ROW_4 = 8'b1100_0011;
    localparam [7:0] U_ROW_5 = 8'b1100_0011;
    localparam [7:0] U_ROW_6 = 8'b1110_0111;
    localparam [7:0] U_ROW_7 = 8'b0111_1110;

    // "S": top bar, left stroke, middle bar, right stroke, bottom bar
    localparam [7:0] S_ROW_0 = 8'b0111_1110;
    localparam [7:0] S_ROW_1 = 8'b1100_0011;
    localparam [7:0] S_ROW_2 = 8'b1100_0000;
    localparam [7:0] S_ROW_3 = 8'b0111_1110;
    localparam [7:0] S_ROW_4 = 8'b0000_0011;
    localparam [7:0] S_ROW_5 = 8'b0000_0011;
    localparam [7:0] S_ROW_6 = 8'b1100_0011;
    localparam [7:0] S_ROW_7 = 8'b0111_1110;

    // "T": two-row top bar and a four-bit-wide central stem
    localparam [7:0] T_ROW_0 = 8'b1111_1111;
    localparam [7:0] T_ROW_1 = 8'b1111_1111;
    localparam [7:0] T_ROW_2 = 8'b0011_1100;
    localparam [7:0] T_ROW_3 = 8'b0011_1100;
    localparam [7:0] T_ROW_4 = 8'b0011_1100;
    localparam [7:0] T_ROW_5 = 8'b0011_1100;
    localparam [7:0] T_ROW_6 = 8'b0011_1100;
    localparam [7:0] T_ROW_7 = 8'b0011_1100;

    // ------------------------------------------------------------------
    // Position arithmetic
    // ------------------------------------------------------------------
    wire in_char_row = (pix_y >= CHAR_Y0) && (pix_y < CHAR_Y0 + BOX_W);

    // Offsets inside a box, 0..63.  Only bits [5:3] address the 8x8 bitmap:
    // the lower three bits select a pixel inside the 8x8 screen block produced
    // by the x8 scale, so they are deliberately not part of the lookup.
    /* verilator lint_off UNUSEDSIGNAL */
    wire [5:0] char_y = pix_y[5:0] - CHAR_Y0[5:0];
    wire [5:0] dx_m   = pix_x[5:0] - M_X0[5:0];
    wire [5:0] dx_u   = pix_x[5:0] - U_X0[5:0];
    wire [5:0] dx_s   = pix_x[5:0] - S_X0[5:0];
    wire [5:0] dx_t   = pix_x[5:0] - T_X0[5:0];
    /* verilator lint_on UNUSEDSIGNAL */

    // Bitmap bit index: the parameters are MSB-first.
    wire [2:0] col_m = 3'd7 - dx_m[5:3];
    wire [2:0] col_u = 3'd7 - dx_u[5:3];
    wire [2:0] col_s = 3'd7 - dx_s[5:3];
    wire [2:0] col_t = 3'd7 - dx_t[5:3];

    wire in_m_box = (pix_x >= M_X0) && (pix_x < M_X0 + BOX_W);
    wire in_u_box = (pix_x >= U_X0) && (pix_x < U_X0 + BOX_W);
    wire in_s_box = (pix_x >= S_X0) && (pix_x < S_X0 + BOX_W);
    wire in_t_box = (pix_x >= T_X0) && (pix_x < T_X0 + BOX_W);

    // ------------------------------------------------------------------
    // Pixel lookup: one clocked multiplexer, one register
    // ------------------------------------------------------------------
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            pix_data <= BG_COLOR;
        else if (in_char_row) begin
            if (in_m_box) begin
                case (char_y[5:3])
                    3'd0: pix_data <= M_ROW_0[col_m] ? M_COLOR : BG_COLOR;
                    3'd1: pix_data <= M_ROW_1[col_m] ? M_COLOR : BG_COLOR;
                    3'd2: pix_data <= M_ROW_2[col_m] ? M_COLOR : BG_COLOR;
                    3'd3: pix_data <= M_ROW_3[col_m] ? M_COLOR : BG_COLOR;
                    3'd4: pix_data <= M_ROW_4[col_m] ? M_COLOR : BG_COLOR;
                    3'd5: pix_data <= M_ROW_5[col_m] ? M_COLOR : BG_COLOR;
                    3'd6: pix_data <= M_ROW_6[col_m] ? M_COLOR : BG_COLOR;
                    3'd7: pix_data <= M_ROW_7[col_m] ? M_COLOR : BG_COLOR;
                    default: pix_data <= BG_COLOR;
                endcase
            end else if (in_u_box) begin
                case (char_y[5:3])
                    3'd0: pix_data <= U_ROW_0[col_u] ? U_COLOR : BG_COLOR;
                    3'd1: pix_data <= U_ROW_1[col_u] ? U_COLOR : BG_COLOR;
                    3'd2: pix_data <= U_ROW_2[col_u] ? U_COLOR : BG_COLOR;
                    3'd3: pix_data <= U_ROW_3[col_u] ? U_COLOR : BG_COLOR;
                    3'd4: pix_data <= U_ROW_4[col_u] ? U_COLOR : BG_COLOR;
                    3'd5: pix_data <= U_ROW_5[col_u] ? U_COLOR : BG_COLOR;
                    3'd6: pix_data <= U_ROW_6[col_u] ? U_COLOR : BG_COLOR;
                    3'd7: pix_data <= U_ROW_7[col_u] ? U_COLOR : BG_COLOR;
                    default: pix_data <= BG_COLOR;
                endcase
            end else if (in_s_box) begin
                case (char_y[5:3])
                    3'd0: pix_data <= S_ROW_0[col_s] ? S_COLOR : BG_COLOR;
                    3'd1: pix_data <= S_ROW_1[col_s] ? S_COLOR : BG_COLOR;
                    3'd2: pix_data <= S_ROW_2[col_s] ? S_COLOR : BG_COLOR;
                    3'd3: pix_data <= S_ROW_3[col_s] ? S_COLOR : BG_COLOR;
                    3'd4: pix_data <= S_ROW_4[col_s] ? S_COLOR : BG_COLOR;
                    3'd5: pix_data <= S_ROW_5[col_s] ? S_COLOR : BG_COLOR;
                    3'd6: pix_data <= S_ROW_6[col_s] ? S_COLOR : BG_COLOR;
                    3'd7: pix_data <= S_ROW_7[col_s] ? S_COLOR : BG_COLOR;
                    default: pix_data <= BG_COLOR;
                endcase
            end else if (in_t_box) begin
                case (char_y[5:3])
                    3'd0: pix_data <= T_ROW_0[col_t] ? T_COLOR : BG_COLOR;
                    3'd1: pix_data <= T_ROW_1[col_t] ? T_COLOR : BG_COLOR;
                    3'd2: pix_data <= T_ROW_2[col_t] ? T_COLOR : BG_COLOR;
                    3'd3: pix_data <= T_ROW_3[col_t] ? T_COLOR : BG_COLOR;
                    3'd4: pix_data <= T_ROW_4[col_t] ? T_COLOR : BG_COLOR;
                    3'd5: pix_data <= T_ROW_5[col_t] ? T_COLOR : BG_COLOR;
                    3'd6: pix_data <= T_ROW_6[col_t] ? T_COLOR : BG_COLOR;
                    3'd7: pix_data <= T_ROW_7[col_t] ? T_COLOR : BG_COLOR;
                    default: pix_data <= BG_COLOR;
                endcase
            end else begin
                pix_data <= BG_COLOR;          // inside a character row, between boxes
            end
        end else begin
            pix_data <= BG_COLOR;              // background above and below the boxes
        end
    end

endmodule
