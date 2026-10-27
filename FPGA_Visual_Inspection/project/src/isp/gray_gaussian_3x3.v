`timescale 1ns/1ps

//==========================================================================
// 3x3 Gaussian filter for an 8-bit grayscale video stream
//
// Kernel:
//          1  2  1
//   1/16 * 2  4  2
//          1  2  1
//
// The module reuses VIP_Matrix_Generate_3X3_8Bit from the original project.
// Pixel data and VS/HS/DE are pipelined together.  Throughput is one pixel
// per clock; only fixed line/clock latency is added.
//==========================================================================
module gray_gaussian_3x3 #(
    parameter [13:0] IMG_HDISP = 14'd1920,
    parameter [13:0] IMG_VDISP = 14'd1080
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       in_vsync,
    input  wire       in_hsync,
    input  wire       in_de,
    input  wire [7:0] in_gray,

    output reg        out_vsync,
    output reg        out_hsync,
    output reg        out_de,
    output reg  [7:0] out_gray
);

    //----------------------------------------------------------------------
    // 3x3 sliding window supplied by the original demo project
    //----------------------------------------------------------------------
    wire       matrix_vsync;
    wire       matrix_hsync;
    wire       matrix_de;

    wire [7:0] p11, p12, p13;
    wire [7:0] p21, p22, p23;
    wire [7:0] p31, p32, p33;

    VIP_Matrix_Generate_3X3_8Bit #(
        .IMG_HDISP (IMG_HDISP),
        .IMG_VDISP (IMG_VDISP)
    ) u_gaussian_matrix (
        .clk                (clk),
        .rst_n              (rst_n),

        .per_frame_vsync    (in_vsync),
        .per_frame_href     (in_de),
        .per_frame_hsync    (in_hsync),
        .per_img_Y          (in_gray),

        .matrix_frame_vsync (matrix_vsync),
        .matrix_frame_href  (matrix_de),
        .matrix_frame_hsync (matrix_hsync),

        .matrix_p11         (p11),
        .matrix_p12         (p12),
        .matrix_p13         (p13),
        .matrix_p21         (p21),
        .matrix_p22         (p22),
        .matrix_p23         (p23),
        .matrix_p31         (p31),
        .matrix_p32         (p32),
        .matrix_p33         (p33)
    );

    //----------------------------------------------------------------------
    // Pipeline stage 1: weighted sum of each row
    //
    // top/bottom maximum: 255 + 2*255 + 255 = 1020 (10 bits)
    // middle maximum:     2*255 + 4*255 + 2*255 = 2040 (11 bits)
    //----------------------------------------------------------------------
    reg [9:0]  row_top_d1;
    reg [10:0] row_mid_d1;
    reg [9:0]  row_bottom_d1;

    reg vsync_d1;
    reg hsync_d1;
    reg de_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_top_d1    <= 10'd0;
            row_mid_d1    <= 11'd0;
            row_bottom_d1 <= 10'd0;

            vsync_d1 <= 1'b0;
            hsync_d1 <= 1'b0;
            de_d1    <= 1'b0;
        end
        else begin
            vsync_d1 <= matrix_vsync;
            hsync_d1 <= matrix_hsync;
            de_d1    <= matrix_de;

            if (matrix_de) begin
                row_top_d1 <=
                    {2'b00, p11} +
                    {1'b0,  p12, 1'b0} +
                    {2'b00, p13};

                row_mid_d1 <=
                    {2'b00, p21, 1'b0} +
                    {1'b0,  p22, 2'b00} +
                    {2'b00, p23, 1'b0};

                row_bottom_d1 <=
                    {2'b00, p31} +
                    {1'b0,  p32, 1'b0} +
                    {2'b00, p33};
            end
            else begin
                row_top_d1    <= 10'd0;
                row_mid_d1    <= 11'd0;
                row_bottom_d1 <= 10'd0;
            end
        end
    end

    //----------------------------------------------------------------------
    // Pipeline stage 2: add three rows, round, and divide by 16
    // Maximum weighted sum is 4080; adding 8 for rounding still fits 12 bits.
    //----------------------------------------------------------------------
    wire [11:0] gaussian_sum;

    assign gaussian_sum =
        {2'b00, row_top_d1} +
        {1'b0,  row_mid_d1} +
        {2'b00, row_bottom_d1} +
        12'd8;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vsync <= 1'b0;
            out_hsync <= 1'b0;
            out_de    <= 1'b0;
            out_gray  <= 8'd0;
        end
        else begin
            // Control and pixel data are registered in the same stage.
            out_vsync <= vsync_d1;
            out_hsync <= hsync_d1;
            out_de    <= de_d1;

            if (de_d1)
                out_gray <= gaussian_sum[11:4];
            else
                out_gray <= 8'd0;
        end
    end

endmodule
