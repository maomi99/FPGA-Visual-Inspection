// edge_shape_boxes.v
// Timing-conscious class overlay + Chinese class name label.
// Class colors stay unchanged:
//   1 circle=blue, 2 rectangle=green, 3 triangle=red, 4 hexagon=magenta.
// Chinese labels:
//   circle -> 圆形, rectangle -> 矩形, triangle -> 三角形, hexagon -> 六边形
// 16x16 glyphs are embedded as a tiny bitmap ROM; no external font file is needed.
module edge_shape_boxes #(
    parameter integer MAX_OBJECTS = 8
)(
    input  wire clk,input wire rst_n,input wire in_vsync,input wire in_hsync,input wire in_de,
    input  wire [7:0] in_r,in_g,in_b,
    input  wire [MAX_OBJECTS-1:0] object_valid,
    input  wire [MAX_OBJECTS*3-1:0] object_class,
    input  wire [MAX_OBJECTS*12-1:0] object_xmin,object_xmax,object_ymin,object_ymax,
    output reg out_vsync,out_hsync,out_de,output reg [7:0] out_r,out_g,out_b
);
    reg [MAX_OBJECTS-1:0] dv;
    reg [MAX_OBJECTS*3-1:0] dc;
    reg [MAX_OBJECTS*12-1:0] xmin,xmax,ymin,ymax;
    reg [11:0] x,y; reg vs_d,de_d;

    // stage 1: box hit + Chinese-label region selection
    reg [MAX_OBJECTS-1:0] hit_s1;
    reg vs_s1,hs_s1,de_s1; reg [7:0] r_s1,g_s1,b_s1;
    reg label_valid_s1; reg [2:0] label_class_s1;
    reg [5:0] label_relx_s1; reg [3:0] label_rely_s1;
    reg [MAX_OBJECTS-1:0] hit_next;
    reg label_valid_next; reg [2:0] label_class_next;
    reg [5:0] label_relx_next; reg [3:0] label_rely_next;
    reg [11:0] lx0,ly0; integer i;

    always @* begin
        hit_next={MAX_OBJECTS{1'b0}};
        label_valid_next=1'b0;label_class_next=3'd0;
        label_relx_next=0;label_rely_next=0;lx0=0;ly0=0;
        if(in_de && x>=12'd960) begin
            for(i=0;i<MAX_OBJECTS;i=i+1) begin
                hit_next[i]=dv[i] && x>=xmin[i*12 +:12] && x<=xmax[i*12 +:12] &&
                            y>=ymin[i*12 +:12] && y<=ymax[i*12 +:12];
                lx0=xmin[i*12 +:12];
                ly0=(ymin[i*12 +:12]>=12'd20)?ymin[i*12 +:12]-12'd20:ymin[i*12 +:12]+12'd2;
                // 48x16 fits the longest three-Chinese-character label.
                if(!label_valid_next && dv[i] && dc[i*3 +:3]!=0 &&
                   x>=lx0 && x<lx0+12'd48 && y>=ly0 && y<ly0+12'd16) begin
                    label_valid_next=1'b1;label_class_next=dc[i*3 +:3];
                    label_relx_next=x-lx0;label_rely_next=y-ly0;
                end
            end
        end
    end

    reg edge_selected_s2; reg [2:0] edge_class_s2;
    reg label_bit_s2,label_valid_s2; reg [2:0] label_class_s2;
    reg vs_s2,hs_s2,de_s2; reg [7:0] r_s2,g_s2,b_s2;
    integer j; reg [1:0] char_idx; reg [3:0] glyph_col,glyph_row; reg [3:0] glyph_code; reg [15:0] glyph_bits;

    // code: 1圆 2形 3矩 4三 5角 6六 7边
    function [15:0] chinese_row;
      input [3:0] code; input [3:0] row;
      begin chinese_row=16'h0000; case(code)
      4'd1: begin // 圆
        case(row)
          4'd0: chinese_row=16'h7FFC;
          4'd1: chinese_row=16'h7FFC;
          4'd2: chinese_row=16'h600C;
          4'd3: chinese_row=16'h6FEC;
          4'd4: chinese_row=16'h6C6C;
          4'd5: chinese_row=16'h6FEC;
          4'd6: chinese_row=16'h6FEC;
          4'd7: chinese_row=16'h6FEC;
          4'd8: chinese_row=16'h696C;
          4'd9: chinese_row=16'h6B6C;
          4'd10: chinese_row=16'h67EC;
          4'd11: chinese_row=16'h7EFC;
          4'd12: chinese_row=16'h682C;
          4'd13: chinese_row=16'h7FFC;
          4'd14: chinese_row=16'h7FFC;
          4'd15: chinese_row=16'h0000;
          default: chinese_row=16'h0000;
        endcase
      end
      4'd2: begin // 形
        case(row)
          4'd0: chinese_row=16'h0008;
          4'd1: chinese_row=16'h7F9C;
          4'd2: chinese_row=16'h7FB8;
          4'd3: chinese_row=16'h3770;
          4'd4: chinese_row=16'h3760;
          4'd5: chinese_row=16'h370C;
          4'd6: chinese_row=16'hFF9C;
          4'd7: chinese_row=16'hFFF8;
          4'd8: chinese_row=16'h3770;
          4'd9: chinese_row=16'h370C;
          4'd10: chinese_row=16'h370C;
          4'd11: chinese_row=16'h7718;
          4'd12: chinese_row=16'h6778;
          4'd13: chinese_row=16'hE7E0;
          4'd14: chinese_row=16'h4740;
          4'd15: chinese_row=16'h0000;
          default: chinese_row=16'h0000;
        endcase
      end
      4'd3: begin // 矩
        case(row)
          4'd0: chinese_row=16'h2000;
          4'd1: chinese_row=16'h61FC;
          4'd2: chinese_row=16'h7FFC;
          4'd3: chinese_row=16'h7D80;
          4'd4: chinese_row=16'hF9FC;
          4'd5: chinese_row=16'h59FC;
          4'd6: chinese_row=16'h7F8C;
          4'd7: chinese_row=16'h7F8C;
          4'd8: chinese_row=16'h19FC;
          4'd9: chinese_row=16'h39FC;
          4'd10: chinese_row=16'h3D80;
          4'd11: chinese_row=16'h3F80;
          4'd12: chinese_row=16'h77FC;
          4'd13: chinese_row=16'hE1FE;
          4'd14: chinese_row=16'h4000;
          4'd15: chinese_row=16'h0000;
          default: chinese_row=16'h0000;
        endcase
      end
      4'd4: begin // 三
        case(row)
          4'd0: chinese_row=16'h0000;
          4'd1: chinese_row=16'h3FF8;
          4'd2: chinese_row=16'h3FF8;
          4'd3: chinese_row=16'h0000;
          4'd4: chinese_row=16'h0000;
          4'd5: chinese_row=16'h0000;
          4'd6: chinese_row=16'h0000;
          4'd7: chinese_row=16'h1FF0;
          4'd8: chinese_row=16'h1FF0;
          4'd9: chinese_row=16'h0000;
          4'd10: chinese_row=16'h0000;
          4'd11: chinese_row=16'h0000;
          4'd12: chinese_row=16'h7FFC;
          4'd13: chinese_row=16'h7FFC;
          4'd14: chinese_row=16'h0000;
          4'd15: chinese_row=16'h0000;
          default: chinese_row=16'h0000;
        endcase
      end
      4'd5: begin // 角
        case(row)
          4'd0: chinese_row=16'h0C00;
          4'd1: chinese_row=16'h1FE0;
          4'd2: chinese_row=16'h1FE0;
          4'd3: chinese_row=16'h38E0;
          4'd4: chinese_row=16'h7FFC;
          4'd5: chinese_row=16'h7FFC;
          4'd6: chinese_row=16'h399C;
          4'd7: chinese_row=16'h1FFC;
          4'd8: chinese_row=16'h3FFC;
          4'd9: chinese_row=16'h399C;
          4'd10: chinese_row=16'h3FFC;
          4'd11: chinese_row=16'h3FFC;
          4'd12: chinese_row=16'h319C;
          4'd13: chinese_row=16'h71FC;
          4'd14: chinese_row=16'h61B8;
          4'd15: chinese_row=16'h0000;
          default: chinese_row=16'h0000;
        endcase
      end
      4'd6: begin // 六
        case(row)
          4'd0: chinese_row=16'h0300;
          4'd1: chinese_row=16'h0380;
          4'd2: chinese_row=16'h0380;
          4'd3: chinese_row=16'h0180;
          4'd4: chinese_row=16'h7FFC;
          4'd5: chinese_row=16'h7FFE;
          4'd6: chinese_row=16'h0000;
          4'd7: chinese_row=16'h0820;
          4'd8: chinese_row=16'h0C60;
          4'd9: chinese_row=16'h1C70;
          4'd10: chinese_row=16'h1838;
          4'd11: chinese_row=16'h3838;
          4'd12: chinese_row=16'h701C;
          4'd13: chinese_row=16'h600C;
          4'd14: chinese_row=16'h2008;
          4'd15: chinese_row=16'h0000;
          default: chinese_row=16'h0000;
        endcase
      end
      4'd7: begin // 边
        case(row)
          4'd0: chinese_row=16'h60C0;
          4'd1: chinese_row=16'h70C0;
          4'd2: chinese_row=16'h3FFC;
          4'd3: chinese_row=16'h07FC;
          4'd4: chinese_row=16'h00CC;
          4'd5: chinese_row=16'hF1CC;
          4'd6: chinese_row=16'hF18C;
          4'd7: chinese_row=16'h318C;
          4'd8: chinese_row=16'h338C;
          4'd9: chinese_row=16'h330C;
          4'd10: chinese_row=16'h377C;
          4'd11: chinese_row=16'h3678;
          4'd12: chinese_row=16'h7C04;
          4'd13: chinese_row=16'hEFFE;
          4'd14: chinese_row=16'h43FC;
          4'd15: chinese_row=16'h0000;
          default: chinese_row=16'h0000;
        endcase
      end
        default:chinese_row=16'h0000;
      endcase end
    endfunction

    always @* begin
        edge_selected_s2=1'b0;edge_class_s2=0;
        for(j=0;j<MAX_OBJECTS;j=j+1)
            if(!edge_selected_s2 && hit_s1[j]) begin edge_selected_s2=1'b1;edge_class_s2=dc[j*3 +:3];end

        char_idx=label_relx_s1[5:4];
        glyph_col=label_relx_s1[3:0];
        glyph_row=label_rely_s1;
        glyph_code=0;
        case(label_class_s1)
          3'd1: case(char_idx) 0:glyph_code=1;1:glyph_code=2;default:glyph_code=0;endcase       // 圆形
          3'd2: case(char_idx) 0:glyph_code=3;1:glyph_code=2;default:glyph_code=0;endcase       // 矩形
          3'd3: case(char_idx) 0:glyph_code=4;1:glyph_code=5;2:glyph_code=2;default:glyph_code=0;endcase // 三角形
          3'd4: case(char_idx) 0:glyph_code=6;1:glyph_code=7;2:glyph_code=2;default:glyph_code=0;endcase // 六边形
          default:glyph_code=0;
        endcase
        glyph_bits=chinese_row(glyph_code,glyph_row);
        label_bit_s2=label_valid_s1 && glyph_code!=0 && glyph_bits[15-glyph_col];
    end

    function [23:0] class_color; input [2:0] cls; begin
      case(cls)
        3'd1:class_color=24'h0064ff;
        3'd2:class_color=24'h00ff46;
        3'd3:class_color=24'hff4646;
        3'd4:class_color=24'hff00ff;
        default:class_color=24'hffffff;
      endcase
    end endfunction

    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        dv<=0;dc<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;x<=0;y<=0;vs_d<=0;de_d<=0;
        hit_s1<=0;vs_s1<=0;hs_s1<=0;de_s1<=0;r_s1<=0;g_s1<=0;b_s1<=0;
        label_valid_s1<=0;label_class_s1<=0;label_relx_s1<=0;label_rely_s1<=0;
        vs_s2<=0;hs_s2<=0;de_s2<=0;r_s2<=0;g_s2<=0;b_s2<=0;label_valid_s2<=0;label_class_s2<=0;
        out_vsync<=0;out_hsync<=0;out_de<=0;out_r<=0;out_g<=0;out_b<=0;
      end else begin
        vs_d<=in_vsync;de_d<=in_de;
        if(in_vsync&&!vs_d) begin x<=0;y<=0;dv<=object_valid;dc<=object_class;xmin<=object_xmin;xmax<=object_xmax;ymin<=object_ymin;ymax<=object_ymax;end
        else if(in_de)x<=x+1'b1; else if(de_d)begin x<=0;y<=y+1'b1;end

        hit_s1<=hit_next;vs_s1<=in_vsync;hs_s1<=in_hsync;de_s1<=in_de;r_s1<=in_r;g_s1<=in_g;b_s1<=in_b;
        label_valid_s1<=label_valid_next;label_class_s1<=label_class_next;label_relx_s1<=label_relx_next;label_rely_s1<=label_rely_next;

        vs_s2<=vs_s1;hs_s2<=hs_s1;de_s2<=de_s1;label_valid_s2<=label_valid_s1;label_class_s2<=label_class_s1;
        if(de_s1 && edge_selected_s2 && ((r_s1|g_s1|b_s1)!=0)) {r_s2,g_s2,b_s2}<=class_color(edge_class_s2);
        else begin r_s2<=r_s1;g_s2<=g_s1;b_s2<=b_s1;end

        out_vsync<=vs_s2;out_hsync<=hs_s2;out_de<=de_s2;
        if(!de_s2)begin out_r<=0;out_g<=0;out_b<=0;end
        else if(label_valid_s2)begin
          if(label_bit_s2){out_r,out_g,out_b}<=class_color(label_class_s2);
          else {out_r,out_g,out_b}<=24'h000000;
        end else begin out_r<=r_s2;out_g<=g_s2;out_b<=b_s2;end
      end
    end
endmodule
