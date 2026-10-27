`timescale 1ns/1ps

// One-shot I2C writer: START + device(W) + reg[15:8] + reg[7:0] + data + STOP.
// SDA uses active-high output enable and open-drain signalling (sda_o is 0;
// logic 1 means release SDA). SCL is push-pull, matching the original demo.
module i2c_reg16_write_master #(
    parameter integer CLK_HZ = 96000000,
    parameter integer I2C_HZ = 400000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [6:0]  dev_addr,
    input  wire [15:0] reg_addr,
    input  wire [7:0]  wr_data,
    output reg         busy,
    output reg         done,
    output reg         ack_error,
    output reg         scl_o,
    output wire        scl_oe,
    output wire        sda_o,
    output reg         sda_oe,
    input  wire        sda_i
);

    // The bit states alternate SCL low/high once per tick, so this divider is
    // one half of an I2C period.
    localparam integer HALF_DIV = CLK_HZ / (I2C_HZ * 2);
    localparam [3:0] ST_IDLE         = 4'd0,
                     ST_START        = 4'd1,
                     ST_BIT_LOW      = 4'd2,
                     ST_BIT_HIGH     = 4'd3,
                     ST_ACK_LOW      = 4'd4,
                     ST_ACK_HIGH     = 4'd5,
                     ST_ACK_SAMPLE   = 4'd6,
                     ST_STOP_LOW     = 4'd7,
                     ST_STOP_HIGH    = 4'd8,
                     ST_STOP_RELEASE = 4'd9;

    reg [15:0] div_count;
    reg [3:0]  state;
    reg [1:0]  byte_index;
    reg [2:0]  bit_index;
    reg [7:0]  tx_byte;
    reg [15:0] reg_addr_latched;
    reg [7:0]  wr_data_latched;

    assign scl_oe = 1'b1;
    assign sda_o  = 1'b0;

    wire half_tick = (div_count == HALF_DIV-1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_count <= 16'd0;
        end else if (half_tick) begin
            div_count <= 16'd0;
        end else begin
            div_count <= div_count + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_IDLE;
            byte_index       <= 2'd0;
            bit_index        <= 3'd7;
            tx_byte          <= 8'hff;
            reg_addr_latched <= 16'd0;
            wr_data_latched  <= 8'd0;
            busy             <= 1'b0;
            done             <= 1'b0;
            ack_error        <= 1'b0;
            scl_o            <= 1'b1;
            sda_oe           <= 1'b0;
        end else begin
            done <= 1'b0;

            if ((state == ST_IDLE) && start) begin
                reg_addr_latched <= reg_addr;
                wr_data_latched  <= wr_data;
                tx_byte          <= {dev_addr, 1'b0};
                byte_index       <= 2'd0;
                bit_index        <= 3'd7;
                busy             <= 1'b1;
                ack_error        <= 1'b0;
                scl_o            <= 1'b1;
                sda_oe           <= 1'b0;
                state            <= ST_START;
            end else if (half_tick) begin
                case (state)
                    ST_IDLE: begin
                        scl_o  <= 1'b1;
                        sda_oe <= 1'b0;
                    end

                    ST_START: begin
                        // SDA high-to-low while SCL is high.
                        scl_o  <= 1'b1;
                        sda_oe <= 1'b1;
                        state  <= ST_BIT_LOW;
                    end

                    ST_BIT_LOW: begin
                        scl_o  <= 1'b0;
                        sda_oe <= ~tx_byte[bit_index];
                        state  <= ST_BIT_HIGH;
                    end

                    ST_BIT_HIGH: begin
                        scl_o <= 1'b1;
                        if (bit_index == 3'd0)
                            state <= ST_ACK_LOW;
                        else begin
                            bit_index <= bit_index - 1'b1;
                            state     <= ST_BIT_LOW;
                        end
                    end

                    ST_ACK_LOW: begin
                        scl_o  <= 1'b0;
                        sda_oe <= 1'b0;
                        state  <= ST_ACK_HIGH;
                    end

                    ST_ACK_HIGH: begin
                        scl_o <= 1'b1;
                        state <= ST_ACK_SAMPLE;
                    end

                    ST_ACK_SAMPLE: begin
                        if (sda_i)
                            ack_error <= 1'b1;
                        scl_o <= 1'b0;
                        if (byte_index == 2'd3) begin
                            sda_oe <= 1'b1;
                            state  <= ST_STOP_LOW;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            bit_index  <= 3'd7;
                            case (byte_index)
                                2'd0: tx_byte <= reg_addr_latched[15:8];
                                2'd1: tx_byte <= reg_addr_latched[7:0];
                                2'd2: tx_byte <= wr_data_latched;
                                default: tx_byte <= 8'h00;
                            endcase
                            state <= ST_BIT_LOW;
                        end
                    end

                    ST_STOP_LOW: begin
                        scl_o  <= 1'b0;
                        sda_oe <= 1'b1;
                        state  <= ST_STOP_HIGH;
                    end

                    ST_STOP_HIGH: begin
                        scl_o  <= 1'b1;
                        sda_oe <= 1'b1;
                        state  <= ST_STOP_RELEASE;
                    end

                    ST_STOP_RELEASE: begin
                        scl_o  <= 1'b1;
                        sda_oe <= 1'b0;
                        busy   <= 1'b0;
                        done   <= 1'b1;
                        state  <= ST_IDLE;
                    end

                    default: state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
