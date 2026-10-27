module replay_status_osd_mode #(
 parameter integer TOTAL_FRAMES=100,
 parameter integer X0=32,Y0=32
)(
 input wire ui_clk,ui_reset,
 input wire enable_ui,
 input wire [2:0] mode_ui,
 input wire [6:0] count_ui,number_ui,
 input wire pclk,rst_n,in_vsync,in_hsync,in_de,
 input wire [7:0] in_r,in_g,in_b,
 output reg out_vsync,out_hsync,out_de,
 output reg [7:0] out_r,out_g,out_b
);
 reg [17:0] mailbox;
 reg req,ack;
 (* async_reg="true" *) reg ack_meta,ack_sync,req_meta,req_sync;
 reg seen;
 reg [17:0] pending,shown;
 wire [17:0] status_now={enable_ui,mode_ui,count_ui,number_ui};
 always @(posedge ui_clk or posedge ui_reset) begin
  if(ui_reset) begin mailbox<=0;req<=0;ack_meta<=0;ack_sync<=0;end
  else begin
   ack_meta<=ack;ack_sync<=ack_meta;
   if(ack_sync==req && mailbox!=status_now) begin mailbox<=status_now;req<=~req;end
  end
 end
 // mailbox stays stable until ack traverses back to the source. Both clocks
 // must be running; resets are the existing board UI/pixel resets.
 reg vs_d,de_d;
 reg [11:0] x,y;
 always @(posedge pclk or negedge rst_n) begin
  if(!rst_n) begin
   req_meta<=0;req_sync<=0;seen<=0;ack<=0;pending<=0;shown<=0;
   vs_d<=0;de_d<=0;x<=0;y<=0;
  end else begin
   req_meta<=req;req_sync<=req_meta;
   if(req_sync!=seen) begin pending<=mailbox;seen<=req_sync;ack<=req_sync;end
   vs_d<=in_vsync;de_d<=in_de;
   if(in_vsync&&!vs_d) begin x<=0;y<=0;shown<=pending;end
   else if(in_de) x<=x+1'b1;
   else if(de_d) begin x<=0;y<=y+1'b1;end
  end
 end
 wire shown_enable=shown[17];
 wire [2:0] shown_mode=shown[16:14];
 wire [6:0] value=(shown_mode==2)?shown[13:7]:shown[6:0];
 // Binary to BCD by small bounded subtract network, no general divider.
 reg [3:0] hundreds,tens,ones;
 reg [7:0] rem;
 integer j;
 always @* begin
  rem={1'b0,value};hundreds=0;tens=0;
  if(rem>=100) begin hundreds=1;rem=rem-100;end
  for(j=0;j<9;j=j+1) if(rem>=10) begin tens=tens+1'b1;rem=rem-10;end
  ones=rem[3:0];
 end
 reg [3:0] hd,td,od;
 always @(posedge pclk or negedge rst_n) begin
  if(!rst_n) begin hd<=0;td<=0;od<=0;end
  else begin hd<=hundreds;td<=tens;od<=ones;end
 end
 wire region=in_de && x>=X0 && x<X0+14*32 && y>=Y0 && y<Y0+28;
 wire [11:0] local_x=x-X0,local_y=y-Y0;
 wire [6:0] char_index=local_x>>5;
 wire [2:0] col=local_x[4:2];
 wire [2:0] row=local_y>>2;
 reg [7:0] ch;
 always @* begin
  ch=" ";
  case(char_index)
   0: case(shown_mode) 0:ch="L";1:ch="A";2:ch="R";3:ch="P";4:ch="P";default:ch="?";endcase
   1: case(shown_mode) 0:ch="I";1:ch="R";2:ch="E";3:ch="A";4:ch="L";default:ch=" ";endcase
   2: case(shown_mode) 0:ch="V";1:ch="M";2:ch="C";3:ch="U";4:ch="A";default:ch=" ";endcase
   3: case(shown_mode) 0:ch="E";3:ch="S";4:ch="Y";default:ch=" ";endcase
   5:ch="0"+hd;
   6:ch="0"+td;
   7:ch="0"+od;
   8:ch="/";
   9:ch="0"+(TOTAL_FRAMES/100)%10;
   10:ch="0"+(TOTAL_FRAMES/10)%10;
   11:ch="0"+TOTAL_FRAMES%10;
   default:ch=" ";
  endcase
 end
 function [34:0] glyph;
 input [7:0] c;
 begin
  case(c)
   "0":glyph=35'b01110100011001110101110011000101110;
   "1":glyph=35'b00100011000010000100001000010001110;
   "2":glyph=35'b01110100010000100010001000100011111;
   "3":glyph=35'b11110000010000101110000010000111110;
   "4":glyph=35'b00010001100101010010111110001000010;
   "5":glyph=35'b11111100001000011110000010000111110;
   "6":glyph=35'b01110100001000011110100011000101110;
   "7":glyph=35'b11111000010001000100010000100001000;
   "8":glyph=35'b01110100011000101110100011000101110;
   "9":glyph=35'b01110100011000101111000010000101110;
   "L":glyph=35'b10000100001000010000100001000011111;
   "I":glyph=35'b01110001000010000100001000010001110;
   "V":glyph=35'b10001100011000110001100010101000100;
   "E":glyph=35'b11111100001000011110100001000011111;
   "A":glyph=35'b01110100011000111111100011000110001;
   "R":glyph=35'b11110100011000111110101001001010001;
   "M":glyph=35'b10001110111010110101100011000110001;
   "C":glyph=35'b01111100001000010000100001000001111;
   "P":glyph=35'b11110100011000111110100001000010000;
   "U":glyph=35'b10001100011000110001100011000101110;
   "S":glyph=35'b01111100001000001110000010000111110;
   "Y":glyph=35'b10001100010101000100001000010000100;
   "/":glyph=35'b00001000010001000100010001000010000;
   default:glyph=0;
  endcase
 end
 endfunction
 reg [34:0] bits;
 reg [2:0] col_q,row_q;
 reg region_q,vs_q,hs_q,de_q;
 reg [7:0] r_q,g_q,b_q;
 always @(posedge pclk or negedge rst_n) begin
  if(!rst_n) begin bits<=0;col_q<=0;row_q<=0;region_q<=0;
   vs_q<=0;hs_q<=0;de_q<=0;r_q<=0;g_q<=0;b_q<=0;end
  else begin bits<=glyph(ch);col_q<=col;row_q<=row;region_q<=region;
   vs_q<=in_vsync;hs_q<=in_hsync;de_q<=in_de;r_q<=in_r;g_q<=in_g;b_q<=in_b;end
 end
 wire ink=(col_q<5)&&(row_q<7) ? bits[34-row_q*5-col_q] : 1'b0;
 always @(posedge pclk or negedge rst_n) begin
  if(!rst_n) begin out_vsync<=0;out_hsync<=0;out_de<=0;out_r<=0;out_g<=0;out_b<=0;end
  else begin
   out_vsync<=vs_q;out_hsync<=hs_q;out_de<=de_q;
   if(shown_enable && region_q) begin
    out_r<=ink?8'hff:8'h00;
    out_g<=ink?8'hff:8'h00;
    out_b<=ink?8'h00:8'h00;
   end else begin out_r<=r_q;out_g<=g_q;out_b<=b_q;end
  end
 end
endmodule
