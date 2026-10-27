`timescale 1ns/1ps

module gray_sobel_split #(
    parameter integer SRC_WIDTH  = 1920,
    parameter integer HALF_WIDTH = 960
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       in_vsync,
    input  wire       in_hsync,
    input  wire       in_de,

    // 必须是与Sobel输出严格对齐的灰度
    input  wire [7:0] in_gray,
    input  wire [7:0] in_edge,

    output reg        out_vsync,
    output reg        out_hsync,
    output reg        out_de,

    output reg  [7:0] out_r,
    output reg  [7:0] out_g,
    output reg  [7:0] out_b
);

    // 1920像素需要11位计数器
    reg [10:0] x_cnt;

    // 当前输入像素应当显示的结果
    reg [7:0] selected_pixel;

    //==============================================================
    // 组合逻辑：按照当前像素横坐标选择显示内容
    //
    // x = 0~959：
    //     显示源图像左半部分的灰度
    //
    // x = 960~1919：
    //     显示源图像右半部分的Sobel边缘
    //==============================================================
    always @(*) begin
        if (!in_de)
            selected_pixel = 8'd0;
        else if (x_cnt < HALF_WIDTH)
            selected_pixel = in_gray;
        else
            selected_pixel = in_edge;
    end

    //==============================================================
    // 像素坐标计数
    //==============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 11'd0;
        end
        else begin
            if (in_de) begin
                if (x_cnt == SRC_WIDTH - 1)
                    x_cnt <= 11'd0;
                else
                    x_cnt <= x_cnt + 1'b1;
            end
            else begin
                // 每一行消隐期间复位横坐标
                x_cnt <= 11'd0;
            end
        end
    end

    //==============================================================
    // 输出流水线
    //
    // selected_pixel、DE、HS、VS统一打1拍，保持严格对齐
    //==============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vsync <= 1'b0;
            out_hsync <= 1'b0;
            out_de    <= 1'b0;

            out_r     <= 8'd0;
            out_g     <= 8'd0;
            out_b     <= 8'd0;
        end
        else begin
            // 同步信号打1拍
            out_vsync <= in_vsync;
            out_hsync <= in_hsync;
            out_de    <= in_de;

            // 像素数据也打1拍
            if (in_de) begin
                out_r <= selected_pixel;
                out_g <= selected_pixel;
                out_b <= selected_pixel;
            end
            else begin
                out_r <= 8'd0;
                out_g <= 8'd0;
                out_b <= 8'd0;
            end
        end
    end

endmodule