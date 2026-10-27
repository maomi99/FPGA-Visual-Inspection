`timescale 1ns/1ps

//====================================================================
// key_debounce_unit.v
//
// 功能：
//   1. 两级同步
//   2. 按键消抖
//   3. 短按只产生一次 key_press
//   4. 按住 LONG_PRESS_MS 后进入长按
//   5. 长按期间每 REPEAT_MS 产生一次 key_repeat
//
// 硬件按键：
//   未按下 = 1
//   按下   = 0
//====================================================================

module key_debounce_unit #(
    parameter integer CLK_HZ        = 96_000_000,
    parameter integer DEBOUNCE_MS   = 20,
    parameter integer LONG_PRESS_MS = 600,
    parameter integer REPEAT_MS     = 100
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_raw,

    output reg  key_value,
    output reg  key_press,
    output reg  key_repeat
);

    //==============================================================
    // 计数参数
    //
    // 关键修正：
    // 不能直接 CLK_HZ * LONG_PRESS_MS / 1000
    // 96,000,000 * 600 会产生很大的中间值。
    //
    // 先除 1000，再乘，避免 integer 中间运算溢出。
    //==============================================================

    localparam integer CLK_KHZ = CLK_HZ / 1000;

    localparam integer DEBOUNCE_COUNT =
        CLK_KHZ * DEBOUNCE_MS;       // 1,920,000

    localparam integer LONG_COUNT =
        CLK_KHZ * LONG_PRESS_MS;     // 57,600,000

    localparam integer REPEAT_COUNT =
        CLK_KHZ * REPEAT_MS;         // 9,600,000


    //==============================================================
    // 1. 输入两级同步
    //==============================================================

    reg key_sync1;
    reg key_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync1 <= 1'b1;
            key_sync2 <= 1'b1;
        end
        else begin
            key_sync1 <= key_raw;
            key_sync2 <= key_sync1;
        end
    end


    //==============================================================
    // 2. 消抖
    //
    // key_level：
    //   1 = 稳定释放
    //   0 = 稳定按下
    //==============================================================

    reg        key_level;
    reg [31:0] debounce_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_level    <= 1'b1;
            debounce_cnt <= 32'd0;
        end
        else begin

            if (key_sync2 == key_level) begin

                // 当前输入与稳定状态相同
                debounce_cnt <= 32'd0;

            end
            else begin

                // 输入发生变化，开始消抖计数
                if (debounce_cnt < DEBOUNCE_COUNT - 1) begin
                    debounce_cnt <= debounce_cnt + 1'b1;
                end
                else begin

                    // 连续稳定达到 20ms
                    key_level    <= key_sync2;
                    debounce_cnt <= 32'd0;

                end
            end
        end
    end


    //==============================================================
    // 3. 转换为高有效 pressed
    //==============================================================

    wire pressed;

    assign pressed = ~key_level;


    //==============================================================
    // 4. 状态机
    //
    // IDLE：
    //   未按下
    //
    // PRESSED：
    //   已按下，但不足 600ms
    //
    // LONG：
    //   已按住超过 600ms
    //==============================================================

    localparam [1:0] ST_IDLE    = 2'd0;
    localparam [1:0] ST_PRESSED = 2'd1;
    localparam [1:0] ST_LONG    = 2'd2;

    reg [1:0] state;

    reg [31:0] hold_cnt;
    reg [31:0] repeat_cnt;


    //==============================================================
    // 5. 状态机 + 输出事件
    //==============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state      <= ST_IDLE;

            hold_cnt   <= 32'd0;
            repeat_cnt <= 32'd0;

            key_value  <= 1'b0;
            key_press  <= 1'b0;
            key_repeat <= 1'b0;

        end
        else begin

            //------------------------------------------------------
            // 默认值
            //
            // key_press / key_repeat 每拍默认拉低，
            // 只有发生事件的那个时钟周期才拉高。
            //------------------------------------------------------

            key_value  <= pressed;
            key_press  <= 1'b0;
            key_repeat <= 1'b0;


            case (state)

                //==================================================
                // 未按下
                //==================================================

                ST_IDLE: begin

                    hold_cnt   <= 32'd0;
                    repeat_cnt <= 32'd0;

                    if (pressed) begin

                        // ★ 一次稳定按下，只在这里产生一次 press
                        key_press <= 1'b1;

                        hold_cnt <= 32'd0;

                        state <= ST_PRESSED;

                    end

                end


                //==================================================
                // 已按下，但尚未达到长按时间
                //==================================================

                ST_PRESSED: begin

                    repeat_cnt <= 32'd0;

                    if (!pressed) begin

                        // 松手
                        hold_cnt <= 32'd0;
                        state    <= ST_IDLE;

                    end
                    else begin

                        if (hold_cnt < LONG_COUNT - 1) begin

                            hold_cnt <= hold_cnt + 1'b1;

                        end
                        else begin

                            // ★ 满 600ms 后才允许进入 LONG
                            hold_cnt   <= hold_cnt;
                            repeat_cnt <= 32'd0;

                            state <= ST_LONG;

                        end

                    end

                end


                //==================================================
                // 长按状态
                //==================================================

                ST_LONG: begin

                    if (!pressed) begin

                        // ★ 一松手立即彻底复位
                        hold_cnt   <= 32'd0;
                        repeat_cnt <= 32'd0;

                        state <= ST_IDLE;

                    end
                    else begin

                        if (repeat_cnt < REPEAT_COUNT - 1) begin

                            repeat_cnt <= repeat_cnt + 1'b1;

                        end
                        else begin

                            repeat_cnt <= 32'd0;

                            // ★ 每 100ms 只产生一个时钟周期
                            key_repeat <= 1'b1;

                        end

                    end

                end


                //==================================================
                // 异常恢复
                //==================================================

                default: begin

                    state      <= ST_IDLE;

                    hold_cnt   <= 32'd0;
                    repeat_cnt <= 32'd0;

                    key_press  <= 1'b0;
                    key_repeat <= 1'b0;

                end

            endcase

        end

    end

endmodule