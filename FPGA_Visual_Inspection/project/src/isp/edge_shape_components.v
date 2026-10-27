module edge_shape_components #(
    parameter integer MAX_OBJECTS=8,
    parameter integer MIN_EDGE=30,
    parameter integer MIN_SIZE=8,
    parameter integer SIDE_TOL=3,
    parameter integer RECT_FIT_PERCENT=88,
    parameter integer RECT_MIN_SIDE=16,
    parameter integer RECT_MAX_ASPECT=2,
    parameter integer RECT_MIN_BINS=6,
    parameter integer RECT_CORNER_TOL=4,
    parameter integer RECT_CORNER_POINTS=2,
    parameter integer RECT_ADAPTIVE_TOL=1,
    parameter integer RECT_SIDE_TOL_MAX=8,
    parameter integer RECT_CORNER_TOL_MAX=10,
    parameter integer POLY_FIT_PERCENT=92,
    // Relaxed generic-triangle thresholds.  These apply only while poly_hex=0.
    parameter integer TRI_FIT_PERCENT=80,
    parameter integer TRI_MIN_SIDE_POINTS=3,
    parameter integer TRI_SUPPORT_PERCENT=45,
    parameter integer POLY_MIN_SPAN=24,
    parameter integer HEX_MIN_SPAN=48,
    parameter integer POLY_TOL_Q8=512,
    parameter integer POLY_MAX_TOL_Q8=1024,
    parameter integer RECT_STRICT_PERCENT=75,
    parameter integer CIRCLE_FIT_PERCENT=80,
    parameter integer QUEUE_AW=11,
    parameter integer POINT_AW=11
) (
    input wire clk, rst_n, in_vsync, in_de,
    input wire [7:0] in_edge,
    output reg [MAX_OBJECTS-1:0] object_valid,
    output reg [MAX_OBJECTS*3-1:0] object_class,
    output reg [MAX_OBJECTS*12-1:0] object_xmin,object_xmax,
    output reg [MAX_OBJECTS*12-1:0] object_ymin,object_ymax,
    output reg result_toggle,
    output reg frame_error,
    output reg [15:0] skipped_frames,
    output reg [15:0] component_count_debug,
    output wire analysis_busy
);
    localparam integer SW=240, SH=270, DEPTH=64800;
    localparam integer QDEPTH=(1<<QUEUE_AW), PDEPTH=(1<<POINT_AW);
    // P_* rectangle/circle datapath is split over several cycles to remove
    // the point_mem -> DSP projection -> corner-counter critical path.
    localparam [5:0] IDLE=0,SCAN_ADDR=1,SCAN_WAIT=2,SCAN_TEST=3,
        NEXT_SCAN=4,Q_WAIT=5,Q_POP=6,N_ADDR=7,N_WAIT=8,N_TEST=9,
        N_NEXT=10,COMP_END=11,R_PREP=12,P_ADDR=13,P_WAIT=14,
        P_TEST=15,R_DECIDE=16,A_PREP=17,A_SUPPORT=18,A_DECIDE=19,
        SAVE=20,PUBLISH=21,Q_ADDR=22, POL_PREP=23, POL_ADDR=24, POL_WAIT=25,
        POL_PROJ=26, POL_USE=27, POL_NEXT=28, POL_DECIDE=29, POL_SUPPORT=30,
        POL_METRIC=31, P_COORD=32, P_PROJECT=33, P_DELTA=34, P_FLAGS=35,
        R_METRIC=36, A_METRIC=37, POL_FINAL_METRIC=38,
        POL_METRIC_SPAN=39, POL_METRIC_SCALE=40, POL_METRIC_ACCUM=41;
    reg [5:0] state;
    assign analysis_busy=(state!=IDLE);
    reg vs_d,de_d,frame_seen,write_bank,read_bank;
    reg [11:0] x,y;
    reg [239:0] block_or;
    wire [7:0] cap_col=(x>=960 && x<1920)?((x-960)>>2):0;
    wire [15:0] cap_addr=(y>>2)*240+cap_col;
    wire cap_we=rst_n && frame_seen && in_de &&
                !(in_vsync && !vs_d) && x>=960 && x<1920 && y<1080 &&
                x[1:0]==2'b11 && y[1:0]==2'b11;
    wire cap_bit=block_or[cap_col] | (in_edge!=0);
    reg [0:0] map0[0:DEPTH-1],map1[0:DEPTH-1];
    reg [0:0] map0_q,map1_q;
    reg [15:0] maddr,clear_addr;
    reg clear_we;
    wire mbit=read_bank?map1_q[0]:map0_q[0];
    // Banks alternate roles. A bank has one write address in a given cycle.
    wire we0=(cap_we && !write_bank)||(clear_we && !read_bank);
    wire we1=(cap_we && write_bank)||(clear_we && read_bank);
    wire [15:0] wa0=(clear_we && !read_bank)?clear_addr:cap_addr;
    wire [15:0] wa1=(clear_we && read_bank)?clear_addr:cap_addr;
    wire wd0=(clear_we && !read_bank)?1'b0:cap_bit;
    wire wd1=(clear_we && read_bank)?1'b0:cap_bit;
    always @(posedge clk) if(we0) map0[wa0]<=wd0;
    always @(posedge clk) if(we1) map1[wa1]<=wd1;
    always @(posedge clk) map0_q<=map0[maddr];
    always @(posedge clk) map1_q<=map1[maddr];

    // Coordinates {y[8:0],x[7:0]}. FIFO frontier, not a frame label image.
    reg [16:0] queue_mem[0:QDEPTH-1],point_mem[0:PDEPTH-1];
    reg [16:0] queue_q,point_q,qdata,pdata;
    reg [QUEUE_AW-1:0] qhead,qtail,qwaddr;
    reg [POINT_AW-1:0] praddr,pwaddr;
    reg qwe,pwe;
    reg [QUEUE_AW:0] qcount;
    always @(posedge clk) if(qwe) queue_mem[qwaddr]<=qdata;
    always @(posedge clk) queue_q<=queue_mem[qhead];
    always @(posedge clk) if(pwe) point_mem[pwaddr]<=pdata;
    always @(posedge clk) point_q<=point_mem[praddr];

    reg [15:0] scan_addr,naddr,count,pindex,inliers,fit_count;
    reg [7:0] scan_x,px,minx,maxx,cx,nx;
    reg [8:0] scan_y,py,miny,maxy,cy,ny;
    reg [2:0] neighbor;
    reg touch,component_large,work_error;
    reg [7:0] octants;
    reg [18:0] radius2;
    reg [2:0] kind;
    reg [5:0] angle;
    reg support_pass;
    reg [15:0] sides0,sides1,sides2,sides3;
    reg signed [20:0] umin,umax,vmin,vmax;
    reg [7:0] cover0,cover1,cover2,cover3;
    reg [15:0] corners0,corners1,corners2,corners3;

    // Timing pipeline for circle/rectangle point tests.
    reg signed [10:0] p_dx_q,p_dy_q;
    reg signed [20:0] p_u_q,p_v_q;
    reg [22:0] p_distance2_q;
    reg [2:0]  p_sector_q;
    reg [21:0] p_from_u_q,p_to_u_q,p_from_v_q,p_to_v_q;
    reg p_side0_q,p_side1_q,p_side2_q,p_side3_q;
    reg p_corner0_q,p_corner1_q,p_corner2_q,p_corner3_q;
    reg p_rect_strict_near_q;
    reg p_circle_inlier_q;
    reg [2:0] p_bin_u_q,p_bin_v_q;

    // Registered final-decision metrics.  The old R/A/POL decide states mixed
    // multiply-by-constant, reductions and next-state control in one cycle.
    // These registers isolate arithmetic from FSM control without changing any
    // threshold or classification formula.
    reg [31:0] r_fit_lhs_q,r_fit_rhs_q;
    reg r_octants_ok_q,r_aspect_ok_q;
    reg [31:0] a_fit_lhs_q,a_fit_rhs_q,a_strict_lhs_q,a_strict_rhs_q;
    reg a_shape_ok_q;
    reg [31:0] poly_fit_lhs_q,poly_fit_rhs_q;
    reg poly_shape_ok_q;

    reg [MAX_OBJECTS-1:0] work_valid;
    reg [MAX_OBJECTS*3-1:0] work_class;
    reg [MAX_OBJECTS*12-1:0] work_xmin,work_xmax,work_ymin,work_ymax;
    integer slot;
    reg [15:0] work_components;

    reg signed [10:0] tx,ty;
    always @* begin
        tx=$signed({1'b0,px}); ty=$signed({1'b0,py});
        case(neighbor)
            0: begin tx=tx-1;ty=ty-1;end
            1: begin ty=ty-1;end
            2: begin tx=tx+1;ty=ty-1;end
            3: begin tx=tx-1;end
            4: begin tx=tx+1;end
            5: begin tx=tx-1;ty=ty+1;end
            6: begin ty=ty+1;end
            7: begin tx=tx+1;ty=ty+1;end
        endcase
    end
    wire neighbor_ok=(tx>=0 && tx<240 && ty>=0 && ty<270);
    wire [9:0] bw={2'b0,maxx}-{2'b0,minx}+1'b1;
    wire [9:0] bh={1'b0,maxy}-{1'b0,miny}+1'b1;
    wire [19:0] box_square=bw*bw+bh*bh;
    wire signed [10:0] dx=$signed({1'b0,point_q[7:0]})-$signed({1'b0,cx});
    wire signed [10:0] dy=$signed({1'b0,point_q[16:8]})-$signed({1'b0,cy});
    wire [21:0] dx2=dx*dx,dy2=dy*dy;
    wire [22:0] distance2=dx2+dy2;
    wire [10:0] absdx=dx[10]?-dx:dx,absdy=dy[10]?-dy:dy;
    wire [2:0] sector={dy[10],dx[10],(absdx>absdy)};
    reg signed [9:0] cosine,sine;
    // 64 orientations, 1.40625 degrees per step, modulo 90 degrees.
    // Constant Q8 ROM; no real numbers/trigonometry in hardware.
    always @* begin
        case(angle)
            6'd0:begin cosine=10'sd256;sine=10'sd0;end
            6'd1:begin cosine=10'sd256;sine=10'sd6;end
            6'd2:begin cosine=10'sd256;sine=10'sd13;end
            6'd3:begin cosine=10'sd255;sine=10'sd19;end
            6'd4:begin cosine=10'sd255;sine=10'sd25;end
            6'd5:begin cosine=10'sd254;sine=10'sd31;end
            6'd6:begin cosine=10'sd253;sine=10'sd38;end
            6'd7:begin cosine=10'sd252;sine=10'sd44;end
            6'd8:begin cosine=10'sd251;sine=10'sd50;end
            6'd9:begin cosine=10'sd250;sine=10'sd56;end
            6'd10:begin cosine=10'sd248;sine=10'sd62;end
            6'd11:begin cosine=10'sd247;sine=10'sd68;end
            6'd12:begin cosine=10'sd245;sine=10'sd74;end
            6'd13:begin cosine=10'sd243;sine=10'sd80;end
            6'd14:begin cosine=10'sd241;sine=10'sd86;end
            6'd15:begin cosine=10'sd239;sine=10'sd92;end
            6'd16:begin cosine=10'sd237;sine=10'sd98;end
            6'd17:begin cosine=10'sd234;sine=10'sd104;end
            6'd18:begin cosine=10'sd231;sine=10'sd109;end
            6'd19:begin cosine=10'sd229;sine=10'sd115;end
            6'd20:begin cosine=10'sd226;sine=10'sd121;end
            6'd21:begin cosine=10'sd223;sine=10'sd126;end
            6'd22:begin cosine=10'sd220;sine=10'sd132;end
            6'd23:begin cosine=10'sd216;sine=10'sd137;end
            6'd24:begin cosine=10'sd213;sine=10'sd142;end
            6'd25:begin cosine=10'sd209;sine=10'sd147;end
            6'd26:begin cosine=10'sd206;sine=10'sd152;end
            6'd27:begin cosine=10'sd202;sine=10'sd157;end
            6'd28:begin cosine=10'sd198;sine=10'sd162;end
            6'd29:begin cosine=10'sd194;sine=10'sd167;end
            6'd30:begin cosine=10'sd190;sine=10'sd172;end
            6'd31:begin cosine=10'sd185;sine=10'sd177;end
            6'd32:begin cosine=10'sd181;sine=10'sd181;end
            6'd33:begin cosine=10'sd177;sine=10'sd185;end
            6'd34:begin cosine=10'sd172;sine=10'sd190;end
            6'd35:begin cosine=10'sd167;sine=10'sd194;end
            6'd36:begin cosine=10'sd162;sine=10'sd198;end
            6'd37:begin cosine=10'sd157;sine=10'sd202;end
            6'd38:begin cosine=10'sd152;sine=10'sd206;end
            6'd39:begin cosine=10'sd147;sine=10'sd209;end
            6'd40:begin cosine=10'sd142;sine=10'sd213;end
            6'd41:begin cosine=10'sd137;sine=10'sd216;end
            6'd42:begin cosine=10'sd132;sine=10'sd220;end
            6'd43:begin cosine=10'sd126;sine=10'sd223;end
            6'd44:begin cosine=10'sd121;sine=10'sd226;end
            6'd45:begin cosine=10'sd115;sine=10'sd229;end
            6'd46:begin cosine=10'sd109;sine=10'sd231;end
            6'd47:begin cosine=10'sd104;sine=10'sd234;end
            6'd48:begin cosine=10'sd98;sine=10'sd237;end
            6'd49:begin cosine=10'sd92;sine=10'sd239;end
            6'd50:begin cosine=10'sd86;sine=10'sd241;end
            6'd51:begin cosine=10'sd80;sine=10'sd243;end
            6'd52:begin cosine=10'sd74;sine=10'sd245;end
            6'd53:begin cosine=10'sd68;sine=10'sd247;end
            6'd54:begin cosine=10'sd62;sine=10'sd248;end
            6'd55:begin cosine=10'sd56;sine=10'sd250;end
            6'd56:begin cosine=10'sd50;sine=10'sd251;end
            6'd57:begin cosine=10'sd44;sine=10'sd252;end
            6'd58:begin cosine=10'sd38;sine=10'sd253;end
            6'd59:begin cosine=10'sd31;sine=10'sd254;end
            6'd60:begin cosine=10'sd25;sine=10'sd255;end
            6'd61:begin cosine=10'sd19;sine=10'sd255;end
            6'd62:begin cosine=10'sd13;sine=10'sd256;end
            default:begin cosine=10'sd6;sine=10'sd256;end
        endcase
    end
    wire signed [20:0] u=dx*cosine+dy*sine;
    wire signed [20:0] v=-dx*sine+dy*cosine;

    // Registered P_* datapath helper expressions.
    wire [21:0] p_dx2_w=p_dx_q*p_dx_q;
    wire [21:0] p_dy2_w=p_dy_q*p_dy_q;
    wire [10:0] p_absdx_w=p_dx_q[10]?-p_dx_q:p_dx_q;
    wire [10:0] p_absdy_w=p_dy_q[10]?-p_dy_q:p_dy_q;
    wire signed [20:0] p_u_w=p_dx_q*cosine+p_dy_q*sine;
    wire signed [20:0] p_v_w=-p_dx_q*sine+p_dy_q*cosine;
    // Differences are nonnegative after the extrema pass; Q8 units.
    wire [21:0] span_u=$signed(umax)-$signed(umin);
    wire [21:0] span_v=$signed(vmax)-$signed(vmin);
    wire [21:0] from_u=$signed(u)-$signed(umin);
    wire [21:0] from_v=$signed(v)-$signed(vmin);
    wire [21:0] to_u=$signed(umax)-$signed(u);
    wire [21:0] to_v=$signed(vmax)-$signed(v);
    // Register tolerance once per orientation, outside the per-point datapath.
    wire [21:0] long_span=(span_u>span_v)?span_u:span_v;
    wire [21:0] short_span=(span_u<span_v)?span_u:span_v;
    wire [21:0] side_candidate=SIDE_TOL*256+(long_span>>4);
    wire [21:0] corner_candidate=RECT_CORNER_TOL*256+(short_span>>3);
    reg [21:0] side_band,corner_band;
    wire side0=(from_u <= side_band);
    wire side1=(to_u <= side_band);
    wire side2=(from_v <= side_band);
    wire side3=(to_v <= side_band);
    // Eight equal bins without a variable divider. Last endpoint clamps to 7.
    function [2:0] segment_bin;
        input [21:0] position,span;
        integer k;
        begin
            segment_bin=0;
            for(k=1;k<8;k=k+1)
                if(({3'b0,position}<<3)>=span*k) segment_bin=k;
        end
    endfunction
    wire [2:0] p_bin_u_w=segment_bin(p_from_u_q,span_u);
    wire [2:0] p_bin_v_w=segment_bin(p_from_v_q,span_v);

    function [3:0] pop8;
        input [7:0] mask;
        integer k;
        begin
            pop8=0;
            for(k=0;k<8;k=k+1) pop8=pop8+{3'b0,mask[k]};
        end
    endfunction
    wire [2:0] bin_u=segment_bin(from_u,span_u);
    wire [2:0] bin_v=segment_bin(from_v,span_v);
    wire corner0=(from_u<=corner_band && from_v<=corner_band);
    wire corner1=(to_u<=corner_band && from_v<=corner_band);
    wire corner2=(from_u<=corner_band && to_v<=corner_band);
    wire corner3=(to_u<=corner_band && to_v<=corner_band);
    wire [11:0] out_minx=960+minx*4;
    wire [11:0] out_maxx=960+maxx*4+3;
    wire [11:0] out_miny=miny*4;
    wire [11:0] out_maxy=maxy*4+3;

    // Three/six equally spaced outward support normals. One projection
    // datapath reused serially, with a register before extrema/fit updates.
    reg poly_hex,poly_pass;
    reg [5:0] poly_angle;
    reg [2:0] poly_n;
    reg signed [20:0] poly_min[0:5],poly_max[0:5];
    reg [21:0] poly_gap[0:5];
    reg [15:0] poly_side[0:5],poly_corner[0:5];
    reg signed [20:0] poly_tmin[0:5],poly_tmax[0:5];
    reg signed [20:0] poly_stmin[0:5],poly_stmax[0:5];
    reg signed [20:0] poly_tangent_q;
    wire signed [20:0] poly_tangent=-dx*poly_sin+dy*poly_cos;
    reg [15:0] rect_strict_count;
    reg [21:0] rect_strict_band;
    wire [21:0] rect_strict_candidate=22'd512+(long_span>>6);
    wire rect_strict_near=(from_u<=rect_strict_band || to_u<=rect_strict_band ||
                           from_v<=rect_strict_band || to_v<=rect_strict_band);
    reg [21:0] poly_band;
    reg [15:0] poly_fit;
    reg signed [20:0] poly_proj_q;
    wire [7:0] poly_rom_addr = poly_angle +
        (poly_hex ? (poly_n*24) : (poly_n*48));
    reg signed [9:0] poly_cos,poly_sin;
    always @* begin
        case(poly_rom_addr)
            8'd0:begin poly_cos=10'sd256;poly_sin=10'sd0;end
            8'd1:begin poly_cos=10'sd256;poly_sin=10'sd11;end
            8'd2:begin poly_cos=10'sd255;poly_sin=10'sd22;end
            8'd3:begin poly_cos=10'sd254;poly_sin=10'sd33;end
            8'd4:begin poly_cos=10'sd252;poly_sin=10'sd44;end
            8'd5:begin poly_cos=10'sd250;poly_sin=10'sd55;end
            8'd6:begin poly_cos=10'sd247;poly_sin=10'sd66;end
            8'd7:begin poly_cos=10'sd244;poly_sin=10'sd77;end
            8'd8:begin poly_cos=10'sd241;poly_sin=10'sd88;end
            8'd9:begin poly_cos=10'sd237;poly_sin=10'sd98;end
            8'd10:begin poly_cos=10'sd232;poly_sin=10'sd108;end
            8'd11:begin poly_cos=10'sd227;poly_sin=10'sd118;end
            8'd12:begin poly_cos=10'sd222;poly_sin=10'sd128;end
            8'd13:begin poly_cos=10'sd216;poly_sin=10'sd138;end
            8'd14:begin poly_cos=10'sd210;poly_sin=10'sd147;end
            8'd15:begin poly_cos=10'sd203;poly_sin=10'sd156;end
            8'd16:begin poly_cos=10'sd196;poly_sin=10'sd165;end
            8'd17:begin poly_cos=10'sd189;poly_sin=10'sd173;end
            8'd18:begin poly_cos=10'sd181;poly_sin=10'sd181;end
            8'd19:begin poly_cos=10'sd173;poly_sin=10'sd189;end
            8'd20:begin poly_cos=10'sd165;poly_sin=10'sd196;end
            8'd21:begin poly_cos=10'sd156;poly_sin=10'sd203;end
            8'd22:begin poly_cos=10'sd147;poly_sin=10'sd210;end
            8'd23:begin poly_cos=10'sd138;poly_sin=10'sd216;end
            8'd24:begin poly_cos=10'sd128;poly_sin=10'sd222;end
            8'd25:begin poly_cos=10'sd118;poly_sin=10'sd227;end
            8'd26:begin poly_cos=10'sd108;poly_sin=10'sd232;end
            8'd27:begin poly_cos=10'sd98;poly_sin=10'sd237;end
            8'd28:begin poly_cos=10'sd88;poly_sin=10'sd241;end
            8'd29:begin poly_cos=10'sd77;poly_sin=10'sd244;end
            8'd30:begin poly_cos=10'sd66;poly_sin=10'sd247;end
            8'd31:begin poly_cos=10'sd55;poly_sin=10'sd250;end
            8'd32:begin poly_cos=10'sd44;poly_sin=10'sd252;end
            8'd33:begin poly_cos=10'sd33;poly_sin=10'sd254;end
            8'd34:begin poly_cos=10'sd22;poly_sin=10'sd255;end
            8'd35:begin poly_cos=10'sd11;poly_sin=10'sd256;end
            8'd36:begin poly_cos=10'sd0;poly_sin=10'sd256;end
            8'd37:begin poly_cos=-10'sd11;poly_sin=10'sd256;end
            8'd38:begin poly_cos=-10'sd22;poly_sin=10'sd255;end
            8'd39:begin poly_cos=-10'sd33;poly_sin=10'sd254;end
            8'd40:begin poly_cos=-10'sd44;poly_sin=10'sd252;end
            8'd41:begin poly_cos=-10'sd55;poly_sin=10'sd250;end
            8'd42:begin poly_cos=-10'sd66;poly_sin=10'sd247;end
            8'd43:begin poly_cos=-10'sd77;poly_sin=10'sd244;end
            8'd44:begin poly_cos=-10'sd88;poly_sin=10'sd241;end
            8'd45:begin poly_cos=-10'sd98;poly_sin=10'sd237;end
            8'd46:begin poly_cos=-10'sd108;poly_sin=10'sd232;end
            8'd47:begin poly_cos=-10'sd118;poly_sin=10'sd227;end
            8'd48:begin poly_cos=-10'sd128;poly_sin=10'sd222;end
            8'd49:begin poly_cos=-10'sd138;poly_sin=10'sd216;end
            8'd50:begin poly_cos=-10'sd147;poly_sin=10'sd210;end
            8'd51:begin poly_cos=-10'sd156;poly_sin=10'sd203;end
            8'd52:begin poly_cos=-10'sd165;poly_sin=10'sd196;end
            8'd53:begin poly_cos=-10'sd173;poly_sin=10'sd189;end
            8'd54:begin poly_cos=-10'sd181;poly_sin=10'sd181;end
            8'd55:begin poly_cos=-10'sd189;poly_sin=10'sd173;end
            8'd56:begin poly_cos=-10'sd196;poly_sin=10'sd165;end
            8'd57:begin poly_cos=-10'sd203;poly_sin=10'sd156;end
            8'd58:begin poly_cos=-10'sd210;poly_sin=10'sd147;end
            8'd59:begin poly_cos=-10'sd216;poly_sin=10'sd138;end
            8'd60:begin poly_cos=-10'sd222;poly_sin=10'sd128;end
            8'd61:begin poly_cos=-10'sd227;poly_sin=10'sd118;end
            8'd62:begin poly_cos=-10'sd232;poly_sin=10'sd108;end
            8'd63:begin poly_cos=-10'sd237;poly_sin=10'sd98;end
            8'd64:begin poly_cos=-10'sd241;poly_sin=10'sd88;end
            8'd65:begin poly_cos=-10'sd244;poly_sin=10'sd77;end
            8'd66:begin poly_cos=-10'sd247;poly_sin=10'sd66;end
            8'd67:begin poly_cos=-10'sd250;poly_sin=10'sd55;end
            8'd68:begin poly_cos=-10'sd252;poly_sin=10'sd44;end
            8'd69:begin poly_cos=-10'sd254;poly_sin=10'sd33;end
            8'd70:begin poly_cos=-10'sd255;poly_sin=10'sd22;end
            8'd71:begin poly_cos=-10'sd256;poly_sin=10'sd11;end
            8'd72:begin poly_cos=-10'sd256;poly_sin=10'sd0;end
            8'd73:begin poly_cos=-10'sd256;poly_sin=-10'sd11;end
            8'd74:begin poly_cos=-10'sd255;poly_sin=-10'sd22;end
            8'd75:begin poly_cos=-10'sd254;poly_sin=-10'sd33;end
            8'd76:begin poly_cos=-10'sd252;poly_sin=-10'sd44;end
            8'd77:begin poly_cos=-10'sd250;poly_sin=-10'sd55;end
            8'd78:begin poly_cos=-10'sd247;poly_sin=-10'sd66;end
            8'd79:begin poly_cos=-10'sd244;poly_sin=-10'sd77;end
            8'd80:begin poly_cos=-10'sd241;poly_sin=-10'sd88;end
            8'd81:begin poly_cos=-10'sd237;poly_sin=-10'sd98;end
            8'd82:begin poly_cos=-10'sd232;poly_sin=-10'sd108;end
            8'd83:begin poly_cos=-10'sd227;poly_sin=-10'sd118;end
            8'd84:begin poly_cos=-10'sd222;poly_sin=-10'sd128;end
            8'd85:begin poly_cos=-10'sd216;poly_sin=-10'sd138;end
            8'd86:begin poly_cos=-10'sd210;poly_sin=-10'sd147;end
            8'd87:begin poly_cos=-10'sd203;poly_sin=-10'sd156;end
            8'd88:begin poly_cos=-10'sd196;poly_sin=-10'sd165;end
            8'd89:begin poly_cos=-10'sd189;poly_sin=-10'sd173;end
            8'd90:begin poly_cos=-10'sd181;poly_sin=-10'sd181;end
            8'd91:begin poly_cos=-10'sd173;poly_sin=-10'sd189;end
            8'd92:begin poly_cos=-10'sd165;poly_sin=-10'sd196;end
            8'd93:begin poly_cos=-10'sd156;poly_sin=-10'sd203;end
            8'd94:begin poly_cos=-10'sd147;poly_sin=-10'sd210;end
            8'd95:begin poly_cos=-10'sd138;poly_sin=-10'sd216;end
            8'd96:begin poly_cos=-10'sd128;poly_sin=-10'sd222;end
            8'd97:begin poly_cos=-10'sd118;poly_sin=-10'sd227;end
            8'd98:begin poly_cos=-10'sd108;poly_sin=-10'sd232;end
            8'd99:begin poly_cos=-10'sd98;poly_sin=-10'sd237;end
            8'd100:begin poly_cos=-10'sd88;poly_sin=-10'sd241;end
            8'd101:begin poly_cos=-10'sd77;poly_sin=-10'sd244;end
            8'd102:begin poly_cos=-10'sd66;poly_sin=-10'sd247;end
            8'd103:begin poly_cos=-10'sd55;poly_sin=-10'sd250;end
            8'd104:begin poly_cos=-10'sd44;poly_sin=-10'sd252;end
            8'd105:begin poly_cos=-10'sd33;poly_sin=-10'sd254;end
            8'd106:begin poly_cos=-10'sd22;poly_sin=-10'sd255;end
            8'd107:begin poly_cos=-10'sd11;poly_sin=-10'sd256;end
            8'd108:begin poly_cos=10'sd0;poly_sin=-10'sd256;end
            8'd109:begin poly_cos=10'sd11;poly_sin=-10'sd256;end
            8'd110:begin poly_cos=10'sd22;poly_sin=-10'sd255;end
            8'd111:begin poly_cos=10'sd33;poly_sin=-10'sd254;end
            8'd112:begin poly_cos=10'sd44;poly_sin=-10'sd252;end
            8'd113:begin poly_cos=10'sd55;poly_sin=-10'sd250;end
            8'd114:begin poly_cos=10'sd66;poly_sin=-10'sd247;end
            8'd115:begin poly_cos=10'sd77;poly_sin=-10'sd244;end
            8'd116:begin poly_cos=10'sd88;poly_sin=-10'sd241;end
            8'd117:begin poly_cos=10'sd98;poly_sin=-10'sd237;end
            8'd118:begin poly_cos=10'sd108;poly_sin=-10'sd232;end
            8'd119:begin poly_cos=10'sd118;poly_sin=-10'sd227;end
            8'd120:begin poly_cos=10'sd128;poly_sin=-10'sd222;end
            8'd121:begin poly_cos=10'sd138;poly_sin=-10'sd216;end
            8'd122:begin poly_cos=10'sd147;poly_sin=-10'sd210;end
            8'd123:begin poly_cos=10'sd156;poly_sin=-10'sd203;end
            8'd124:begin poly_cos=10'sd165;poly_sin=-10'sd196;end
            8'd125:begin poly_cos=10'sd173;poly_sin=-10'sd189;end
            8'd126:begin poly_cos=10'sd181;poly_sin=-10'sd181;end
            8'd127:begin poly_cos=10'sd189;poly_sin=-10'sd173;end
            8'd128:begin poly_cos=10'sd196;poly_sin=-10'sd165;end
            8'd129:begin poly_cos=10'sd203;poly_sin=-10'sd156;end
            8'd130:begin poly_cos=10'sd210;poly_sin=-10'sd147;end
            8'd131:begin poly_cos=10'sd216;poly_sin=-10'sd138;end
            8'd132:begin poly_cos=10'sd222;poly_sin=-10'sd128;end
            8'd133:begin poly_cos=10'sd227;poly_sin=-10'sd118;end
            8'd134:begin poly_cos=10'sd232;poly_sin=-10'sd108;end
            8'd135:begin poly_cos=10'sd237;poly_sin=-10'sd98;end
            8'd136:begin poly_cos=10'sd241;poly_sin=-10'sd88;end
            8'd137:begin poly_cos=10'sd244;poly_sin=-10'sd77;end
            8'd138:begin poly_cos=10'sd247;poly_sin=-10'sd66;end
            8'd139:begin poly_cos=10'sd250;poly_sin=-10'sd55;end
            8'd140:begin poly_cos=10'sd252;poly_sin=-10'sd44;end
            8'd141:begin poly_cos=10'sd254;poly_sin=-10'sd33;end
            8'd142:begin poly_cos=10'sd255;poly_sin=-10'sd22;end
            8'd143:begin poly_cos=10'sd256;poly_sin=-10'sd11;end
            default:begin poly_cos=10'sd256;poly_sin=0;end
        endcase
    end
    wire signed [20:0] poly_projection = dx*poly_cos + dy*poly_sin;
    function [21:0] poly_extent;
        input signed [20:0] hi,lo;
        begin poly_extent=$signed(hi)-$signed(lo);end
    endfunction
    // Timing optimization: do not reduce six 21-bit extrema arrays through one
    // large combinational tree.  The old poly_span_min/max/sides/corners block
    // was on the clk_pixel_2x critical path.  Only the per-point "near any side"
    // OR remains combinational; span/support metrics are accumulated serially in
    // POL_METRIC, one normal per clock.
    integer pk;
    reg poly_near;
    always @* begin
        poly_near=1'b0;
        for(pk=0;pk<6;pk=pk+1)begin
            if((poly_hex || pk<3) && (poly_gap[pk]<=poly_band))
                poly_near=1'b1;
        end
    end

    reg [2:0]  poly_metric_n;
    reg        poly_metric_decide;
    reg [21:0] poly_span_min_q,poly_span_max_q;
    reg        poly_sides_ok_q,poly_corners_ok_q;

    // Polygon metric timing pipeline.
    // Stage 0 latches the currently indexed array entries so poly_metric_n no
    // longer feeds subtraction/multipliers/comparators in one combinational cone.
    reg signed [20:0] poly_m_max_q,poly_m_min_q;
    reg signed [20:0] poly_m_stmax_q,poly_m_stmin_q;
    reg signed [20:0] poly_m_tmax_q,poly_m_tmin_q;
    reg [15:0] poly_m_side_q,poly_m_corner_q;
    reg        poly_m_last_q;
    // Stage 1 span results.
    reg [21:0] poly_m_span_q,poly_m_support_span_q,poly_m_full_span_q;
    // Stage 2 scaled support products.
    reg [31:0] poly_m_support_lhs_q,poly_m_support_rhs_q;
    integer pj;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;vs_d<=0;de_d<=0;frame_seen<=0;
            poly_hex<=0;poly_pass<=0;poly_angle<=0;poly_n<=0;
            poly_band<=0;poly_fit<=0;poly_proj_q<=0;poly_tangent_q<=0;
            poly_metric_n<=0;poly_metric_decide<=0;
            poly_span_min_q<=22'h3fffff;poly_span_max_q<=0;
            poly_sides_ok_q<=1'b1;poly_corners_ok_q<=1'b1;
            poly_m_max_q<=0;poly_m_min_q<=0;poly_m_stmax_q<=0;poly_m_stmin_q<=0;
            poly_m_tmax_q<=0;poly_m_tmin_q<=0;poly_m_side_q<=0;poly_m_corner_q<=0;
            poly_m_last_q<=0;poly_m_span_q<=0;poly_m_support_span_q<=0;poly_m_full_span_q<=0;
            poly_m_support_lhs_q<=0;poly_m_support_rhs_q<=0;
            rect_strict_count<=0;rect_strict_band<=0;
            for(pj=0;pj<6;pj=pj+1)begin
                poly_min[pj]<=0;poly_max[pj]<=0;poly_gap[pj]<=0;
                poly_side[pj]<=0;poly_corner[pj]<=0;
                poly_tmin[pj]<=21'sd1048575;poly_tmax[pj]<=-21'sd1048576;
                poly_stmin[pj]<=21'sd1048575;poly_stmax[pj]<=-21'sd1048576;
            end
            x<=0;y<=0;block_or<=0;write_bank<=0;read_bank<=1;
            maddr<=0;clear_addr<=0;clear_we<=0;qwe<=0;pwe<=0;
            qhead<=0;qtail<=0;qcount<=0;qwaddr<=0;qdata<=0;
            praddr<=0;pwaddr<=0;pdata<=0;
            scan_addr<=0;scan_x<=0;scan_y<=0;
            px<=0;py<=0;neighbor<=0;nx<=0;ny<=0;naddr<=0;
            count<=0;minx<=0;maxx<=0;miny<=0;maxy<=0;
            cx<=0;cy<=0;touch<=0;component_large<=0;work_error<=0;
            pindex<=0;inliers<=0;octants<=0;radius2<=0;kind<=0;
            angle<=0;support_pass<=0;fit_count<=0;side_band<=0;corner_band<=0;
            umin<=0;umax<=0;vmin<=0;vmax<=0;
            sides0<=0;sides1<=0;sides2<=0;sides3<=0;
            cover0<=0;cover1<=0;cover2<=0;cover3<=0;
            corners0<=0;corners1<=0;corners2<=0;corners3<=0;
            p_dx_q<=0;p_dy_q<=0;p_u_q<=0;p_v_q<=0;p_distance2_q<=0;p_sector_q<=0;
            p_from_u_q<=0;p_to_u_q<=0;p_from_v_q<=0;p_to_v_q<=0;
            p_side0_q<=0;p_side1_q<=0;p_side2_q<=0;p_side3_q<=0;
            p_corner0_q<=0;p_corner1_q<=0;p_corner2_q<=0;p_corner3_q<=0;
            p_rect_strict_near_q<=0;p_circle_inlier_q<=0;p_bin_u_q<=0;p_bin_v_q<=0;
            r_fit_lhs_q<=0;r_fit_rhs_q<=0;r_octants_ok_q<=0;r_aspect_ok_q<=0;
            a_fit_lhs_q<=0;a_fit_rhs_q<=0;a_strict_lhs_q<=0;a_strict_rhs_q<=0;a_shape_ok_q<=0;
            poly_fit_lhs_q<=0;poly_fit_rhs_q<=0;poly_shape_ok_q<=0;
            work_valid<=0;work_class<=0;work_xmin<=0;work_xmax<=0;
            work_ymin<=0;work_ymax<=0;slot<=0;work_components<=0;
            object_valid<=0;object_class<=0;object_xmin<=0;object_xmax<=0;
            object_ymin<=0;object_ymax<=0;result_toggle<=0;
            frame_error<=0;skipped_frames<=0;component_count_debug<=0;
        end else begin
            vs_d<=in_vsync;de_d<=in_de;clear_we<=0;qwe<=0;pwe<=0;
            if(in_vsync && !vs_d) begin
                x<=0;y<=0;block_or<=0;frame_seen<=1;
                if(frame_seen) begin
                    if(state==IDLE) begin
                        read_bank<=write_bank;write_bank<=~write_bank;
                        scan_addr<=0;scan_x<=0;scan_y<=0;
                        work_valid<=0;work_class<=0;slot<=0;
                        work_components<=0;work_error<=0;
                        state<=SCAN_ADDR;
                    end else skipped_frames<=skipped_frames+1'b1;
                end
            end else if(in_de) begin
                x<=x+1'b1;
                if(x>=960 && x<1920 && y<1080) begin
                    block_or[cap_col]<=block_or[cap_col]|(in_edge!=0);
                    if(x[1:0]==3 && y[1:0]==3) block_or[cap_col]<=0;
                end
            end else if(de_d) begin x<=0;y<=y+1'b1;end

            case(state)
                IDLE:begin end
                SCAN_ADDR:begin maddr<=scan_addr;state<=SCAN_WAIT;end
                SCAN_WAIT:state<=SCAN_TEST;
                SCAN_TEST:begin
                    if(mbit) begin
                        clear_addr<=scan_addr;clear_we<=1;
                        qhead<=0;qtail<=1;qcount<=1;qwaddr<=0;
                        qdata<={scan_y,scan_x};qwe<=1;
                        count<=0;minx<=239;maxx<=0;miny<=269;maxy<=0;
                        touch<=0;component_large<=0;kind<=0;
                        work_components<=work_components+1'b1;
                        state<=Q_ADDR;
                    end else state<=NEXT_SCAN;
                end
                NEXT_SCAN:begin
                    if(scan_addr==DEPTH-1) state<=PUBLISH;
                    else begin
                        scan_addr<=scan_addr+1'b1;
                        if(scan_x==239)begin scan_x<=0;scan_y<=scan_y+1'b1;end
                        else scan_x<=scan_x+1'b1;
                        state<=SCAN_ADDR;
                    end
                end
                Q_ADDR:state<=Q_WAIT;
                Q_WAIT:state<=Q_POP;
                Q_POP:begin
                    if(qcount==0) state<=COMP_END;
                    else begin
                        px<=queue_q[7:0];py<=queue_q[16:8];
                        qhead<=qhead+1'b1;qcount<=qcount-1'b1;neighbor<=0;
                        if(count<PDEPTH) begin
                            pwaddr<=count[POINT_AW-1:0];pdata<=queue_q;pwe<=1;
                        end else component_large<=1;
                        count<=count+1'b1;
                        if(queue_q[7:0]<minx)minx<=queue_q[7:0];
                        if(queue_q[7:0]>maxx)maxx<=queue_q[7:0];
                        if(queue_q[16:8]<miny)miny<=queue_q[16:8];
                        if(queue_q[16:8]>maxy)maxy<=queue_q[16:8];
                        if(queue_q[7:0]==0 || queue_q[7:0]==239 ||
                           queue_q[16:8]==0 || queue_q[16:8]==269)touch<=1;
                        state<=N_ADDR;
                    end
                end
                N_ADDR:begin
                    if(neighbor_ok)begin
                        nx<=tx[7:0];ny<=ty[8:0];naddr<=ty*240+tx;
                        maddr<=ty*240+tx;state<=N_WAIT;
                    end else state<=N_NEXT;
                end
                N_WAIT:state<=N_TEST;
                N_TEST:begin
                    if(mbit) begin
                        if(qcount==QDEPTH)begin work_error<=1;state<=PUBLISH;end
                        else begin
                            clear_addr<=naddr;clear_we<=1;
                            qwaddr<=qtail;qdata<={ny,nx};qwe<=1;
                            qtail<=qtail+1'b1;qcount<=qcount+1'b1;
                            state<=N_NEXT;
                        end
                    end else state<=N_NEXT;
                end
                N_NEXT:begin
                    if(neighbor==7)state<=Q_ADDR;
                    else begin neighbor<=neighbor+1'b1;state<=N_ADDR;end
                end
                COMP_END:begin
                    if(count<MIN_EDGE || bw<MIN_SIZE || bh<MIN_SIZE || touch)
                        state<=NEXT_SCAN;
                    else if(component_large || count>PDEPTH)begin kind<=0;state<=SAVE;end
                    else begin
                        cx<=({1'b0,minx}+{1'b0,maxx})>>1;
                        cy<=({1'b0,miny}+{1'b0,maxy})>>1;
                        poly_hex<=0;poly_angle<=0;state<=POL_PREP;
                    end
                end
                R_PREP:begin
                    cx<=({1'b0,minx}+{1'b0,maxx})>>1;
                    cy<=({1'b0,miny}+{1'b0,maxy})>>1;
                    radius2<=box_square>>3;pindex<=0;octants<=0;inliers<=0;
                    state<=P_ADDR;support_pass<=0;angle<=0;
                end
                P_ADDR:begin
                    praddr<=pindex[POINT_AW-1:0];
                    state<=P_WAIT;
                end
                P_WAIT:state<=P_COORD;

                // Stage 1: centered point coordinates.
                P_COORD:begin
                    p_dx_q<=$signed({1'b0,point_q[7:0]})-$signed({1'b0,cx});
                    p_dy_q<=$signed({1'b0,point_q[16:8]})-$signed({1'b0,cy});
                    state<=P_PROJECT;
                end

                // Stage 2: projection and circle radius metric.
                P_PROJECT:begin
                    p_u_q<=p_u_w;
                    p_v_q<=p_v_w;
                    p_distance2_q<=p_dx2_w+p_dy2_w;
                    p_sector_q<={p_dy_q[10],p_dx_q[10],(p_absdx_w>p_absdy_w)};
                    state<=P_DELTA;
                end

                // Stage 3: distance from the point to each fitted support line.
                P_DELTA:begin
                    p_from_u_q<=$signed(p_u_q)-$signed(umin);
                    p_to_u_q  <=$signed(umax)-$signed(p_u_q);
                    p_from_v_q<=$signed(p_v_q)-$signed(vmin);
                    p_to_v_q  <=$signed(vmax)-$signed(p_v_q);
                    state<=P_FLAGS;
                end

                // Stage 4: register side/corner/bin decisions.
                P_FLAGS:begin
                    p_side0_q <= (p_from_u_q<=side_band);
                    p_side1_q <= (p_to_u_q<=side_band);
                    p_side2_q <= (p_from_v_q<=side_band);
                    p_side3_q <= (p_to_v_q<=side_band);
                    p_corner0_q <= (p_from_u_q<=corner_band && p_from_v_q<=corner_band);
                    p_corner1_q <= (p_to_u_q<=corner_band && p_from_v_q<=corner_band);
                    p_corner2_q <= (p_from_u_q<=corner_band && p_to_v_q<=corner_band);
                    p_corner3_q <= (p_to_u_q<=corner_band && p_to_v_q<=corner_band);
                    p_rect_strict_near_q <=
                        (p_from_u_q<=rect_strict_band) || (p_to_u_q<=rect_strict_band) ||
                        (p_from_v_q<=rect_strict_band) || (p_to_v_q<=rect_strict_band);
                    // Same circle shell as before: 3/4*radius2 <= d2 <= 5/4*radius2.
                    // Register it here so P_TEST only updates counters.
                    p_circle_inlier_q <=
                        (p_distance2_q*4>=radius2*3) &&
                        (p_distance2_q*4<=radius2*5);
                    p_bin_u_q<=p_bin_u_w;
                    p_bin_v_q<=p_bin_v_w;
                    state<=P_TEST;
                end

                P_TEST:begin
                    if(!support_pass && angle==0 && kind==0)begin
                        octants[p_sector_q]<=1;
                        if(p_circle_inlier_q)inliers<=inliers+1'b1;
                    end else if(!support_pass)begin
                        if(p_u_q<umin)umin<=p_u_q;if(p_u_q>umax)umax<=p_u_q;
                        if(p_v_q<vmin)vmin<=p_v_q;if(p_v_q>vmax)vmax<=p_v_q;
                    end else begin
                        if(p_side0_q || p_side1_q || p_side2_q || p_side3_q)
                            fit_count<=fit_count+1'b1;
                        if(p_rect_strict_near_q)rect_strict_count<=rect_strict_count+1'b1;
                        if(p_side0_q)begin sides0<=sides0+1'b1;cover0[p_bin_v_q]<=1'b1;end
                        if(p_side1_q)begin sides1<=sides1+1'b1;cover1[p_bin_v_q]<=1'b1;end
                        if(p_side2_q)begin sides2<=sides2+1'b1;cover2[p_bin_u_q]<=1'b1;end
                        if(p_side3_q)begin sides3<=sides3+1'b1;cover3[p_bin_u_q]<=1'b1;end
                        if(p_corner0_q)corners0<=corners0+1'b1;
                        if(p_corner1_q)corners1<=corners1+1'b1;
                        if(p_corner2_q)corners2<=corners2+1'b1;
                        if(p_corner3_q)corners3<=corners3+1'b1;
                    end
                    if(pindex==count-1)begin
                        if(kind==0)state<=R_METRIC;
                        else if(!support_pass)state<=A_SUPPORT;
                        else state<=A_METRIC;
                    end else begin
                        pindex<=pindex+1'b1;state<=P_ADDR;
                    end
                end
                R_METRIC:begin
                    r_octants_ok_q<=(octants==8'hff);
                    r_aspect_ok_q<=(bw*4<=bh*5 && bh*4<=bw*5);
                    r_fit_lhs_q<=inliers*32'd100;
                    r_fit_rhs_q<=count*CIRCLE_FIT_PERCENT;
                    state<=R_DECIDE;
                end
                R_DECIDE:begin
                    if(r_octants_ok_q && r_aspect_ok_q && r_fit_lhs_q>=r_fit_rhs_q)begin
                        kind<=1;state<=SAVE;
                    end else begin kind<=3;angle<=0;state<=A_PREP;end
                end
                A_PREP:begin
                    umin<=21'sd1048575;umax<=-21'sd1048576;
                    vmin<=21'sd1048575;vmax<=-21'sd1048576;
                    support_pass<=0;pindex<=0;state<=P_ADDR;
                end
                A_SUPPORT:begin
                    if(RECT_ADAPTIVE_TOL)begin
                        side_band<=(side_candidate>RECT_SIDE_TOL_MAX*256)?
                            RECT_SIDE_TOL_MAX*256:side_candidate;
                        corner_band<=(corner_candidate>RECT_CORNER_TOL_MAX*256)?
                            RECT_CORNER_TOL_MAX*256:corner_candidate;
                    end else begin
                        side_band<=SIDE_TOL*256;corner_band<=RECT_CORNER_TOL*256;
                    end
                    rect_strict_band<=(rect_strict_candidate>22'd1024)?22'd1024:rect_strict_candidate;
                    rect_strict_count<=0;
                    support_pass<=1;fit_count<=0;sides0<=0;sides1<=0;
                    sides2<=0;sides3<=0;
                    cover0<=0;cover1<=0;cover2<=0;cover3<=0;
                    corners0<=0;corners1<=0;corners2<=0;corners3<=0;
                    pindex<=0;state<=P_ADDR;
                end
                A_METRIC:begin
                    a_fit_lhs_q<=fit_count*32'd100;
                    a_fit_rhs_q<=count*RECT_FIT_PERCENT;
                    a_strict_lhs_q<=rect_strict_count*32'd100;
                    a_strict_rhs_q<=count*RECT_STRICT_PERCENT;
                    a_shape_ok_q<=
                       sides0>=6 && sides1>=6 && sides2>=6 && sides3>=6 &&
                       span_u>=RECT_MIN_SIDE*256 && span_v>=RECT_MIN_SIDE*256 &&
                       span_u<=span_v*RECT_MAX_ASPECT &&
                       span_v<=span_u*RECT_MAX_ASPECT &&
                       pop8(cover0)>=RECT_MIN_BINS && pop8(cover1)>=RECT_MIN_BINS &&
                       pop8(cover2)>=RECT_MIN_BINS && pop8(cover3)>=RECT_MIN_BINS &&
                       corners0>=RECT_CORNER_POINTS && corners1>=RECT_CORNER_POINTS &&
                       corners2>=RECT_CORNER_POINTS && corners3>=RECT_CORNER_POINTS;
                    state<=A_DECIDE;
                end
                A_DECIDE:begin
                    if(a_fit_lhs_q>=a_fit_rhs_q &&
                       a_strict_lhs_q>=a_strict_rhs_q && a_shape_ok_q)begin
                        kind<=2;state<=SAVE;
                    end else if(angle==63)begin kind<=0;state<=SAVE;end
                    else begin angle<=angle+1'b1;state<=A_PREP;end
                end
                POL_PREP:begin
                    for(pj=0;pj<6;pj=pj+1)begin
                        poly_min[pj]<=21'sd1048575;
                        poly_max[pj]<=-21'sd1048576;
                        poly_side[pj]<=0;poly_corner[pj]<=0;
                poly_tmin[pj]<=21'sd1048575;poly_tmax[pj]<=-21'sd1048576;
                poly_stmin[pj]<=21'sd1048575;poly_stmax[pj]<=-21'sd1048576;
                    end
                    poly_pass<=0;poly_n<=0;pindex<=0;poly_fit<=0;
                    state<=POL_ADDR;
                end
                POL_ADDR:begin praddr<=pindex[POINT_AW-1:0];state<=POL_WAIT;end
                POL_WAIT:state<=POL_PROJ;
                POL_PROJ:begin poly_proj_q<=poly_projection;poly_tangent_q<=poly_tangent;state<=POL_USE;end
                POL_USE:begin
                    if(!poly_pass)begin
                        if(poly_proj_q<poly_min[poly_n])poly_min[poly_n]<=poly_proj_q;
                        if(poly_proj_q>poly_max[poly_n])poly_max[poly_n]<=poly_proj_q;
                        if(poly_tangent_q<poly_tmin[poly_n])poly_tmin[poly_n]<=poly_tangent_q;
                        if(poly_tangent_q>poly_tmax[poly_n])poly_tmax[poly_n]<=poly_tangent_q;
                    end else begin
                        poly_gap[poly_n]<={poly_max[poly_n][20],poly_max[poly_n]}-{poly_proj_q[20],poly_proj_q};
                        if(({poly_max[poly_n][20],poly_max[poly_n]}-
                            {poly_proj_q[20],poly_proj_q})<=poly_band)begin
                            if(poly_tangent_q<poly_stmin[poly_n])poly_stmin[poly_n]<=poly_tangent_q;
                            if(poly_tangent_q>poly_stmax[poly_n])poly_stmax[poly_n]<=poly_tangent_q;
                        end
                    end
                    if(poly_n==(poly_hex?5:2))begin poly_n<=0;state<=POL_NEXT;end
                    else begin poly_n<=poly_n+1'b1;state<=POL_PROJ;end
                end
                POL_NEXT:begin
                    if(poly_pass)begin
                        if(poly_near)poly_fit<=poly_fit+1'b1;
                        for(pj=0;pj<6;pj=pj+1)begin
                            if(poly_hex || pj<3)begin
                                if(poly_gap[pj]<=poly_band)poly_side[pj]<=poly_side[pj]+1'b1;
                                if(poly_gap[pj]<=poly_band &&
                                   poly_gap[(pj==(poly_hex?5:2))?0:pj+1]<=poly_band)
                                    poly_corner[pj]<=poly_corner[pj]+1'b1;
                            end
                        end
                    end
                    if(pindex==count-1)begin
                        // Break the old wide reduction path.  Collect span/support
                        // metrics over 3 (triangle) or 6 (hexagon) clocks.
                        poly_metric_n<=0;
                        poly_metric_decide<=poly_pass;
                        poly_span_min_q<=22'h3fffff;
                        poly_span_max_q<=0;
                        poly_sides_ok_q<=1'b1;
                        poly_corners_ok_q<=1'b1;
                        state<=POL_METRIC;
                    end else begin
                        pindex<=pindex+1'b1;state<=POL_ADDR;
                    end
                end

                POL_METRIC:begin
                    // Stage 0: dynamic array selection only.  All six values for
                    // this normal are captured before any subtraction/product.
                    poly_m_max_q<=poly_max[poly_metric_n];
                    poly_m_min_q<=poly_min[poly_metric_n];
                    poly_m_stmax_q<=poly_stmax[poly_metric_n];
                    poly_m_stmin_q<=poly_stmin[poly_metric_n];
                    poly_m_tmax_q<=poly_tmax[poly_metric_n];
                    poly_m_tmin_q<=poly_tmin[poly_metric_n];
                    poly_m_side_q<=poly_side[poly_metric_n];
                    poly_m_corner_q<=poly_corner[poly_metric_n];
                    poly_m_last_q<=(poly_metric_n==(poly_hex?5:2));
                    state<=POL_METRIC_SPAN;
                end

                POL_METRIC_SPAN:begin
                    // Stage 1: span arithmetic only.
                    poly_m_span_q <=
                        {poly_m_max_q[20],poly_m_max_q} -
                        {poly_m_min_q[20],poly_m_min_q};
                    poly_m_support_span_q <=
                        poly_extent(poly_m_stmax_q,poly_m_stmin_q);
                    poly_m_full_span_q <=
                        poly_extent(poly_m_tmax_q,poly_m_tmin_q);
                    state<=POL_METRIC_SCALE;
                end

                POL_METRIC_SCALE:begin
                    // Stage 2: scaled support products only.
                    // Original requirement is unchanged:
                    // support_span*100 >= full_span*(hex ? 32 : 65).
                    poly_m_support_lhs_q <= poly_m_support_span_q*32'd100;
                    poly_m_support_rhs_q <=
                        poly_m_full_span_q*
                        (poly_hex ? 32'd32 : TRI_SUPPORT_PERCENT);
                    state<=POL_METRIC_ACCUM;
                end

                POL_METRIC_ACCUM:begin
                    // Stage 3: registered comparisons and accumulator updates.
                    if(poly_m_span_q<poly_span_min_q)
                        poly_span_min_q<=poly_m_span_q;
                    if(poly_m_span_q>poly_span_max_q)
                        poly_span_max_q<=poly_m_span_q;
                    if(poly_metric_decide)begin
                        if(!(poly_m_side_q >=
                             (poly_hex ? 16'd6 : TRI_MIN_SIDE_POINTS) &&
                             poly_m_support_lhs_q>=poly_m_support_rhs_q))
                            poly_sides_ok_q<=1'b0;
                        if(poly_m_corner_q<16'd1)
                            poly_corners_ok_q<=1'b0;
                    end

                    if(poly_m_last_q)begin
                        if(poly_metric_decide)
                            state<=POL_FINAL_METRIC;
                        else
                            state<=POL_SUPPORT;
                    end else begin
                        poly_metric_n<=poly_metric_n+1'b1;
                        state<=POL_METRIC;
                    end
                end

                POL_SUPPORT:begin
                    // POL_METRIC has already registered all active normals,
                    // including the last one, before entering this state.
                    if((POLY_TOL_Q8 + (poly_span_max_q>>6)) > POLY_MAX_TOL_Q8)
                        poly_band<=POLY_MAX_TOL_Q8;
                    else
                        poly_band<=POLY_TOL_Q8 + (poly_span_max_q>>6);
                    poly_pass<=1;pindex<=0;poly_n<=0;state<=POL_ADDR;
                end

                POL_FINAL_METRIC:begin
                    poly_fit_lhs_q<=poly_fit*32'd100;
                    poly_fit_rhs_q<=count*
                        (poly_hex ? POLY_FIT_PERCENT : TRI_FIT_PERCENT);
                    // Hexagon remains regular: keep the original max/min span <= 1.3.
                    // Triangle becomes generic: require size + three supported sides
                    // + three corners, but do not require equal directional spans.
                    poly_shape_ok_q<=
                       poly_span_min_q>=(poly_hex?HEX_MIN_SPAN:POLY_MIN_SPAN)*256 &&
                       (poly_hex ? (poly_span_max_q*10<=poly_span_min_q*13) : 1'b1) &&
                       poly_sides_ok_q && poly_corners_ok_q;
                    state<=POL_DECIDE;
                end
                POL_DECIDE:begin
                    // All wide reductions/products are registered before this
                    // state, leaving only small comparisons and FSM control.
                    if(poly_shape_ok_q && poly_fit_lhs_q>=poly_fit_rhs_q)begin
                        kind<=poly_hex?3'd4:3'd3;state<=SAVE;
                    end else if(poly_angle==(poly_hex?23:47))begin
                        if(!poly_hex)begin poly_hex<=1;poly_angle<=0;state<=POL_PREP;end
                        else state<=R_PREP;
                    end else begin poly_angle<=poly_angle+1'b1;state<=POL_PREP;end
                end
                SAVE:begin
                    if(slot<MAX_OBJECTS)begin
                        work_valid[slot]<=1;work_class[slot*3 +:3]<=kind;
                        work_xmin[slot*12 +:12]<=out_minx;
                        work_xmax[slot*12 +:12]<=out_maxx;
                        work_ymin[slot*12 +:12]<=out_miny;
                        work_ymax[slot*12 +:12]<=out_maxy;
                        slot<=slot+1;
                    end
                    state<=NEXT_SCAN;
                end
                PUBLISH:begin
                    object_valid<=work_error?0:work_valid;
                    object_class<=work_class;object_xmin<=work_xmin;
                    object_xmax<=work_xmax;object_ymin<=work_ymin;
                    object_ymax<=work_ymax;frame_error<=work_error;
                    component_count_debug<=work_components;
                    result_toggle<=~result_toggle;state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
