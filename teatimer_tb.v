`define ASSERT_EQUALS(_got, _expected) \
        if (_got != _expected) begin \
            $write("Assertion failed! line %01d: expected 0x%02x, got 0x%02x\n", `__LINE__, _expected, _got); \
            $stop; \
        end

module tb;
    initial begin
        $dumpvars;
        #2000 $finish;
    end
endmodule

module clkdiv_tb;
    reg clk, reset;

    initial begin
        clk = 0;
        reset = 1;
        #2 reset = 0;
        #2 reset = 1;
    end

    always #1 clk = ~clk;

    wire clkdiv4;
    clkdiv #(.divider(4)) clkdiv4_dut(.clk(clk), .reset(reset), .clkdiv(clkdiv4));

    wire clkdiv8;
    clkdiv #(.divider(8)) clkdiv8_dut(.clk(clk), .reset(reset), .clkdiv(clkdiv8));
endmodule

module button_edge_to_pulse_tb;
    reg clk, reset;
    reg button_n;

    initial begin
        clk = 0;
        reset = 1;
        button_n = 1;
        #2 reset = 0;
        #2 reset = 1;
        #5 button_n = 0;
        #6 button_n = 1;
        #4 button_n = 0;
        #6 button_n = 1;
        #2 button_n = 0;
        #1 button_n = 1;
    end

    always #1 clk = ~clk;

    wire button_pulse;
    button_edge_to_pulse button_edge_to_pulse_dut(.clk(clk), .reset(reset),
                                                  .button_n(button_n),
                                                  .button_pulse(button_pulse));
endmodule

