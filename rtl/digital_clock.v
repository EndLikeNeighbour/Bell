`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: digital_clock
// Basys 3 24-hour clock with setting, page switching and 4-digit display.
// Display outputs: AN active-low; seg={DP,CA,CB,CC,CD,CE,CF,CG}, active-low.
//////////////////////////////////////////////////////////////////////////////////
module digital_clock #(
    parameter integer CLK_FREQ_HZ = 100000000,
    parameter integer DEBOUNCE_CYCLES = 1000000,
    parameter integer SCAN_DIV = 25000,
    parameter integer AUTO_HH_SECONDS = 5,
    parameter integer AUTO_MM_SECONDS = 3
)(
    input  wire       clk,
    input  wire       btnc,
    input  wire       btnu,
    input  wire       btnd,
    input  wire       btnl,
    input  wire       btnr,
    input  wire       sw0,
    input  wire       sw1,
    input  wire       sw2,
    output reg  [3:0] an,
    output reg  [7:0] seg,
    output reg        ld0,
    output reg        ld1
);

    localparam integer DB_LIMIT = (DEBOUNCE_CYCLES < 1) ? 1 : DEBOUNCE_CYCLES;
    localparam integer SCAN_LIMIT = (SCAN_DIV < 1) ? 1 : SCAN_DIV;
    localparam integer AUTO_HH_LIMIT = (AUTO_HH_SECONDS < 1) ? 1 : AUTO_HH_SECONDS;
    localparam integer AUTO_MM_LIMIT = (AUTO_MM_SECONDS < 1) ? 1 : AUTO_MM_SECONDS;
    localparam integer AUTO_PHASE_MAX = (AUTO_HH_LIMIT > AUTO_MM_LIMIT) ? AUTO_HH_LIMIT : AUTO_MM_LIMIT;
    localparam integer AUTO_PHASE_W = (AUTO_PHASE_MAX <= 1) ? 1 : $clog2(AUTO_PHASE_MAX);
    localparam integer SEC_COUNT_W = (CLK_FREQ_HZ <= 2) ? 1 : $clog2(CLK_FREQ_HZ);
    localparam integer DB_COUNT_W = (DB_LIMIT <= 1) ? 1 : $clog2(DB_LIMIT + 1);
    localparam integer SCAN_COUNT_W = (SCAN_LIMIT <= 1) ? 1 : $clog2(SCAN_LIMIT);

    reg btnc_meta;
    reg btnc_sync;
    reg sw0_meta;
    reg sw0_sync;
    reg sw1_meta;
    reg sw1_sync;
    reg sw2_meta;
    reg sw2_sync;
    reg sw2_sync_d;
    reg [3:0] key_meta;
    reg [3:0] key_sync;
    reg [3:0] key_state;
    reg [3:0] key_rise;
    reg [DB_COUNT_W-1:0] db_count [0:3];

    reg [SEC_COUNT_W-1:0] sec_count;
    reg [SCAN_COUNT_W-1:0] scan_count;
    reg [1:0] scan_sel;
    reg [5:0] second;
    reg [5:0] minute;
    reg [4:0] hour;
    reg manual_page_sel;
    reg auto_page_sel;
    reg [AUTO_PHASE_W-1:0] auto_elapsed;
    reg [SEC_COUNT_W-1:0] auto_sec_count;
    reg [3:0] digit;
    reg dp_on;
    integer i;

    wire display_page;
    wire colon_blink;
    assign display_page = sw2_sync ? auto_page_sel : manual_page_sel;
    assign colon_blink = (second[0] == 1'b0);

    // BTNC is active-high, synchronized, synchronous reset.
    always @(posedge clk) begin
        btnc_meta <= btnc;
        btnc_sync <= btnc_meta;
    end

    // Synchronize mode switches before using them in sequential control.
    always @(posedge clk) begin
        if (btnc_sync == 1'b1) begin
            sw0_meta <= 1'b0;
            sw0_sync <= 1'b0;
            sw1_meta <= 1'b0;
            sw1_sync <= 1'b0;
            sw2_meta <= 1'b0;
            sw2_sync <= 1'b0;
            sw2_sync_d <= 1'b0;
        end else begin
            sw0_meta <= sw0;
            sw0_sync <= sw0_meta;
            sw1_meta <= sw1;
            sw1_sync <= sw1_meta;
            sw2_meta <= sw2;
            sw2_sync <= sw2_meta;
            sw2_sync_d <= sw2_sync;
        end
    end

    // Synchronize user control buttons; debounce below creates one-cycle press events.
    always @(posedge clk) begin
        if (btnc_sync == 1'b1) begin
            key_meta <= 4'b0000;
            key_sync <= 4'b0000;
        end else begin
            key_meta <= {btnr, btnl, btnd, btnu};
            key_sync <= key_meta;
        end
    end

    // Debounce controls: key_rise[0]=BTNU, [1]=BTND, [2]=BTNL, [3]=BTNR.
    always @(posedge clk) begin
        if (btnc_sync == 1'b1) begin
            key_state <= 4'b0000;
            key_rise <= 4'b0000;
            for (i = 0; i < 4; i = i + 1) db_count[i] <= {DB_COUNT_W{1'b0}};
        end else begin
            for (i = 0; i < 4; i = i + 1) begin
                key_rise[i] <= 1'b0;
                if (key_sync[i] == key_state[i]) begin
                    db_count[i] <= {DB_COUNT_W{1'b0}};
                end else if (db_count[i] >= DB_LIMIT - 1) begin
                    db_count[i] <= {DB_COUNT_W{1'b0}};
                    key_state[i] <= key_sync[i];
                    if (key_sync[i] == 1'b1) key_rise[i] <= 1'b1;
                end else begin
                    db_count[i] <= db_count[i] + 1'b1;
                end
            end
        end
    end

    // 24-hour timekeeping, pause in setting mode, and manual time adjustment.
    always @(posedge clk) begin
        if (btnc_sync == 1'b1) begin
            sec_count <= {SEC_COUNT_W{1'b0}};
            second <= 6'd0;
            minute <= 6'd0;
            hour <= 5'd0;
            manual_page_sel <= 1'b0;
            auto_page_sel <= 1'b0;
            auto_elapsed <= {AUTO_PHASE_W{1'b0}};
            auto_sec_count <= {SEC_COUNT_W{1'b0}};
        end else begin
            if (sw2_sync == 1'b0) begin
                auto_page_sel <= 1'b0;
                auto_elapsed <= {AUTO_PHASE_W{1'b0}};
                auto_sec_count <= {SEC_COUNT_W{1'b0}};
            end else if (sw2_sync_d == 1'b0) begin
                auto_page_sel <= 1'b0;
                auto_elapsed <= {AUTO_PHASE_W{1'b0}};
                auto_sec_count <= {SEC_COUNT_W{1'b0}};
            end else if (sw0_sync == 1'b0) begin
                if (auto_sec_count == CLK_FREQ_HZ - 1) begin
                    auto_sec_count <= {SEC_COUNT_W{1'b0}};
                    if (auto_page_sel == 1'b0) begin
                        if (auto_elapsed == AUTO_HH_LIMIT - 1) begin
                            auto_page_sel <= 1'b1;
                            auto_elapsed <= {AUTO_PHASE_W{1'b0}};
                        end else auto_elapsed <= auto_elapsed + 1'b1;
                    end else begin
                        if (auto_elapsed == AUTO_MM_LIMIT - 1) begin
                            auto_page_sel <= 1'b0;
                            auto_elapsed <= {AUTO_PHASE_W{1'b0}};
                        end else auto_elapsed <= auto_elapsed + 1'b1;
                    end
                end else auto_sec_count <= auto_sec_count + 1'b1;
            end else auto_sec_count <= {SEC_COUNT_W{1'b0}};

            if (sw0_sync == 1'b0) begin
                if (sw2_sync == 1'b0) begin
                    if (key_rise[2] == 1'b1) manual_page_sel <= 1'b0;
                    else if (key_rise[3] == 1'b1) manual_page_sel <= 1'b1;
                end

                if (sec_count == CLK_FREQ_HZ - 1) begin
                    sec_count <= {SEC_COUNT_W{1'b0}};
                    if (second == 6'd59) begin
                        second <= 6'd0;
                        if (minute == 6'd59) begin
                            minute <= 6'd0;
                            if (hour == 5'd23) hour <= 5'd0;
                            else hour <= hour + 1'b1;
                        end else minute <= minute + 1'b1;
                    end else second <= second + 1'b1;
                end else sec_count <= sec_count + 1'b1;
            end else begin
                sec_count <= {SEC_COUNT_W{1'b0}};
                if (key_rise[0] == 1'b1) begin
                    if (sw1_sync == 1'b0) begin
                        if (hour == 5'd23) hour <= 5'd0;
                        else hour <= hour + 1'b1;
                    end else begin
                        if (minute == 6'd59) minute <= 6'd0;
                        else minute <= minute + 1'b1;
                    end
                end else if (key_rise[1] == 1'b1) begin
                    if (sw1_sync == 1'b0) begin
                        if (hour == 5'd0) hour <= 5'd23;
                        else hour <= hour - 1'b1;
                    end else begin
                        if (minute == 6'd0) minute <= 6'd59;
                        else minute <= minute - 1'b1;
                    end
                end
            end
        end
    end

    // Four-digit display refresh scanner.
    always @(posedge clk) begin
        if (btnc_sync == 1'b1) begin
            scan_count <= {SCAN_COUNT_W{1'b0}};
            scan_sel <= 2'd0;
        end else if (scan_count == SCAN_LIMIT - 1) begin
            scan_count <= {SCAN_COUNT_W{1'b0}};
            scan_sel <= scan_sel + 1'b1;
        end else scan_count <= scan_count + 1'b1;
    end

    // Default page is HH:MM; second page is MM:SS.
    // DP is low-active.  HH:MM uses AN2 as the blinking colon point.
    // MM:SS keeps AN2 on as the separator and lights AN0 as the seconds marker.
    always @(*) begin
        an = 4'b1111;
        digit = 4'd0;
        dp_on = 1'b0;
        case (scan_sel)
            2'd0: begin
                an = 4'b1110;
                digit = display_page ? second % 10 : minute % 10;
                dp_on = display_page;
            end
            2'd1: begin
                an = 4'b1101;
                digit = display_page ? second / 10 : minute / 10;
                dp_on = 1'b0;
            end
            2'd2: begin
                an = 4'b1011;
                digit = display_page ? minute % 10 : hour % 10;
                dp_on = display_page ? 1'b1 : colon_blink;
            end
            2'd3: begin
                an = 4'b0111;
                digit = display_page ? minute / 10 : hour / 10;
                dp_on = 1'b0;
            end
            default: begin
                an = 4'b1111;
                digit = 4'd0;
                dp_on = 1'b0;
            end
        endcase
        seg[7] = ~dp_on;
        case (digit)
            4'd0: seg[6:0] = 7'b0000001;
            4'd1: seg[6:0] = 7'b1001111;
            4'd2: seg[6:0] = 7'b0010010;
            4'd3: seg[6:0] = 7'b0000110;
            4'd4: seg[6:0] = 7'b1001100;
            4'd5: seg[6:0] = 7'b0100100;
            4'd6: seg[6:0] = 7'b0100000;
            4'd7: seg[6:0] = 7'b0001111;
            4'd8: seg[6:0] = 7'b0000000;
            4'd9: seg[6:0] = 7'b0000100;
            default: seg[6:0] = 7'b1111111;
        endcase
    end

    always @(*) begin
        ld0 = sw0_sync;
        ld1 = display_page;
    end

endmodule
