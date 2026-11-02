// ============================================================================
// EIE330 FPGA-based System Design - Lab 3-1
// Testbench   : tb_vga_pic
// Purpose     : verify every pixel of all four 64x64 character boxes
// Run         : iverilog -g2012 -Wall -o tb_vga_pic.vvp tb_vga_pic.v ../RTL/vga_pic.v
//               vvp tb_vga_pic.vvp
//
// The reference model is written differently from the DUT: it stores each
// glyph as one 64-bit vector and extracts a row with a variable part-select,
// while the DUT uses one parameter per row and a case statement.  Both must
// produce identical colors for all 4 x 64 x 64 = 16 384 box pixels.
// ============================================================================
`timescale 1ns / 1ns

module tb_vga_pic;

    localparam [15:0] BG = 16'h0088;
    localparam [15:0] MC = 16'hF800;
    localparam [15:0] UC = 16'h07E0;
    localparam [15:0] SC = 16'h07FF;
    localparam [15:0] TC = 16'hFFE0;

    // 8 rows per glyph, MSB byte = row 0
    localparam [63:0] M_FONT = 64'hC3E7FFDBC3C3C3C3;
    localparam [63:0] U_FONT = 64'hC3C3C3C3C3C3E77E;
    localparam [63:0] S_FONT = 64'h7EC3C07E0303C37E;
    localparam [63:0] T_FONT = 64'hFFFF3C3C3C3C3C3C;

    reg         vga_clk   = 1'b0;
    reg         sys_rst_n = 1'b1;
    reg  [9:0]  pix_x     = 10'd0;
    reg  [9:0]  pix_y     = 10'd0;
    wire [15:0] pix_data;

    integer errors = 0;
    integer checks = 0;
    integer c, xx, yy, row;
    integer X0 [0:3];
    integer check_x [0:13];
    integer check_y [0:13];
    reg [15:0] expected;

    integer fpic;

    vga_pic dut (
        .vga_clk   (vga_clk),
        .sys_rst_n (sys_rst_n),
        .pix_x     (pix_x),
        .pix_y     (pix_y),
        .pix_data  (pix_data)
    );

    always #20 vga_clk = ~vga_clk;      // 25 MHz

    // ------------------------------------------------------------------
    // Independent reference model
    // ------------------------------------------------------------------
    function [15:0] ref_pixel;
        input integer x;
        input integer y;
        integer dx, dy, r, col;
        reg [7:0] bits;
        begin
            ref_pixel = BG;
            if ((y >= 208) && (y < 272)) begin
                dy  = y - 208;
                r   = dy / 8;
                if ((x >= 144) && (x < 208)) begin
                    dx = x - 144; col = dx / 8;
                    bits = M_FONT[63 - r*8 -: 8];
                    ref_pixel = bits[7 - col] ? MC : BG;
                end else if ((x >= 240) && (x < 304)) begin
                    dx = x - 240; col = dx / 8;
                    bits = U_FONT[63 - r*8 -: 8];
                    ref_pixel = bits[7 - col] ? UC : BG;
                end else if ((x >= 336) && (x < 400)) begin
                    dx = x - 336; col = dx / 8;
                    bits = S_FONT[63 - r*8 -: 8];
                    ref_pixel = bits[7 - col] ? SC : BG;
                end else if ((x >= 432) && (x < 496)) begin
                    dx = x - 432; col = dx / 8;
                    bits = T_FONT[63 - r*8 -: 8];
                    ref_pixel = bits[7 - col] ? TC : BG;
                end
            end
        end
    endfunction

    initial begin
        X0[0] = 144; X0[1] = 240; X0[2] = 336; X0[3] = 432;
    end

    initial begin
        fpic = $fopen("pic_pixels.csv", "w");
        $dumpfile("tb_vga_pic.vcd");
        $dumpvars(0, tb_vga_pic);

        $timeformat(-9, 0, " ns", 6);
        $display("=== Lab 3-1 vga_pic bitmap test ===");

        #5   sys_rst_n = 1'b0;
        #70  sys_rst_n = 1'b1;         // release at t = 75 ns

        // Every pixel of every character box.
        for (c = 0; c < 4; c = c + 1) begin
            for (yy = 0; yy < 64; yy = yy + 1) begin
                for (xx = 0; xx < 64; xx = xx + 1) begin
                    @(negedge vga_clk);
                    pix_x = X0[c] + xx;
                    pix_y = 208 + yy;
                    @(posedge vga_clk);
                    #1;
                    expected = ref_pixel(X0[c] + xx, 208 + yy);
                    checks = checks + 1;
                    if (pix_data !== expected) begin
                        errors = errors + 1;
                        if (errors <= 12)
                            $display("FAIL box %0d at (%0d,%0d): got %h expected %h",
                                     c, X0[c] + xx, 208 + yy, pix_data, expected);
                    end
                end
            end
        end

        // Pixels just outside every box and in the gaps must be background.
        check_x[0] = 0;    check_y[0] = 0;
        check_x[1] = 143;  check_y[1] = 208;
        check_x[2] = 208;  check_y[2] = 208;
        check_x[3] = 239;  check_y[3] = 208;
        check_x[4] = 304;  check_y[4] = 208;
        check_x[5] = 335;  check_y[5] = 208;
        check_x[6] = 400;  check_y[6] = 208;
        check_x[7] = 431;  check_y[7] = 208;
        check_x[8] = 496;  check_y[8] = 208;
        check_x[9] = 144;  check_y[9] = 207;
        check_x[10] = 144; check_y[10] = 272;
        check_x[11] = 320; check_y[11] = 240;
        check_x[12] = 639; check_y[12] = 479;
        check_x[13] = 100; check_y[13] = 100;

        for (c = 0; c < 14; c = c + 1) begin
            @(negedge vga_clk);
            pix_x = check_x[c];
            pix_y = check_y[c];
            @(posedge vga_clk);
            #1;
            checks = checks + 1;
            if (pix_data !== BG) begin
                errors = errors + 1;
                $display("FAIL outside pixel (%0d,%0d): got %h expected %h",
                         check_x[c], check_y[c], pix_data, BG);
            end
        end

        // Data for the pixel-generation figure: first screen row of glyph
        // rows 0, 2 and 3 of the letter M.
        for (row = 0; row < 3; row = row + 1) begin
            for (xx = 0; xx < 64; xx = xx + 1) begin
                @(negedge vga_clk);
                pix_x = 144 + xx;
                pix_y = 208 + row*8;
                @(posedge vga_clk);
                #1;
                $fwrite(fpic, "%0d,%0d,%04x,%04x\n",
                        row, xx, pix_data, ref_pixel(144 + xx, 208 + row*8));
            end
        end

        $display("box pixels checked      : %0d", checks - 14);
        $display("outside pixels checked  : 14");
        $display("total mismatches        : %0d", errors);
        if (checks !== (16384 + 14)) begin
            errors = errors + 1;
            $display("FAIL: check count %0d, expected %0d", checks, 16384 + 14);
        end

        if (errors == 0)
            $display("RESULT: PASS (16384 box pixels + 14 outside pixels)");
        else
            $display("RESULT: FAIL (%0d errors)", errors);

        $fclose(fpic);
        $finish;
    end

endmodule
