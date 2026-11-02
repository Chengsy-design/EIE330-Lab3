`timescale 1ns / 1ns

module tb_pll;

    reg  sys_clk   = 1'b0;
    reg  sys_rst_n = 1'b1;
    wire vga_clk;

    integer errors        = 0;
    integer periods       = 0;
    integer reset_samples = 0;
    time    t_last_rise   = 0;

    integer fcsv;

    pll dut (
        .sys_clk   (sys_clk),
        .sys_rst_n (sys_rst_n),
        .vga_clk   (vga_clk)
    );


    always #10 sys_clk = ~sys_clk;

    initial fcsv = $fopen("pll_clocks.csv", "w");
    always @(sys_clk or vga_clk or sys_rst_n) begin
        if (fcsv != 0)
            $fwrite(fcsv, "%0t,%b,%b,%b\n", $time, sys_clk, vga_clk, sys_rst_n);
    end


    always @(posedge vga_clk) begin
        if (!sys_rst_n) begin
            reset_samples = reset_samples + 1;
            errors = errors + 1;                 
        end else begin
            if (periods > 0) begin
                if (($time - t_last_rise) !== 40) begin
                    errors = errors + 1;
                    $display("FAIL: vga_clk period %0t, expected 40 ns", $time - t_last_rise);
                end
            end
            t_last_rise = $time;
            if (periods < 10)
                $display("vga_clk rising edge %0d at t=%0t", periods, $time);
            periods = periods + 1;
        end
    end

    always @(negedge vga_clk) begin
        if (sys_rst_n && t_last_rise != 0) begin
            if (($time - t_last_rise) !== 20) begin
                errors = errors + 1;
                $display("FAIL: vga_clk high time %0t, expected 20 ns", $time - t_last_rise);
            end
        end
    end

    initial begin
        $dumpfile("tb_pll.vcd");
        $dumpvars(0, tb_pll);

        $timeformat(-9, 0, " ns", 6);
        $display("=== Lab 3-1 pll divide-by-2 test ===");
        $display("sys_clk period = 20 ns (50 MHz)");

        #15 sys_rst_n = 1'b0;         
        #50 sys_rst_n = 1'b1;         

        #500;                          

        $display("vga_clk periods measured: %0d", periods - 1);
        $display("vga_clk frequency        : 25 MHz (period 40 ns)");

        if (periods < 11) begin
            errors = errors + 1;
            $display("FAIL: only %0d vga_clk rising edges", periods);
        end
        if (reset_samples != 0) begin
            $display("FAIL: vga_clk rose %0d times during reset", reset_samples);
        end

        if (errors == 0)
            $display("RESULT: PASS (divide-by-2, 25 MHz, reset holds clock low)");
        else
            $display("RESULT: FAIL (%0d errors)", errors);

        $fclose(fcsv);
        $finish;
    end

endmodule
