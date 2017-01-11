module clkdiv #(parameter divider=1) (input clk, input reset, output clkdiv);
    localparam COUNTER_SIZE = $clog2(divider);

    reg [COUNTER_SIZE-1:0] counter;

    assign clkdiv = counter[COUNTER_SIZE-1];

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end
endmodule

module button_edge_to_pulse(input clk, input reset, input button_n, output button_pulse);
    reg button_sync;
    reg button_state;

    /* Button pulse on 1 -> 0 transition */
    assign button_pulse = !button_sync & button_state;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            button_sync <= 0;
            button_state <= 0;
        end else begin
            button_sync <= button_n;
            button_state <= button_sync;
        end
    end
endmodule

module timer #(parameter divider=1024)
              (input clk_1khz,
               input reset,
               input ctrl_startstop,
               input ctrl_reset,
               input ctrl_incmin,
               input ctrl_incsec,
               output reg [6:0] time_min,
               output reg [5:0] time_sec,
               output reg alarm_enable);
    localparam COUNTER_SIZE = $clog2(divider);

    reg [2:0] state, n_state;
    reg [COUNTER_SIZE-1:0] counter, n_counter;

    reg [6:0] n_time_min;
    reg [5:0] n_time_sec;
    reg n_alarm_enable;

    localparam  STATE_IDLE_DOWN  = 3'd0,
                STATE_IDLE_UP    = 3'd1,
                STATE_COUNT_DOWN = 3'd2,
                STATE_COUNT_UP   = 3'd3,
                STATE_EXPIRED    = 3'd4;

    always @(*) begin
        n_state = state;
        n_time_min = time_min;
        n_time_sec = time_sec;
        n_counter = 0;
        n_alarm_enable = 0;

        case (state)
            STATE_IDLE_DOWN, STATE_IDLE_UP: begin
                if (ctrl_startstop) begin
                    n_counter = 1;
                    if ((time_sec == 0 && time_min == 0) || state == STATE_IDLE_UP) begin
                        n_state = STATE_COUNT_UP;
                    end else begin
                        n_state = STATE_COUNT_DOWN;
                    end
                end else if (ctrl_reset) begin
                    n_time_min = 0;
                    n_time_sec = 0;
                end else if (ctrl_incmin) begin
                    n_state = STATE_IDLE_DOWN;
                    if (time_min == 99) begin
                        /* Saturate at 99 minutes */
                    end else begin
                        n_time_min = time_min + 1;
                    end
                end else if (ctrl_incsec) begin
                    n_state = STATE_IDLE_DOWN;
                    if (time_min == 99 && time_sec >= 45) begin
                        /* Saturate at 99:59 time */
                        n_time_sec = 59;
                    end else if (time_sec >= 45) begin
                        n_time_min = time_min + 1;
                        n_time_sec = time_sec - 45;
                    end else begin
                        n_time_sec = time_sec + 15;
                    end
                end
            end
            STATE_COUNT_UP: begin
                if (ctrl_startstop) begin
                    n_state = STATE_IDLE_UP;
                end else if (counter == 0) begin
                    if (time_min == 99 && time_sec == 59) begin
                        /* Saturate at 99:59 time */
                    end else if (time_sec == 59) begin
                        n_time_min = time_min + 1;
                        n_time_sec = 0;
                    end else begin
                        n_time_sec = time_sec + 1;
                    end
                end
                n_counter = counter + 1;
            end
            STATE_COUNT_DOWN: begin
                if (ctrl_startstop) begin
                    n_state = STATE_IDLE_DOWN;
                end else if (counter == 0) begin
                    if (time_min == 0 && time_sec == 1) begin
                        n_time_sec = 0;
                        n_state = STATE_EXPIRED;
                        n_alarm_enable = 1;
                    end else if (time_sec == 0) begin
                        n_time_min = time_min - 1;
                        n_time_sec = 59;
                    end else begin
                        n_time_sec = time_sec - 1;
                    end
                end
                n_counter = counter + 1;
            end
            STATE_EXPIRED: begin
                if (ctrl_startstop || ctrl_reset) begin
                    n_state = STATE_IDLE_DOWN;
                end else begin
                    n_alarm_enable = 1;
                end
            end
        endcase
    end

    always @(posedge clk_1khz or negedge reset) begin
        if (!reset) begin
            state <= STATE_IDLE_DOWN;
            time_min <= 0;
            time_sec <= 0;
            counter <= 0;
            alarm_enable <= 0;
        end else begin
            state <= n_state;
            time_min <= n_time_min;
            time_sec <= n_time_sec;
            counter <= n_counter;
            alarm_enable <= n_alarm_enable;
        end
    end
endmodule

