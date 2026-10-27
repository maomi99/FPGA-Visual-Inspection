`timescale 1ns/1ps
//====================================================================
// sobel_edge.v（改造版）
// 原编译期参数 THRESHOLD 已改为可调输入端口 threshold
// threshold>0：输出二值边缘（gradient>threshold → 白 FF，否则黑 00）
//====================================================================
module sobel_edge #(
    parameter [13:0] IMG_HDISP = 14'd1920,
    parameter [13:0] IMG_VDISP = 14'd1080
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       in_vsync,
    input  wire       in_hsync,
    input  wire       in_de,
    input  wire [7:0] in_gray,

    input  wire [7:0] threshold,          // ★ 可调阈值（原 parameter）

    output reg        out_vsync,
    output reg        out_hsync,
    output reg        out_de,

    output reg  [7:0] out_r,
    output reg  [7:0] out_g,
    output reg  [7:0] out_b,

    output reg  [7:0] out_edge,
    output reg  [7:0] out_gray_aligned
);

    //==================================================================
    // 3×3 矩阵生成
    //==================================================================
    wire       matrix_frame_vsync;
    wire       matrix_frame_href;
    wire       matrix_frame_hsync;

    wire [7:0] matrix_p11, matrix_p12, matrix_p13;
    wire [7:0] matrix_p21, matrix_p22, matrix_p23;
    wire [7:0] matrix_p31, matrix_p32, matrix_p33;

    VIP_Matrix_Generate_3X3_8Bit #(
        .IMG_HDISP (IMG_HDISP),
        .IMG_VDISP (IMG_VDISP)
    ) u_matrix_gen (
        .clk                (clk),
        .rst_n              (rst_n),

        .per_frame_vsync    (in_vsync),
        .per_frame_href     (in_de),
        .per_frame_hsync    (in_hsync),
        .per_img_Y          (in_gray),

        .matrix_frame_vsync (matrix_frame_vsync),
        .matrix_frame_href  (matrix_frame_href),
        .matrix_frame_hsync (matrix_frame_hsync),

        .matrix_p11         (matrix_p11),
        .matrix_p12         (matrix_p12),
        .matrix_p13         (matrix_p13),
        .matrix_p21         (matrix_p21),
        .matrix_p22         (matrix_p22),
        .matrix_p23         (matrix_p23),
        .matrix_p31         (matrix_p31),
        .matrix_p32         (matrix_p32),
        .matrix_p33         (matrix_p33)
    );

    //==================================================================
    // 第1级流水线：计算 Gx / Gy
    //==================================================================
    wire [10:0] gx_col_right, gx_col_left;
    wire [10:0] gy_row_bottom, gy_row_top;

    assign gx_col_right =
        {3'b000, matrix_p13} +
        {2'b00, matrix_p23, 1'b0} +
        {3'b000, matrix_p33};

    assign gx_col_left =
        {3'b000, matrix_p11} +
        {2'b00, matrix_p21, 1'b0} +
        {3'b000, matrix_p31};

    assign gy_row_bottom =
        {3'b000, matrix_p31} +
        {2'b00, matrix_p32, 1'b0} +
        {3'b000, matrix_p33};

    assign gy_row_top =
        {3'b000, matrix_p11} +
        {2'b00, matrix_p12, 1'b0} +
        {3'b000, matrix_p13};

    reg signed [11:0] gx_d1;
    reg signed [11:0] gy_d1;
    reg [7:0]  gray_d1;
    reg vsync_d1, hsync_d1, de_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx_d1    <= 12'sd0;
            gy_d1    <= 12'sd0;
            gray_d1  <= 8'd0;
            vsync_d1 <= 1'b0;
            hsync_d1 <= 1'b0;
            de_d1    <= 1'b0;
        end
        else begin
            gx_d1 <= $signed({1'b0, gx_col_right}) -
                     $signed({1'b0, gx_col_left});
            gy_d1 <= $signed({1'b0, gy_row_bottom}) -
                     $signed({1'b0, gy_row_top});
            gray_d1  <= matrix_p22;
            vsync_d1 <= matrix_frame_vsync;
            hsync_d1 <= matrix_frame_hsync;
            de_d1    <= matrix_frame_href;
        end
    end

    //==================================================================
    // 第2级流水线：绝对值与梯度幅值
    //==================================================================
    wire [10:0] gx_abs = gx_d1[11] ? (~gx_d1[10:0] + 1'b1) : gx_d1[10:0];
    wire [10:0] gy_abs = gy_d1[11] ? (~gy_d1[10:0] + 1'b1) : gy_d1[10:0];

    reg [11:0] gradient_d2;
    reg [7:0]  gray_d2;
    reg vsync_d2, hsync_d2, de_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gradient_d2 <= 12'd0;
            gray_d2     <= 8'd0;
            vsync_d2    <= 1'b0;
            hsync_d2    <= 1'b0;
            de_d2       <= 1'b0;
        end
        else begin
            gradient_d2 <= gx_abs + gy_abs;
            gray_d2     <= gray_d1;
            vsync_d2    <= vsync_d1;
            hsync_d2    <= hsync_d1;
            de_d2       <= de_d1;
        end
    end

    //==================================================================
    // 第3级流水线：压缩、阈值、输出
    //==================================================================
    wire [9:0] gradient_8;
    wire [7:0] edge_pixel;

    assign gradient_8 = gradient_d2[11:2];      // (|Gx|+|Gy|)/4

    assign edge_pixel =
        (threshold > 8'd0)
        ? ((gradient_8 > {2'b00, threshold})
            ? 8'hFF
            : 8'h00)
        : ((gradient_8 > 10'd255)
            ? 8'hFF
            : gradient_8[7:0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vsync        <= 1'b0;
            out_hsync        <= 1'b0;
            out_de           <= 1'b0;
            out_edge         <= 8'd0;
            out_gray_aligned <= 8'd0;
            out_r            <= 8'd0;
            out_g            <= 8'd0;
            out_b            <= 8'd0;
        end
        else begin
            out_vsync        <= vsync_d2;
            out_hsync        <= hsync_d2;
            out_de           <= de_d2;
            out_edge         <= edge_pixel;
            out_gray_aligned <= gray_d2;
            out_r            <= edge_pixel;
            out_g            <= edge_pixel;
            out_b            <= edge_pixel;
        end
    end

endmodule
