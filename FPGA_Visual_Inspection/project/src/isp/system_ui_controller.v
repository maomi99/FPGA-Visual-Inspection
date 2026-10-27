`timescale 1ns/1ps
module system_ui_controller #(
  parameter [7:0] THRESHOLD_INIT=8'd14,
  parameter [7:0] THRESHOLD_MIN=8'd1,
  parameter [7:0] THRESHOLD_MAX=8'd255,
  parameter [7:0] SHORT_STEP=8'd1,
  parameter [7:0] LONG_STEP=8'd5
)(
  input wire clk,input wire reset,
  input wire key1_short,input wire key1_long,input wire key2_short,input wire key2_long,
  input wire [2:0] ddr_mode,
  output reg [2:0] work_mode,output reg [7:0] sobel_threshold,
  output reg shape_boxes_enable,
  output reg ddr_key1_short,output reg ddr_key1_long,output reg ddr_key2_short,output reg ddr_key2_long
);
  localparam [2:0] MODE_RAW=3'd0, MODE_EDGE=3'd1, MODE_SHAPE=3'd2,
                   MODE_PLATE=3'd3, MODE_DDR=3'd4;
  localparam [2:0] DDR_LIVE=3'd0,DDR_ARM=3'd1,DDR_REC=3'd2,DDR_PAUSE=3'd3,DDR_PLAY=3'd4;

  always @(posedge clk or posedge reset) begin
    if(reset) begin
      work_mode<=MODE_RAW;
      sobel_threshold<=THRESHOLD_INIT;
      shape_boxes_enable<=1'b1;
      ddr_key1_short<=0;ddr_key1_long<=0;ddr_key2_short<=0;ddr_key2_long<=0;
    end else begin
      ddr_key1_short<=0;ddr_key1_long<=0;ddr_key2_short<=0;ddr_key2_long<=0;
      case(work_mode)
        MODE_RAW: begin
          if(key1_short) work_mode<=MODE_EDGE;
        end

        MODE_EDGE: begin
          if(key1_short) work_mode<=MODE_SHAPE;
          else if(key1_long) begin
            if(sobel_threshold > THRESHOLD_MIN+LONG_STEP-1'b1)
              sobel_threshold<=sobel_threshold-LONG_STEP;
            else sobel_threshold<=THRESHOLD_MIN;
          end else if(key2_long) begin
            if(sobel_threshold < THRESHOLD_MAX-LONG_STEP+1'b1)
              sobel_threshold<=sobel_threshold+LONG_STEP;
            else sobel_threshold<=THRESHOLD_MAX;
          end else if(key2_short) begin
            if(sobel_threshold < THRESHOLD_MAX-SHORT_STEP+1'b1)
              sobel_threshold<=sobel_threshold+SHORT_STEP;
            else sobel_threshold<=THRESHOLD_MAX;
          end
        end

        MODE_SHAPE: begin
          if(key1_long) work_mode<=MODE_EDGE;
          else if(key1_short) work_mode<=MODE_DDR;  // DDR now comes before plate inspection
          else if(key2_short) shape_boxes_enable<=~shape_boxes_enable;
        end

        MODE_DDR: begin
          // Short-key semantics inside DDR are unchanged.
          // Long K1 now leaves DDR and proceeds to plate inspection instead of RAW.
          if(key1_long) begin
            ddr_key1_long<=1'b1;
            work_mode<=MODE_PLATE;
          end else case(ddr_mode)
            DDR_LIVE: if(key2_short) ddr_key1_short<=1'b1;
            DDR_ARM: begin end
            DDR_REC: begin end
            DDR_PAUSE,DDR_PLAY: begin
              if(key1_short) ddr_key1_short<=1'b1;
              if(key2_short) ddr_key2_short<=1'b1;
              if(key2_long) ddr_key2_long<=1'b1;
            end
          endcase
        end

        MODE_PLATE: begin
          // Plate remains automatic. Short K1 closes the display cycle to RAW.
          if(key1_long) work_mode<=MODE_DDR;
          else if(key1_short) work_mode<=MODE_RAW;
        end
        default: work_mode<=MODE_RAW;
      endcase
    end
  end
endmodule
