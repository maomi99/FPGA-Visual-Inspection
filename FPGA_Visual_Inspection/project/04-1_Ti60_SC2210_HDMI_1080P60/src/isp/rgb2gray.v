`timescale 1ns/1ps

module rgb2gray #(
    // Q8 定点系数：77=0.299*256, 150=0.587*256, 29=0.114*256
    parameter [9:0] R_COEF = 10'd77,
    parameter [9:0] G_COEF = 10'd150,
    parameter [9:0] B_COEF = 10'd29
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

    // 灰度输出：RGB三通道相同值，兼容现有HDMI链路
    output reg  [7:0] out_r,
    output reg  [7:0] out_g,
    output reg  [7:0] out_b,

    // 纯灰度8bit输出（供Sobel等后续模块使用）
    output reg  [7:0] out_gray
);

    //==================================================================
    // 第1级流水线：计算三个乘积（8bit × 10bit = 18bit）
    //==================================================================
    reg [17:0] r_product_d1;
    reg [17:0] g_product_d1;
    reg [17:0] b_product_d1;

    reg        vsync_d1;
    reg        hsync_d1;
    reg        de_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_product_d1 <= 18'd0;
            g_product_d1 <= 18'd0;
            b_product_d1 <= 18'd0;
            vsync_d1 <= 1'b0;
            hsync_d1 <= 1'b0;
            de_d1    <= 1'b0;
        end
        else begin
            r_product_d1 <= in_r * R_COEF;
            g_product_d1 <= in_g * G_COEF;
            b_product_d1 <= in_b * B_COEF;
            vsync_d1 <= in_vsync;
            hsync_d1 <= in_hsync;
            de_d1    <= in_de;
        end
    end

    //==================================================================
    // 第2级流水线：乘积求和 + 四舍五入(+128)
    //   最大和：3×(255×150) + 128 = 114878，18bit 足够
    //==================================================================
    reg [17:0] gray_sum_d2;

    reg        vsync_d2;
    reg        hsync_d2;
    reg        de_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gray_sum_d2 <= 18'd0;
            vsync_d2 <= 1'b0;
            hsync_d2 <= 1'b0;
            de_d2    <= 1'b0;
        end
        else begin
            gray_sum_d2 <= r_product_d1 + g_product_d1 + b_product_d1 + 18'd128;
            vsync_d2 <= vsync_d1;
            hsync_d2 <= hsync_d1;
            de_d2    <= de_d1;
        end
    end

    //==================================================================
    // 第3级流水线：Q8右移、饱和截断、输出
    //==================================================================
    wire [9:0] gray_val = gray_sum_d2[17:8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vsync <= 1'b0;
            out_hsync <= 1'b0;
            out_de    <= 1'b0;
            out_r     <= 8'd0;
            out_g     <= 8'd0;
            out_b     <= 8'd0;
            out_gray  <= 8'd0;
        end
        else begin
            out_vsync <= vsync_d2;
            out_hsync <= hsync_d2;
            out_de    <= de_d2;

            if (gray_val > 10'd255) begin
                out_gray <= 8'hFF;
                out_r    <= 8'hFF;
                out_g    <= 8'hFF;
                out_b    <= 8'hFF;
            end
            else begin
                out_gray <= gray_val[7:0];
                out_r    <= gray_val[7:0];
                out_g    <= gray_val[7:0];
                out_b    <= gray_val[7:0];
            end
        end
    end

endmodule
