`timescale 1ns/1ps

module rgb_white_balance #(
    // Q8定点增益：256表示1.0
    parameter [9:0] R_GAIN = 10'd320,  // 1.25
    parameter [9:0] G_GAIN = 10'd256,  // 1.00
    parameter [9:0] B_GAIN = 10'd384   // 1.50
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       in_vsync,
    input  wire       in_hsync,
    input  wire       in_de,

    input  wire [7:0] in_r,
    input  wire [7:0] in_g,
    input  wire [7:0] in_b,

    output reg        out_vsync,
    output reg        out_hsync,
    output reg        out_de,

    output reg  [7:0] out_r,
    output reg  [7:0] out_g,
    output reg  [7:0] out_b
);

    // 8位像素 × 10位Q8增益，再加0.5用于四舍五入
    wire [17:0] r_product = in_r * R_GAIN + 18'd128;
    wire [17:0] g_product = in_g * G_GAIN + 18'd128;
    wire [17:0] b_product = in_b * B_GAIN + 18'd128;

    // Q8转换后的整数结果
    wire [9:0] r_scaled = r_product[17:8];
    wire [9:0] g_scaled = g_product[17:8];
    wire [9:0] b_scaled = b_product[17:8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vsync <= 1'b0;
            out_hsync <= 1'b0;
            out_de    <= 1'b0;

            out_r <= 8'd0;
            out_g <= 8'd0;
            out_b <= 8'd0;
        end
        else begin
            // 白平衡产生1个时钟延迟，控制信号同步延迟
            out_vsync <= in_vsync;
            out_hsync <= in_hsync;
            out_de    <= in_de;

            // 饱和截断，避免增益后溢出回绕
            out_r <= (r_scaled > 10'd255) ? 8'hFF :
                     r_scaled[7:0];

            out_g <= (g_scaled > 10'd255) ? 8'hFF :
                     g_scaled[7:0];

            out_b <= (b_scaled > 10'd255) ? 8'hFF :
                     b_scaled[7:0];
        end
    end

endmodule
