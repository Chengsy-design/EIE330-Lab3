// ============================================================================
// EIE330 FPGA-based System Design - Lab 3-1
// Testbench   : tb_vga_display_top
// Purpose     : full-system check of vga_display_top
// Run         : iverilog -g2012 -Wall -o tb_vga_display_top.vvp \
//                   tb_vga_display_top.v ../RTL/vga_display_top.v \
//                   ../RTL/pll.v ../RTL/vga_ctrl.v ../RTL/vga_pic.v
//               vvp tb_vga_display_top.vvp
//
// What is checked
//   1. While sys_rst_n is low, rgb is 0 and both syncs stay high.
//   2. In every active frame, all 307 200 pixels match an independent
//      reference model of the four glyphs (64-bit font vectors + variable
//      part-select, not the DUT case/parameter lookup).
//   3. The first active pixel is (0,0) and the last is (639,479).
//   4. Twenty screen positions (glyph strokes, holes, gaps, background) are
//      probed and printed as a table.
//   5. After a mid-frame reset, the first active pixel is again (0,0) and the
//      first character pixel is correct.
//
// Side products
//   frame.ppm        P6 image of frame 2, 640x480, written from rgb samples
//   m_row0.csv       rgb on screen row y=208 (M glyph row 0), x=0..639
//   m_row2.csv       rgb on screen row y=226 (M glyph row 2), x=0..639
//   reset_window.csv reset assert/release window for the report figure
//   tb_vga_display_top.vcd  short windows only
// ============================================================================
`timescale 1ns / 1ns

module tb_vga_display_top;

    localparam [15:0] BG = 16'h0088;
    localparam [15:0] MC = 16'hF800;
    localparam [15:0] UC = 16'h07E0;
    localparam [15:0] SC = 16'h07FF;
    localparam [15:0] TC = 16'hFFE0;

    localparam [63:0] M_FONT = 64'hC3E7FFDBC3C3C3C3;
    localparam [63:0] U_FONT = 64'hC3C3C3C3C3C3E77E;
    localparam [63:0] S_FONT = 64'h7EC3C07E0303C37E;
    localparam [63:0] T_FONT = 64'hFFFF3C3C3C3C3C3C;

    localparam integer NP = 20;

    reg  sys_clk   = 1'b0;
    reg  sys_rst_n = 1'b1;

    wire hsync;
    wire vsync;
    wire [15:0] rgb;

    // Internal probes used by the checker
    wire        vga_clk     = dut.vga_clk;
    wire [9:0]  cnt_h       = dut.u_vga_ctrl.cnt_h;
    wire [9:0]  cnt_v       = dut.u_vga_ctrl.cnt_v;
    wire        rgb_valid   = dut.u_vga_ctrl.rgb_valid;
    wire [9:0]  pix_x       = dut.u_vga_ctrl.pix_x;
    wire [9:0]  pix_y       = dut.u_vga_ctrl.pix_y;

    integer errors       = 0;
    integer active_pixels = 0;
    integer outside_checks = 0;
    integer reset_checks = 0;
    integer cap_pixels   = 0;
    integer post_reset_pixels = 0;
    integer frame_pixels = 0;
    integer vsync_edges  = 0;
    integer frame_no     = 0;
    integer x, y, i;
    reg [15:0] expected;

    reg seen_first       = 1'b0;
    reg seen_last        = 1'b0;
    reg seen_post_first  = 1'b0;
    reg seen_post_char   = 1'b0;
    reg post_reset       = 1'b0;
    reg reset_log        = 1'b0;
    reg dumping          = 1'b0;

    integer PX [0:NP-1];
    integer PY [0:NP-1];
    reg [15:0] PACT [0:NP-1];

    integer fppm, frow0, frow2, freset;

    vga_display_top dut (
        .sys_clk   (sys_clk),
        .sys_rst_n (sys_rst_n),
        .hsync     (hsync),
        .vsync     (vsync),
        .rgb       (rgb)
    );

    always #10 sys_clk = ~sys_clk;      // 50 MHz board clock

    // ------------------------------------------------------------------
    // Independent reference model
    // ------------------------------------------------------------------
    function [15:0] ref_pixel;
        input integer rx;
        input integer ry;
        integer dx, dy, r, col;
        reg [7:0] bits;
        begin
            ref_pixel = BG;
            if ((ry >= 208) && (ry < 272)) begin
                dy = ry - 208;
                r  = dy / 8;
                if ((rx >= 144) && (rx < 208)) begin
                    dx = rx - 144; col = dx / 8;
                    bits = M_FONT[63 - r*8 -: 8];
                    ref_pixel = bits[7 - col] ? MC : BG;
                end else if ((rx >= 240) && (rx < 304)) begin
                    dx = rx - 240; col = dx / 8;
                    bits = U_FONT[63 - r*8 -: 8];
                    ref_pixel = bits[7 - col] ? UC : BG;
                end else if ((rx >= 336) && (rx < 400)) begin
                    dx = rx - 336; col = dx / 8;
                    bits = S_FONT[63 - r*8 -: 8];
                    ref_pixel = bits[7 - col] ? SC : BG;
                end else if ((rx >= 432) && (rx < 496)) begin
                    dx = rx - 432; col = dx / 8;
                    bits = T_FONT[63 - r*8 -: 8];
                    ref_pixel = bits[7 - col] ? TC : BG;
                end
            end
        end
    endfunction

    // ------------------------------------------------------------------
    // Probe coordinates
    // ------------------------------------------------------------------
    initial begin
        PX[0]=144;  PY[0]=208;    // M row 0, column 0, bitmap bit 7 = 1
        PX[1]=152;  PY[1]=208;    // M row 0, column 1, bit 6 = 1
        PX[2]=160;  PY[2]=208;    // M row 0, column 2, bit 5 = 0
        PX[3]=200;  PY[3]=208;    // M row 0, column 7, bit 0 = 1
        PX[4]=151;  PY[4]=226;    // M row 2 (all ones), column 0
        PX[5]=240;  PY[5]=208;    // U row 0, column 0
        PX[6]=303;  PY[6]=208;    // U row 0, column 7
        PX[7]=336;  PY[7]=208;    // S row 0, column 0 (bit 7 = 0)
        PX[8]=344;  PY[8]=208;    // S row 0, column 1 (bit 6 = 1)
        PX[9]=432;  PY[9]=208;    // T row 0, column 0 (top bar)
        PX[10]=432; PY[10]=240;   // T row 4, column 0 (left of stem)
        PX[11]=464; PY[11]=240;   // T row 4, column 4 (inside stem)
        PX[12]=100; PY[12]=100;   // background, above the boxes
        PX[13]=639; PY[13]=479;   // last pixel of the active window
        PX[14]=143; PY[14]=208;   // one pixel left of M
        PX[15]=208; PY[15]=208;   // one pixel right of M
        PX[16]=239; PY[16]=208;   // one pixel left of U
        PX[17]=304; PY[17]=208;   // one pixel right of U
        PX[18]=144; PY[18]=207;   // one row above M
        PX[19]=144; PY[19]=272;   // one row below M
    end

    // ------------------------------------------------------------------
    // Reset check: sys_clk keeps running while vga_clk is frozen low
    // ------------------------------------------------------------------
    always @(posedge sys_clk) begin
        #1;
        if (!sys_rst_n) begin
            reset_checks = reset_checks + 1;
            if (rgb !== 16'h0000) begin
                errors = errors + 1;
                $display("FAIL reset: rgb=%h while sys_rst_n=0", rgb);
            end
            if ((hsync !== 1'b1) || (vsync !== 1'b1)) begin
                errors = errors + 1;
                $display("FAIL reset: hsync=%b vsync=%b while sys_rst_n=0", hsync, vsync);
            end
        end
    end

    // ------------------------------------------------------------------
    // Frame accounting
    // ------------------------------------------------------------------
    always @(posedge vsync) begin
        if (sys_rst_n) begin        // ignore edges created by reset itself
            vsync_edges = vsync_edges + 1;
            $display("VSYNC edge %0d at %0t: previous frame = %0d active pixels",
                     vsync_edges, $time, frame_pixels);
            if ((vsync_edges <= 2) && (frame_pixels !== 307200)) begin
                errors = errors + 1;
                $display("FAIL: frame had %0d active pixels, expected 307200", frame_pixels);
            end
            frame_pixels = 0;
            frame_no = vsync_edges;
        end
    end

    // ------------------------------------------------------------------
    // Pixel-by-pixel checker, probe sampler and image capture
    // ------------------------------------------------------------------
    always @(posedge vga_clk) begin
        #1;
        if (sys_rst_n) begin
            if (rgb_valid) begin
                x = cnt_h - 10'd144;
                y = cnt_v - 10'd35;
                active_pixels = active_pixels + 1;
                frame_pixels  = frame_pixels + 1;

                expected = ref_pixel(x, y);
                if (rgb !== expected) begin
                    errors = errors + 1;
                    if (errors <= 20)
                        $display("FAIL pixel (%0d,%0d): rgb=%h expected %h",
                                 x, y, rgb, expected);
                end

                if (!seen_first) begin
                    seen_first = 1'b1;
                    if ((x !== 0) || (y !== 0)) begin
                        errors = errors + 1;
                        $display("FAIL first active pixel (%0d,%0d), expected (0,0)", x, y);
                    end
                end

                if ((x == 639) && (y == 479))
                    seen_last = 1'b1;

                if (post_reset) begin
                    post_reset_pixels = post_reset_pixels + 1;
                    if (!seen_post_first) begin
                        seen_post_first = 1'b1;
                        if ((x !== 0) || (y !== 0)) begin
                            errors = errors + 1;
                            $display("FAIL first pixel after reset (%0d,%0d)", x, y);
                        end
                    end
                    if ((x == 144) && (y == 208)) begin
                        seen_post_char = 1'b1;
                        if (rgb !== MC) begin
                            errors = errors + 1;
                            $display("FAIL first character pixel after reset: %h", rgb);
                        end
                    end
                end

                if (frame_no == 1) begin
                    // P6 pixel bytes, MSB-aligned RGB565 expansion
                    $fwrite(fppm, "%c%c%c",
                            {rgb[15:11], rgb[15:13]},
                            {rgb[10:5],  rgb[10:9]},
                            {rgb[4:0],   rgb[4:2]});
                    cap_pixels = cap_pixels + 1;

                    for (i = 0; i < NP; i = i + 1)
                        if ((x == PX[i]) && (y == PY[i]))
                            PACT[i] = rgb;

                    if (y == 208)
                        $fwrite(frow0, "%0d,%04x\n", x, rgb);
                    if (y == 226)
                        $fwrite(frow2, "%0d,%04x\n", x, rgb);
                end
            end else begin
                outside_checks = outside_checks + 1;
                if (rgb !== 16'h0000) begin
                    errors = errors + 1;
                    if (errors <= 20)
                        $display("FAIL outside window: rgb=%h at cnt %0d,%0d",
                                 rgb, cnt_h, cnt_v);
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Reset-window log (sys_clk based, because vga_clk is frozen in reset)
    // ------------------------------------------------------------------
    always @(posedge sys_clk) begin
        #1;
        if (reset_log)
            $fwrite(freset, "%0t,%b,%b,%b,%b,%04x,%b,%0d,%0d\n",
                    $time, sys_rst_n, hsync, vsync, rgb_valid, rgb, vga_clk,
                    cnt_h, cnt_v);
    end

    // ------------------------------------------------------------------
    // Short VCD windows
    // ------------------------------------------------------------------
    always @(posedge vga_clk) begin
        if (!dumping &&
            (reset_log ||
             ((frame_no == 1) && (cnt_v == 10'd243) &&
              (cnt_h >= 10'd130) && (cnt_h < 10'd180)))) begin
            $dumpon;
            dumping = 1'b1;
        end else if (dumping &&
            !(reset_log ||
              ((frame_no == 1) && (cnt_v == 10'd243) &&
               (cnt_h >= 10'd130) && (cnt_h < 10'd180)))) begin
            $dumpoff;
            dumping = 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------------
    initial begin
        PACT[0]=0; PACT[1]=0; PACT[2]=0; PACT[3]=0; PACT[4]=0;
        PACT[5]=0; PACT[6]=0; PACT[7]=0; PACT[8]=0; PACT[9]=0;
        PACT[10]=0; PACT[11]=0; PACT[12]=0; PACT[13]=0; PACT[14]=0;
        PACT[15]=0; PACT[16]=0; PACT[17]=0; PACT[18]=0; PACT[19]=0;

        fppm   = $fopen("frame.ppm", "wb");
        frow0  = $fopen("m_row0.csv", "w");
        frow2  = $fopen("m_row2.csv", "w");
        freset = $fopen("reset_window.csv", "w");
        $fwrite(fppm, "P6\n640 480\n255\n");

        $dumpfile("tb_vga_display_top.vcd");
        $dumpvars(0, tb_vga_display_top);
        $dumpoff;

        $timeformat(-9, 0, " ns", 6);
        $display("=== Lab 3-1 vga_display_top full-system test ===");
        $display("50 MHz system clock, 640x480@60, frame = 16.8 ms");

        #5   sys_rst_n = 1'b0;           // create an active-low reset edge
        #295 sys_rst_n = 1'b1;           // release at t = 300 ns

        // Two clean frames.  VSYNC edges occur at about 16.8 and 33.6 ms.
        #33_699_675;                     // t = 33.700 ms

        // Mid-frame reset: hold low for 2 us, release, then observe a
        // complete new frame up to the first character row.
        reset_log = 1'b1;
        sys_rst_n = 1'b0;
        #2_000;
        sys_rst_n = 1'b1;
        post_reset = 1'b1;
        #200_000;                        // keep logging the release
        reset_log  = 1'b0;

        #17_000_000;                     // one complete frame after reset
        post_reset = 1'b0;

        $display("active pixels checked       : %0d", active_pixels);
        $display("outside-window samples      : %0d", outside_checks);
        $display("reset samples checked       : %0d", reset_checks);
        $display("frame-2 pixels captured     : %0d", cap_pixels);
        $display("post-reset pixels checked   : %0d", post_reset_pixels);

        if (cap_pixels !== 307200) begin
            errors = errors + 1;
            $display("FAIL: captured %0d pixels, expected 307200", cap_pixels);
        end
        if (!seen_first || !seen_last) begin
            errors = errors + 1;
            $display("FAIL: active window endpoints not both observed");
        end
        if (!seen_post_first || !seen_post_char) begin
            errors = errors + 1;
            $display("FAIL: display did not restart correctly after reset");
        end
        if (post_reset_pixels < 307200) begin
            errors = errors + 1;
            $display("FAIL: only %0d pixels checked after reset", post_reset_pixels);
        end
        if (reset_checks < 50) begin
            errors = errors + 1;
            $display("FAIL: only %0d reset samples checked", reset_checks);
        end

        $display("---- probe table (frame 2) ----");
        for (i = 0; i < NP; i = i + 1) begin
            expected = ref_pixel(PX[i], PY[i]);
            $display("probe %2d (%3d,%3d): expected %h actual %h %s",
                     i, PX[i], PY[i], expected, PACT[i],
                     (PACT[i] === expected) ? "PASS" : "FAIL");
            if (PACT[i] !== expected)
                errors = errors + 1;
        end

        if (errors == 0)
            $display("RESULT: PASS (all %0d active pixels across three frames matched)", active_pixels);
        else
            $display("RESULT: FAIL (%0d errors)", errors);

        $fclose(fppm);
        $fclose(frow0);
        $fclose(frow2);
        $fclose(freset);
        $finish;
    end

endmodule
