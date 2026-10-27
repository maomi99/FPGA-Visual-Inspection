// Timing-closure revision: radial point test and final circle-fit comparison pipelined.
// Recognition thresholds/formulas are unchanged; only analysis latency is increased.
// Entire right half, 1920x1080. 2x2 OR -> 480x540 edge map.
// No learned template. Connected edge components -> circular contour descriptors.
// Client owns read-only map port after features_ready until client_done.
module plate_edge_features #(
 parameter integer MAX_HOLES=16, MIN_DIAM=6, MAX_DIAM=80,
 parameter integer MIN_POINTS=16, CIRCLE_PERCENT=75,
 parameter integer QUEUE_AW=11, POINT_AW=11,
 parameter integer WATCHDOG_CYCLES=12000000
)(
 input wire clk,rst_n,enable,in_vsync,in_de,input wire[7:0]in_edge,
 output reg features_ready,output reg[4:0]hole_count,
 output reg[MAX_HOLES*11-1:0]hole_x,hole_y,
 output reg[MAX_HOLES*8-1:0]hole_diameter,
 input wire client_done,input wire[17:0]client_addr,output wire client_bit,
 output wire busy,output reg analysis_error,output reg[15:0]skipped_frames
);
 localparam integer DEPTH=259200,QD=1<<QUEUE_AW,PD=1<<POINT_AW;
 // Timing-closure states: the radial point test is split into registered
 // coordinate, distance and compare stages.  CD_CALC also registers the final
 // circle-fit products so no multiplier feeds the publish decision directly.
 localparam IDLE=0,CLEAR=1,SA=2,SW=3,ST=4,NEXT=5,QA=6,QW=7,QP=8,
 NA=9,NW=10,NT=11,NN=12,CE=13,PA=14,PW=15,PT=16,CD=17,READY=18,CLIENT=19,
 PT_COORD=20,PT_DIST=21,PT_CHECK=22,CD_CALC=23;
 reg[4:0]state;
 assign busy=state!=IDLE;
 reg[0:0]bank0[0:DEPTH-1],bank1[0:DEPTH-1],visited[0:DEPTH-1];
 reg[0:0]q0,q1,vq;
 reg wb,rb,vs_d,de_d,seen;
 reg[11:0]x,y;
 reg[479:0]row_or;
 reg[18:0]written;
 wire sof=in_vsync&&!vs_d;
 wire active=in_de&&x>=960&&x<1920&&y<1080;
 wire[8:0]col=active ? ((x-960)>>1):0;
 wire[17:0]cap_addr=(y>>1)*480+col;
 wire cap_we=rst_n&&enable&&seen&&!sof&&active&&x[0]&&y[0];
 wire cap_bit=row_or[col]||(in_edge!=0);
 reg[17:0]maddr,clear_addr,visit_addr;
 reg visit_we;
 wire[17:0]read_addr=state==CLIENT ? client_addr:maddr;
 wire mb=rb?q1[0]:q0[0];assign client_bit=mb;
 wire vw=rst_n&&(state==CLEAR||visit_we);
 wire[17:0]va=state==CLEAR?clear_addr:visit_addr;
 wire vd=state!=CLEAR;
 always @(posedge clk) begin if(cap_we&&!wb)bank0[cap_addr]<=cap_bit;q0<=bank0[read_addr];end
 always @(posedge clk) begin if(cap_we&&wb)bank1[cap_addr]<=cap_bit;q1<=bank1[read_addr];end
 always @(posedge clk) begin if(vw)visited[va]<=vd;vq<=visited[maddr];end
 reg[18:0]queue_mem[0:QD-1],point_mem[0:PD-1];
 reg[18:0]qq,pq,qdata,pdata;
 reg[QUEUE_AW-1:0]head,tail,qwa;
 reg[POINT_AW-1:0]pra,pwa;
 reg qwe,pwe;
 reg[QUEUE_AW:0]qcount;
 always @(posedge clk)begin if(qwe)queue_mem[qwa]<=qdata;qq<=queue_mem[head];end
 always @(posedge clk)begin if(pwe)point_mem[pwa]<=pdata;pq<=point_mem[pra];end
 reg[17:0]scan_addr,naddr;
 reg[8:0]sx,px,minx,maxx,nx;
 reg[9:0]sy,py,miny,maxy,ny;
 reg[18:0]count;
 reg[15:0]pi,inliers;
 reg[2:0]neighbor;
 reg touch;
 reg[7:0]sectors;
 reg[10:0]cx2,cy2;
 reg[22:0]rad2;
 // Registered radial-analysis pipeline.  These registers deliberately break
 // point_mem -> subtract -> DSP square/add -> comparator -> inliers.
 reg signed[12:0] pt_dx_q,pt_dy_q;
 reg[2:0] pt_sector_q;
 reg[25:0] pt_d2_q;
 reg[25:0] pt_r3_q;
 reg[31:0] circle_lhs_q,circle_rhs_q;
 reg circle_sectors_ok_q;
 reg[23:0]watchdog;
 reg signed[11:0]tx,ty;
 always @*begin
 tx=$signed({3'b0,px});ty=$signed({2'b0,py});
 case(neighbor)
 0:begin tx=tx-1;ty=ty-1;end 1:ty=ty-1;2:begin tx=tx+1;ty=ty-1;end
 3:tx=tx-1;4:tx=tx+1;5:begin tx=tx-1;ty=ty+1;end 6:ty=ty+1;7:begin tx=tx+1;ty=ty+1;end
 endcase
 end
 wire nok=tx>=0&&tx<480&&ty>=0&&ty<540;
 wire[10:0]spanx={2'b0,maxx}-{2'b0,minx},spany={1'b0,maxy}-{1'b0,miny};
 wire[22:0]bbox2=spanx*spanx+spany*spany;
 // Radial point calculations below are intentionally derived from registered
 // pt_dx_q/pt_dy_q rather than directly from point RAM output pq.
 wire[25:0] pt_d2_w=pt_dx_q*pt_dx_q+pt_dy_q*pt_dy_q;
 wire[12:0] pt_adx_w=pt_dx_q[12]?-pt_dx_q:pt_dx_q;
 wire[12:0] pt_ady_w=pt_dy_q[12]?-pt_dy_q:pt_dy_q;
 wire[2:0] pt_sector_w={pt_dy_q[12],pt_dx_q[12],pt_adx_w>pt_ady_w};
 // Wide radial band accepts multi-pixel Sobel contours; layout/outline checks follow.
 always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
 state<=IDLE;wb<=0;rb<=1;x<=0;y<=0;vs_d<=0;de_d<=0;seen<=0;row_or<=0;written<=0;
 features_ready<=0;hole_count<=0;hole_x<=0;hole_y<=0;hole_diameter<=0;
 analysis_error<=0;skipped_frames<=0;watchdog<=0;maddr<=0;clear_addr<=0;visit_addr<=0;visit_we<=0;
 head<=0;tail<=0;qwa<=0;pra<=0;pwa<=0;qwe<=0;pwe<=0;qcount<=0;qdata<=0;pdata<=0;
 scan_addr<=0;naddr<=0;sx<=0;sy<=0;px<=0;py<=0;minx<=0;maxx<=0;miny<=0;maxy<=0;nx<=0;ny<=0;
 count<=0;pi<=0;inliers<=0;neighbor<=0;touch<=0;sectors<=0;cx2<=0;cy2<=0;rad2<=0;
 pt_dx_q<=0;pt_dy_q<=0;pt_sector_q<=0;pt_d2_q<=0;pt_r3_q<=0;
 circle_lhs_q<=0;circle_rhs_q<=0;circle_sectors_ok_q<=0;
 end else begin
 vs_d<=in_vsync;de_d<=in_de;visit_we<=0;qwe<=0;pwe<=0;features_ready<=0;
 if(sof)begin
 x<=0;y<=0;seen<=1;row_or<=0;written<=0;
 if(enable&&seen&&written==DEPTH)begin
 if(state==IDLE)begin rb<=wb;wb<=~wb;clear_addr<=0;hole_count<=0;analysis_error<=0;watchdog<=0;state<=CLEAR;end
 else skipped_frames<=skipped_frames+1'b1;
 end
 end else if(in_de)begin
 x<=x+1'b1;
 if(enable&&active)begin row_or[col]<=row_or[col]||(in_edge!=0);if(x[0]&&y[0])row_or[col]<=0;end
 end else if(de_d)begin x<=0;y<=y+1'b1;end
 if(cap_we)written<=written+1'b1;
 if(state!=IDLE&&state!=CLIENT)watchdog<=watchdog+1'b1;
 case(state)
 IDLE:begin end
 CLEAR:if(clear_addr==DEPTH-1)begin scan_addr<=0;sx<=0;sy<=0;state<=SA;end else clear_addr<=clear_addr+1'b1;
 SA:begin maddr<=scan_addr;state<=SW;end
 SW:state<=ST;
 ST:if(mb&&!vq[0])begin
 visit_we<=1;visit_addr<=scan_addr;head<=0;tail<=1;qcount<=1;qwa<=0;qdata<={sy,sx};qwe<=1;
 count<=0;minx<=479;maxx<=0;miny<=539;maxy<=0;touch<=0;state<=QA;
 end else state<=NEXT;
 NEXT:if(scan_addr==DEPTH-1)state<=READY;else begin
 scan_addr<=scan_addr+1'b1;if(sx==479)begin sx<=0;sy<=sy+1'b1;end else sx<=sx+1'b1;state<=SA;end
 QA:state<=QW;
 QW:state<=QP;
 QP:if(qcount==0)state<=CE;else begin
 px<=qq[8:0];py<=qq[18:9];head<=head+1'b1;qcount<=qcount-1'b1;neighbor<=0;
 if(count<PD)begin pwa<=count[POINT_AW-1:0];pdata<=qq;pwe<=1;end
 count<=count+1'b1;
 if(qq[8:0]<minx)minx<=qq[8:0];if(qq[8:0]>maxx)maxx<=qq[8:0];
 if(qq[18:9]<miny)miny<=qq[18:9];if(qq[18:9]>maxy)maxy<=qq[18:9];
 if(qq[8:0]==0||qq[8:0]==479||qq[18:9]==0||qq[18:9]==539)touch<=1;
 state<=NA;end
 NA:if(nok)begin nx<=tx[8:0];ny<=ty[9:0];naddr<=ty*480+tx;maddr<=ty*480+tx;state<=NW;end else state<=NN;
 NW:state<=NT;
 NT:if(mb&&!vq[0])begin
 if(qcount==QD)begin analysis_error<=1;state<=READY;end
 else begin visit_we<=1;visit_addr<=naddr;qwa<=tail;qdata<={ny,nx};qwe<=1;tail<=tail+1'b1;qcount<=qcount+1'b1;state<=NN;end
 end else state<=NN;
 NN:if(neighbor==7)state<=QA;else begin neighbor<=neighbor+1'b1;state<=NA;end
 CE:if(count<MIN_POINTS||count>PD||spanx<MIN_DIAM||spany<MIN_DIAM||spanx>MAX_DIAM||spany>MAX_DIAM||
 spanx*4>spany*5||spany*4>spanx*5||touch)state<=NEXT;
 else begin cx2<={2'b0,minx}+maxx;cy2<={1'b0,miny}+maxy;rad2<=bbox2>>1;pi<=0;inliers<=0;sectors<=0;state<=PA;end
 PA:begin pra<=pi[POINT_AW-1:0];state<=PW;end
 // point_mem is synchronous: PW lets pq receive the addressed point.
 PW:state<=PT_COORD;
 // Stage 1: only center subtraction from the RAM output.
 PT_COORD:begin
 pt_dx_q<=$signed({3'b0,pq[8:0],1'b0})-$signed({2'b0,cx2});
 pt_dy_q<=$signed({2'b0,pq[18:9],1'b0})-$signed({2'b0,cy2});
 state<=PT_DIST;
 end
 // Stage 2: DSP square/add and octant classification are registered.
 PT_DIST:begin
 pt_d2_q<=pt_d2_w;
 pt_sector_q<=pt_sector_w;
 pt_r3_q<=rad2*3;
 state<=PT_CHECK;
 end
 // Stage 3: only the radial-band comparison and counter updates remain.
 PT_CHECK:begin
 sectors[pt_sector_q]<=1'b1;
 if(({pt_d2_q,1'b0}>=rad2) && ({pt_d2_q,1'b0}<=pt_r3_q))
   inliers<=inliers+1'b1;
 if(pi==count-1)state<=CD_CALC;
 else begin pi<=pi+1'b1;state<=PA;end
 end
 // Register the final fit products.  This keeps the multiply-by-constant
 // operations out of the same cycle as hole output writes/state control.
 CD_CALC:begin
 circle_sectors_ok_q<=(sectors==8'hff);
 circle_lhs_q<=inliers*32'd100;
 circle_rhs_q<=count*CIRCLE_PERCENT;
 state<=CD;
 end
 CD:begin
 if(circle_sectors_ok_q&&circle_lhs_q>=circle_rhs_q)begin
 if(hole_count==MAX_HOLES)analysis_error<=1;
 else begin hole_x[hole_count*11 +:11]<=cx2;hole_y[hole_count*11 +:11]<=cy2;
 hole_diameter[hole_count*8 +:8]<=spanx+spany;hole_count<=hole_count+1'b1;end
 end
 state<=NEXT;end
 READY:begin features_ready<=1;state<=CLIENT;end
 CLIENT:if(client_done)state<=IDLE;
 default:state<=IDLE;
 endcase
 if(state!=IDLE&&state!=CLIENT&&state!=READY&&watchdog>=WATCHDOG_CYCLES)begin analysis_error<=1;state<=READY;end
 end
 end
endmodule
