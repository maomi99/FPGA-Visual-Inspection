`timescale 1ns/1ps

//====================================================================
// key_debounce_ctrl.v
//
// key_data[0] = K1 = 阈值 +
// key_data[1] = K2 = 阈值 -
//
// 按键：低有效
//====================================================================

module key_debounce_ctrl #(
    parameter integer KEY_WIDTH     = 2,
    parameter integer CLK_HZ        = 96_000_000,
    parameter integer DEBOUNCE_MS   = 20,
    parameter integer LONG_PRESS_MS = 600,
    parameter integer REPEAT_MS     = 100
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire [KEY_WIDTH-1:0] key_data,

    output wire [KEY_WIDTH-1:0] key_value,
    output wire [KEY_WIDTH-1:0] key_press,
    output wire [KEY_WIDTH-1:0] key_repeat
);


    genvar i;

    generate

        for (i = 0; i < KEY_WIDTH; i = i + 1) begin : GEN_KEY

            key_debounce_unit #(
                .CLK_HZ        (CLK_HZ),
                .DEBOUNCE_MS   (DEBOUNCE_MS),
                .LONG_PRESS_MS (LONG_PRESS_MS),
                .REPEAT_MS     (REPEAT_MS)
            )
            u_key_debounce_unit
            (
                .clk        (clk),
                .rst_n      (rst_n),

                .key_raw    (key_data[i]),

                .key_value  (key_value[i]),
                .key_press  (key_press[i]),
                .key_repeat (key_repeat[i])
            );

        end

    endgenerate

endmodule