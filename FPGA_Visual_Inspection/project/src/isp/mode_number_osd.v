`timescale 1ns/1ps
// Final displayed sequence:
//   RAW: no number (startup/return screen)
//   001: EDGE / Sobel threshold tuning
//   002: basic shape recognition
//   003: DDR LIVE / ARM / REC
//   004: DDR PAUSE / PLAY
//   005: T-shape / plate geometry inspection
// Internal work_mode IDs are intentionally kept unchanged so the verified
// video MUX and detector wiring do not need to be rewritten.
module mode_number_osd(
 input wire pclk,input wire rst_n,input wire [2:0] work_mode,input wire [2:0] ddr_mode,input wire [7:0] threshold,
 input wire in_vsync,input wire in_hsync,input wire in_de,input wire [7:0] in_r,input wire [7:0] in_g,input wire [7:0] in_b,
 output reg out_vsync,output reg out_hsync,output reg out_de,output reg [7:0] out_r,output reg [7:0] out_g,output reg [7:0] out_b
);
 localparam integer X0=24,Y0=20,S=3;
 localparam [2:0] MODE_RAW=3'd0,MODE_EDGE=3'd1,MODE_SHAPE=3'd2,MODE_PLATE=3'd3,MODE_DDR=3'd4;
 localparam [2:0] DDR_LIVE=3'd0,DDR_ARM=3'd1,DDR_REC=3'd2,DDR_PAUSE=3'd3,DDR_PLAY=3'd4;
 reg [11:0] x,y; reg de_d,vs_d; reg [3:0] status_digit; reg status_valid;
 wire [7:0] th_h=threshold/8'd100;
 wire [7:0] th_t=(threshold%8'd100)/8'd10;
 wire [7:0] th_o=threshold%8'd10;
 always @* begin
   status_digit=0; status_valid=1'b1;
   case(work_mode)
     MODE_RAW:   begin status_digit=0; status_valid=1'b0; end
     MODE_EDGE:  status_digit=1;
     MODE_SHAPE: status_digit=2;
     MODE_PLATE: status_digit=5;
     MODE_DDR: begin
       if(ddr_mode==DDR_PAUSE || ddr_mode==DDR_PLAY) status_digit=4;
       else status_digit=3; // LIVE / ARM / REC
     end
     default: begin status_digit=0; status_valid=1'b0; end
   endcase
 end
 function [4:0] glyph; input [3:0] c; input [2:0] r; begin
  case(c)
   0:case(r)0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b10011;3:glyph=5'b10101;4:glyph=5'b11001;5:glyph=5'b10001;default:glyph=5'b01110;endcase
   1:case(r)0:glyph=5'b00100;1:glyph=5'b01100;2:glyph=5'b00100;3:glyph=5'b00100;4:glyph=5'b00100;5:glyph=5'b00100;default:glyph=5'b01110;endcase
   2:case(r)0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b00001;3:glyph=5'b00010;4:glyph=5'b00100;5:glyph=5'b01000;default:glyph=5'b11111;endcase
   3:case(r)0:glyph=5'b11110;1:glyph=5'b00001;2:glyph=5'b00001;3:glyph=5'b01110;4:glyph=5'b00001;5:glyph=5'b00001;default:glyph=5'b11110;endcase
   4:case(r)0:glyph=5'b00010;1:glyph=5'b00110;2:glyph=5'b01010;3:glyph=5'b10010;4:glyph=5'b11111;5:glyph=5'b00010;default:glyph=5'b00010;endcase
   5:case(r)0:glyph=5'b11111;1:glyph=5'b10000;2:glyph=5'b10000;3:glyph=5'b11110;4:glyph=5'b00001;5:glyph=5'b00001;default:glyph=5'b11110;endcase
   6:case(r)0:glyph=5'b01110;1:glyph=5'b10000;2:glyph=5'b10000;3:glyph=5'b11110;4:glyph=5'b10001;5:glyph=5'b10001;default:glyph=5'b01110;endcase
   7:case(r)0:glyph=5'b11111;1:glyph=5'b00001;2:glyph=5'b00010;3:glyph=5'b00100;4:glyph=5'b01000;5:glyph=5'b01000;default:glyph=5'b01000;endcase
   8:case(r)0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b01110;4:glyph=5'b10001;5:glyph=5'b10001;default:glyph=5'b01110;endcase
   9:case(r)0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b01111;4:glyph=5'b00001;5:glyph=5'b00001;default:glyph=5'b01110;endcase
   10:case(r)0:glyph=5'b11111;1:glyph=5'b00100;2:glyph=5'b00100;3:glyph=5'b00100;4:glyph=5'b00100;5:glyph=5'b00100;default:glyph=5'b00100;endcase
   11:case(r)0:glyph=0;1:glyph=5'b11111;2:glyph=0;3:glyph=5'b11111;4:glyph=0;5:glyph=0;default:glyph=0;endcase
   default:glyph=0;
  endcase
 end endfunction
 function fp; input [3:0] c;input [11:0] px;input [11:0] py;reg [2:0] col,row;reg [4:0] bits;begin
  col=px/S;row=py/S;bits=glyph(c,row);if(col<5&&row<7)fp=bits[4-col];else fp=0;
 end endfunction
 reg ink,bg;reg [11:0] lx,ly,cx;reg [3:0] ch;
 always @* begin
  ink=0;bg=0;lx=0;ly=0;cx=0;ch=0;
  if(status_valid && in_de&&x>=X0&&x<X0+190&&y>=Y0&&y<Y0+24) begin
   bg=1;lx=x-X0;ly=y-Y0;
   // Always render 00N, where N is 1..5.
   if(lx<15)begin ch=0;cx=lx;ink=fp(ch,cx,ly);end
   else if(lx>=21&&lx<36)begin ch=0;cx=lx-21;ink=fp(ch,cx,ly);end
   else if(lx>=42&&lx<57)begin ch=status_digit;cx=lx-42;ink=fp(ch,cx,ly);end
   // Threshold value is shown only in 001 EDGE mode.
   else if(work_mode==MODE_EDGE) begin
    if(lx>=72&&lx<87)begin ch=10;cx=lx-72;ink=fp(ch,cx,ly);end
    else if(lx>=93&&lx<108)begin ch=11;cx=lx-93;ink=fp(ch,cx,ly);end
    else if(lx>=114&&lx<129)begin ch=th_h[3:0];cx=lx-114;ink=fp(ch,cx,ly);end
    else if(lx>=135&&lx<150)begin ch=th_t[3:0];cx=lx-135;ink=fp(ch,cx,ly);end
    else if(lx>=156&&lx<171)begin ch=th_o[3:0];cx=lx-156;ink=fp(ch,cx,ly);end
   end
  end
 end
 always @(posedge pclk or negedge rst_n) begin
  if(!rst_n)begin x<=0;y<=0;de_d<=0;vs_d<=0;out_vsync<=0;out_hsync<=0;out_de<=0;out_r<=0;out_g<=0;out_b<=0;end
  else begin
   vs_d<=in_vsync;de_d<=in_de;
   if(in_vsync&&!vs_d)begin x<=0;y<=0;end
   else if(in_de)x<=x+1'b1;
   else if(de_d&&!in_de)begin x<=0;y<=y+1'b1;end
   out_vsync<=in_vsync;out_hsync<=in_hsync;out_de<=in_de;
   if(ink)begin out_r<=8'hff;out_g<=8'hff;out_b<=8'hff;end
   else if(bg)begin out_r<=in_r>>2;out_g<=in_g>>2;out_b<=in_b>>2;end
   else begin out_r<=in_r;out_g<=in_g;out_b<=in_b;end
  end
 end
endmodule
