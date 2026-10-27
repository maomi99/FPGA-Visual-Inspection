// UI clock domain only. Events are one UI-clock pulse.
// Live: four original 4MiB banks. Archive: 100 x 2MiB from 16MiB.
// Frame ownership changes ONLY at original writer/read-frame boundaries.
module replay100_scheduler #(
 parameter integer RECORD_FRAMES=100,
 parameter integer PLAY_HOLD_FRAMES=6
)(
 input wire clk,reset,write_done,read_boundary,
 input wire key1_short,key1_long,key2_short,key2_long,
 output wire [31:0] write_base,read_base,
 output reg frame_ready,
 output reg [2:0] mode, // 0 LIVE,1 ARM,2 REC,3 PAUSE,4 PLAY
 output reg [6:0] recorded_count,
 output reg [6:0] displayed_number,
 output wire replay_active,
 output wire ae_allow
);
 // synthesis translate_off
 initial begin
  if(RECORD_FRAMES<1||RECORD_FRAMES>100) begin
   $display("ERROR: RECORD_FRAMES must be 1..100");$finish;
  end
  if(PLAY_HOLD_FRAMES<1||PLAY_HOLD_FRAMES>65535) begin
   $display("ERROR: PLAY_HOLD_FRAMES must be 1..65535");$finish;
  end
 end
 // synthesis translate_on
 localparam [2:0] LIVE=0,ARM=1,REC=2,PAUSE=3,PLAY=4;
 reg [6:0] wr_slot,rd_slot,latest_slot;
 reg latest_valid;
 reg [6:0] selected;
 reg [15:0] hold_count;
 reg [6:0] nw,nr,nlatest,ncount,nselected,nnumber;
 reg [2:0] nm;
 reg nv,nready;
 reg [15:0] nhold;
 reg [1:0] live_candidate;
 integer k;
 function [31:0] slot_address;
 input [6:0] s;
 begin
  if(s<4) slot_address={8'd0,s[1:0],22'd0};
  else slot_address={4'd0,s,21'd0};
 end
 endfunction
 assign write_base=slot_address(wr_slot);
 assign read_base=slot_address(rd_slot);
 assign replay_active=(rd_slot>=8)&&frame_ready&&(mode==PAUSE||mode==PLAY);
 // Disable AE also during ARM/REC: the stored RAW stream is replayed through
 // the ISP; locking AE for this short clip makes exposure reproducible.
 assign ae_allow=(mode==LIVE)&&(rd_slot<4)&&frame_ready;
 always @* begin
  nw=wr_slot;nr=rd_slot;nlatest=latest_slot;nv=latest_valid;
  nm=mode;ncount=recorded_count;nselected=selected;
  nhold=hold_count;nnumber=displayed_number;nready=frame_ready;
  live_candidate=0;
  // Start only when a live image exists. ARM discards the partly acquired
  // current frame, then redirects the NEXT complete camera frame to slot 8.
  case(mode)
   LIVE: if(key1_short&&frame_ready) begin nm=ARM;ncount=0;nselected=0;nhold=0;end
   ARM: if(key1_long) nm=LIVE;
   REC: begin end // no abort in the middle of an archive frame
   PAUSE,PLAY: begin
    if(key1_long) begin nm=LIVE;nhold=0;end
    else if(key2_short||key2_long) begin
     nm=PAUSE;nhold=0;
     if(key2_long) nselected=(selected==0)?RECORD_FRAMES-1:selected-1'b1;
     else nselected=(selected==RECORD_FRAMES-1)?0:selected+1'b1;
    end else if(key1_short) begin
     nm=(mode==PLAY)?PAUSE:PLAY;nhold=0;
    end
   end
   default: nm=LIVE;
  endcase
  if(write_done) begin
   nlatest=wr_slot;nv=1;
   if(mode==ARM && nm==ARM && rd_slot<4) begin
    nw=8;nm=REC;ncount=0;
   end else if(mode==REC) begin
    ncount=recorded_count+1'b1;
    if(recorded_count==RECORD_FRAMES-1) begin
     nm=PAUSE;nselected=0;nhold=0;
    end else nw=wr_slot+1'b1;
   end
  end
  // Playback speed counts display boundaries (60Hz / 6 = 10fps).
  // Use next mode/selection so a key event at a boundary takes effect once.
  if(read_boundary) begin
   if(nm==PAUSE||nm==PLAY) begin
    if(nm==PLAY && mode==PLAY && !key1_short && !key2_short && !key2_long) begin
     if(hold_count>=PLAY_HOLD_FRAMES-1) begin
      nselected=(nselected==RECORD_FRAMES-1)?0:nselected+1'b1;nhold=0;
     end else nhold=hold_count+1'b1;
    end
    nr=7'd8+nselected;nready=1;nnumber=nselected+1'b1;
   end else if(nv) begin
    nr=nlatest;nready=1;nnumber=0;
   end
  end
  // Outside archive capture, choose a live bank that is neither being
  // displayed nor the latest completed live bank. There are always >=2 free.
  if(write_done && !(mode==ARM&&nm==REC) &&
     !(mode==REC && recorded_count<RECORD_FRAMES-1)) begin
   live_candidate=wr_slot[1:0]+2'd1;
   for(k=0;k<2;k=k+1)
    if({5'd0,live_candidate}==nr || {5'd0,live_candidate}==nlatest)
     live_candidate=live_candidate+2'd1;
   nw={5'd0,live_candidate};
  end
  // Number describes the actually selected DDR bank, even if REC->PAUSE
  // occurred between display boundaries and frame 1 has not been selected yet.
  nnumber=(nr>=8)?nr-7'd7:0;
 end
 always @(posedge clk) begin
  if(reset) begin
   wr_slot<=0;rd_slot<=2;latest_slot<=0;latest_valid<=0;
   frame_ready<=0;mode<=LIVE;recorded_count<=0;
   selected<=0;hold_count<=0;displayed_number<=0;
  end else begin
   wr_slot<=nw;rd_slot<=nr;latest_slot<=nlatest;latest_valid<=nv;
   frame_ready<=nready;mode<=nm;recorded_count<=ncount;
   selected<=nselected;hold_count<=nhold;displayed_number<=nnumber;
  end
 end
endmodule
