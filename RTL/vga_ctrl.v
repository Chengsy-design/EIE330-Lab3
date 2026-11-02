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


    localparam [9:0] H_SYNC   = 10'd96;
    localparam [9:0] H_BACK   = 10'd40;
    localparam [9:0] H_LEFT   = 10'd8;
    localparam [9:0] H_VALID  = 10'd640;
    localparam [9:0] H_RIGHT  = 10'd8;
    localparam [9:0] H_FRONT  = 10'd8;
    localparam [9:0] H_TOTAL  = H_SYNC + H_BACK + H_LEFT + H_VALID
                              + H_RIGHT + H_FRONT;                 


    localparam [9:0] H_START  = H_SYNC + H_BACK + H_LEFT;          
    localparam [9:0] H_END    = H_START + H_VALID;                 


    localparam [9:0] V_SYNC   = 10'd2;
    localparam [9:0] V_BACK   = 10'd25;
    localparam [9:0] V_TOP    = 10'd8;
    localparam [9:0] V_VALID  = 10'd480;
    localparam [9:0] V_BOTTOM = 10'd8;
    localparam [9:0] V_FRONT  = 10'd2;
    localparam [9:0] V_TOTAL  = V_SYNC + V_BACK + V_TOP + V_VALID
                              + V_BOTTOM + V_FRONT;                


    localparam [9:0] V_START  = V_SYNC + V_BACK + V_TOP;           
    localparam [9:0] V_END    = V_START + V_VALID;                

    reg [9:0] cnt_h;                 
    reg [9:0] cnt_v;                

    wire rgb_valid;
    wire pix_data_req;


    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_h <= 10'd0;
        else if (cnt_h == H_TOTAL - 10'd1)
            cnt_h <= 10'd0;
        else
            cnt_h <= cnt_h + 10'd1;
    end


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

    assign hsync = (cnt_h < H_SYNC) ? 1'b1 : 1'b0;
    assign vsync = (cnt_v < V_SYNC) ? 1'b1 : 1'b0;

 
    assign rgb_valid = ((cnt_h >= H_START) && (cnt_h < H_END) &&
                        (cnt_v >= V_START) && (cnt_v < V_END)) ? 1'b1 : 1'b0;

    assign pix_data_req = ((cnt_h >= H_START - 10'd1) &&
                           (cnt_h <  H_END   - 10'd1) &&
                           (cnt_v >= V_START) &&
                           (cnt_v <  V_END)) ? 1'b1 : 1'b0;


    assign pix_x = (pix_data_req == 1'b1)
                 ? (cnt_h - (H_START - 10'd1)) : 10'h3ff;
    assign pix_y = (pix_data_req == 1'b1)
                 ? (cnt_v - V_START) : 10'h3ff;


    assign rgb = (rgb_valid == 1'b1) ? pix_data : 16'h0000;

endmodule
