`timescale 1ns/1ps

module sc2210_ae_i2c_bridge #(
    parameter integer CLK_HZ = 96000000,
    parameter integer I2C_HZ = 400000
)(
    input  wire        clk_sys,
    input  wire        rst_n,
    input  wire        init_done,
    input  wire        ae_update_toggle_async,
    input  wire [15:0] exposure_lines_async,
    input  wire [2:0]  gain_index_async,

    output wire        i2c_scl_o,
    output wire        i2c_scl_oe,
    output wire        i2c_sda_o,
    output wire        i2c_sda_oe,
    input  wire        i2c_sda_i,
    output reg         update_busy,
    output reg         ack_error_sticky
);

    localparam [1:0] ST_IDLE = 2'd0,
                     ST_ISSUE = 2'd1,
                     ST_WAIT = 2'd2;

    reg toggle_meta;
    reg toggle_sync;
    reg toggle_seen;
    reg [1:0] state;
    reg [2:0] write_index;
    reg [15:0] exposure_latched;
    reg [2:0] gain_latched;
    reg wr_start;

    wire wr_busy;
    wire wr_done;
    wire wr_ack_error;
    reg [15:0] wr_reg_addr;
    reg [7:0] wr_data;

    // Gain ladder used by this first stable version:
    // 0: 1.00x, 1: 1.25x, 2: 1.50x, 3: 1.75x, 4: 2.00x.
    always @* begin
        case (write_index)
            3'd0: begin
                wr_reg_addr = 16'h3e00;
                wr_data     = {4'h0, exposure_latched[15:12]};
            end
            3'd1: begin
                wr_reg_addr = 16'h3e01;
                wr_data     = exposure_latched[11:4];
            end
            3'd2: begin
                wr_reg_addr = 16'h3e02;
                wr_data     = {exposure_latched[3:0], 4'h0};
            end
            3'd3: begin
                wr_reg_addr = 16'h3e08;
                wr_data     = (gain_latched >= 3'd4) ? 8'h07 : 8'h03;
            end
            default: begin
                wr_reg_addr = 16'h3e09;
                case (gain_latched)
                    3'd0: wr_data = 8'h40;
                    3'd1: wr_data = 8'h50;
                    3'd2: wr_data = 8'h60;
                    3'd3: wr_data = 8'h70;
                    default: wr_data = 8'h40;
                endcase
            end
        endcase
    end

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            toggle_meta       <= 1'b0;
            toggle_sync       <= 1'b0;
            toggle_seen       <= 1'b0;
            state             <= ST_IDLE;
            write_index       <= 3'd0;
            exposure_latched  <= 16'd1108;
            gain_latched      <= 3'd2;
            wr_start          <= 1'b0;
            update_busy       <= 1'b0;
            ack_error_sticky  <= 1'b0;
        end else begin
            toggle_meta <= ae_update_toggle_async;
            toggle_sync <= toggle_meta;
            wr_start    <= 1'b0;

            if (wr_done && wr_ack_error)
                ack_error_sticky <= 1'b1;

            case (state)
                ST_IDLE: begin
                    update_busy <= 1'b0;
                    if (init_done && (toggle_sync != toggle_seen)) begin
                        toggle_seen      <= toggle_sync;
                        exposure_latched <= exposure_lines_async;
                        gain_latched     <= gain_index_async;
                        write_index      <= 3'd0;
                        update_busy      <= 1'b1;
                        state            <= ST_ISSUE;
                    end
                end

                ST_ISSUE: begin
                    if (!wr_busy) begin
                        wr_start <= 1'b1;
                        state    <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (wr_done) begin
                        if (write_index == 3'd4)
                            state <= ST_IDLE;
                        else begin
                            write_index <= write_index + 1'b1;
                            state       <= ST_ISSUE;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    i2c_reg16_write_master #(
        .CLK_HZ (CLK_HZ),
        .I2C_HZ (I2C_HZ)
    ) u_ae_i2c_writer (
        .clk       (clk_sys),
        .rst_n     (rst_n),
        .start     (wr_start),
        .dev_addr  (7'h30),
        .reg_addr  (wr_reg_addr),
        .wr_data   (wr_data),
        .busy      (wr_busy),
        .done      (wr_done),
        .ack_error (wr_ack_error),
        .scl_o     (i2c_scl_o),
        .scl_oe    (i2c_scl_oe),
        .sda_o     (i2c_sda_o),
        .sda_oe    (i2c_sda_oe),
        .sda_i     (i2c_sda_i)
    );

endmodule