module timer_tb;
    reg clk, reset;
    reg ctrl_startstop, ctrl_reset, ctrl_incmin, ctrl_incsec;

    wire [6:0] time_min;
    wire [5:0] time_sec;
    wire alarm_enable;

    task strobe_startstop;
    begin
        ctrl_startstop = 1;
        #1 ctrl_startstop = 0;
    end
    endtask

    task strobe_reset;
    begin
        ctrl_reset = 1;
        #1 ctrl_reset = 0;
    end
    endtask

    task strobe_incmin;
    begin
        ctrl_incmin = 1;
        #1 ctrl_incmin = 0;
    end
    endtask

    task strobe_incsec;
    begin
        ctrl_incsec = 1;
        #1 ctrl_incsec = 0;
    end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        ctrl_startstop = 0;
        ctrl_reset = 0;
        ctrl_incmin = 0;
        ctrl_incsec = 0;
        #2 reset = 0;
        #2 reset = 1;

        /* Setup min:sec to 01:15 */
        #5 strobe_incmin;
        #5 strobe_incsec;
        `ASSERT_EQUALS(time_min, 1);
        `ASSERT_EQUALS(time_sec, 15);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Reset back to 00:00 */
        #5 strobe_reset;
        `ASSERT_EQUALS(time_min, 0);
        `ASSERT_EQUALS(time_sec, 0);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Set up min:sec to 01:15 by incrementing sec */
        #5 strobe_incsec;
        #5 strobe_incsec;
        #5 strobe_incsec;
        #5 strobe_incsec;
        #5 strobe_incsec;
        `ASSERT_EQUALS(time_min, 1);
        `ASSERT_EQUALS(time_sec, 15);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Start count down */
        #3 strobe_startstop;

        /* Check it counted down to 01:14 */
        #5;
        `ASSERT_EQUALS(time_min, 1);
        `ASSERT_EQUALS(time_sec, 14);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Stop count down */
        strobe_startstop;

        /* Check time hasn't changed */
        #8;
        `ASSERT_EQUALS(time_min, 1);
        `ASSERT_EQUALS(time_sec, 14);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Resume count down */
        #5 strobe_startstop;

        /* Count all the way down to 00:00 and check for alarm */
        #296;
        `ASSERT_EQUALS(time_min, 0);
        `ASSERT_EQUALS(time_sec, 0);
        `ASSERT_EQUALS(alarm_enable, 1);

        /* Reset and check alarm stopped */
        #5 strobe_startstop;
        `ASSERT_EQUALS(time_min, 0);
        `ASSERT_EQUALS(time_sec, 0);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Start count up */
        #3 strobe_startstop;
        #256;
        `ASSERT_EQUALS(time_min, 1);
        `ASSERT_EQUALS(time_sec, 4);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Stop count up */
        #1 strobe_startstop;

        /* Check time is frozen */
        #10;
        `ASSERT_EQUALS(time_min, 1);
        `ASSERT_EQUALS(time_sec, 4);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Resume count up */
        #5 strobe_startstop;
        #256;
        `ASSERT_EQUALS(time_min, 2);
        `ASSERT_EQUALS(time_sec, 8);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Stop count up */
        #1 strobe_startstop;

        /* Increment seconds, switching timer to count down */
        #5 strobe_incsec;
        `ASSERT_EQUALS(time_min, 2);
        `ASSERT_EQUALS(time_sec, 23);
        `ASSERT_EQUALS(alarm_enable, 0);

        /* Resume count down */
        #1 strobe_startstop;
        #256;
        `ASSERT_EQUALS(time_min, 1);
        `ASSERT_EQUALS(time_sec, 19);
        `ASSERT_EQUALS(alarm_enable, 0);
    end

    always #1 clk = ~clk;

    timer #(.divider(2)) timer_dut(.clk_1khz(clk), .reset(reset),
                                   .ctrl_startstop(ctrl_startstop),
                                   .ctrl_reset(ctrl_reset),
                                   .ctrl_incmin(ctrl_incmin),
                                   .ctrl_incsec(ctrl_incsec),
                                   .time_min(time_min),
                                   .time_sec(time_sec),
                                   .alarm_enable(alarm_enable));
endmodule

module bin_to_bcd_tb;
    reg [6:0] bin;
    wire [7:0] bcd;

    initial begin
        #1 bin = 01;
        #1 `ASSERT_EQUALS(bcd, 'h01);
        #1 bin = 12;
        #1 `ASSERT_EQUALS(bcd, 'h12);
        #1 bin = 34;
        #1 `ASSERT_EQUALS(bcd, 'h34);
        #1 bin = 56;
        #1 `ASSERT_EQUALS(bcd, 'h56);
        #1 bin = 78;
        #1 `ASSERT_EQUALS(bcd, 'h78);
        #1 bin = 90;
        #1 `ASSERT_EQUALS(bcd, 'h90);
    end

    bin_to_bcd bin_to_bcd_dut(.bin(bin), .bcd(bcd));
endmodule

module led_driver_tb;
    reg clk, reset;
    reg [6:0] time_min;
    reg [5:0] time_sec;
    reg blink;

    initial begin;
        clk = 0;
        reset = 1;
        time_min = 0;
        time_sec = 0;
        blink = 0;
        #2 reset = 0;
        #2 reset = 1;

        /* Drive different times*/
        #1 time_min = 7'd12; time_sec = 6'd34;
        #10 time_min = 7'd56; time_sec = 6'd49;
        #10 time_min = 7'd90; time_sec = 6'd12;

        /* Enable blink */
        #5 blink = 1;

        /* Disable blink */
        #100 blink = 0;
    end

    always #1 clk = ~clk;

    wire [6:0] led_anode_abcdefg;
    wire [3:0] led_cathode_digit;

    led_driver #(.blink_count(16)) led_driver_dut(.clk(clk), .reset(reset),
                                                  .time_min(time_min),
                                                  .time_sec(time_sec),
                                                  .blink(blink),
                                                  .led_anode_abcdefg(led_anode_abcdefg),
                                                  .led_cathode_digit(led_cathode_digit));
endmodule

module buzzer_tb;
    reg clk, reset;
    reg enable;

    initial begin;
        clk = 0;
        enable = 0;
        reset = 1;
        #2 reset = 0;
        #2 reset = 1;

        #5 enable = 1;
        #136 enable = 0;

        #10 enable = 1;
        #32 enable = 0;

        #10 enable = 1;
        #10 enable = 0;
    end

    always #1 clk = ~clk;

    wire buzzer;
    buzzer_driver #(.buzzer_on_count(6), .buzzer_off_count(3), .buzzer_pause_count(5))
                  buzzer_driver_dut(.clk_4khz(clk), .reset(reset),
                                    .enable(enable),
                                    .buzzer(buzzer));
endmodule
