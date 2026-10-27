`timescale 1ns/1ps

module sc2210_auto_exposure #(
    parameter [7:0] TARGET_LOW        = 8'd88,
    parameter [7:0] TARGET_HIGH       = 8'd104,
    parameter [15:0] EXPOSURE_MIN     = 16'd64,
    parameter [15:0] EXPOSURE_MAX     = 16'd1108,
    parameter [15:0] EXPOSURE_INIT    = 16'd1108,
    parameter [2:0] GAIN_INIT_INDEX   = 3'd2,
    parameter [2:0] GAIN_MAX_INDEX    = 3'd4,
    parameter integer UPDATE_INTERVAL = 4,
    parameter integer ADJUST_EXPOSURE = 1
)(
    input  wire        pclk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        in_vsync,
    input  wire        in_de,
    input  wire [7:0]  in_r,
    input  wire [7:0]  in_g,
    input  wire [7:0]  in_b,

    output reg  [7:0]  mean_luma,
    output reg  [12:0] sample_count_debug,
    output reg  [15:0] exposure_lines,
    output reg  [2:0]  gain_index,
    output reg          ae_update_toggle,
    output reg          statistics_valid,
    output reg          too_dark,
    output reg          too_bright
);

    reg         vsync_d;
    reg         de_d;
    reg [11:0]  x_count;
    reg [10:0]  y_count;
    reg [19:0]  luma_sum;
    reg [12:0]  sample_count;
    reg [7:0]   mean_filtered;
    reg [3:0]   startup_frames;
    reg [3:0]   update_count;
    reg         initial_sync_sent;

    wire frame_end = vsync_d && !in_vsync;
    wire [9:0] luma_wide = {2'b0, in_r} + {1'b0, in_g, 1'b0} + {2'b0, in_b};
    wire [7:0] luma = luma_wide[9:2];

    // x=448..1456 every 16 pixels; y=28..1036 every 16 lines.
    // This is exactly 64*64=4096 samples when input is 1920x1080.
    wire sample_point = in_vsync && in_de &&
                        (x_count >= 12'd448) && (x_count <= 12'd1456) &&
                        (y_count >= 11'd28)  && (y_count <= 11'd1036) &&
                        (x_count[3:0] == 4'h0) && (y_count[3:0] == 4'hc);

    wire [7:0] current_mean = luma_sum[19:12];
    wire signed [8:0] filter_error =
        $signed({1'b0, current_mean}) - $signed({1'b0, mean_filtered});

    function [15:0] exposure_step;
        input [7:0] mean_value;
        begin
            if (mean_value < (TARGET_LOW - 8'd24))
                exposure_step = 16'd64;
            else
                exposure_step = 16'd16;
        end
    endfunction

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_d            <= 1'b0;
            de_d               <= 1'b0;
            x_count            <= 12'd0;
            y_count            <= 11'd0;
            luma_sum           <= 20'd0;
            sample_count       <= 13'd0;
            sample_count_debug <= 13'd0;
            mean_luma          <= 8'd0;
            mean_filtered      <= (TARGET_LOW + TARGET_HIGH) >> 1;
            startup_frames     <= 4'd0;
            update_count       <= 4'd0;
            initial_sync_sent  <= 1'b0;
            exposure_lines     <= EXPOSURE_INIT;
            gain_index         <= GAIN_INIT_INDEX;
            ae_update_toggle   <= 1'b0;
            statistics_valid   <= 1'b0;
            too_dark           <= 1'b0;
            too_bright         <= 1'b0;
        end else begin
            vsync_d <= in_vsync;
            de_d    <= in_de;

            if (frame_end) begin
                mean_luma          <= current_mean;
                sample_count_debug <= sample_count;
                statistics_valid   <= (sample_count == 13'd4096);
                luma_sum           <= 20'd0;
                sample_count       <= 13'd0;
                x_count            <= 12'd0;
                y_count            <= 11'd0;

                if (sample_count == 13'd4096) begin
                    // IIR alpha=1/8 suppresses single-frame noise and flicker.
                    mean_filtered <= mean_filtered + (filter_error >>> 3);
                    too_dark      <= (mean_filtered < TARGET_LOW);
                    too_bright    <= (mean_filtered > TARGET_HIGH);

                    if (startup_frames != 4'hf)
                        startup_frames <= startup_frames + 1'b1;

                    if (update_count == UPDATE_INTERVAL-1)
                        update_count <= 4'd0;
                    else
                        update_count <= update_count + 1'b1;

                    // First synchronize the configured initial exposure/gain
                    // to the sensor. Then adjust at most every four frames.
                    if (enable && !initial_sync_sent && (startup_frames >= 4'd7)) begin
                        initial_sync_sent <= 1'b1;
                        ae_update_toggle  <= ~ae_update_toggle;
                    end else if (enable && (startup_frames >= 4'd8) &&
                        (update_count == UPDATE_INTERVAL-1)) begin
                        if (mean_filtered < TARGET_LOW) begin
                            if (ADJUST_EXPOSURE && (exposure_lines < EXPOSURE_MAX)) begin
                                if (exposure_lines + exposure_step(mean_filtered) >= EXPOSURE_MAX)
                                    exposure_lines <= EXPOSURE_MAX;
                                else
                                    exposure_lines <= exposure_lines + exposure_step(mean_filtered);
                                ae_update_toggle <= ~ae_update_toggle;
                            end else if (gain_index < GAIN_MAX_INDEX) begin
                                gain_index       <= gain_index + 1'b1;
                                ae_update_toggle <= ~ae_update_toggle;
                            end
                        end else if (mean_filtered > TARGET_HIGH) begin
                            // Reduce gain first in bright scenes for lower noise.
                            if (gain_index != 3'd0) begin
                                gain_index       <= gain_index - 1'b1;
                                ae_update_toggle <= ~ae_update_toggle;
                            end else if (ADJUST_EXPOSURE && (exposure_lines > EXPOSURE_MIN)) begin
                                if (exposure_lines <= EXPOSURE_MIN + 16'd16)
                                    exposure_lines <= EXPOSURE_MIN;
                                else
                                    exposure_lines <= exposure_lines - 16'd16;
                                ae_update_toggle <= ~ae_update_toggle;
                            end
                        end
                    end
                end
            end else if (in_vsync) begin
                if (in_de)
                    x_count <= x_count + 1'b1;
                else
                    x_count <= 12'd0;

                if (de_d && !in_de)
                    y_count <= y_count + 1'b1;

                if (sample_point) begin
                    luma_sum     <= luma_sum + luma;
                    sample_count <= sample_count + 1'b1;
                end
            end
        end
    end

endmodule
