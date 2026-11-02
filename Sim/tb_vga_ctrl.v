// ============================================================================
// EIE330 FPGA-based System Design - Lab 3-1
// Testbench   : tb_vga_ctrl
// Purpose     : verify the complete 640x480@60 timing of vga_ctrl
// Run         : iverilog -g2012 -Wall -o tb_vga_ctrl.vvp tb_vga_ctrl.v ../RTL/vga_ctrl.v
//               vvp tb_vga_ctrl.vvp
//
// Measured quantities
//   hsync period      800 x 40 ns = 32 000 ns
//   hsync pulse width  96 x 40 ns =  3 840 ns
//   vsync period      525 x 32 us = 16 800 000 ns
//   vsync pulse width    2 x 32 us =     64 000 ns
//   active window     first (0,0), last (639,479), 307 200 pixels per frame
//   request lead      pix_x = 1 and pix_y = 0 when rgb_valid first rises
//
// The simulation runs two full frames.  VCD recording is enabled only around
// the line start, one character row and the frame end, because a naive dump of
// 850 000 pixel clocks would be tens of megabytes.
// ============================================================================
`timescale 1ns / 1ns

module tb_vga_ctrl;

    reg         vga_clk   = 1'b0;
    reg         sys_rst_n = 1'b1;       // pulled low at t=5 ns, released at t=100 ns
    reg  [15:0] pix_data  = 16'hA5A5;   // recognizable test color

    wire [9:0]  pix_x;
    wire [9:0]  pix_y;
    wire        hsync;
    wire        vsync;
    wire [15:0] rgb;

    // Internal counters are probed for the coordinate checks.
    wire [9:0] cnt_h = dut.cnt_h;
    wire [9:0] cnt_v = dut.cnt_v;
    wire       rgb_valid   = dut.rgb_valid;
    wire       pix_data_req = dut.pix_data_req;

    integer errors        = 0;
    integer active_pixels = 0;
    integer frame_pixels  = 0;
    integer vsync_edges   = 0;
    integer outside_checks = 0;

    integer h_edges = 0;
    integer v_edges = 0;
    reg     h_width_ok = 1'b0;
    reg     v_width_ok = 1'b0;
    reg     seen_first = 1'b0;
    reg     seen_last  = 1'b0;
    reg     line_done  = 1'b0;
    reg     frame_done = 1'b0;
    integer frame_rows = 0;

    time h_rise = 0;
    time v_rise = 0;

    integer f_line;
    integer f_frame;

    reg dumping = 1'b0;

    vga_ctrl dut (
        .vga_clk   (vga_clk),
        .sys_rst_n (sys_rst_n),
        .pix_data  (pix_data),
        .pix_x     (pix_x),
        .pix_y     (pix_y),
        .hsync     (hsync),
        .vsync     (vsync),
        .rgb       (rgb)
    );

    always #20 vga_clk = ~vga_clk;      // 25 MHz

    // ------------------------------------------------------------------
    // hsync period and pulse width
    // ------------------------------------------------------------------
    always @(posedge hsync) begin
        if (sys_rst_n) begin
            if (h_edges > 0) begin
                if (($time - h_rise) !== 32000) begin
                    errors = errors + 1;
                    $display("FAIL hsync period %0t ns (expected 32000)", $time - h_rise);
                end
            end
            h_rise = $time;
            h_edges = h_edges + 1;
        end
    end

    always @(negedge hsync) begin
        if (sys_rst_n && h_edges > 0 && !h_width_ok) begin
            h_width_ok = 1'b1;
            if (($time - h_rise) !== 3840) begin
                errors = errors + 1;
                $display("FAIL hsync width %0t ns (expected 3840)", $time - h_rise);
            end else begin
                $display("hsync  period = 32000 ns, pulse width = %0t (expected 3840 ns)", $time - h_rise);
            end
        end
    end

    // ------------------------------------------------------------------
    // vsync period and pulse width
    // ------------------------------------------------------------------
    always @(posedge vsync) begin
        if (sys_rst_n) begin
            if (v_edges > 0) begin
                if (($time - v_rise) !== 16_800_000) begin
                    errors = errors + 1;
                    $display("FAIL vsync period %0t ns (expected 16800000)", $time - v_rise);
                end
            end
            v_rise = $time;
            v_edges = v_edges + 1;

            $display("VSYNC edge %0d: previous frame had %0d active pixels",
                     v_edges, frame_pixels);
            if (frame_pixels !== 307200) begin
                errors = errors + 1;
                $display("FAIL frame contains %0d active pixels (expected 307200)",
                         frame_pixels);
            end
            frame_pixels = 0;
        end
    end

    always @(negedge vsync) begin
        if (sys_rst_n && v_edges > 0 && !v_width_ok) begin
            v_width_ok = 1'b1;
            if (($time - v_rise) !== 64_000) begin
                errors = errors + 1;
                $display("FAIL vsync width %0t ns (expected 64000)", $time - v_rise);
            end else begin
                $display("vsync  period = 16800000 ns, pulse width = %0t (expected 64000 ns)", $time - v_rise);
            end
        end
    end

    // ------------------------------------------------------------------
    // Active-window checks, sample by sample
    // ------------------------------------------------------------------
    always @(posedge vga_clk) begin
        #1;                            // let nonblocking updates settle
        if (sys_rst_n) begin
            if (rgb_valid) begin
                active_pixels = active_pixels + 1;
                frame_pixels  = frame_pixels + 1;

                if (!seen_first) begin
                    seen_first = 1'b1;
                    if ((cnt_h !== 10'd144) || (cnt_v !== 10'd35)) begin
                        errors = errors + 1;
                        $display("FAIL first valid pixel at cnt %0d,%0d (expected 144,35)",
                                 cnt_h, cnt_v);
                    end
                    if ((pix_x !== 10'd1) || (pix_y !== 10'd0)) begin
                        errors = errors + 1;
                        $display("FAIL request lead at first valid pixel: pix_x=%0d pix_y=%0d",
                                 pix_x, pix_y);
                    end else begin
                        $display("first valid pixel: cnt_h=144 cnt_v=35, request pix_x=1 pix_y=0");
                    end
                end

                if (!seen_last && (cnt_h == 10'd783) && (cnt_v == 10'd514)) begin
                    seen_last = 1'b1;
                    $display("last valid pixel : cnt_h=783 cnt_v=514 -> screen (639,479)");
                end

                if (rgb !== pix_data) begin
                    errors = errors + 1;
                    $display("FAIL rgb=%h inside valid window, expected %h", rgb, pix_data);
                end
            end else begin
                outside_checks = outside_checks + 1;
                if (rgb !== 16'h0000) begin
                    errors = errors + 1;
                    $display("FAIL rgb=%h outside valid window", rgb);
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Data for the report figures
    // ------------------------------------------------------------------
    always @(posedge vga_clk) begin
        #1;
        if (sys_rst_n && !line_done && (cnt_v == 10'd243)) begin
            $fwrite(f_line, "%0d,%0d,%0d,%0d,%0d,%0d,%04x\n",
                    cnt_h, hsync, rgb_valid, pix_data_req, pix_x, pix_y, rgb);
            if (cnt_h == 10'd799)
                line_done = 1'b1;
        end

        if (sys_rst_n && (frame_rows < 525) && (cnt_h == 10'd0)) begin
            $fwrite(f_frame, "%0d,%0d,%0d,%0d\n",
                    cnt_v, vsync, rgb_valid,
                    ((cnt_v >= 10'd35) && (cnt_v < 10'd515)) ? 1'b1 : 1'b0);
            frame_rows = frame_rows + 1;
            if (frame_rows == 525)
                frame_done = 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // Short VCD windows: line start, character row, frame end
    // ------------------------------------------------------------------
    always @(posedge vga_clk) begin
        if (!dumping &&
            (((cnt_v == 10'd0)   && (cnt_h < 10'd200)) ||
             ((cnt_v == 10'd243) && (cnt_h >= 10'd130) && (cnt_h < 10'd180)) ||
             ((cnt_v == 10'd514) && (cnt_h > 10'd760)))) begin
            $dumpon;
            dumping = 1'b1;
        end else if (dumping &&
            !(((cnt_v == 10'd0)   && (cnt_h < 10'd200)) ||
              ((cnt_v == 10'd243) && (cnt_h >= 10'd130) && (cnt_h < 10'd180)) ||
              ((cnt_v == 10'd514) && (cnt_h > 10'd760)))) begin
            $dumpoff;
            dumping = 1'b0;
        end
    end

    initial begin
        f_line  = $fopen("line_timing.csv", "w");
        f_frame = $fopen("frame_timing.csv", "w");

        $dumpfile("tb_vga_ctrl.vcd");
        $dumpvars(0, tb_vga_ctrl);
        $dumpoff;

        $timeformat(-9, 0, " ns", 6);
        $display("=== Lab 3-1 vga_ctrl timing test ===");
        $display("pixel clock 25 MHz (40 ns), 640x480@60, two full frames");

        #5   sys_rst_n = 1'b0;         // create an active-low reset edge
        #95  sys_rst_n = 1'b1;         // release at t = 100 ns

        #33_900_000;                   // more than two complete frames

        $display("active pixels counted over the run: %0d", active_pixels);
        $display("outside-window samples checked  : %0d", outside_checks);
        $display("hsync edges / vsync edges       : %0d / %0d", h_edges, v_edges);

        if (!seen_first || !seen_last) begin
            errors = errors + 1;
            $display("FAIL: valid window endpoints were not both observed");
        end
        if (!h_width_ok || !v_width_ok) begin
            errors = errors + 1;
            $display("FAIL: sync pulse widths were not both measured");
        end
        if (h_edges < 1000) begin
            errors = errors + 1;
            $display("FAIL: too few hsync edges (%0d)", h_edges);
        end

        if (errors == 0)
            $display("RESULT: PASS (800 x 525 timing, 307200 pixels/frame)");
        else
            $display("RESULT: FAIL (%0d errors)", errors);

        $fclose(f_line);
        $fclose(f_frame);
        $finish;
    end

endmodule
