`timescale 1ns/1ps

module sobel_despike_3x3 #(
    parameter [13:0] IMG_HDISP = 14'd1920,
    parameter [13:0] IMG_VDISP = 14'd1080,

    // 1：至少有1个相邻白点，适合保留细边缘
    // 2：至少有2个相邻白点，去噪更强
    parameter [3:0] MIN_NEIGHBORS = 4'd1
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       in_vsync,
    input  wire       in_hsync,
    input  wire       in_de,

    input  wire [7:0] in_edge,
    input  wire [7:0] in_gray_aligned,

    output reg        out_vsync,
    output reg        out_hsync,
    output reg        out_de,

    output reg  [7:0] out_edge,
    output reg  [7:0] out_gray_aligned
);

    //==============================================================
    // 边缘图3×3窗口
    //==============================================================
    wire edge_matrix_vsync;
    wire edge_matrix_hsync;
    wire edge_matrix_de;

    wire [7:0] e11;
    wire [7:0] e12;
    wire [7:0] e13;
    wire [7:0] e21;
    wire [7:0] e22;
    wire [7:0] e23;
    wire [7:0] e31;
    wire [7:0] e32;
    wire [7:0] e33;

    VIP_Matrix_Generate_3X3_8Bit #(
        .IMG_HDISP (IMG_HDISP),
        .IMG_VDISP (IMG_VDISP)
    ) u_edge_matrix (
        .clk                (clk),
        .rst_n              (rst_n),

        .per_frame_vsync    (in_vsync),
        .per_frame_href     (in_de),
        .per_frame_hsync    (in_hsync),
        .per_img_Y          (in_edge),

        .matrix_frame_vsync (edge_matrix_vsync),
        .matrix_frame_href  (edge_matrix_de),
        .matrix_frame_hsync (edge_matrix_hsync),

        .matrix_p11         (e11),
        .matrix_p12         (e12),
        .matrix_p13         (e13),
        .matrix_p21         (e21),
        .matrix_p22         (e22),
        .matrix_p23         (e23),
        .matrix_p31         (e31),
        .matrix_p32         (e32),
        .matrix_p33         (e33)
    );

    //==============================================================
    // 灰度图并行3×3窗口
    //
    // 只取中心像素g22，使灰度图与滤波后的边缘图严格对齐
    //==============================================================
    wire [7:0] g22;

    VIP_Matrix_Generate_3X3_8Bit #(
        .IMG_HDISP (IMG_HDISP),
        .IMG_VDISP (IMG_VDISP)
    ) u_gray_delay_matrix (
        .clk                (clk),
        .rst_n              (rst_n),

        .per_frame_vsync    (in_vsync),
        .per_frame_href     (in_de),
        .per_frame_hsync    (in_hsync),
        .per_img_Y          (in_gray_aligned),

        .matrix_frame_vsync (),
        .matrix_frame_href  (),
        .matrix_frame_hsync (),

        .matrix_p11         (),
        .matrix_p12         (),
        .matrix_p13         (),
        .matrix_p21         (),
        .matrix_p22         (g22),
        .matrix_p23         (),
        .matrix_p31         (),
        .matrix_p32         (),
        .matrix_p33         ()
    );

    //==============================================================
    // 统计中心像素周围8个方向的白色边缘数量
    //==============================================================
    wire [3:0] neighbor_count;

    assign neighbor_count =
        {3'd0, e11[7]} +
        {3'd0, e12[7]} +
        {3'd0, e13[7]} +
        {3'd0, e21[7]} +
        {3'd0, e23[7]} +
        {3'd0, e31[7]} +
        {3'd0, e32[7]} +
        {3'd0, e33[7]};

    wire keep_edge;

    // 中心本身是白色，并且周围存在足够数量的白色点才保留
    assign keep_edge =
        e22[7] &&
        (neighbor_count >= MIN_NEIGHBORS);

    //==============================================================
    // 输出统一打1拍
    //==============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vsync        <= 1'b0;
            out_hsync        <= 1'b0;
            out_de           <= 1'b0;
            out_edge         <= 8'd0;
            out_gray_aligned <= 8'd0;
        end
        else begin
            // 同步信号和数据统一打1拍
            out_vsync <= edge_matrix_vsync;
            out_hsync <= edge_matrix_hsync;
            out_de    <= edge_matrix_de;

            if (edge_matrix_de) begin
                out_edge <= keep_edge ? 8'hFF : 8'h00;

                // 与处理后的边缘严格对应
                out_gray_aligned <= g22;
            end
            else begin
                out_edge         <= 8'd0;
                out_gray_aligned <= 8'd0;
            end
        end
    end

endmodule