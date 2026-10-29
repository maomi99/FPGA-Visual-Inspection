// Two detections from ONE immutable feature/map snapshot, ONE arithmetic core.
// Fixed MAX_HOLES=16: the verified core uses sentinel index 16 and 16-bit masks.
module plate_geometry_check_dual #(
 parameter integer POSITION_TOL_MM=3, MIN_MISS_RUN=4, MAX_MISSING_PERCENT=8,
 parameter integer AFFINE_LIMIT_PERCENT=10
)(
 input wire clk,rst_n,start,source_error,
 input wire [4:0] hole_count,
 input wire [175:0] hole_x,hole_y,
 input wire [127:0] hole_diameter,
 output reg done, output wire [17:0] map_addr, input wire map_bit,
 output reg [1:0] detected,passed,
 output reg result_toggle,
 output reg [7:0] fault_code,
 output reg [9:0] result_hole_count,
 output reg [23:0] box_valid,
 output reg [287:0] box_xmin,box_xmax,box_ymin,box_ymax,
 output wire busy
);
 localparam IDLE=0,LAUNCH=1,WAIT_CORE=2,COMMIT=3;
 reg [1:0] state;
 reg pass_index,core_start,error_q;
 reg [4:0] count_q;
 reg [175:0] x_q,y_q;
 reg [127:0] diameter_q;
 reg [15:0] excluded;
 reg [1:0] reserved,clear_q;
 reg [1:0] d_pending,p_pending;
 reg [7:0] f_pending;
 reg [9:0] h_pending;
 reg [23:0] v_pending;
 reg [287:0] x0_pending,x1_pending,y0_pending,y1_pending;
 wire core_done,core_detected,core_passed,core_slot,unused_toggle;
 wire [15:0] consumed;
 wire [3:0] core_fault;
 wire [4:0] core_holes;
 wire [11:0] core_valid;
 wire [143:0] core_x0,core_x1,core_y0,core_y1;
 assign busy=(state!=IDLE);
 plate_geometry_check_dual_core #(
  .POSITION_TOL_MM(POSITION_TOL_MM),.MIN_MISS_RUN(MIN_MISS_RUN),
  .MAX_MISSING_PERCENT(MAX_MISSING_PERCENT),.AFFINE_LIMIT_PERCENT(AFFINE_LIMIT_PERCENT)
 ) u_core (
  .clk(clk),.rst_n(rst_n),.start(core_start),.source_error(error_q),
  .exclude_mask(excluded),.reserved_slots(reserved),.clear_history(clear_q),
  .result_slot(core_slot),.consumed_mask(consumed),
  .hole_count(count_q),.hole_x(x_q),.hole_y(y_q),.hole_diameter(diameter_q),
  .done(core_done),.map_addr(map_addr),.map_bit(map_bit),
  .detected(core_detected),.passed(core_passed),.result_toggle(unused_toggle),
  .fault_code(core_fault),.result_hole_count(core_holes),
  .box_valid(core_valid),.box_xmin(core_x0),.box_xmax(core_x1),
  .box_ymin(core_y0),.box_ymax(core_y1)
 );
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;done<=0;core_start<=0;error_q<=0;count_q<=0;
   x_q<=0;y_q<=0;diameter_q<=0;excluded<=0;reserved<=0;clear_q<=0;pass_index<=0;
   d_pending<=0;p_pending<=0;f_pending<=0;h_pending<=0;v_pending<=0;
   x0_pending<=0;x1_pending<=0;y0_pending<=0;y1_pending<=0;
   detected<=0;passed<=0;result_toggle<=0;fault_code<=0;result_hole_count<=0;
   box_valid<=0;box_xmin<=0;box_xmax<=0;box_ymin<=0;box_ymax<=0;
  end else begin
   done<=0;core_start<=0;
   case(state)
    IDLE:if(start)begin
     count_q<=hole_count;x_q<=hole_x;y_q<=hole_y;diameter_q<=hole_diameter;
     error_q<=source_error;excluded<=0;reserved<=0;clear_q<=~detected;pass_index<=0;
     d_pending<=0;p_pending<=0;v_pending<=0;f_pending<=0;h_pending<=0;
     x0_pending<=0;x1_pending<=0;y0_pending<=0;y1_pending<=0;
     state<=LAUNCH;
    end
    LAUNCH:begin core_start<=1;state<=WAIT_CORE;end
    WAIT_CORE:if(core_done)begin
     if(core_detected)begin
      d_pending[core_slot]<=1;p_pending[core_slot]<=core_passed;
      f_pending[core_slot*4 +:4]<=core_fault;
      h_pending[core_slot*5 +:5]<=core_holes;
      v_pending[core_slot*12 +:12]<=core_valid;
      x0_pending[core_slot*144 +:144]<=core_x0;
      x1_pending[core_slot*144 +:144]<=core_x1;
      y0_pending[core_slot*144 +:144]<=core_y0;
      y1_pending[core_slot*144 +:144]<=core_y1;
     end
     // Keep the frontend bank locked until BOTH checks have finished.
     if(!pass_index && core_detected)begin
      excluded<=excluded|consumed;reserved[core_slot]<=1;
      clear_q<=0;pass_index<=1;state<=LAUNCH;
     end else begin
      if(!core_detected && !pass_index)begin
       f_pending<={core_fault,core_fault};h_pending<={core_holes,core_holes};
      end
      state<=COMMIT;
     end
    end
    COMMIT:begin
     detected<=d_pending;passed<=p_pending;fault_code<=f_pending;
     result_hole_count<=h_pending;box_valid<=v_pending;
     box_xmin<=x0_pending;box_xmax<=x1_pending;
     box_ymin<=y0_pending;box_ymax<=y1_pending;
     result_toggle<=~result_toggle;done<=1;state<=IDLE;
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
