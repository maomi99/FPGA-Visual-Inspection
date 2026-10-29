// Serial overlays: two clocks per slot, FOUR clocks total on VS/HS/DE/RGB.
// Both slot metadata banks are published atomically by the dual controller.
module plate_geometry_overlay_dual (
 input wire clk,rst_n,show_enable,
 input wire in_vsync,in_hsync,in_de,input wire[7:0]in_r,in_g,in_b,
 input wire[1:0]detected,passed,input wire result_toggle,
 input wire[7:0]raw_fault,input wire[9:0]hole_count,
 input wire[23:0]box_valid,input wire[287:0]box_xmin,box_xmax,box_ymin,box_ymax,
 output wire out_vsync,out_hsync,out_de,output wire[7:0]out_r,out_g,out_b
);
 wire mid_vs,mid_hs,mid_de;
 wire[7:0]mid_r,mid_g,mid_b;
 // Delay result/control buses by the same two clocks as the first video stage.
 // Thus both overlays latch the SAME completed batch on the SAME source VSYNC.
 reg show_d1,show_d2,toggle_d1,toggle_d2;
 reg[1:0]det_d1,det_d2,pass_d1,pass_d2;
 reg[7:0]fault_d1,fault_d2;
 reg[9:0]holes_d1,holes_d2;
 reg[23:0]valid_d1,valid_d2;
 reg[287:0]x0_d1,x0_d2,x1_d1,x1_d2,y0_d1,y0_d2,y1_d1,y1_d2;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   show_d1<=0;show_d2<=0;toggle_d1<=0;toggle_d2<=0;
   det_d1<=0;det_d2<=0;pass_d1<=0;pass_d2<=0;
   fault_d1<=0;fault_d2<=0;holes_d1<=0;holes_d2<=0;valid_d1<=0;valid_d2<=0;
   x0_d1<=0;x0_d2<=0;x1_d1<=0;x1_d2<=0;y0_d1<=0;y0_d2<=0;y1_d1<=0;y1_d2<=0;
  end else begin
   show_d1<=show_enable;show_d2<=show_d1;toggle_d1<=result_toggle;toggle_d2<=toggle_d1;
   det_d1<=detected;det_d2<=det_d1;pass_d1<=passed;pass_d2<=pass_d1;
   fault_d1<=raw_fault;fault_d2<=fault_d1;holes_d1<=hole_count;holes_d2<=holes_d1;
   valid_d1<=box_valid;valid_d2<=valid_d1;
   x0_d1<=box_xmin;x0_d2<=x0_d1;x1_d1<=box_xmax;x1_d2<=x1_d1;
   y0_d1<=box_ymin;y0_d2<=y0_d1;y1_d1<=box_ymax;y1_d2<=y1_d1;
  end
 end
 plate_geometry_overlay_slot #(.OSD_X(980)) u_slot0 (
  .clk(clk),.rst_n(rst_n),.show_enable(show_enable),
  .in_vsync(in_vsync),.in_hsync(in_hsync),.in_de(in_de),.in_r(in_r),.in_g(in_g),.in_b(in_b),
  .detected(detected[0]),.passed(passed[0]),.result_toggle(result_toggle),
  .raw_fault(raw_fault[3:0]),.hole_count(hole_count[4:0]),
  .box_valid(box_valid[11:0]),.box_xmin(box_xmin[143:0]),.box_xmax(box_xmax[143:0]),
  .box_ymin(box_ymin[143:0]),.box_ymax(box_ymax[143:0]),
  .out_vsync(mid_vs),.out_hsync(mid_hs),.out_de(mid_de),.out_r(mid_r),.out_g(mid_g),.out_b(mid_b)
 );
 plate_geometry_overlay_slot #(.OSD_X(1100)) u_slot1 (
  .clk(clk),.rst_n(rst_n),.show_enable(show_d2),
  .in_vsync(mid_vs),.in_hsync(mid_hs),.in_de(mid_de),.in_r(mid_r),.in_g(mid_g),.in_b(mid_b),
  .detected(det_d2[1]),.passed(pass_d2[1]),.result_toggle(toggle_d2),
  .raw_fault(fault_d2[7:4]),.hole_count(holes_d2[9:5]),
  .box_valid(valid_d2[23:12]),.box_xmin(x0_d2[287:144]),.box_xmax(x1_d2[287:144]),
  .box_ymin(y0_d2[287:144]),.box_ymax(y1_d2[287:144]),
  .out_vsync(out_vsync),.out_hsync(out_hsync),.out_de(out_de),.out_r(out_r),.out_g(out_g),.out_b(out_b)
 );
endmodule
