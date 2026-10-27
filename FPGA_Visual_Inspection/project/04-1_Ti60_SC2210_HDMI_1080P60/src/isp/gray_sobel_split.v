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

    input  wire [7:0] in_gray,
    input  wire [7:0] in_edge,

    output reg        out_vsync,
    output reg        out_hsync,
    output reg        out_de,

    output reg  [7:0] out_r,
    output reg  [7:0] out_g,
    output reg  [7:0] out_b
);

    //==================================================================
    // 两组行缓存
    //
    // 每个地址：
    // [15:8] = 灰度
    // [7:0]  = Sobel边缘
    //
    // 一组写当前行，另一组读上一行。
    //==================================================================
    reg [15:0] line_buf0 [0:SRC_WIDTH-1];
    reg [15:0] line_buf1 [0:SRC_WIDTH-1];

    reg [10:0] x_cnt;

    reg write_bank;
    reg read_bank;
    reg line_valid;

    reg de_prev;
    reg vsync_prev;

    wire de_falling;
    wire frame_start;

    assign de_falling = de_prev && !in_de;

    // 本工程lcd_vs为低有效，因此下降沿是一帧开始
    assign frame_start = vsync_prev && !in_vsync;

    //==================================================================
    // 显示地址
    //
    // 左半屏x=0...959：
    //   读取源图0,2,4,...,1918
    //
    // 右半屏x=960...1919：
    //   再读取源图0,2,4,...,1918
    //==================================================================
    wire [10:0] half_x;
    wire [10:0] read_addr;

    assign half_x =
        (x_cnt < HALF_WIDTH)
        ? x_cnt
        : x_cnt - HALF_WIDTH;

    assign read_addr = half_x << 1;

    // BRAM同步读数据
    reg [15:0] read_data;

    // 与同步读数据对应的控制流水线
    reg vsync_d1;
    reg hsync_d1;
    reg de_d1;
    reg side_d1;

    //==================================================================
    // 行缓存控制
    //==================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt      <= 11'd0;

            write_bank <= 1'b0;
            read_bank  <= 1'b1;
            line_valid <= 1'b0;

            de_prev    <= 1'b0;
            vsync_prev <= 1'b1;

            read_data  <= 16'd0;

            vsync_d1   <= 1'b0;
            hsync_d1   <= 1'b0;
            de_d1      <= 1'b0;
            side_d1    <= 1'b0;

            out_vsync  <= 1'b0;
            out_hsync  <= 1'b0;
            out_de     <= 1'b0;

            out_r      <= 8'd0;
            out_g      <= 8'd0;
            out_b      <= 8'd0;
        end
        else begin
            //----------------------------------------------------------
            // 保存边沿检测信号
            //----------------------------------------------------------
            de_prev    <= in_de;
            vsync_prev <= in_vsync;

            //----------------------------------------------------------
            // 新的一帧开始
            //
            // 当前尚未收到新帧的第一行，所以暂时禁止输出。
            //----------------------------------------------------------
            if (frame_start) begin
                line_valid <= 1'b0;
            end

            //----------------------------------------------------------
            // 写入当前输入行
            //----------------------------------------------------------
            if (in_de) begin
                if (write_bank == 1'b0)
                    line_buf0[x_cnt] <= {in_gray, in_edge};
                else
                    line_buf1[x_cnt] <= {in_gray, in_edge};

                if (x_cnt < SRC_WIDTH - 1)
                    x_cnt <= x_cnt + 1'b1;
            end
            else begin
                x_cnt <= 11'd0;
            end

            //----------------------------------------------------------
            // 从上一行缓存读取
            //----------------------------------------------------------
            if (in_de && line_valid) begin
                if (read_bank == 1'b0)
                    read_data <= line_buf0[read_addr];
                else
                    read_data <= line_buf1[read_addr];
            end
            else begin
                read_data <= 16'd0;
            end

            //----------------------------------------------------------
            // 一行结束后交换读写缓存
            //----------------------------------------------------------
            if (de_falling) begin
                read_bank  <= write_bank;
                write_bank <= ~write_bank;
                line_valid <= 1'b1;
            end

            //----------------------------------------------------------
            // 控制信号延迟一拍，与BRAM读取结果对齐
            //----------------------------------------------------------
            vsync_d1 <= in_vsync;
            hsync_d1 <= in_hsync;
            de_d1    <= in_de && line_valid;
            side_d1  <= (x_cnt >= HALF_WIDTH);

            out_vsync <= vsync_d1;
            out_hsync <= hsync_d1;
            out_de    <= de_d1;

            //----------------------------------------------------------
            // 像素选择
            //----------------------------------------------------------
            if (!de_d1) begin
                out_r <= 8'd0;
                out_g <= 8'd0;
                out_b <= 8'd0;
            end
            else if (!side_d1) begin
                // 左半屏：灰度图
                out_r <= read_data[15:8];
                out_g <= read_data[15:8];
                out_b <= read_data[15:8];
            end
            else begin
                // 右半屏：Sobel边缘图
                out_r <= read_data[7:0];
                out_g <= read_data[7:0];
                out_b <= read_data[7:0];
            end
        end
    end

endmodule