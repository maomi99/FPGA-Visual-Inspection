module plate_geometry_overlay_slot #(
 parameter integer OSD_X=980, STALE_FRAMES=30,
 parameter integer CONFIRM_RESULTS=3,
 parameter integer INITIAL_CONFIRM_RESULTS=1
)(
 input wire clk,rst_n,show_enable,
 input wire in_vsync,in_hsync,in_de,input wire[7:0]in_r,in_g,in_b,
 input wire detected,passed,result_toggle,
 input wire[3:0]raw_fault,input wire[4:0]hole_count,
 input wire[11:0]box_valid,input wire[143:0]box_xmin,box_xmax,box_ymin,box_ymax,
 output reg out_vsync,out_hsync,out_de,output reg[7:0]out_r,out_g,out_b
);

reg[11:0] x,y;
 reg vd,dd,show_s,det_s,pass_s;
 reg[11:0] mask;
 reg[143:0] x0s,x1s,y0s,y1s;
 reg seen_toggle;
 reg[7:0] age;
 reg verdict_valid,last_candidate;
 reg have_result,raw_detected_s;
 reg[7:0] confirm_count;
 reg[3:0] fault_s;
 reg[4:0] holes_s;

 // -------------------------------------------------------------------------
 // Parallel geometry-border hit generation.
 // The old procedural for-loop repeatedly updated overall/defect and could
 // synthesize into a long priority chain.  Each box is independent here.
 // -------------------------------------------------------------------------
 wire [11:0] box_border_hit;
 genvar gi;
 generate
   for(gi=0; gi<12; gi=gi+1) begin: GEN_BOX_BORDER
     wire [11:0] bx0 = x0s[gi*12 +: 12];
     wire [11:0] bx1 = x1s[gi*12 +: 12];
     wire [11:0] by0 = y0s[gi*12 +: 12];
     wire [11:0] by1 = y1s[gi*12 +: 12];
     wire inside_box = (x>=bx0) && (x<=bx1) && (y>=by0) && (y<=by1);
     wire on_border  = (x<(bx0+12'd2)) || (x>(bx1-12'd2)) ||
                       (y<(by0+12'd2)) || (y>(by1-12'd2));
     assign box_border_hit[gi] = mask[gi] && inside_box && on_border;
   end
 endgenerate
 wire overall_hit = box_border_hit[0];
 wire defect_hit  = |box_border_hit[11:1];

 // -------------------------------------------------------------------------
 // 5x7 font, unchanged glyphs.
 // -------------------------------------------------------------------------
 function[4:0] font;
 input[7:0] c;
 input[2:0] r;
 begin
   font=0;
   case(c)
   "0":case(r)0,6:font=14;1,2,3,4,5:font=17;endcase
   "1":case(r)0,2,3,4,5:font=4;1:font=12;6:font=14;endcase
   "2":case(r)0,6:font=31;1:font=1;2:font=2;3:font=4;4:font=8;5:font=16;endcase
   "3":case(r)0,3,6:font=30;1,2,4,5:font=1;endcase
   "4":case(r)0,1,2:font=18;3:font=31;4,5,6:font=2;endcase
   "5":case(r)0,3,6:font=31;1,2:font=16;4,5:font=1;endcase
   "6":case(r)0,3,6:font=14;1,2:font=16;4,5:font=17;endcase
   "7":case(r)0:font=31;1:font=1;2:font=2;3:font=4;4,5,6:font=8;endcase
   "8":case(r)0,3,6:font=14;1,2,4,5:font=17;endcase
   "9":case(r)0,3,6:font=14;1,2:font=17;4,5:font=1;endcase
   "B":case(r)0,3,6:font=30;1,2,4,5:font=17;endcase
   "C":case(r)0,6:font=15;1,2,3,4,5:font=16;endcase
   "D":case(r)0,6:font=30;1,2,3,4,5:font=17;endcase
   "E":case(r)0,3,6:font=31;1,2,4,5:font=16;endcase
   "H":case(r)0,1,2,4,5,6:font=17;3:font=31;endcase
   "P":case(r)0,3:font=30;1,2:font=17;4,5,6:font=16;endcase
   "A":case(r)0:font=14;1,2,4,5,6:font=17;3:font=31;endcase
   "S":case(r)0,3,6:font=15;1,2:font=16;4,5:font=1;endcase
   "F":case(r)0,3:font=31;1,2,4,5,6:font=16;endcase
   "I":case(r)0,6:font=14;1,2,3,4,5:font=4;endcase
   "L":case(r)0,1,2,3,4,5:font=16;6:font=31;endcase
   "-":case(r)3:font=31;endcase
   default:font=0;
   endcase
 end
 endfunction

 // -------------------------------------------------------------------------
 // Fixed OSD region decode.
 // Replaces gx/12 and gx%12 with six fixed 12-pixel cells.  This keeps the
 // exact same 5x7 font scaled 2x inside each 12-pixel cell (10 active + 2 gap).
 // -------------------------------------------------------------------------
 reg [2:0] text_line;       // 0=none, 1=title, 2=diagnostic, 3=status
 reg [2:0] char_index;      // 0..5
 reg [3:0] cell_offset;     // 0..11
 reg [2:0] font_col;        // 0..5 after /2
 reg [2:0] font_row;        // 0..7 after /2
 reg [7:0] text_ch;
 reg [4:0] glyph_bits;
 reg text_bit;
 reg in_text_rect;
 reg [11:0] text_x_rel;
 reg [5:0] text_y_rel;

 always @* begin
   text_line=0; char_index=0; cell_offset=0; font_col=0; font_row=0;
   text_ch=" "; glyph_bits=0; text_bit=0; in_text_rect=0;
   text_x_rel=0; text_y_rel=0;

   // Full painted rectangles are 16 pixels high, matching the original.
   if(x>=OSD_X && x<(OSD_X+74)) begin
     if(y>=12'd54 && y<12'd70) begin
       text_line=2; in_text_rect=1; text_x_rel=x-OSD_X; text_y_rel=y-12'd54;
     end else if(y>=12'd76 && y<12'd92) begin
       text_line=3; in_text_rect=1; text_x_rel=x-OSD_X; text_y_rel=y-12'd76;
     end else if(x<(OSD_X+50) && y>=12'd32 && y<12'd48) begin
       text_line=1; in_text_rect=1; text_x_rel=x-OSD_X; text_y_rel=y-12'd32;
     end
   end

   // Fixed 12-pixel character cells; no divider/modulo hardware.
   if(text_x_rel<12) begin char_index=0; cell_offset=text_x_rel[3:0]; end
   else if(text_x_rel<24) begin char_index=1; cell_offset=text_x_rel-12; end
   else if(text_x_rel<36) begin char_index=2; cell_offset=text_x_rel-24; end
   else if(text_x_rel<48) begin char_index=3; cell_offset=text_x_rel-36; end
   else if(text_x_rel<60) begin char_index=4; cell_offset=text_x_rel-48; end
   else begin char_index=5; cell_offset=text_x_rel-60; end
   font_col = cell_offset[3:1];
   font_row = text_y_rel[3:1];

   case(text_line)
     1: begin
       if(pass_s) begin
         case(char_index) 0:text_ch="P";1:text_ch="A";2:text_ch="S";3:text_ch="S";default:text_ch=" ";endcase
       end else begin
         case(char_index) 0:text_ch="F";1:text_ch="A";2:text_ch="I";3:text_ch="L";default:text_ch=" ";endcase
       end
     end
     2: begin
       case(char_index)
         0:text_ch="F";
         1:text_ch=(fault_s<10)?("0"+fault_s):("A"+fault_s-10);
         3:text_ch="H";
         4:text_ch="0"+holes_s[4];
         5:text_ch=(holes_s[3:0]<10)?("0"+holes_s[3:0]):("A"+holes_s[3:0]-10);
         default:text_ch=" ";
       endcase
     end
     3: begin
       case(char_index)
         0:text_ch="D";
         1:text_ch=have_result?(raw_detected_s?"1":"0"):"-";
         3:text_ch="A";
         4:text_ch=!have_result?"-":((age[7:4]<10)?("0"+age[7:4]):("A"+age[7:4]-10));
         5:text_ch=!have_result?"-":((age[3:0]<10)?("0"+age[3:0]):("A"+age[3:0]-10));
         default:text_ch=" ";
       endcase
     end
     default:text_ch=" ";
   endcase

   if(in_text_rect && text_y_rel<14 && font_col<5 && font_row<7) begin
     glyph_bits=font(text_ch,font_row);
     text_bit=glyph_bits[4-font_col];
   end
 end

 // -------------------------------------------------------------------------
 // Stage 1: register all overlay decisions and the source pixel/control.
 // Final RGB selection no longer sees x/y or the large box/font logic.
 // -------------------------------------------------------------------------
 localparam [2:0] PAINT_NONE       = 3'd0;
 localparam [2:0] PAINT_GREEN      = 3'd1;
 localparam [2:0] PAINT_RED        = 3'd2;
 localparam [2:0] PAINT_TITLE_G    = 3'd3;
 localparam [2:0] PAINT_TITLE_R    = 3'd4;
 localparam [2:0] PAINT_DIAG       = 3'd5;
 localparam [2:0] PAINT_STATUS     = 3'd6;

 reg s1_vsync,s1_hsync,s1_de;
 reg [7:0] s1_r,s1_g,s1_b;
 reg [2:0] s1_paint;
 reg s1_text_bit;
 reg [2:0] paint_next;

 always @* begin
   paint_next=PAINT_NONE;

   // Overall/defect border display is only active for a detected target.
   if(show_s && det_s && in_de && x>=12'd960) begin
     if(overall_hit) paint_next = pass_s ? PAINT_GREEN : PAINT_RED;
     if(defect_hit)  paint_next = PAINT_RED; // same priority as the verified code

     // PASS/FAIL title overrides geometry borders in its rectangle.
     if(text_line==1 && in_text_rect)
       paint_next = pass_s ? PAINT_TITLE_G : PAINT_TITLE_R;
   end

   // Raw diagnostic/status OSD override the debounced target overlay.
   if(show_s && in_de && text_line==2 && in_text_rect) paint_next=PAINT_DIAG;
   if(show_s && in_de && text_line==3 && in_text_rect) paint_next=PAINT_STATUS;
 end

 // -------------------------------------------------------------------------
 // Sequential block: metadata/counters remain frame based; output adds one
 // pipeline clock, with VS/HS/DE/RGB delayed together so there is no skew.
 // -------------------------------------------------------------------------
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
     x<=0; y<=0; vd<=0; dd<=0; show_s<=0; det_s<=0; pass_s<=0; mask<=0;
     x0s<=0; x1s<=0; y0s<=0; y1s<=0; seen_toggle<=0; age<=15;
     verdict_valid<=0; last_candidate<=0; confirm_count<=0; fault_s<=0; holes_s<=0;
     have_result<=0; raw_detected_s<=0;

     s1_vsync<=0; s1_hsync<=0; s1_de<=0; s1_r<=0; s1_g<=0; s1_b<=0;
     s1_paint<=PAINT_NONE; s1_text_bit<=0;
     out_vsync<=0; out_hsync<=0; out_de<=0; out_r<=0; out_g<=0; out_b<=0;
   end else begin
     // Pixel counters and frame-level metadata snapshot: original behavior.
     vd<=in_vsync;
     dd<=in_de;
     if(in_vsync && !vd) begin
       x<=0; y<=0; show_s<=show_enable; seen_toggle<=result_toggle;
       if(!show_enable) begin
         have_result<=0; raw_detected_s<=0; age<=15; det_s<=0;
         verdict_valid<=0; confirm_count<=0;
       end else if(result_toggle!=seen_toggle) begin
         age<=0; fault_s<=raw_fault; holes_s<=hole_count;
         have_result<=1; raw_detected_s<=detected;
         x0s<=box_xmin; x1s<=box_xmax; y0s<=box_ymin; y1s<=box_ymax;
         if(!detected) begin
           det_s<=0; verdict_valid<=0; confirm_count<=0; mask<=0;
         end else if(verdict_valid && passed==pass_s) begin
           det_s<=1; confirm_count<=0; last_candidate<=passed;
           mask<=passed ? (box_valid & 12'b1) : box_valid;
         end else begin
           last_candidate<=passed;
           if((!verdict_valid && (INITIAL_CONFIRM_RESULTS<=1 ||
               (last_candidate==passed && confirm_count>=INITIAL_CONFIRM_RESULTS-1))) ||
              (verdict_valid && (CONFIRM_RESULTS<=1 ||
               (last_candidate==passed && confirm_count>=CONFIRM_RESULTS-1)))) begin
             det_s<=1; verdict_valid<=1; pass_s<=passed; confirm_count<=0;
             mask<=passed ? (box_valid & 12'b1) : box_valid;
           end else begin
             confirm_count<=last_candidate==passed ? confirm_count+1'b1 : 8'd1;
             det_s<=verdict_valid;
             mask<=box_valid & 12'b1;
           end
         end
       end else begin
         if(age<255) age<=age+1'b1;
         if(age>=STALE_FRAMES-1) begin det_s<=0; verdict_valid<=0; confirm_count<=0; end
       end
     end else if(in_de) begin
       x<=x+1'b1;
     end else if(dd) begin
       x<=0; y<=y+1'b1;
     end

     // Stage 1 capture.
     s1_vsync<=in_vsync;
     s1_hsync<=in_hsync;
     s1_de<=in_de;
     s1_r<=in_r;
     s1_g<=in_g;
     s1_b<=in_b;
     s1_paint<=paint_next;
     s1_text_bit<=text_bit;

     // Stage 2: very small final mux; no x/y or box/font arithmetic here.
     out_vsync<=s1_vsync;
     out_hsync<=s1_hsync;
     out_de<=s1_de;
     if(!s1_de) begin
       out_r<=8'h00; out_g<=8'h00; out_b<=8'h00;
     end else begin
       case(s1_paint)
         PAINT_GREEN: begin out_r<=8'h00; out_g<=8'hff; out_b<=8'h00; end
         PAINT_RED: begin out_r<=8'hff; out_g<=8'h00; out_b<=8'h00; end
         PAINT_TITLE_G: begin
           if(s1_text_bit) begin out_r<=8'h00;out_g<=8'hff;out_b<=8'h00;end
           else begin out_r<=8'h00;out_g<=8'h00;out_b<=8'h00;end
         end
         PAINT_TITLE_R: begin
           if(s1_text_bit) begin out_r<=8'hff;out_g<=8'h00;out_b<=8'h00;end
           else begin out_r<=8'h00;out_g<=8'h00;out_b<=8'h00;end
         end
         PAINT_DIAG: begin
           if(s1_text_bit) begin out_r<=8'hff;out_g<=8'hff;out_b<=8'h00;end
           else begin out_r<=8'h00;out_g<=8'h00;out_b<=8'h00;end
         end
         PAINT_STATUS: begin
           if(s1_text_bit) begin out_r<=8'h00;out_g<=8'hff;out_b<=8'hff;end
           else begin out_r<=8'h00;out_g<=8'h00;out_b<=8'h00;end
         end
         default: begin out_r<=s1_r; out_g<=s1_g; out_b<=s1_b; end
       endcase
     end
   end
 end
endmodule
