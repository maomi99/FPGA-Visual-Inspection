`timescale 1ns/1ps

//====================================================================
// sobel_threshold_ctrl.v
//
// K1：阈值 +
// K2：阈值 -
//
// 默认：14
// 范围：1 ~ 255
//
// 短按：±1
// 长按：±1
//====================================================================

module sobel_threshold_ctrl #(

    parameter [7:0] THRESHOLD_DEFAULT = 8'd14,
    parameter [7:0] THRESHOLD_MIN     = 8'd1,
    parameter [7:0] THRESHOLD_MAX     = 8'd255,

    parameter [7:0] STEP_PRESS        = 8'd1,
    parameter [7:0] STEP_REPEAT       = 8'd1

)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       key_up_press,
    input  wire       key_up_repeat,

    input  wire       key_down_press,
    input  wire       key_down_repeat,

    input  wire       key_reset,

    output reg  [7:0] threshold_o,
    output wire [7:0] led_show
);


    wire up_evt;
    wire down_evt;

    assign up_evt   = key_up_press   | key_up_repeat;
    assign down_evt = key_down_press | key_down_repeat;


    // 根据事件类型决定步进
    wire [7:0] up_step;
    wire [7:0] down_step;

    assign up_step =
        key_up_repeat ? STEP_REPEAT : STEP_PRESS;

    assign down_step =
        key_down_repeat ? STEP_REPEAT : STEP_PRESS;


    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            threshold_o <= THRESHOLD_DEFAULT;

        end
        else if (key_reset) begin

            threshold_o <= THRESHOLD_DEFAULT;

        end

        //==========================================================
        // 同时按下时不调节
        //
        // 比原来“+优先”更适合实际按键操作，
        // 防止两个键同时按时产生意外变化。
        //==========================================================

        else if (up_evt && !down_evt) begin

            // 加
            if (threshold_o >= THRESHOLD_MAX - up_step)
                threshold_o <= THRESHOLD_MAX;
            else
                threshold_o <= threshold_o + up_step;

        end

        else if (down_evt && !up_evt) begin

            // 减
            if (threshold_o <= THRESHOLD_MIN + down_step)
                threshold_o <= THRESHOLD_MIN;
            else
                threshold_o <= threshold_o - down_step;

        end

    end


    assign led_show = threshold_o;

endmodule