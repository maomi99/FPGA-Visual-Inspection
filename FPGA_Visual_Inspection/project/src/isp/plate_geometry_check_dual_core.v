// DUAL_R1: uploaded timing-pipelined checker, shared across two targets.
// LP40111 analytic geometry checker. No learned image / no angle ROM.
// Hole coordinates are twice 480x540 map coordinates (original pixel units).
// Ordered end-hole pairs define 80mm baseline; perpendicular defines stem.
module plate_geometry_check_dual_core #(
 parameter integer MAX_HOLES=16, POSITION_TOL_MM=3,
 parameter integer MIN_BASE_PIXELS=120, MAX_BASE_PIXELS=560,
 parameter integer MIN_MISS_RUN=4, MAX_MISSING_PERCENT=8,
 parameter integer AFFINE_LIMIT_PERCENT=10,
 parameter integer DEBUG_EDGE_CAUSE=2, // 0 original; 1 edge causes; 2 adds no-target reasons
 parameter integer SLOPE_CLEAR_RESULTS=6, // completed analyses, not video frames
 parameter integer SLOPE_CURVE_Q1=5, // second-difference units: half a map pixel = one original pixel
 parameter integer SLOPE_CURVE_HITS=4,
 // Independent limits for the three upper segments. Other sides keep
 // MIN_MISS_RUN / MAX_MISSING_PERCENT supplied by the existing top level.
 parameter integer TOP_MISS_RUN=4, TOP_MISSING_PERCENT=8,
 parameter integer SLOPE_MISS_RUN=4, SLOPE_MISSING_PERCENT=8
)(
 input wire clk,rst_n,start,input wire source_error,
 input wire [15:0] exclude_mask,
 input wire [1:0] reserved_slots, clear_history,
 output reg result_slot, output reg [15:0] consumed_mask,
 input wire[4:0]hole_count,input wire[MAX_HOLES*11-1:0]hole_x,hole_y,
 input wire[MAX_HOLES*8-1:0]hole_diameter,
 output reg done,output reg[17:0]map_addr,input wire map_bit,
 output reg detected,passed,result_toggle,output reg[3:0]fault_code,
 output reg[4:0]result_hole_count,
 output reg[11:0]box_valid,output reg[143:0]box_xmin,box_xmax,box_ymin,box_ymax
);
 localparam IDLE=0,POSE=1,LENGTH=2,EXPECT=3,FIND=4,MATCH=5,SAVE=6,NEXT=7,
 SELECT=8,HOLES=9,EXTRA=10,EXTRA_TEST=11,LINE=12,ENDPOINT=13,
 SETUP=14,REQ=15,WAIT_RAM=16,TAKE=17,POINT=18,LINE_END=19,PUBLISH=20,REFINE_PREP=21,REFINE_CHECK=22,TOP_PREP=23,TOP_FIND=24,TOP_USE=25,PROFILE_REQ=26,PROFILE_WAIT=27,PROFILE_TAKE=28,PROFILE_USE=29,
 HOLE_DIAM=30,HOLE_SCALE=31,HOLE_CHECK=32,ALIGN_LATCH=33,ALIGN_ENDPOINT=34,
 REFINE_BASE=35,REFINE_CENTER=36,AFFINE_DELTA=37,AFFINE_SQUARE=38,
 AFFINE_SUM=39,AFFINE_SCALE=40,AFFINE_CHECK=41,
 FIND_LATCH=42,FIND_DELTA=43,FIND_SQUARE=44,FIND_DIST=45,FIND_COMPARE=46,
 MATCH_SCALE=47,MATCH_CHECK=48,EXTRA_LATCH=49,EXTRA_DELTA=50,EXTRA_DOT=51,ENDPOINT_DIV=52,ENDPOINT_DIV5=53,ENDPOINT_SIGN=54,EXTRA_LIMITS=55,EXTRA_SCALE=56,EXTRA_SUM=57,EXTRA_CHECK=58,HISTORY_PICK=59,HISTORY_LOAD=60,SELECT_APPLY=61;
 reg[5:0]state;
 reg[4:0]i,j,k,idx,nearest,best_index[0:4],matches[0:4];
 reg[2:0]h,hits,best_hits;
 reg[15:0]used,best_used,owned_mask;
 reg signed[12:0]ax,ay,ox,oy,ex,ey,bax,bay,boxc,boyc;
 reg[25:0]len2,near_d2,score,best_score,blen2;
 reg[3:0]fault;
 reg[2:0] edge_causes; // bit0 spatial, bit1 rough, bit2 held
 reg[11:0]valid_w;
 reg[143:0]x0w,x1w,y0w,y1w;
 // Fine pose in 1/16 original-pixel units. Limited affine calibration uses
 // three bottom-row holes and middle stem hole; top hole is never a calibrator.
 reg signed[20:0] ofx,ofy,ufx,ufy,vfx,vfy;
 reg signed[20:0] cox,coy,cux,cuy,cvx,cvy;
 reg affine_used;

 // Full affine timing pipeline.  The old implementation formed:
 //   delta -> square -> sum -> *10000 -> compare -> vfx/vfy enable
 // in one combinational cone.  Every arithmetic boundary below is now
 // registered; the mathematical test is unchanged.
 localparam [63:0] AFFINE_RHS_SCALE =
      64'd256*AFFINE_LIMIT_PERCENT*AFFINE_LIMIT_PERCENT;
 reg [10:0] cal_x0_q,cal_y0_q,cal_x1_q,cal_y1_q;
 reg [10:0] cal_x2_q,cal_y2_q,cal_x3_q,cal_y3_q;
 reg signed[13:0] refine_sum_x_q,refine_sum_y_q;
 reg signed[12:0] refine_du_x_q,refine_du_y_q;
 reg signed[21:0] affine_dx_q,affine_dy_q;
 reg [43:0] affine_sq_x_q,affine_sq_y_q;
 reg [44:0] affine_delta2_q;
 reg [63:0] affine_lhs_q,affine_rhs_q;
 reg affine_accept_q;
 function signed[12:0] round_fine;
 input signed[21:0] a;
 begin round_fine=a>=0?(a+8)/16:(a-8)/16;end
 endfunction
 function signed[15:0] round_map;
 input signed[31:0] a;
 begin round_map=a>=0?(a+2560)/5120:(a-2560)/5120;end
 endfunction
 reg signed[31:0]udot,vdot;
 reg[2:0]side;
 reg signed[15:0]lx,ly,lendx,lendy;
 reg signed[15:0]adx,ady,stepx,stepy,err;
 wire signed[16:0]e2=$signed(err)*2;
 reg signed[31:0]numx0,numy0,numx1,numy1;
 // Timing split for round_map(): first register the signed rounding bias,
 // then perform the unchanged signed /5120 in ENDPOINT_DIV.
 reg signed[31:0]round_x0_q,round_y0_q,round_x1_q,round_y1_q;
 // Exact constant-division pipeline for /5120 = /1024 then /5.
 // We operate on magnitude and restore the sign afterwards, matching
 // signed Verilog division truncation toward zero.
 reg [31:0] round_abs_x0_q,round_abs_y0_q,round_abs_x1_q,round_abs_y1_q;
 reg [15:0] round_div5_x0_q,round_div5_y0_q,round_div5_x1_q,round_div5_y1_q;
 reg round_sign_x0_q,round_sign_y0_q,round_sign_x1_q,round_sign_y1_q;
 reg signed[9:0]mx0,my0,mx1,my1;
 // History is specific to the two sloping sides (2 and 4).
 // Two raw failures in four analyses arm the hold; one isolated failure
 // retains V2 behavior. Six consecutive clean analyses release an armed hold.
 reg[2:0] slope_hist[0:1];
 reg[7:0] slope_clean[0:1];
 reg[1:0] slope_hold;
 reg pose_seen;
 reg signed[12:0] prev_ox,prev_oy,prev_ax,prev_ay;
 wire signed[13:0] move_x=boxc-prev_ox,move_y=boyc-prev_oy;
 wire signed[13:0] axis_x=bax-prev_ax,axis_y=bay-prev_ay;
 wire[13:0] move_abs_x=move_x<0?-move_x:move_x,move_abs_y=move_y<0?-move_y:move_y;
 wire[13:0] axis_abs_x=axis_x<0?-axis_x:axis_x,axis_abs_y=axis_y<0?-axis_y:axis_y;
 wire[14:0] move_l1={1'b0,move_abs_x}+{1'b0,move_abs_y};
 wire[14:0] axis_l1={1'b0,axis_abs_x}+{1'b0,axis_abs_y};
 // Two independent temporal contexts. Slots are matched by center AND axis;
 // a newly acquired pose resets history through the original same_pose test.
 reg [1:0] ctx_valid;
 reg [1:0] ctx_hold[0:1];
 reg [2:0] ctx_hist0[0:1],ctx_hist1[0:1];
 reg [7:0] ctx_clean0[0:1],ctx_clean1[0:1];
 reg signed [12:0] ctx_ox[0:1],ctx_oy[0:1],ctx_ax[0:1],ctx_ay[0:1];
 reg [1:0] ctx_match_q;
 reg [15:0] ctx_cost0_q,ctx_cost1_q;
 function [13:0] absdiff13;
 input signed [12:0] a,b;
 reg signed [13:0] d;
 begin d={a[12],a}-{b[12],b}; absdiff13=d<0?-d:d; end
 endfunction
 wire [14:0] cm0={1'b0,absdiff13(boxc,ctx_ox[0])}+absdiff13(boyc,ctx_oy[0]);
 wire [14:0] cm1={1'b0,absdiff13(boxc,ctx_ox[1])}+absdiff13(boyc,ctx_oy[1]);
 wire [14:0] ca0={1'b0,absdiff13(bax,ctx_ax[0])}+absdiff13(bay,ctx_ay[0]);
 wire [14:0] ca1={1'b0,absdiff13(bax,ctx_ax[1])}+absdiff13(bay,ctx_ay[1]);
 wire same_pose=pose_seen && move_l1*17'd4<=({4'b0,abs_bax}+abs_bay) &&
                            axis_l1*17'd4<=({4'b0,abs_bax}+abs_bay);
 wire is_slope=(side==2 || side==4);
 wire slope_idx=(side==4);
 // Registration applies to all sides except the bottom. Scan -3..+3 map pixels;
 // accept an offset only within 2mm according to the 80mm hole baseline.
 // This is one constant displacement for the ENTIRE segment, never a
 // per-point follower. Hole and bottom-edge rules are unchanged.
 wire align_side=(side!=0);
 wire tilt_side=(side==2 || side==4);
 reg align_probe,align_tilt_phase,align_x_axis;
 reg signed[3:0] align_tilt,align_best_tilt,align_center;
 reg signed[3:0] align_shift,align_best;
 reg[10:0] align_best_missing;
 reg signed[15:0] nominal_x0,nominal_y0,nominal_x1,nominal_y1;
 wire[3:0] align_abs=align_shift<0?-align_shift:align_shift;
 wire[3:0] best_abs=align_best<0?-align_best:align_best;
 wire[3:0] tilt_abs=align_tilt<0?-align_tilt:align_tilt;
 wire[4:0] endpoint_abs={1'b0,align_abs}+{1'b0,tilt_abs};
 // Exact equivalent of endpoint_abs^2*6400 <= blen2 for endpoint_abs=0..3.
 // endpoint_abs>3 is rejected exactly as before. This removes two cascaded
 // multipliers from the align_tilt timing path.
 reg [25:0] align_limit_q;
 always @* begin
   case(endpoint_abs)
     5'd0: align_limit_q=26'd0;
     5'd1: align_limit_q=26'd6400;
     5'd2: align_limit_q=26'd25600;
     5'd3: align_limit_q=26'd57600;
     default: align_limit_q=26'h3ffffff;
   endcase
 end
 wire align_allowed=(endpoint_abs<=3) && (align_limit_q<=blen2);
 wire align_better=align_allowed &&
       (missing<align_best_missing ||
       (missing==align_best_missing && !align_tilt_phase && align_abs<best_abs));
 wire signed[3:0] chosen_shift=align_better?align_shift:align_best;
 wire signed[3:0] chosen_tilt=align_better?align_tilt:align_best_tilt;
 reg signed[3:0] next_shift,next_tilt;
 reg next_probe,next_tilt_phase;
 reg signed[3:0] align_pending_shift,align_pending_tilt;
 reg align_pending_probe,align_pending_tilt_phase;
 // Candidate schedule: rigid translation, then small endpoint tilts around
 // its best translation. Top/side walls retain translation only.
 always @* begin
 next_shift=align_shift;next_tilt=align_tilt;
 next_probe=1;next_tilt_phase=align_tilt_phase;
 if(!align_tilt_phase)begin
 if(align_shift==3)begin
 next_shift=chosen_shift;
 if(tilt_side)begin next_tilt_phase=1;next_tilt=-2;end
 else begin next_probe=0;next_tilt=0;end
 end else if(align_shift==0)next_shift=-3;
 else if(align_shift==-1)next_shift=1;
 else next_shift=align_shift+1;
 end else begin
 next_shift=align_center;
 if(align_tilt==2)begin next_probe=0;next_shift=chosen_shift;next_tilt=chosen_tilt;end
 else if(align_tilt==-1)next_tilt=1;
 else next_tilt=align_tilt+1;
 end
 end

 reg[4:0] profile_n;
 reg profile_found,profile_ok;
 reg signed[5:0] profile_min,profile_max;
 reg[4:0] profile_run_len,profile_best_len;
 reg signed[5:0] profile_run_start;
 wire signed[5:0] candidate_start=(profile_run_len==0)?profile_offset:profile_run_start;
 wire signed[6:0] candidate_mid=$signed(candidate_start)+$signed(profile_offset);
 wire signed[6:0] chosen_mid=$signed(profile_min)+$signed(profile_max);
 wire[6:0] candidate_abs=candidate_mid<0?-candidate_mid:candidate_mid;
 wire[6:0] chosen_abs=chosen_mid<0?-chosen_mid:chosen_mid;
 reg signed[5:0] previous_profile1,previous_profile2;
 reg[1:0] median_valid;
 function signed[5:0] median3;
 input signed[5:0] a,b,c;
 begin
 if(a>b)begin
 if(b>c)median3=b;else if(a>c)median3=c;else median3=a;
 end else begin
 if(a>c)median3=a;else if(b>c)median3=c;else median3=b;
 end
 end endfunction
 wire signed[5:0] profile_offset=$signed({1'b0,profile_n})-6'sd8;
 reg signed[5:0] profile_delay[0:7];
 reg[3:0] profile_valid_count;
 reg[10:0] curve_pos,curve_neg;
 wire signed[7:0] profile_mid=profile_min+profile_max;
 wire signed[5:0] filtered_profile=median3(profile_mid,previous_profile1,previous_profile2);
 wire signed[9:0] curvature=$signed(filtered_profile)-($signed(profile_delay[3])*10'sd2)+$signed(profile_delay[7]);
 wire rough_line_bad=is_slope && curve_pos>=2 && curve_neg>=2 &&
                     ({1'b0,curve_pos}+curve_neg)>=SLOPE_CURVE_HITS;
 wire spatial_line_bad=(side==3) ?
    (maxrun>=TOP_MISS_RUN || missing*100>samples*TOP_MISSING_PERCENT) :
    is_slope ? (maxrun>=SLOPE_MISS_RUN || missing*100>samples*SLOPE_MISSING_PERCENT) :
    (maxrun>=MIN_MISS_RUN || missing*100>samples*MAX_MISSING_PERCENT);
 wire raw_line_bad=rough_line_bad || spatial_line_bad;
 wire hold_line_bad=is_slope && slope_hold[slope_idx] &&
                    (slope_clean[slope_idx] < SLOPE_CLEAR_RESULTS-1);
 reg signed[15:0] line_start_x,line_start_y;
 reg[5:0]n; // 0..24 for the top 5x5 search
 reg sample_ok,near_edge;
 reg[10:0]samples,missing,run,maxrun;
 reg[11:0]badx0,badx1,bady0,bady1,allx0,allx1,ally0,ally1;
 reg signed[15:0]rx,ry;
 wire[10:0]hx=hole_x[k*11 +:11],hy=hole_y[k*11 +:11];
 // Registered nearest-hole search pipeline. Dynamic hole_x/hole_y selection is
 // isolated from subtract/square/scale/compare arithmetic.
 reg [10:0] find_hx_q,find_hy_q;
 reg find_used_q,find_last_q,find_top_q;
 reg signed [12:0] find_ddx_q,find_ddy_q;
 reg [25:0] find_ddx2_q,find_ddy2_q,find_dist2_q;
 reg [39:0] near_scaled_q,pos_limit_q;
 // EXTRA-hole dot-product pipeline uses the same principle.
 reg [10:0] extra_hx_q,extra_hy_q;
 reg signed [12:0] extra_dx_q,extra_dy_q;
 // Hole-diameter verdict pipeline. This is functionally identical to the
 // original diam -> diam^2 -> *6400 -> compare chain, but each multiplier
 // is separated by a register to shorten the clk_pixel_2x critical path.
 reg        hole_missing_q;
 reg [7:0]  hole_diam_q;
 reg [15:0] hole_diam2_q;
 reg [39:0] hole_diam_scaled_q;
 reg [39:0] diam_low_q, diam_high_q; // 7..11 mm limits based on 80 mm baseline
 wire signed[31:0]u_abs=udot<0?-udot:udot;
 // Pipelined interior-of-plate test for extra circles.
 // Original inequalities are unchanged; only the arithmetic is registered.
 reg [63:0] extra_lim18_q,extra_lim58_q,extra_lim98_q,extra_lim138_q;
 reg signed [63:0] extra_u80_q,extra_v80_q,extra_u160_q,extra_edge_q;
 reg extra_used_q,extra_last_q;
 function[11:0]clampx;input signed[15:0]v;begin
 if(v<0)clampx=960;else if(v>479)clampx=1919;else clampx=960+(v<<1);end endfunction
 function[11:0]clampy;input signed[15:0]v;begin
 if(v<0)clampy=0;else if(v>539)clampy=1079;else clampy=v<<1;end endfunction
 // Segments exclude the 2mm corner rounds; coordinates in half millimetres.
 always @*begin
 mx0=0;my0=0;mx1=0;my1=0;
 case(side)
 0:begin mx0=-110;my0=-36;mx1=110;my1=-36;end
 1:begin mx0=116;my0=-30;mx1=116;my1=38;end
 2:begin mx0=113;my0=50;mx1=43;my1=190;end
 3:begin mx0=34;my0=196;mx1=-34;my1=196;end
 4:begin mx0=-43;my0=190;mx1=-113;my1=50;end
 5:begin mx0=-116;my0=38;mx1=-116;my1=-30;end
 endcase
 // Top uses 5x5 (previously 7x7); slopes/other sides use 3x3.
 if(side==3)begin rx=lx+(n%5)-2;ry=ly+(n/5)-2;end
 else begin rx=lx+(n%3)-1;ry=ly+(n/3)-1;end
 end
 integer t; integer ct;
 integer pd;
 reg[11:0]hole_pad;
 wire[12:0]abs_bax=bax<0?-bax:bax,abs_bay=bay<0?-bay:bay;
 always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
 result_slot<=0;consumed_mask<=0;owned_mask<=0;ctx_valid<=0;ctx_match_q<=0;
 ctx_cost0_q<=0;ctx_cost1_q<=0;
 for(ct=0;ct<2;ct=ct+1)begin
 ctx_hold[ct]<=0;ctx_hist0[ct]<=0;ctx_hist1[ct]<=0;
 ctx_clean0[ct]<=0;ctx_clean1[ct]<=0;
 ctx_ox[ct]<=0;ctx_oy[ct]<=0;ctx_ax[ct]<=0;ctx_ay[ct]<=0;
 end
 align_probe<=0;align_shift<=0;align_best<=0;align_best_missing<=2047;
 align_tilt_phase<=0;align_x_axis<=0;align_tilt<=0;align_best_tilt<=0;align_center<=0;
 align_pending_shift<=0;align_pending_tilt<=0;align_pending_probe<=0;align_pending_tilt_phase<=0;
 nominal_x0<=0;nominal_y0<=0;nominal_x1<=0;nominal_y1<=0;
 profile_n<=0;profile_found<=0;profile_ok<=0;profile_min<=0;profile_max<=0;
 profile_run_len<=0;profile_best_len<=0;profile_run_start<=0;
 previous_profile1<=0;previous_profile2<=0;median_valid<=0;
 profile_valid_count<=0;curve_pos<=0;curve_neg<=0;median_valid<=0;
 for(pd=0;pd<8;pd=pd+1)profile_delay[pd]<=0;
 slope_hold<=0;pose_seen<=0;prev_ox<=0;prev_oy<=0;prev_ax<=0;prev_ay<=0;
 slope_hist[0]<=0;slope_hist[1]<=0;slope_clean[0]<=0;slope_clean[1]<=0;
 line_start_x<=0;line_start_y<=0;
 state<=IDLE;i<=0;j<=0;k<=0;idx<=0;nearest<=0;h<=0;hits<=0;best_hits<=0;used<=0;best_used<=0;
 ax<=0;ay<=0;ox<=0;oy<=0;ex<=0;ey<=0;bax<=0;bay<=0;boxc<=0;boyc<=0;
 len2<=0;near_d2<=0;score<=0;best_score<=0;blen2<=0;fault<=0;edge_causes<=0;valid_w<=0;
 x0w<=0;x1w<=0;y0w<=0;y1w<=0;udot<=0;vdot<=0;side<=0;
 lx<=0;ly<=0;lendx<=0;lendy<=0;adx<=0;ady<=0;stepx<=0;stepy<=0;err<=0;
 numx0<=0;numy0<=0;numx1<=0;numy1<=0;round_x0_q<=0;round_y0_q<=0;round_x1_q<=0;round_y1_q<=0;
 round_abs_x0_q<=0;round_abs_y0_q<=0;round_abs_x1_q<=0;round_abs_y1_q<=0;
 round_div5_x0_q<=0;round_div5_y0_q<=0;round_div5_x1_q<=0;round_div5_y1_q<=0;
 round_sign_x0_q<=0;round_sign_y0_q<=0;round_sign_x1_q<=0;round_sign_y1_q<=0;
 n<=0;sample_ok<=0;near_edge<=0;
 samples<=0;missing<=0;run<=0;maxrun<=0;badx0<=0;badx1<=0;bady0<=0;bady1<=0;
 allx0<=0;allx1<=0;ally0<=0;ally1<=0;hole_pad<=0;
 hole_missing_q<=0;hole_diam_q<=0;hole_diam2_q<=0;hole_diam_scaled_q<=0;
 diam_low_q<=0;diam_high_q<=0;
 ofx<=0;ofy<=0;ufx<=0;ufy<=0;vfx<=0;vfy<=0;
 cox<=0;coy<=0;cux<=0;cuy<=0;cvx<=0;cvy<=0;affine_used<=0;
 cal_x0_q<=0;cal_y0_q<=0;cal_x1_q<=0;cal_y1_q<=0;
 cal_x2_q<=0;cal_y2_q<=0;cal_x3_q<=0;cal_y3_q<=0;
 refine_sum_x_q<=0;refine_sum_y_q<=0;refine_du_x_q<=0;refine_du_y_q<=0;
 affine_dx_q<=0;affine_dy_q<=0;affine_sq_x_q<=0;affine_sq_y_q<=0;
 affine_delta2_q<=0;affine_lhs_q<=0;affine_rhs_q<=0;affine_accept_q<=0;
 find_hx_q<=0;find_hy_q<=0;find_used_q<=0;find_last_q<=0;find_top_q<=0;
 find_ddx_q<=0;find_ddy_q<=0;find_ddx2_q<=0;find_ddy2_q<=0;find_dist2_q<=0;
 near_scaled_q<=0;pos_limit_q<=0;extra_hx_q<=0;extra_hy_q<=0;extra_dx_q<=0;extra_dy_q<=0;
 extra_lim18_q<=0;extra_lim58_q<=0;extra_lim98_q<=0;extra_lim138_q<=0;
 extra_u80_q<=0;extra_v80_q<=0;extra_u160_q<=0;extra_edge_q<=0;
 extra_used_q<=0;extra_last_q<=0;
 result_hole_count<=0;done<=0;map_addr<=0;detected<=0;passed<=0;result_toggle<=0;fault_code<=0;
 box_valid<=0;box_xmin<=0;box_xmax<=0;box_ymin<=0;box_ymax<=0;
 for(t=0;t<5;t=t+1)begin matches[t]<=16;best_index[t]<=16;end
 end else begin
 done<=0;
 case(state)
 IDLE:if(start)begin
 ctx_valid<=ctx_valid & ~clear_history;
 best_used<=0;consumed_mask<=0;owned_mask<=0;
 i<=0;j<=0;best_hits<=0;best_score<=26'h3ffffff;
 fault<=source_error?4'b1000:0;edge_causes<=0;valid_w<=0;x0w<=0;x1w<=0;y0w<=0;y1w<=0;
 if(hole_count<4)begin
 slope_hold<=0;pose_seen<=0;slope_hist[0]<=0;slope_hist[1]<=0;
 slope_clean[0]<=0;slope_clean[1]<=0;state<=PUBLISH;
 end else state<=POSE;end
 POSE:if(i==j || exclude_mask[i] || exclude_mask[j])state<=NEXT;else begin
 ax<=$signed({2'b0,hole_x[j*11 +:11]})-$signed({2'b0,hole_x[i*11 +:11]});
 ay<=$signed({2'b0,hole_y[j*11 +:11]})-$signed({2'b0,hole_y[i*11 +:11]});
 ox<=({1'b0,hole_x[i*11 +:11]}+{1'b0,hole_x[j*11 +:11]})>>1;
 oy<=({1'b0,hole_y[i*11 +:11]}+{1'b0,hole_y[j*11 +:11]})>>1;
 state<=LENGTH;end
 LENGTH:begin len2<=ax*ax+ay*ay;h<=0;hits<=0;score<=0;used<=0;state<=EXPECT;end
 EXPECT:if(len2<MIN_BASE_PIXELS*MIN_BASE_PIXELS||len2>MAX_BASE_PIXELS*MAX_BASE_PIXELS)state<=NEXT;
 else begin
 case(h)
 0:begin ex<=ox-(ax>>>1);ey<=oy-(ay>>>1);end
 1:begin ex<=ox+(ax>>>1);ey<=oy+(ay>>>1);end
 2:begin ex<=ox;ey<=oy;end
 3:begin ex<=ox-(ay>>>1);ey<=oy+(ax>>>1);end
 4:begin ex<=ox-ay;ey<=oy+ax;end
 endcase
 k<=0;near_d2<=26'h3ffffff;nearest<=16;find_top_q<=0;state<=FIND_LATCH;end
 FIND_LATCH:begin
 // Stage 0: dynamic array selection only.
 find_hx_q<=hole_x[k*11 +:11];
 find_hy_q<=hole_y[k*11 +:11];
 find_used_q<=used[k] || exclude_mask[k];
 find_last_q<=(k==hole_count-1);
 state<=FIND_DELTA;
 end
 FIND_DELTA:begin
 // Stage 1: coordinate subtraction only.
 find_ddx_q<=$signed({2'b0,find_hx_q})-ex;
 find_ddy_q<=$signed({2'b0,find_hy_q})-ey;
 state<=FIND_SQUARE;
 end
 FIND_SQUARE:begin
 // Stage 2: independent square DSPs, captured before the adder.
 find_ddx2_q<=find_ddx_q*find_ddx_q;
 find_ddy2_q<=find_ddy_q*find_ddy_q;
 state<=FIND_DIST;
 end
 FIND_DIST:begin
 // Stage 3: distance sum only.
 find_dist2_q<=find_ddx2_q+find_ddy2_q;
 state<=FIND_COMPARE;
 end
 FIND_COMPARE:begin
 // Stage 4: registered distance comparison / nearest-index update.
 if(!find_used_q&&find_dist2_q<near_d2)begin near_d2<=find_dist2_q;nearest<=k;end
 if(find_last_q)state<=MATCH_SCALE;
 else begin k<=k+1'b1;state<=FIND_LATCH;end
 end
 MATCH_SCALE:begin
 // Stage 5: scale registered nearest distance and position limit separately.
 near_scaled_q<=near_d2*14'd6400;
 pos_limit_q<=len2*(POSITION_TOL_MM*POSITION_TOL_MM);
 state<=MATCH_CHECK;
 end
 MATCH_CHECK:begin
 // Stage 6: final comparison only. FIND and TOP_FIND share this stage.
 if(find_top_q)begin
   if(best_index[4]<16)best_used[best_index[4]]<=0;
   if(nearest<16&&near_scaled_q<=pos_limit_q)begin
     best_index[4]<=nearest;best_used[nearest]<=1;
     if(best_index[4]==16)best_hits<=best_hits+1'b1;
   end else begin
     best_index[4]<=16;if(best_index[4]<16)best_hits<=best_hits-1'b1;
   end
   state<=HOLES;
 end else begin
   if(nearest<16&&near_scaled_q<=pos_limit_q)begin
     hits<=hits+1'b1;score<=score+near_d2;used[nearest]<=1;matches[h]<=nearest;
   end else matches[h]<=16;
   if(h==4)state<=SAVE;else begin h<=h+1'b1;state<=EXPECT;end
 end
 end
 SAVE:begin
 if(hits>best_hits||(hits==best_hits&&score<best_score))begin
 best_hits<=hits;best_score<=score;bax<=ax;bay<=ay;boxc<=ox;boyc<=oy;blen2<=len2;best_used<=used;
 for(t=0;t<5;t=t+1)best_index[t]<=matches[t];
 end
 state<=NEXT;end
 NEXT:if(j==hole_count-1)begin
 j<=0;if(i==hole_count-1)state<=SELECT;else begin i<=i+1'b1;state<=POSE;end
 end else begin j<=j+1'b1;state<=POSE;end
 SELECT:if(best_hits<4)begin
 state<=PUBLISH;
 end else begin
 ctx_match_q[0]<=ctx_valid[0] && !reserved_slots[0] &&
   ({cm0,2'b0}<=({4'b0,abs_bax}+abs_bay)) &&
   ({ca0,2'b0}<=({4'b0,abs_bax}+abs_bay));
 ctx_match_q[1]<=ctx_valid[1] && !reserved_slots[1] &&
   ({cm1,2'b0}<=({4'b0,abs_bax}+abs_bay)) &&
   ({ca1,2'b0}<=({4'b0,abs_bax}+abs_bay));
 ctx_cost0_q<={1'b0,cm0}+ca0;ctx_cost1_q<={1'b0,cm1}+ca1;
 state<=HISTORY_PICK;
 end
 HISTORY_PICK:begin
 if(ctx_match_q==2'b11)result_slot<=ctx_cost1_q<ctx_cost0_q;
 else if(ctx_match_q[0])result_slot<=0;
 else if(ctx_match_q[1])result_slot<=1;
 else result_slot<=reserved_slots[0];
 state<=HISTORY_LOAD;
 end
 HISTORY_LOAD:begin
 pose_seen<=ctx_valid[result_slot];
 prev_ox<=ctx_ox[result_slot];prev_oy<=ctx_oy[result_slot];
 prev_ax<=ctx_ax[result_slot];prev_ay<=ctx_ay[result_slot];
 slope_hold<=ctx_hold[result_slot];
 slope_hist[0]<=ctx_hist0[result_slot];slope_hist[1]<=ctx_hist1[result_slot];
 slope_clean[0]<=ctx_clean0[result_slot];slope_clean[1]<=ctx_clean1[result_slot];
 state<=SELECT_APPLY;
 end
 SELECT_APPLY:begin
 if(!same_pose)begin
 slope_hold<=0;slope_hist[0]<=0;slope_hist[1]<=0;
 slope_clean[0]<=0;slope_clean[1]<=0;
 end
 pose_seen<=1;prev_ox<=boxc;prev_oy<=boyc;prev_ax<=bax;prev_ay<=bay;
 valid_w[0]<=1;h<=0;side<=0;hole_pad<=((abs_bax+abs_bay)>>3)+3;
 allx0<=1919;allx1<=960;ally0<=1079;ally1<=0;
 ofx<=boxc*16;ofy<=boyc*16;ufx<=bax*16;ufy<=bay*16;vfx<=-bay*16;vfy<=bax*16;
 // Register baseline-derived diameter limits once per target result.
 // Original equations: diam_low=blen2*49, diam_high=blen2*121.
 diam_low_q<=blen2*7'd49;
 diam_high_q<=blen2*7'd121;
 affine_used<=0;affine_accept_q<=0;state<=REFINE_PREP;
 end
 REFINE_PREP:begin
 // Stage 0: latch the four calibrator coordinates.  Dynamic best_index[]
 // selection stops here and cannot feed the affine arithmetic directly.
 if(best_index[0]<16&&best_index[1]<16&&best_index[2]<16&&best_index[3]<16)begin
 cal_x0_q<=hole_x[best_index[0]*11 +:11];
 cal_y0_q<=hole_y[best_index[0]*11 +:11];
 cal_x1_q<=hole_x[best_index[1]*11 +:11];
 cal_y1_q<=hole_y[best_index[1]*11 +:11];
 cal_x2_q<=hole_x[best_index[2]*11 +:11];
 cal_y2_q<=hole_y[best_index[2]*11 +:11];
 cal_x3_q<=hole_x[best_index[3]*11 +:11];
 cal_y3_q<=hole_y[best_index[3]*11 +:11];
 state<=REFINE_BASE;
 end else begin
 affine_accept_q<=0;
 state<=TOP_PREP;
 end
 end

 REFINE_BASE:begin
 // Stage 1: only additions/subtractions in original-pixel coordinates.
 refine_sum_x_q <= $signed({1'b0,cal_x0_q})+
                   $signed({1'b0,cal_x1_q})+
                   $signed({1'b0,cal_x2_q});
 refine_sum_y_q <= $signed({1'b0,cal_y0_q})+
                   $signed({1'b0,cal_y1_q})+
                   $signed({1'b0,cal_y2_q});
 refine_du_x_q <= $signed({2'b0,cal_x1_q})-$signed({2'b0,cal_x0_q});
 refine_du_y_q <= $signed({2'b0,cal_y1_q})-$signed({2'b0,cal_y0_q});
 state<=REFINE_CENTER;
 end

 REFINE_CENTER:begin
 // Stage 2: same fine-coordinate definitions as before.  *16 is a shift;
 // the /3 center definition is unchanged.
 cox <= (refine_sum_x_q*32'sd16)/3;
 coy <= (refine_sum_y_q*32'sd16)/3;
 cux <= refine_du_x_q*32'sd16;
 cuy <= refine_du_y_q*32'sd16;
 state<=REFINE_CHECK;
 end

 REFINE_CHECK:begin
 // Stage 3: derive the perpendicular calibration vector from the latched
 // fourth hole and the registered center.
 cvx <= 2*($signed({1'b0,cal_x3_q})*32'sd16-cox);
 cvy <= 2*($signed({1'b0,cal_y3_q})*32'sd16-coy);
 state<=AFFINE_DELTA;
 end

 AFFINE_DELTA:begin
 // Stage 4: orthogonality error components only.
 affine_dx_q <= $signed(cvx)+$signed(cuy);
 affine_dy_q <= $signed(cvy)-$signed(cux);
 state<=AFFINE_SQUARE;
 end

 AFFINE_SQUARE:begin
 // Stage 5: one squaring layer.  Both products are captured before any sum.
 affine_sq_x_q <= $signed(affine_dx_q)*$signed(affine_dx_q);
 affine_sq_y_q <= $signed(affine_dy_q)*$signed(affine_dy_q);
 state<=AFFINE_SUM;
 end

 AFFINE_SUM:begin
 // Stage 6: sum the registered squares and independently form the unchanged
 // baseline-side limit.  No result from either operation is compared here.
 affine_delta2_q <= {1'b0,affine_sq_x_q}+{1'b0,affine_sq_y_q};
 affine_rhs_q <= blen2*AFFINE_RHS_SCALE;
 state<=AFFINE_SCALE;
 end

 AFFINE_SCALE:begin
 // Stage 7: original lhs = affine_delta2 * 10000.
 affine_lhs_q <= affine_delta2_q*64'd10000;
 state<=AFFINE_CHECK;
 end

 AFFINE_CHECK:begin
 // Stage 8: compare registered quantities only.  The comparison result itself
 // is registered so it cannot become the clock-enable cone of vfx/vfy.
 affine_accept_q <= (affine_lhs_q<=affine_rhs_q);
 state<=TOP_PREP;
 end

 TOP_PREP:begin
 // Stage 9: apply the already-registered verdict.  Missing calibrators enter
 // here with affine_accept_q=0 and therefore keep the original nominal pose.
 if(affine_accept_q)begin
 ofx<=cox;ofy<=coy;ufx<=cux;ufy<=cuy;vfx<=cvx;vfy<=cvy;affine_used<=1;
 ex<=round_fine(cox+cvx);ey<=round_fine(coy+cvy);
 end else begin
 ex<=round_fine(ofx+vfx);ey<=round_fine(ofy+vfy);
 end
 used<=best_used; if(best_index[4]<16)used[best_index[4]]<=0;
 len2<=blen2;k<=0;near_d2<=26'h3ffffff;nearest<=16;find_top_q<=1;state<=FIND_LATCH;
 end
 HOLES:begin
 // Stage 0: latch the selected hole diameter and expected center.
 // Missing-hole information is latched explicitly so dynamic best_index[h]
 // does not feed the diameter arithmetic/comparator in one long path.
 hole_missing_q <= (best_index[h]==16);
 if(best_index[h]<16) hole_diam_q <= hole_diameter[best_index[h]*8 +:8];
 else                 hole_diam_q <= 8'd0;
 case(h)
 0:begin ex<=round_fine(ofx-(ufx>>>1));ey<=round_fine(ofy-(ufy>>>1));end
 1:begin ex<=round_fine(ofx+(ufx>>>1));ey<=round_fine(ofy+(ufy>>>1));end
 2:begin ex<=round_fine(ofx);ey<=round_fine(ofy);end
 3:begin ex<=round_fine(ofx+(vfx>>>1));ey<=round_fine(ofy+(vfy>>>1));end
 4:begin ex<=round_fine(ofx+vfx);ey<=round_fine(ofy+vfy);end
 endcase
 state<=HOLE_DIAM;
 end
 HOLE_DIAM:begin
 // Stage 1: first multiplier only.
 hole_diam2_q <= hole_diam_q * hole_diam_q;
 state<=HOLE_SCALE;
 end
 HOLE_SCALE:begin
 // Stage 2: constant scaling only.
 hole_diam_scaled_q <= hole_diam2_q * 14'd6400;
 state<=HOLE_CHECK;
 end
 HOLE_CHECK:begin
 // Stage 3: compare registered values and update the same fault bits/box flag
 // as the original one-cycle implementation. No tolerance is changed.
 if(hole_missing_q || hole_diam_scaled_q<diam_low_q || hole_diam_scaled_q>diam_high_q)begin
 valid_w[h+1]<=1;
 if(hole_missing_q)fault[0]<=1;else fault[1]<=1;
 end
 state<=EXTRA_TEST;idx<=0;
 end
 EXTRA_TEST:if(idx==0)begin
 // ex/ey are full-resolution coordinates relative to right-half origin.
 x0w[(h+1)*12 +:12]<=ex>hole_pad?960+ex-hole_pad:960;
 x1w[(h+1)*12 +:12]<=ex+hole_pad<960?960+ex+hole_pad:1919;
 y0w[(h+1)*12 +:12]<=ey>hole_pad?ey-hole_pad:0;
 y1w[(h+1)*12 +:12]<=ey+hole_pad<1080?ey+hole_pad:1079;
 if(h==4)begin k<=0;state<=EXTRA_LIMITS;end else begin h<=h+1'b1;state<=HOLES;end
 end else begin
 // idx==1 path is no longer used for the extra-hole verdict; the pipelined
 // EXTRA_CHECK state below performs the same test and advances k.
 state<=EXTRA_CHECK;
 end

 EXTRA_LIMITS:begin
 // Register the four blen2-derived limits once per target result.
 // Original constants: 18, 58, 98 and 138.
 extra_lim18_q <= $unsigned(blen2) * 64'd18;
 extra_lim58_q <= $unsigned(blen2) * 64'd58;
 extra_lim98_q <= $unsigned(blen2) * 64'd98;
 extra_lim138_q<= $unsigned(blen2) * 64'd138;
 state<=EXTRA_LATCH;
 end

 EXTRA_LATCH:begin
 // Dynamic k-indexed coordinate/used selection only.
 extra_hx_q<=hole_x[k*11 +:11];
 extra_hy_q<=hole_y[k*11 +:11];
 extra_used_q<=best_used[k] || exclude_mask[k];
 extra_last_q<=(k==hole_count-1);
 state<=EXTRA_DELTA;
 end
 EXTRA_DELTA:begin
 extra_dx_q<=$signed({2'b0,extra_hx_q})-boxc;
 extra_dy_q<=$signed({2'b0,extra_hy_q})-boyc;
 state<=EXTRA_DOT;
 end
 EXTRA_DOT:begin
 // Dot-product DSP layer is isolated from the dynamic selector.
 udot<=extra_dx_q*bax+extra_dy_q*bay;
 vdot<=-extra_dx_q*bay+extra_dy_q*bax;
 state<=EXTRA_SCALE;
 end
 EXTRA_SCALE:begin
 // Scale registered dot products exactly as in the original inside_plate test.
 extra_u80_q <= $signed(udot) * 64'sd80;
 extra_v80_q <= $signed(vdot) * 64'sd80;
 extra_u160_q<= $signed(u_abs) * 64'sd160;
 state<=EXTRA_SUM;
 end
 EXTRA_SUM:begin
 // Final sloping-edge expression: abs(u)*160 + v*80.
 extra_edge_q <= extra_u160_q + extra_v80_q;
 state<=EXTRA_CHECK;
 end
 EXTRA_CHECK:begin
 // Registered-only comparison stage.  This is mathematically identical to:
 //   u*80 in (-blen2*58, +blen2*58)
 //   v*80 in (-blen2*18, +blen2*98)
 //   abs(u)*160 + v*80 < blen2*138
 if(
    extra_u80_q > -$signed(extra_lim58_q) &&
    extra_u80_q <  $signed(extra_lim58_q) &&
    extra_v80_q > -$signed(extra_lim18_q) &&
    extra_v80_q <  $signed(extra_lim98_q) &&
    extra_edge_q < $signed(extra_lim138_q))
     owned_mask[k]<=1'b1;
 if(!extra_used_q &&
    extra_u80_q > -$signed(extra_lim58_q) &&
    extra_u80_q <  $signed(extra_lim58_q) &&
    extra_v80_q > -$signed(extra_lim18_q) &&
    extra_v80_q <  $signed(extra_lim98_q) &&
    extra_edge_q < $signed(extra_lim138_q))
     fault[2]<=1'b1;
 if(extra_last_q)begin
     side<=0;idx<=0;state<=LINE;
 end else begin
     k<=k+1'b1;idx<=0;state<=EXTRA_LATCH;
 end
 end
 LINE:begin
 numx0<=ofx*160+ufx*mx0+vfx*my0;numy0<=ofy*160+ufy*mx0+vfy*my0;
 numx1<=ofx*160+ufx*mx1+vfx*my1;numy1<=ofy*160+ufy*mx1+vfy*my1;
 state<=ENDPOINT;end
 ENDPOINT:begin
 // Stage A: perform only the exact rounding bias from round_map().
 // Original: a>=0 ? (a+2560)/5120 : (a-2560)/5120.
 // Registering the biased numerators breaks the final numy0 -> DSP path.
 round_x0_q <= (numx0>=0) ? (numx0+32'sd2560) : (numx0-32'sd2560);
 round_y0_q <= (numy0>=0) ? (numy0+32'sd2560) : (numy0-32'sd2560);
 round_x1_q <= (numx1>=0) ? (numx1+32'sd2560) : (numx1-32'sd2560);
 round_y1_q <= (numy1>=0) ? (numy1+32'sd2560) : (numy1-32'sd2560);
 // Axis choice is also captured here, independently of the division path.
 align_x_axis<=((numy1>=numy0?numy1-numy0:numy0-numy1)>=
                (numx1>=numx0?numx1-numx0:numx0-numx1));
 state<=ENDPOINT_DIV;end

 ENDPOINT_DIV:begin
 // Stage B1: capture sign and absolute magnitude only.
 // Original round_*_q already contains the +/-2560 rounding bias.
 round_sign_x0_q <= round_x0_q[31];
 round_sign_y0_q <= round_y0_q[31];
 round_sign_x1_q <= round_x1_q[31];
 round_sign_y1_q <= round_y1_q[31];
 round_abs_x0_q <= round_x0_q[31] ? -round_x0_q : round_x0_q;
 round_abs_y0_q <= round_y0_q[31] ? -round_y0_q : round_y0_q;
 round_abs_x1_q <= round_x1_q[31] ? -round_x1_q : round_x1_q;
 round_abs_y1_q <= round_y1_q[31] ? -round_y1_q : round_y1_q;
 state<=ENDPOINT_DIV5;end

 ENDPOINT_DIV5:begin
 // Stage B2: exact unsigned /5120 = ((magnitude >> 10) / 5).
 // floor(floor(M/1024)/5) == floor(M/5120) for M>=0.
 // Only the small post-shift value enters a /5 divider.
 round_div5_x0_q <= (round_abs_x0_q >> 10) / 5;
 round_div5_y0_q <= (round_abs_y0_q >> 10) / 5;
 round_div5_x1_q <= (round_abs_x1_q >> 10) / 5;
 round_div5_y1_q <= (round_abs_y1_q >> 10) / 5;
 state<=ENDPOINT_SIGN;end

 ENDPOINT_SIGN:begin
 // Stage B3: restore sign. This is exactly signed truncation toward zero.
 nominal_x0 <= round_sign_x0_q ? -$signed({1'b0,round_div5_x0_q}) :
                                $signed({1'b0,round_div5_x0_q});
 nominal_y0 <= round_sign_y0_q ? -$signed({1'b0,round_div5_y0_q}) :
                                $signed({1'b0,round_div5_y0_q});
 nominal_x1 <= round_sign_x1_q ? -$signed({1'b0,round_div5_x1_q}) :
                                $signed({1'b0,round_div5_x1_q});
 nominal_y1 <= round_sign_y1_q ? -$signed({1'b0,round_div5_y1_q}) :
                                $signed({1'b0,round_div5_y1_q});
 lx    <= round_sign_x0_q ? -$signed({1'b0,round_div5_x0_q}) :
                            $signed({1'b0,round_div5_x0_q});
 ly    <= round_sign_y0_q ? -$signed({1'b0,round_div5_y0_q}) :
                            $signed({1'b0,round_div5_y0_q});
 lendx <= round_sign_x1_q ? -$signed({1'b0,round_div5_x1_q}) :
                            $signed({1'b0,round_div5_x1_q});
 lendy <= round_sign_y1_q ? -$signed({1'b0,round_div5_y1_q}) :
                            $signed({1'b0,round_div5_y1_q});
 align_probe<=align_side;align_shift<=0;align_best<=0;align_best_missing<=2047;
 align_tilt_phase<=0;align_tilt<=0;align_best_tilt<=0;align_center<=0;
 state<=SETUP;end
 SETUP:begin
 line_start_x<=lx;line_start_y<=ly;
 profile_valid_count<=0;curve_pos<=0;curve_neg<=0;median_valid<=0;
 adx<=lendx>lx?lendx-lx:lx-lendx;ady<=lendy>ly?lendy-ly:ly-lendy;
 stepx<=lendx>lx?1:-1;stepy<=lendy>ly?1:-1;
 err<=(lendx>lx?lendx-lx:lx-lendx)-(lendy>ly?lendy-ly:ly-lendy);
 samples<=0;missing<=0;run<=0;maxrun<=0;badx0<=1919;badx1<=960;bady0<=1079;bady1<=0;
 n<=0;near_edge<=0;state<=REQ;end
 REQ:begin
 sample_ok<=rx>=0&&rx<480&&ry>=0&&ry<540;
 map_addr<=rx>=0&&rx<480&&ry>=0&&ry<540?ry*480+rx:0;
 state<=WAIT_RAM;end
 WAIT_RAM:state<=TAKE;
 TAKE:begin
 near_edge<=near_edge||(sample_ok&&map_bit);
 if((side==3 && n==24)||(side!=3 && n==8))begin
 if(is_slope && !align_probe)begin profile_n<=0;profile_found<=0;profile_run_len<=0;profile_best_len<=0;state<=PROFILE_REQ;end
 else state<=POINT;
 end else begin n<=n+1'b1;state<=REQ;end
 end
 // Search a transverse 17-pixel strip in the map. Choose edge-band midpoint,
 // not the first near-ideal hit: a shallow notch must change the profile.
 PROFILE_REQ:begin
 if(ady>=adx)begin
 profile_ok<=lx+profile_offset>=0 && lx+profile_offset<480 && ly>=0 && ly<540;
 map_addr<=lx+profile_offset>=0 && lx+profile_offset<480 && ly>=0 && ly<540 ? ly*480+lx+profile_offset:0;
 end else begin
 profile_ok<=lx>=0 && lx<480 && ly+profile_offset>=0 && ly+profile_offset<540;
 map_addr<=lx>=0 && lx<480 && ly+profile_offset>=0 && ly+profile_offset<540 ? (ly+profile_offset)*480+lx:0;
 end
 state<=PROFILE_WAIT;end
 PROFILE_WAIT:state<=PROFILE_TAKE;
 PROFILE_TAKE:begin
 if(profile_ok && map_bit)begin
 // Only a contiguous run can define the band. Disconnected speckles must
 // never stretch min/max across the entire transverse search strip.
 if(profile_run_len==0)profile_run_start<=profile_offset;
 profile_run_len<=profile_run_len+1'b1;
 if(profile_run_len+1>profile_best_len ||
    (profile_run_len+1==profile_best_len && candidate_abs<chosen_abs))begin
 profile_min<=candidate_start;profile_max<=profile_offset;
 profile_best_len<=profile_run_len+1'b1;profile_found<=1;
 end
 end else profile_run_len<=0;
 if(profile_n==16)state<=PROFILE_USE;
 else begin profile_n<=profile_n+1'b1;state<=PROFILE_REQ;end
 end
 PROFILE_USE:begin
 // Second difference at 4-map-pixel spacing rejects constant offsets and
 // linear pose drift. Require repeated positive AND negative curvature.
 // Missing or clipped cross sections break the history, never fabricate data.
 if(profile_found && profile_min>-8 && profile_max<8)begin
 previous_profile2<=previous_profile1;previous_profile1<=profile_mid;
 if(median_valid<2)median_valid<=median_valid+1'b1;
 if(median_valid>=2)begin
 for(pd=7;pd>0;pd=pd-1)profile_delay[pd]<=profile_delay[pd-1];
 profile_delay[0]<=filtered_profile;
 if(profile_valid_count<8)profile_valid_count<=profile_valid_count+1'b1;
 if(profile_valid_count>=8)begin
 if(curvature>=SLOPE_CURVE_Q1)curve_pos<=curve_pos+1'b1;
 if(curvature<=-SLOPE_CURVE_Q1)curve_neg<=curve_neg+1'b1;
 end
 end
 end else begin profile_valid_count<=0;median_valid<=0;end
 state<=POINT;end
 POINT:begin
 samples<=samples+1'b1;
 if(!align_probe)begin
 if(clampx(lx)<allx0)allx0<=clampx(lx);if(clampx(lx)>allx1)allx1<=clampx(lx);
 if(clampy(ly)<ally0)ally0<=clampy(ly);if(clampy(ly)>ally1)ally1<=clampy(ly);
 end
 if(!near_edge || lx<2||lx>477||ly<2||ly>537)begin
 missing<=missing+1'b1;run<=run+1'b1;if(run+1>maxrun)maxrun<=run+1'b1;
 if(clampx(lx-2)<badx0)badx0<=clampx(lx-2);if(clampx(lx+2)>badx1)badx1<=clampx(lx+2);
 if(clampy(ly-2)<bady0)bady0<=clampy(ly-2);if(clampy(ly+2)>bady1)bady1<=clampy(ly+2);
 end else run<=0;
 if(lx==lendx&&ly==lendy)state<=LINE_END;
 else begin
 if(e2>-$signed(ady))lx<=lx+stepx;
 if(e2<$signed(adx))ly<=ly+stepy;
 if(e2>-$signed(ady)&&e2<$signed(adx))err<=err-ady+adx;
 else if(e2>-$signed(ady))err<=err-ady;else if(e2<$signed(adx))err<=err+adx;
 n<=0;near_edge<=0;state<=REQ;
 end
 end
 LINE_END:begin
 if(align_probe)begin
 if(align_better)begin
 align_best<=align_shift;align_best_tilt<=align_tilt;align_best_missing<=missing;
 end
 if(!align_tilt_phase && align_shift==3)align_center<=chosen_shift;
 // Stage A: latch the next candidate. The scheduler no longer drives the
 // endpoint coordinates in this same cycle.
 align_pending_probe<=next_probe;
 align_pending_tilt_phase<=next_tilt_phase;
 align_pending_shift<=next_shift;
 align_pending_tilt<=next_tilt;
 state<=ALIGN_LATCH;
 end else begin
 if(spatial_line_bad)edge_causes[0]<=1;
 if(rough_line_bad)edge_causes[1]<=1;
 if(hold_line_bad)edge_causes[2]<=1;
 if(is_slope)begin
 slope_hist[slope_idx]<={slope_hist[slope_idx][1:0],raw_line_bad};
 if(raw_line_bad)begin
 slope_clean[slope_idx]<=0;
 if(|slope_hist[slope_idx])slope_hold[slope_idx]<=1;
 end else if(slope_hold[slope_idx])begin
 if(slope_clean[slope_idx]>=SLOPE_CLEAR_RESULTS-1)begin
 slope_hold[slope_idx]<=0;slope_clean[slope_idx]<=0;
 end else slope_clean[slope_idx]<=slope_clean[slope_idx]+1'b1;
 end
 end
 if(spatial_line_bad)begin
 fault[3]<=1;valid_w[side+6]<=1;
 x0w[(side+6)*12 +:12]<=badx0;x1w[(side+6)*12 +:12]<=badx1;
 y0w[(side+6)*12 +:12]<=bady0;y1w[(side+6)*12 +:12]<=bady1;
 end else if(rough_line_bad || hold_line_bad)begin
 // The current map may have no missing samples. Mark the current segment,
 // never reuse stale image coordinates or the invalid empty bad-point box.
 fault[3]<=1;valid_w[side+6]<=1;
 x0w[(side+6)*12 +:12]<=clampx((line_start_x<lendx?line_start_x:lendx)-2);
 x1w[(side+6)*12 +:12]<=clampx((line_start_x>lendx?line_start_x:lendx)+2);
 y0w[(side+6)*12 +:12]<=clampy((line_start_y<lendy?line_start_y:lendy)-2);
 y1w[(side+6)*12 +:12]<=clampy((line_start_y>lendy?line_start_y:lendy)+2);
 end
 if(side==5)state<=PUBLISH;else begin side<=side+1'b1;state<=LINE;end
 end
 end

 ALIGN_LATCH:begin
 // Stage B: commit the registered alignment candidate.
 align_probe<=align_pending_probe;
 align_tilt_phase<=align_pending_tilt_phase;
 align_shift<=align_pending_shift;
 align_tilt<=align_pending_tilt;
 state<=ALIGN_ENDPOINT;
 end

 ALIGN_ENDPOINT:begin
 // Stage C: generate endpoints from registered shift/tilt values.
 // Geometry is identical to the original LINE_END equations.
 if(align_x_axis)begin
 lx<=nominal_x0+align_pending_shift-align_pending_tilt;
 lendx<=nominal_x1+align_pending_shift+align_pending_tilt;
 ly<=nominal_y0;lendy<=nominal_y1;
 end else begin
 lx<=nominal_x0;lendx<=nominal_x1;
 ly<=nominal_y0+align_pending_shift-align_pending_tilt;
 lendy<=nominal_y1+align_pending_shift+align_pending_tilt;
 end
 state<=SETUP;
 end

 PUBLISH:begin
 consumed_mask<=best_hits>=4 ? (best_used | owned_mask) : 16'd0;
 if(best_hits>=4)begin
 ctx_valid[result_slot]<=1;
 ctx_ox[result_slot]<=prev_ox;ctx_oy[result_slot]<=prev_oy;
 ctx_ax[result_slot]<=prev_ax;ctx_ay[result_slot]<=prev_ay;
 ctx_hold[result_slot]<=slope_hold;
 ctx_hist0[result_slot]<=slope_hist[0];ctx_hist1[result_slot]<=slope_hist[1];
 ctx_clean0[result_slot]<=slope_clean[0];ctx_clean1[result_slot]<=slope_clean[1];
 end
 detected<=best_hits>=4;passed<=best_hits>=4&&fault==0&&!source_error;
 // In mode2, D0/F1 = <4 circular candidates, D0/F2 = layout not matched,
 // D0/F8 = frontend error. With a matched target, retain mode1 edge bits.
 fault_code<=(DEBUG_EDGE_CAUSE==2 && best_hits<4) ?
              (source_error?4'h8:(hole_count<4?4'h1:4'h2)) :
              (DEBUG_EDGE_CAUSE?{fault[3],edge_causes}:fault);result_hole_count<={2'b00,best_hits}; // matched holes for THIS target
 box_valid<=valid_w;
 box_xmin<=x0w;box_xmax<=x1w;box_ymin<=y0w;box_ymax<=y1w;
 box_xmin[11:0]<=allx0>966?allx0-6:960;box_xmax[11:0]<=allx1<1913?allx1+6:1919;
 box_ymin[11:0]<=ally0>6?ally0-6:0;box_ymax[11:0]<=ally1<1073?ally1+6:1079;
 done<=1;result_toggle<=~result_toggle;state<=IDLE;
 end
 default:state<=IDLE;
 endcase
 end
 end
endmodule
