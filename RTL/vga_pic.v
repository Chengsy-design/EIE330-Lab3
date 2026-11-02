`timescale 1ns / 1ns

module vga_pic (
    input  wire        vga_clk,       // 25 MHz pixel clock
    input  wire        sys_rst_n,     // asynchronous reset, active low
    input  wire [9:0]  pix_x,         // request x coordinate
    input  wire [9:0]  pix_y,         // request y coordinate
    output reg  [15:0] pix_data       // RGB565 color for this pixel
);

-
    localparam [15:0] BG_COLOR = 16'h0088;   
    localparam [15:0] M_COLOR  = 16'hF800;   // red
    localparam [15:0] U_COLOR  = 16'h07E0;   // green
    localparam [15:0] S_COLOR  = 16'h07FF;   // cyan
    localparam [15:0] T_COLOR  = 16'hFFE0;   // yellow


    localparam [9:0] CHAR_Y0 = 10'd208;     
    localparam [9:0] BOX_W   = 10'd64;       

    localparam [9:0] M_X0 = 10'd144;
    localparam [9:0] U_X0 = 10'd240;
    localparam [9:0] S_X0 = 10'd336;
    localparam [9:0] T_X0 = 10'd432;


    // "M"
    localparam [7:0] M_ROW_0 = 8'b1100_0011;
    localparam [7:0] M_ROW_1 = 8'b1110_0111;
    localparam [7:0] M_ROW_2 = 8'b1111_1111;
    localparam [7:0] M_ROW_3 = 8'b1101_1011;
    localparam [7:0] M_ROW_4 = 8'b1100_0011;
    localparam [7:0] M_ROW_5 = 8'b1100_0011;
    localparam [7:0] M_ROW_6 = 8'b1100_0011;
    localparam [7:0] M_ROW_7 = 8'b1100_0011;

    // "U"
    localparam [7:0] U_ROW_0 = 8'b1100_0011;
    localparam [7:0] U_ROW_1 = 8'b1100_0011;
    localparam [7:0] U_ROW_2 = 8'b1100_0011;
    localparam [7:0] U_ROW_3 = 8'b1100_0011;
    localparam [7:0] U_ROW_4 = 8'b1100_0011;
    localparam [7:0] U_ROW_5 = 8'b1100_0011;
    localparam [7:0] U_ROW_6 = 8'b1110_0111;
    localparam [7:0] U_ROW_7 = 8'b0111_1110;

    // "S"
    localparam [7:0] S_ROW_0 = 8'b0111_1110;
    localparam [7:0] S_ROW_1 = 8'b1100_0011;
    localparam [7:0] S_ROW_2 = 8'b1100_0000;
    localparam [7:0] S_ROW_3 = 8'b0111_1110;
    localparam [7:0] S_ROW_4 = 8'b0000_0011;
    localparam [7:0] S_ROW_5 = 8'b0000_0011;
    localparam [7:0] S_ROW_6 = 8'b1100_0011;
    localparam [7:0] S_ROW_7 = 8'b0111_1110;

    // "T"
    localparam [7:0] T_ROW_0 = 8'b1111_1111;
    localparam [7:0] T_ROW_1 = 8'b1111_1111;
    localparam [7:0] T_ROW_2 = 8'b0011_1100;
    localparam [7:0] T_ROW_3 = 8'b0011_1100;
    localparam [7:0] T_ROW_4 = 8'b0011_1100;
    localparam [7:0] T_ROW_5 = 8'b0011_1100;
    localparam [7:0] T_ROW_6 = 8'b0011_1100;
    localparam [7:0] T_ROW_7 = 8'b0011_1100;


    wire in_char_row = (pix_y >= CHAR_Y0) && (pix_y < CHAR_Y0 + BOX_W);


    wire [5:0] char_y = pix_y[5:0] - CHAR_Y0[5:0];
    wire [5:0] dx_m   = pix_x[5:0] - M_X0[5:0];
    wire [5:0] dx_u   = pix_x[5:0] - U_X0[5:0];
    wire [5:0] dx_s   = pix_x[5:0] - S_X0[5:0];
    wire [5:0] dx_t   = pix_x[5:0] - T_X0[5:0];

    wire [2:0] col_m = 3'd7 - dx_m[5:3];
    wire [2:0] col_u = 3'd7 - dx_u[5:3];
    wire [2:0] col_s = 3'd7 - dx_s[5:3];
    wire [2:0] col_t = 3'd7 - dx_t[5:3];

    wire in_m_box = (pix_x >= M_X0) && (pix_x < M_X0 + BOX_W);
    wire in_u_box = (pix_x >= U_X0) && (pix_x < U_X0 + BOX_W);
    wire in_s_box = (pix_x >= S_X0) && (pix_x < S_X0 + BOX_W);
    wire in_t_box = (pix_x >= T_X0) && (pix_x < T_X0 + BOX_W);


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
                pix_data <= BG_COLOR;         
            end
        end else begin
            pix_data <= BG_COLOR;             
        end
    end

endmodule