module add3(input [3:0] in, output reg [3:0] out);
    always @(in) begin
        case (in)
            4'b0000: out = 4'b0000;
            4'b0001: out = 4'b0001;
            4'b0010: out = 4'b0010;
            4'b0011: out = 4'b0011;
            4'b0100: out = 4'b0100;
            4'b0101: out = 4'b1000;
            4'b0110: out = 4'b1001;
            4'b0111: out = 4'b1010;
            4'b1000: out = 4'b1011;
            4'b1001: out = 4'b1100;
            default: out = 4'b0000;
        endcase
    end
endmodule

module bin_to_bcd(input [6:0] bin, output [7:0] bcd);
    /* 7-bit Double dabble */

    wire [3:0] c1, c2, c3, c4, c5, c6, c7;
    wire [3:0] d1, d2, d3, d4, d5, d6, d7;

    assign d1 = {2'b0, bin[6:5]};
    assign d2 = {c1[2:0], bin[4]};
    assign d3 = {c2[2:0], bin[3]};
    assign d4 = {c3[2:0], bin[2]};
    assign d5 = {c4[2:0], bin[1]};
    assign d6 = {1'b0, c1[3], c2[3], c3[3]};
    assign d7 = {c6[2:0], c4[3]};

    add3 m1(d1, c1);
    add3 m2(d2, c2);
    add3 m3(d3, c3);
    add3 m4(d4, c4);
    add3 m5(d5, c5);
    add3 m6(d6, c6);
    add3 m7(d7, c7);

    assign bcd = {c7[2:0], c5[3:0], bin[0]};
endmodule

module led_driver #(parameter blink_count=512)
                   (input clk,
                    input reset,
                    input [6:0] time_min,
                    input [5:0] time_sec,
                    input blink,
                    output reg [6:0] led_anode_abcdefg,
                    output reg [3:0] led_cathode_digit);
    localparam COUNTER_SIZE = $clog2(blink_count);

    reg [1:0] cathode_state;
    reg [3:0] digit;

    reg [COUNTER_SIZE-1:0] blink_counter;

    /* Binary to BCD converter */
    reg [6:0] time_bin;
    wire [7:0] time_bcd;
    bin_to_bcd bin_to_bcd(.bin(time_bin), .bcd(time_bcd));

    always @(*) begin
        /* Cycle through 4 digits */
        case (cathode_state)
            2'b00: begin
                time_bin = time_sec;
                digit = time_bcd[3:0];
                led_cathode_digit = 4'b0111;
            end
            2'b01: begin
                time_bin = time_sec;
                digit = time_bcd[7:4];
                led_cathode_digit = 4'b1011;
            end
            2'b10: begin
                time_bin = time_min;
                digit = time_bcd[3:0];
                led_cathode_digit = 4'b1101;
            end
            2'b11: begin
                time_bin = time_min;
                digit = time_bcd[7:4];
                led_cathode_digit = 4'b1110;
            end
        endcase

        /* Look up table for digit -> 7-segment digit */
        case (digit)
            4'd0: led_anode_abcdefg = 7'b0111111;
            4'd1: led_anode_abcdefg = 7'b0000110;
            4'd2: led_anode_abcdefg = 7'b1011011;
            4'd3: led_anode_abcdefg = 7'b1001111;
            4'd4: led_anode_abcdefg = 7'b1100110;
            4'd5: led_anode_abcdefg = 7'b1101101;
            4'd6: led_anode_abcdefg = 7'b1111101;
            4'd7: led_anode_abcdefg = 7'b0000111;
            4'd8: led_anode_abcdefg = 7'b1111111;
            4'd9: led_anode_abcdefg = 7'b1101111;
            default: led_anode_abcdefg = 7'b0000000;
        endcase

        /* Blank screen when blink counter is in blink period */
        if (blink_counter[COUNTER_SIZE-1]) begin
            led_cathode_digit = 4'b1111;
        end
    end

    /* Cathode state */
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            cathode_state <= 0;
            blink_counter <= 0;
        end else begin
            cathode_state <= cathode_state + 1;
            blink_counter <= (blink) ? (blink_counter + 1) : 0;
        end
    end
endmodule

module buzzer_driver #(parameter buzzer_on_count=410,
                                 buzzer_off_count=205,
                                 buzzer_pause_count=1024)
                      (input clk_4khz,
                       input reset,
                       input enable,
                       output reg buzzer);
    localparam COUNTER_SIZE = $clog2(buzzer_on_count*3 + buzzer_off_count*3 + buzzer_pause_count + 1);

    reg [COUNTER_SIZE-1:0] counter, n_counter;

    localparam  COUNTER_BEEP1_ON    = buzzer_on_count;
    localparam  COUNTER_BEEP1_OFF   = COUNTER_BEEP1_ON + buzzer_off_count;
    localparam  COUNTER_BEEP2_ON    = COUNTER_BEEP1_OFF + buzzer_on_count;
    localparam  COUNTER_BEEP2_OFF   = COUNTER_BEEP2_ON + buzzer_off_count;
    localparam  COUNTER_BEEP3_ON    = COUNTER_BEEP2_OFF + buzzer_on_count;
    localparam  COUNTER_BEEP3_OFF   = COUNTER_BEEP3_ON + buzzer_off_count;
    localparam  COUNTER_PAUSE       = COUNTER_BEEP3_OFF + buzzer_pause_count;

    always @(*) begin
        if (!enable) begin
            buzzer = 0;
            n_counter = 0;
        end else if (counter < COUNTER_BEEP1_ON) begin
            buzzer = clk_4khz;
            n_counter = counter + 1;
        end else if (counter < COUNTER_BEEP1_OFF) begin
            buzzer = 0;
            n_counter = counter + 1;
        end else if (counter < COUNTER_BEEP2_ON) begin
            buzzer = clk_4khz;
            n_counter = counter + 1;
        end else if (counter < COUNTER_BEEP2_OFF) begin
            buzzer = 0;
            n_counter = counter + 1;
        end else if (counter < COUNTER_BEEP3_ON) begin
            buzzer = clk_4khz;
            n_counter = counter + 1;
        end else if (counter < COUNTER_BEEP3_OFF) begin
            buzzer = 0;
            n_counter = counter + 1;
        end else if (counter < COUNTER_PAUSE) begin
            buzzer = 0;
            n_counter = counter + 1;
        end else begin
            buzzer = 0;
            n_counter = 0;
        end
    end

    always @(posedge clk_4khz or negedge reset) begin
        if (!reset) begin
            counter <= 0;
        end else begin
            counter <= n_counter;
        end
    end
endmodule

module teatimer_top(input clk,
                    input reset,
                    input ctrl_startstop_n,
                    input ctrl_reset_n,
                    input ctrl_incmin_n,
                    input ctrl_incsec_n,
                    output wire [6:0] led_anode_abcdefg,
                    output wire [3:0] led_cathode_digit,
                    output wire buzzer);
    /* Master clock dividers 32.768 kHz -/8-> 4.096 kHz -/4-> 1.024 kHz */
    wire clk_4khz, clk_1khz;
    clkdiv #(.divider(8)) clkdiv_4khz(.clk(clk), .reset(reset), .clkdiv(clk_4khz));
    clkdiv #(.divider(4)) clkdiv_1khz(.clk(clk_4khz), .reset(reset), .clkdiv(clk_1khz));

    /* Button synchronizers and edge to pulse generators */
    wire ctrl_startstop_pulse, ctrl_reset_pulse, ctrl_incmin_pulse, ctrl_incsec_pulse;
    button_edge_to_pulse button_edge_to_pulse_startstop(.clk(clk_1khz), .reset(reset),
                                                        .button_n(ctrl_startstop_n),
                                                        .button_pulse(ctrl_startstop_pulse));
    button_edge_to_pulse button_edge_to_pulse_reset(.clk(clk_1khz), .reset(reset),
                                                    .button_n(ctrl_reset_n),
                                                    .button_pulse(ctrl_reset_pulse));
    button_edge_to_pulse button_edge_to_pulse_incmin(.clk(clk_1khz), .reset(reset),
                                                     .button_n(ctrl_incmin_n),
                                                     .button_pulse(ctrl_incmin_pulse));
    button_edge_to_pulse button_edge_to_pulse_incsec(.clk(clk_1khz), .reset(reset),
                                                     .button_n(ctrl_incsec_n),
                                                     .button_pulse(ctrl_incsec_pulse));

    /* Timer */
    wire [6:0] time_min;
    wire [5:0] time_sec;
    wire alarm_enable;
    timer timer(.clk_1khz(clk_1khz), .reset(reset),
                .ctrl_startstop(ctrl_startstop_pulse),
                .ctrl_reset(ctrl_reset_pulse),
                .ctrl_incmin(ctrl_incmin_pulse),
                .ctrl_incsec(ctrl_incsec_pulse),
                .time_min(time_min),
                .time_sec(time_sec),
                .alarm_enable(alarm_enable));

    /* LED driver */
    led_driver led_driver(.clk(clk_1khz), .reset(reset),
                          .time_min(time_min),
                          .time_sec(time_sec),
                          .blink(alarm_enable),
                          .led_anode_abcdefg(led_anode_abcdefg),
                          .led_cathode_digit(led_cathode_digit));

    /* Buzzer driver */
    buzzer_driver buzzer_driver(.clk_4khz(clk_4khz), .reset(reset),
                                .enable(alarm_enable),
                                .buzzer(buzzer));
endmodule
