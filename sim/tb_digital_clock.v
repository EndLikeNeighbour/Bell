`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: tb_digital_clock
// Self-checking testbench for the Basys 3 digital clock.
// The reduced clock parameters make the 5 s / 3 s auto-page cycle fast to test.
//////////////////////////////////////////////////////////////////////////////////
module tb_digital_clock;
    reg clk = 0;
    reg btnc = 1;
    reg btnu = 0;
    reg btnd = 0;
    reg btnl = 0;
    reg btnr = 0;
    reg sw0 = 1;
    reg sw1 = 0;
    reg sw2 = 0;
    wire [3:0] an;
    wire [7:0] seg;
    wire ld0;
    wire ld1;
    integer errors = 0;
    integer cases = 0;

    digital_clock #(
        .CLK_FREQ_HZ(4),
        .DEBOUNCE_CYCLES(2),
        .SCAN_DIV(2),
        .AUTO_HH_SECONDS(5),
        .AUTO_MM_SECONDS(3)
    ) dut (
        .clk  (clk  ),
        .btnc (btnc ),
        .btnu (btnu ),
        .btnd (btnd ),
        .btnl (btnl ),
        .btnr (btnr ),
        .sw0  (sw0  ),
        .sw1  (sw1  ),
        .sw2  (sw2  ),
        .an   (an   ),
        .seg  (seg  ),
        .ld0  (ld0  ),
        .ld1  (ld1  )
    );

    always #5 clk = ~clk;

    task check_time;
        input [4:0] h;
        input [5:0] m;
        input [5:0] s;
        begin
            cases = cases + 1;
            if (dut.hour !== h || dut.minute !== m || dut.second !== s) begin
                errors = errors + 1;
                $display("FAIL time got %0d:%0d:%0d expected %0d:%0d:%0d",
                         dut.hour, dut.minute, dut.second, h, m, s);
            end else begin
                $display("PASS time %02d:%02d:%02d", dut.hour, dut.minute, dut.second);
            end
        end
    endtask

    task press;
        input integer id;
        begin
            @(negedge clk);
            case (id)
                0: btnu = 1;
                1: btnd = 1;
                2: btnl = 1;
                3: btnr = 1;
                default: begin end
            endcase
            repeat (8) @(posedge clk);
            @(negedge clk);
            case (id)
                0: btnu = 0;
                1: btnd = 0;
                2: btnl = 0;
                3: btnr = 0;
                default: begin end
            endcase
            repeat (8) @(posedge clk);
            #1;
        end
    endtask

    task reset_clock;
        begin
            @(negedge clk);
            btnc = 1;
            sw0 = 1;
            sw2 = 0;
            repeat (6) @(posedge clk);
            #1;
            check_time(0, 0, 0);
            @(negedge clk);
            btnc = 0;
            repeat (6) @(posedge clk);
        end
    endtask

    task check_dp;
        input [1:0] n;
        input [3:0] expected_an;
        input        expected_dp;
        begin
            @(negedge clk);
            while (dut.scan_sel !== n) @(negedge clk);
            #1;
            cases = cases + 1;
            if (an !== expected_an || seg[7] !== ~expected_dp) begin
                errors = errors + 1;
                $display("FAIL DP digit %0d: an=%b DP=%b expected an=%b DP=%b",
                         n, an, seg[7], expected_an, ~expected_dp);
            end else begin
                $display("PASS DP digit %0d: an=%b DP=%b", n, an, seg[7]);
            end
        end
    endtask

    task wait_clock_cycles;
        input integer count;
        begin
            repeat (count) @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $display("==== digital_clock self-test begin ====");

        // Reset and verify HH:MM with AN2 blinking on at even seconds.
        repeat (6) @(posedge clk);
        #1;
        check_time(0, 0, 0);
        @(negedge clk);
        btnc = 0;
        repeat (6) @(posedge clk);
        #1;
        check_dp(0, 4'b1110, 1'b0);
        check_dp(1, 4'b1101, 1'b0);
        check_dp(2, 4'b1011, 1'b1);
        check_dp(3, 4'b0111, 1'b0);

        // Odd seconds turn the AN2 separator dot off; AN1 remains off.
        @(negedge clk);
        dut.second = 6'd1;
        check_dp(1, 4'b1101, 1'b0);
        check_dp(2, 4'b1011, 1'b0);
        @(negedge clk);
        dut.second = 6'd0;

        // Set a non-zero time for the page checks while staying in setting mode.
        dut.hour = 5'd12;
        dut.minute = 6'd34;
        dut.second = 6'd0;
        check_time(12, 34, 0);
        cases = cases + 1;
        if (ld0 !== 1'b1 || ld1 !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL initial setting/page LEDs: ld0=%b ld1=%b", ld0, ld1);
        end else $display("PASS setting/page LEDs");

        // Leave setting mode and select MM:SS manually.
        @(negedge clk);
        sw0 = 0;
        repeat (6) @(posedge clk);
        press(3);
        cases = cases + 1;
        if (ld1 !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL manual right page selection");
        end else $display("PASS manual right page selection");

        // MM:SS has the middle two dots and the rightmost (seconds) dot on.
        check_dp(0, 4'b1110, 1'b1);
        check_dp(1, 4'b1101, 1'b0);
        check_dp(2, 4'b1011, 1'b1);
        check_dp(3, 4'b0111, 1'b0);

        // Enable SW2 auto cycling. It starts at HH:MM and preserves manual_page_sel.
        @(negedge clk);
        sw2 = 1;
        repeat (6) @(posedge clk);
        @(negedge clk);
        dut.auto_page_sel = 1'b0;
        dut.auto_elapsed = 0;
        dut.auto_sec_count = 0;
        dut.sec_count = 0;
        #1;
        cases = cases + 1;
        if (ld1 !== 1'b0 || dut.auto_page_sel !== 1'b0 || dut.auto_elapsed !== 0) begin
            errors = errors + 1;
            $display("FAIL auto-cycle start: ld1=%b page=%b elapsed=%0d",
                     ld1, dut.auto_page_sel, dut.auto_elapsed);
        end else $display("PASS auto-cycle start at HH:MM");

        // Left/right buttons during auto mode do not overwrite the manual page.
        press(2);
        cases = cases + 1;
        if (dut.manual_page_sel !== 1'b1 || ld1 !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL manual selection changed during auto mode");
        end else $display("PASS manual selection held during auto mode");

        // Verify entering setting mode pauses the automatic page timer.
        @(negedge clk);
        sw0 = 1;
        repeat (6) @(posedge clk);
        @(negedge clk);
        dut.auto_page_sel = 1'b0;
        dut.auto_elapsed = 2;
        dut.auto_sec_count = 1;
        wait_clock_cycles(12);
        cases = cases + 1;
        if (dut.auto_page_sel !== 1'b0 || dut.auto_elapsed !== 2 || dut.auto_sec_count !== 0) begin
            errors = errors + 1;
            $display("FAIL auto timer did not pause in setting mode");
        end else $display("PASS auto timer pauses in setting mode");
        @(negedge clk);
        sw0 = 0;
        repeat (6) @(posedge clk);
        @(negedge clk);
        dut.auto_page_sel = 1'b0;
        dut.auto_elapsed = 0;
        dut.auto_sec_count = 0;

        // Verify the exact five-second HH:MM boundary.  The auto counters are
        // set to the last count so one following one-second tick is the boundary.
        @(negedge clk);
        dut.auto_page_sel = 1'b0;
        dut.auto_elapsed = 5 - 2;
        dut.auto_sec_count = 4 - 1;
        wait_clock_cycles(1);
        cases = cases + 1;
        if (ld1 !== 1'b0 || dut.auto_page_sel !== 1'b0 || dut.auto_elapsed !== 5 - 1) begin
            errors = errors + 1;
            $display("FAIL HH:MM dwell before 5 s: ld1=%b page=%b elapsed=%0d",
                     ld1, dut.auto_page_sel, dut.auto_elapsed);
        end else $display("PASS HH:MM dwell before 5 s");

        @(negedge clk);
        dut.auto_elapsed = 5 - 1;
        dut.auto_sec_count = 4 - 1;
        wait_clock_cycles(1);
        cases = cases + 1;
        if (ld1 !== 1'b1 || dut.auto_page_sel !== 1'b1 || dut.auto_elapsed !== 0) begin
            errors = errors + 1;
            $display("FAIL auto switch HH:MM -> MM:SS at 5 s: ld1=%b page=%b elapsed=%0d",
                     ld1, dut.auto_page_sel, dut.auto_elapsed);
        end else $display("PASS auto switch HH:MM -> MM:SS at 5 s");

        // Verify the exact three-second MM:SS boundary.
        @(negedge clk);
        dut.auto_page_sel = 1'b1;
        dut.auto_elapsed = 3 - 2;
        dut.auto_sec_count = 4 - 1;
        wait_clock_cycles(1);
        cases = cases + 1;
        if (ld1 !== 1'b1 || dut.auto_page_sel !== 1'b1 || dut.auto_elapsed !== 3 - 1) begin
            errors = errors + 1;
            $display("FAIL MM:SS dwell before 3 s: ld1=%b page=%b elapsed=%0d",
                     ld1, dut.auto_page_sel, dut.auto_elapsed);
        end else $display("PASS MM:SS dwell before 3 s");

        @(negedge clk);
        dut.auto_elapsed = 3 - 1;
        dut.auto_sec_count = 4 - 1;
        wait_clock_cycles(1);
        cases = cases + 1;
        if (ld1 !== 1'b0 || dut.auto_page_sel !== 1'b0 || dut.auto_elapsed !== 0) begin
            errors = errors + 1;
            $display("FAIL auto switch MM:SS -> HH:MM at 3 s: ld1=%b page=%b elapsed=%0d",
                     ld1, dut.auto_page_sel, dut.auto_elapsed);
        end else $display("PASS auto switch MM:SS -> HH:MM at 3 s");

        // Disable SW2 and verify the previous manual MM:SS selection is restored.
        @(negedge clk);
        sw2 = 0;
        repeat (6) @(posedge clk);
        #1;
        cases = cases + 1;
        if (ld1 !== 1'b1 || dut.manual_page_sel !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL manual page restore after SW2 off: ld1=%b manual=%b",
                     ld1, dut.manual_page_sel);
        end else $display("PASS manual page restore after SW2 off");

        // Manual page change still works after auto mode is disabled.
        press(2);
        cases = cases + 1;
        if (ld1 !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL manual left page selection after auto mode");
        end else $display("PASS manual left page selection after auto mode");

        // Hours: decrement underflow, increment overflow, and ordinary +/- operations.
        reset_clock();
        @(negedge clk);
        sw0 = 1;
        repeat (6) @(posedge clk);
        press(1); check_time(23, 0, 0);
        press(0); check_time(0, 0, 0);
        press(0); check_time(1, 0, 0);
        press(1); check_time(0, 0, 0);

        // Minutes: exercise 00/59 wrap and normal adjustments.
        @(negedge clk);
        sw1 = 1;
        repeat (4) @(posedge clk);
        press(1); check_time(0, 59, 0);
        press(0); check_time(0, 0, 0);
        press(0); check_time(0, 1, 0);
        press(1); check_time(0, 0, 0);
        press(1); check_time(0, 59, 0);

        // The setting mode pauses the timer.
        wait_clock_cycles(32);
        check_time(0, 59, 0);

        // Run-mode carry and 24-hour rollover: force the counter to the
        // last second of each boundary, then check the next one-second tick.
        @(negedge clk);
        sw0 = 0;
        repeat (6) @(posedge clk);

        @(negedge clk);
        dut.hour = 5'd0;
        dut.minute = 6'd0;
        dut.second = 6'd59;
        dut.sec_count = 0;
        dut.auto_sec_count = 0;
        wait_clock_cycles(4);
        check_time(0, 1, 0);

        @(negedge clk);
        dut.hour = 5'd0;
        dut.minute = 6'd59;
        dut.second = 6'd59;
        dut.sec_count = 0;
        dut.auto_sec_count = 0;
        wait_clock_cycles(4);
        check_time(1, 0, 0);

        @(negedge clk);
        dut.hour = 5'd23;
        dut.minute = 6'd59;
        dut.second = 6'd59;
        dut.sec_count = 0;
        wait_clock_cycles(4);
        check_time(0, 0, 0);

        $display("----------------------------------------");
        if (errors == 0) $display("ALL TESTS PASSED (%0d checks)", cases);
        else $display("TEST FAILED: %0d of %0d checks", errors, cases);
        $finish;
    end
endmodule
