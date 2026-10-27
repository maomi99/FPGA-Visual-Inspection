`timescale 1ns/1ps

//`include "ddr3_controller.vh"


module example_top 
(
	////////////////////////////////////////////////////////////////
	//	External Clock & Reset
	//input 			nrst, 			//	Button K2
	input 			clk_24m,			//	24MHz Crystal
	input 			clk_25m,			//	25MHz Crystal 
	
	
	////////////////////////////////////////////////////////////////
	//	System Clock
	output 			sys_pll_rstn_o, 		
	
	input 			clk_sys,			//	Sys PLL 96MHz 
	input 			clk_pixel,			//	Sys PLL 74.25MHz
	input 			clk_pixel_2x,		//	Sys PLL 148.5MHz
	input 			clk_pixel_10x,		//	Sys PLL 742.5MHz
	
	input 			sys_pll_lock,		//	Sys PLL Lock
	
	////////////////////////////////////////////////////////////////
	//	MIPI-DSI Clock & Reset
	output 			dsi_pll_rstn_o,
	
	input 			dsi_refclk_i,		//	48MHz Reference Clock (for DSI PLL)
	input 			dsi_byteclk_i,		//	DSI Byte Clock (1X)
	input 			dsi_serclk_i,		//	DSI Serial Clock (4X 45)
	input 			dsi_txcclk_i,		//	DSI Serial Clock (4X 135)
	
	input 			dsi_pll_lock,
	
	////////////////////////////////////////////////////////////////
	//	DDR Clock
	output 			ddr_pll_rstn_o, 
	
	input 			tdqss_clk,			
	input 			core_clk,			//	DDR PLL 200MHz
	input 			tac_clk,			
	input 			twd_clk,			
	
	input 			ddr_pll_lock,		//	DDR PLL Lock
	
	////////////////////////////////////////////////////////////////
	//	DDR PLL Phase Shift Interface
	output 	[2:0] 	shift,
	output 	[4:0] 	shift_sel,
	output 			shift_ena,
	
	
	
	////////////////////////////////////////////////////////////////
	//	LVDS Clock
	output 			lvds_pll_rstn_o, 
	
	input 			clk_lvds_1x, 
	input 			clk_lvds_7x, 
	input 			clk_27m, 			//	RGB 1X Clock (16MHz)
	input 			clk_54m, 			//	RGB 2X Clock (32MHz, for export control)
	
	input 			lvds_pll_lock, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	DDR Interface Ports
	output 	[15:0] 	addr,
	output 	[2:0] 	ba,
	output 			we,
	output 			reset,
	output 			ras,
	output 			cas,
	output 			odt,
	output 			cke,
	output 			cs,
	
	//	DQ I/O
	input 	[15:0] 	i_dq_hi,
	input 	[15:0] 	i_dq_lo,
	
	output 	[15:0] 	o_dq_hi,
	output 	[15:0] 	o_dq_lo,
	output 	[15:0] 	o_dq_oe,
	
	//	DM O
	output 	[1:0] 	o_dm_hi,
	output 	[1:0] 	o_dm_lo,
	
	//	DQS I/O
	input 	[1:0] 	i_dqs_hi,
	input 	[1:0] 	i_dqs_lo,
	
//	input 	[1:0] 	i_dqs_n_hi,
//	input 	[1:0] 	i_dqs_n_lo,
	
	output 	[1:0] 	o_dqs_hi,
	output 	[1:0] 	o_dqs_lo,
	
//	output 	[1:0] 	o_dqs_n_hi,
//	output 	[1:0] 	o_dqs_n_lo,
	
	output 	[1:0] 	o_dqs_oe,
	output 	[1:0] 	o_dqs_n_oe,
	
	//	CK
	output 			clk_p_hi, 
	output 			clk_p_lo, 
	output 			clk_n_hi, 
	output 			clk_n_lo, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	MIPI-CSI Ctl / I2C
	output 			csi_ctl0_o,
	output 			csi_ctl0_oe,
	input 			csi_ctl0_i,
	
	output 			csi_ctl1_o,
	output 			csi_ctl1_oe,
	input 			csi_ctl1_i,
	
	output 			csi_scl_o,
	output 			csi_scl_oe,
	input 			csi_scl_i,
	
	output 			csi_sda_o,
	output 			csi_sda_oe,
	input 			csi_sda_i,
	
	//	MIPI-CSI RXC 
	input 			csi_rxc_lp_p_i,
	input 			csi_rxc_lp_n_i,
	output 			csi_rxc_hs_en_o,
	output 			csi_rxc_hs_term_en_o,
	input 			csi_rxc_i,
	
	//	MIPI-CSI RXD0
	output 			csi_rxd0_rst_o,
	output 			csi_rxd0_hs_en_o,
	output 			csi_rxd0_hs_term_en_o,
	
	input 			csi_rxd0_lp_p_i,
	input 			csi_rxd0_lp_n_i,
	input 	[7:0] 	csi_rxd0_hs_i,
	
	//	MIPI-CSI RXD1
	output 			csi_rxd1_rst_o,
	output 			csi_rxd1_hs_en_o,
	output 			csi_rxd1_hs_term_en_o,
	
	input 			csi_rxd1_lp_n_i,
	input 			csi_rxd1_lp_p_i,
	input 	[7:0] 	csi_rxd1_hs_i,
	
	//	MIPI-CSI RXD2
	output 			csi_rxd2_rst_o,
	output 			csi_rxd2_hs_en_o,
	output 			csi_rxd2_hs_term_en_o,
	
	input 			csi_rxd2_lp_p_i,
	input 			csi_rxd2_lp_n_i,
	input 	[7:0] 	csi_rxd2_hs_i,
	
	//	MIPI-CSI RXD3
	output 			csi_rxd3_rst_o,
	output 			csi_rxd3_hs_en_o,
	output 			csi_rxd3_hs_term_en_o,
	
	input 			csi_rxd3_lp_p_i,
	input 			csi_rxd3_lp_n_i,
	input 	[7:0] 	csi_rxd3_hs_i,
	
	//output 			csi_rxd0_fifo_rd_o, 
	//input 			csi_rxd0_fifo_empty_i, 
	//output 			csi_rxd1_fifo_rd_o, 
	//input 			csi_rxd1_fifo_empty_i, 
	//output 			csi_rxd2_fifo_rd_o, 
	//input 			csi_rxd2_fifo_empty_i, 
	//output 			csi_rxd3_fifo_rd_o, 
	//input 			csi_rxd3_fifo_empty_i, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	DSI PWM & Reset Control 
	output 			dsi_pwm_o,			//	MIPI-DSI LCD PWM
	output 			dsi_resetn_o,		//	MIPI-DSI LCD Reset
	
	//	MIPI-DSI TXC / TXD
	output 			dsi_txc_rst_o,
	output 			dsi_txc_lp_p_oe,
	output 			dsi_txc_lp_p_o,
	output 			dsi_txc_lp_n_oe,
	output 			dsi_txc_lp_n_o,
	output 			dsi_txc_hs_oe,
	output 	[7:0] 	dsi_txc_hs_o,
	
	output 			dsi_txd0_rst_o,
	output 			dsi_txd0_hs_oe,
	output 	[7:0] 	dsi_txd0_hs_o,
	output 			dsi_txd0_lp_p_oe,
	output 			dsi_txd0_lp_p_o,
	output 			dsi_txd0_lp_n_oe,
	output 			dsi_txd0_lp_n_o,
	
	output 			dsi_txd1_rst_o,
	output 			dsi_txd1_lp_p_oe,
	output 			dsi_txd1_lp_p_o,
	output 			dsi_txd1_lp_n_oe,
	output 			dsi_txd1_lp_n_o,
	output 			dsi_txd1_hs_oe,
	output 	[7:0] 	dsi_txd1_hs_o,
	
	output 			dsi_txd2_rst_o,
	output 			dsi_txd2_lp_p_oe,
	output 			dsi_txd2_lp_p_o,
	output 			dsi_txd2_lp_n_oe,
	output 			dsi_txd2_lp_n_o,
	output 			dsi_txd2_hs_oe,
	output 	[7:0] 	dsi_txd2_hs_o,
	
	output 			dsi_txd3_rst_o,
	output 			dsi_txd3_lp_p_oe,
	output 			dsi_txd3_lp_p_o,
	output 			dsi_txd3_lp_n_oe,
	output 			dsi_txd3_lp_n_o,
	output 			dsi_txd3_hs_oe,
	output 	[7:0] 	dsi_txd3_hs_o,
	
	input 			dsi_txd0_lp_p_i,
	input 			dsi_txd0_lp_n_i,
	input 			dsi_txd1_lp_p_i,
	input 			dsi_txd1_lp_n_i,
	input 			dsi_txd2_lp_p_i,
	input 			dsi_txd2_lp_n_i,
	input 			dsi_txd3_lp_p_i,
	input 			dsi_txd3_lp_n_i,
	
	
	////////////////////////////////////////////////////////////////
	//	UART Interface
	input 		 	uart_rx_i,			//	Support 460800-8-N-1. 
	output 		 	uart_tx_o, 
	
	
	output 	[5:0] 	led_o,			//	
	
	
	////////////////////////////////////////////////////////////////
	//	CMOS Sensor
	output 			cmos_sclk,
	input 			cmos_sdat_IN,
	output 			cmos_sdat_OUT,
	output 			cmos_sdat_OE,
	
	//	CMOS Interface
	input 			cmos_pclk,
	input 			cmos_vsync,
	input 			cmos_href,
	input 	[7:0] 	cmos_data,
	input 			cmos_ctl1,
	output 			cmos_ctl2,
	output 			cmos_ctl3,
	
	
	////////////////////////////////////////////////////////////////
	//	HDMI Interface
	output 			hdmi_txc_oe,
	output 			hdmi_txd0_oe,
	output 			hdmi_txd1_oe,
	output 			hdmi_txd2_oe,
	
	output 			hdmi_txc_rst_o,
	output 			hdmi_txd0_rst_o,
	output 			hdmi_txd1_rst_o,
	output 			hdmi_txd2_rst_o,
	
	output 	[9:0] 	hdmi_txc_o,
	output 	[9:0] 	hdmi_txd0_o,
	output 	[9:0] 	hdmi_txd1_o,
	output 	[9:0] 	hdmi_txd2_o,
	
	
	////////////////////////////////////////////////////////////////
	//	LVDS Interface
	output 			lvds_txc_oe,
	output 	[6:0] 	lvds_txc_o,
	output 			lvds_txc_rst_o,
	
	output 			lvds_txd0_oe,
	output 	[6:0] 	lvds_txd0_o,
	output 			lvds_txd0_rst_o,
	
	output 			lvds_txd1_oe,
	output 	[6:0] 	lvds_txd1_o,
	output 			lvds_txd1_rst_o,
	
	output 			lvds_txd2_oe,
	output 	[6:0] 	lvds_txd2_o,
	output 			lvds_txd2_rst_o,
	
	output 			lvds_txd3_oe,
	output 	[6:0] 	lvds_txd3_o,
	output 			lvds_txd3_rst_o,
	
	
	////////////////////////////////////////////////////////////////
	//	RGB LCD 5Inch 800x480
	output 			lcd_tp_sda_o,		//	TP SDA
	output 			lcd_tp_sda_oe,
	input 			lcd_tp_sda_i,
	
	output 			lcd_tp_scl_o,		//	TP SCL
	output 			lcd_tp_scl_oe,
	input 			lcd_tp_scl_i,
	
	output 			lcd_tp_int_o,		//	TP INT
	output 			lcd_tp_int_oe,
	input 			lcd_tp_int_i,
	
	output 			lcd_tp_rst_o,		//	TP RST
	
	output 			lcd_pwm_o,			//	Backlight
	output 			lcd_blen_o,
	
	//output 			lcd_pclk_o,			//	PCLK & SCK Mux
	output 			lcd_vs_o,			//	VS & SSN Mux. Fixed to 1. Use DE-Only mode. 
	output 			lcd_hs_o,			//	HS. Fixed to 1. Use DE-Only mode. 
    input wire [1:0] key_data, // [0]=K1, [1]=K2, active low

	output 	[7:0] 	lcd_b7_0_o,			//	B7:B0. 
	output 	[7:0] 	lcd_g7_0_o,			//	G7:G0. Must output 8'hFF when access SPI. 
	output 	[7:0] 	lcd_r7_0_o,			//	R7:R0. 
	
	output 	[7:0] 	lcd_b7_0_oe,		//	B7:B0. 
	output 	[7:0] 	lcd_g7_0_oe,		//	G7:G0. Must output 8'hFF when access SPI. 
	output 	[7:0] 	lcd_r7_0_oe,		//	R7:R0. 

	input 	[7:0] 	lcd_b7_0_i,			//	B7:B0. 
	input 	[7:0] 	lcd_g7_0_i,			//	G7:G0. Must output 8'hFF when access SPI. 
	input 	[7:0] 	lcd_r7_0_i,			//	R7:R0. 
	
	//	SPI Pins
	output 			spi_sck_o, 
	output 			spi_ssn_o 			
);
	
	wire 			csi_rxd0_fifo_rd_o; 
	wire 			csi_rxd0_fifo_empty_i = 0;  
	wire 			csi_rxd1_fifo_rd_o;  
	wire 			csi_rxd1_fifo_empty_i = 0;  
	wire 			csi_rxd2_fifo_rd_o;  
	wire 			csi_rxd2_fifo_empty_i = 0;  
	wire 			csi_rxd3_fifo_rd_o;  
	wire 			csi_rxd3_fifo_empty_i = 0;  
	
	wire 	[1:0] 	i_dqs_n_hi;
	wire 	[1:0] 	i_dqs_n_lo;
	wire 	[1:0] 	o_dqs_n_hi;
	wire 	[1:0] 	o_dqs_n_lo;
	
	
	parameter 	SIM_DATA 	= 0; 
	
	//	Hardware Configuration
	assign clk_p_hi = 1'b0;	//	DDR3 Clock requires 180 degree shifted. 
	assign clk_p_lo = 1'b1;
	assign clk_n_hi = 1'b1;
	assign clk_n_lo = 1'b0; 
	
	//	System Clock Tree Control
	assign sys_pll_rstn_o = 1'b1; 	//	nrst; 	//	Reset whole system when nrst (K2) is pressed. 
	
	assign dsi_pll_rstn_o = sys_pll_lock; 
	assign ddr_pll_rstn_o = sys_pll_lock; 
	assign lvds_pll_rstn_o = sys_pll_lock; 
	
	wire 			w_pll_lock = sys_pll_lock && dsi_pll_lock && ddr_pll_lock && lvds_pll_lock; 
	
	//	Synchronize System Resets. 
	reg 			rstn_sys = 0, rstn_pixel = 0; 
	wire 			rst_sys = ~rstn_sys, rst_pixel = ~rstn_pixel; 
	
	reg 			rstn_dsi_refclk = 0, rstn_dsi_byteclk = 0; 
	wire 			rst_dsi_refclk = ~rstn_dsi_refclk, rst_dsi_byteclk = ~rstn_dsi_byteclk; 
	
	reg 			rstn_lvds_1x = 0; 
	wire 			rst_lvds_1x = ~rstn_lvds_1x; 
	
	reg 			rstn_27m = 0, rstn_54m = 0; 
	wire 			rst_27m = ~rstn_27m, rst_54m = ~rstn_54m; 
	
	//	Clock Gen
	always @(posedge clk_27m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_27m <= 0; else rstn_27m <= 1; end
	always @(posedge clk_54m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_54m <= 0; else rstn_54m <= 1; end
	always @(posedge clk_sys or negedge w_pll_lock) begin if(~w_pll_lock) rstn_sys <= 0; else rstn_sys <= 1; end
	always @(posedge clk_pixel_2x or negedge w_pll_lock) begin if(~w_pll_lock) rstn_pixel <= 0; else rstn_pixel <= 1; end
	always @(posedge dsi_refclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_refclk <= 0; else rstn_dsi_refclk <= 1; end
	always @(posedge dsi_byteclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_byteclk <= 0; else rstn_dsi_byteclk <= 1; end
	always @(posedge clk_lvds_1x or negedge w_pll_lock) begin if(~w_pll_lock) rstn_lvds_1x <= 0; else rstn_lvds_1x <= 1; end
	
	
	localparam 	CLOCK_MAIN 	= 96000000; 	//	System clock using 96MHz. 
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	Flash Burner Control
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	wire 			w_ustick, w_mstick; 
	
	wire  [7:0] 	w_dev_index_o;  
	wire  [7:0] 	w_dev_cmd_o;  
	wire  [31:0] 	w_dev_wdata_o;  
	wire  		w_dev_wvalid_o;  
	wire  		w_dev_rvalid_o;  
	wire 	[31:0] 	w_dev_rdata_i;  
	
	wire 			w_spi_ssn_o, w_spi_sck_o; 
	wire 	[3:0] 	w_spi_data_o, w_spi_data_oe; 
	wire 	[3:0] 	w_spi_data_i; 
	
	//	Flash Control
	reg 			r_flash_en = 0; 		//	0x00:0x00 Enable Flash
	
	always @(posedge clk_sys) begin
		r_flash_en <= (w_dev_wvalid_o && (w_dev_index_o == 8'h00) && (w_dev_cmd_o == 8'h00)) ? w_dev_wdata_o : r_flash_en; 
	end
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	LCD Data Mux
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	wire 	[7:0] 	w_lcd_b_o, w_lcd_g_o, w_lcd_r_o; 
	
	assign lcd_b7_0_o = r_flash_en ? {4'b0, w_spi_data_o[3:2], 2'b0} : w_lcd_b_o; 
	assign lcd_g7_0_o = r_flash_en ? {6'h0, w_spi_data_o[1:0]} : w_lcd_g_o; 
	assign lcd_r7_0_o = r_flash_en ? {8'h00} : w_lcd_r_o; 
	
	assign lcd_b7_0_oe = r_flash_en ? {4'b0, w_spi_data_oe[3:2], 2'b0} : 8'hFF; 
	assign lcd_g7_0_oe = r_flash_en ? {6'h0, w_spi_data_oe[1:0]} : 8'hFF; 
	assign lcd_r7_0_oe = r_flash_en ? {8'h00} : 8'hFF; 
	
	assign spi_sck_o = w_spi_sck_o; 
	assign spi_ssn_o = w_spi_ssn_o; 
	assign w_spi_data_i = {lcd_b7_0_i[3:2], lcd_g7_0_i[1:0]}; 
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	DDR3 Controller
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	wire			w_ddr3_ui_clk = clk_sys;
	wire			w_ddr3_ui_rst = rst_sys;
	wire			w_ddr3_ui_areset = rst_sys;
	wire			w_ddr3_ui_aresetn = rstn_sys;
	

	//	General AXI Interface 
	wire	[3:0] 	w_ddr3_awid;
	wire	[31:0]	w_ddr3_awaddr;
	wire	[7:0]		w_ddr3_awlen;
	wire			w_ddr3_awvalid;
	wire			w_ddr3_awready;
	
	wire 	[3:0]  	w_ddr3_wid;
	wire 	[127:0] 	w_ddr3_wdata;
	wire 	[15:0]	w_ddr3_wstrb;
	wire			w_ddr3_wlast;
	wire			w_ddr3_wvalid;
	wire			w_ddr3_wready;
	
	wire 	[3:0] 	w_ddr3_bid;
	wire 	[1:0] 	w_ddr3_bresp;
	wire			w_ddr3_bvalid;
	wire			w_ddr3_bready;
	
	wire	[3:0] 	w_ddr3_arid;
	wire	[31:0]	w_ddr3_araddr;
	wire	[7:0]		w_ddr3_arlen;
	wire			w_ddr3_arvalid;
	wire			w_ddr3_arready;
	
	wire 	[3:0] 	w_ddr3_rid;
	wire 	[127:0] 	w_ddr3_rdata;
	wire			w_ddr3_rlast;
	wire			w_ddr3_rvalid;
	wire			w_ddr3_rready;
	wire 	[1:0] 	w_ddr3_rresp;
	
	
	//	AXI Interface Request
	wire 	[3:0] 	w_ddr3_aid;
	wire 	[31:0] 	w_ddr3_aaddr;
	wire 	[7:0]  	w_ddr3_alen;
	wire 	[2:0]  	w_ddr3_asize;
	wire 	[1:0]  	w_ddr3_aburst;
	wire 	[1:0]  	w_ddr3_alock;
	wire			w_ddr3_avalid;
	wire			w_ddr3_aready;
	wire			w_ddr3_atype;
	
	wire 			w_ddr3_cal_done, w_ddr3_cal_pass; 
	
	//	Do not issue DDR read / write when ~cal_done. 
	reg 			r_ddr_unlock = 0; 
	always @(posedge w_ddr3_ui_clk or negedge w_ddr3_ui_aresetn) begin
		if(~w_ddr3_ui_aresetn)
			r_ddr_unlock <= 0; 
		else
			r_ddr_unlock <= w_ddr3_cal_done; 
	end
	
	DdrCtrl ddr3_ctl_axi (	
		.core_clk		(core_clk),
		.tac_clk		(tac_clk),
		.twd_clk		(twd_clk),	
		.tdqss_clk		(tdqss_clk),
		
		.reset		(reset),
		.cs			(cs),
		.ras			(ras),
		.cas			(cas),
		.we			(we),
		.cke			(cke),    
		.addr			(addr),
		.ba			(ba),
		.odt			(odt),
		
		.o_dm_hi		(o_dm_hi),
		.o_dm_lo		(o_dm_lo),
		
		.i_dq_hi		(i_dq_hi),
		.i_dq_lo		(i_dq_lo),
		.o_dq_hi		(o_dq_hi),
		.o_dq_lo		(o_dq_lo),
		.o_dq_oe		(o_dq_oe),
		
		.i_dqs_hi		(i_dqs_hi),
		.i_dqs_lo		(i_dqs_lo),
		.i_dqs_n_hi		(i_dqs_n_hi),
		.i_dqs_n_lo		(i_dqs_n_lo),
		.o_dqs_hi		(o_dqs_hi),
		.o_dqs_lo		(o_dqs_lo),
		.o_dqs_n_hi		(o_dqs_n_hi),
		.o_dqs_n_lo		(o_dqs_n_lo),
		.o_dqs_oe		(o_dqs_oe),
		.o_dqs_n_oe		(),				//	o_dqs_n_oe),
		
		.clk			(w_ddr3_ui_clk),
		.reset_n		(w_ddr3_ui_aresetn),
		
		.axi_avalid		(w_ddr3_avalid),		//	Enable command only when unlocked. 
		.axi_aready		(w_ddr3_aready),
		.axi_aaddr		(w_ddr3_aaddr),
		.axi_aid		(w_ddr3_aid),
		.axi_alen		(w_ddr3_alen),
		.axi_asize		(w_ddr3_asize),
		.axi_aburst		(w_ddr3_aburst),
		.axi_alock		(w_ddr3_alock),
		.axi_atype		(w_ddr3_atype),
		
		.axi_wid		(w_ddr3_wid),
		.axi_wvalid		(w_ddr3_wvalid),
		.axi_wready		(w_ddr3_wready),
		.axi_wdata		(w_ddr3_wdata),
		.axi_wstrb		(w_ddr3_wstrb),
		.axi_wlast		(w_ddr3_wlast),
		
		.axi_bvalid		(w_ddr3_bvalid),
		.axi_bready		(w_ddr3_bready),
		.axi_bid		(w_ddr3_bid),
		.axi_bresp		(w_ddr3_bresp),
		
		.axi_rvalid		(w_ddr3_rvalid),
		.axi_rready		(w_ddr3_rready),
		.axi_rdata		(w_ddr3_rdata),
		.axi_rid		(w_ddr3_rid),
		.axi_rresp		(w_ddr3_rresp),
		.axi_rlast		(w_ddr3_rlast),
		
		.shift		(shift),
		.shift_sel		(),
		.shift_ena		(shift_ena),
		
		.cal_ena		(1'b1),
		.cal_done		(w_ddr3_cal_done),
		.cal_pass		(w_ddr3_cal_pass)
	);
	//	The o_dqs_n_oe may not assert at negative edge. 
	assign o_dqs_n_oe = o_dqs_oe; 
	
	assign w_ddr3_bready = 1'b1; 
	assign shift_sel = 5'b00100; 		//	ddr_tac_clk always use PLLOUT[2]. 
	
	
	AXI4_AWARMux #(.AID_LEN(4), .AADDR_LEN(32)) axi4_awar_mux (
		.aclk_i			(w_ddr3_ui_clk), 
		.arst_i			(w_ddr3_ui_rst), 
		
		.awid_i			(w_ddr3_awid),
		.awaddr_i			(w_ddr3_awaddr),
		.awlen_i			(w_ddr3_awlen),
		.awvalid_i			(w_ddr3_awvalid && r_ddr_unlock),
		.awready_o			(w_ddr3_awready),
		
		.arid_i			(w_ddr3_arid),
		.araddr_i			(w_ddr3_araddr),
		.arlen_i			(w_ddr3_arlen),
		.arvalid_i			(w_ddr3_arvalid && r_ddr_unlock),
		.arready_o			(w_ddr3_arready),
		
		.aid_o			(w_ddr3_aid),
		.aaddr_o			(w_ddr3_aaddr),
		.alen_o			(w_ddr3_alen),
		.atype_o			(w_ddr3_atype),
		.avalid_o			(w_ddr3_avalid),
		.aready_i			(w_ddr3_aready)
	);
	
	assign w_ddr3_asize = 4; 		//	Fixed 128 bits (16 bytes, size = 4)
	assign w_ddr3_aburst = 1; 
	assign w_ddr3_alock = 0; 
	
	assign led_o[1:0] = {w_ddr3_cal_pass, w_ddr3_cal_done}; 
	
	
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	I2C Config (SC130GS)
	
	//  i2c timing controller module of 16Bit
	wire            [ 8:0]          sc2210_i2c_config_index;
	wire            [23:0]          sc2210_i2c_config_data;
	wire            [ 8:0]          sc2210_i2c_config_size;
	wire                            sc2210_i2c_config_done;
	
    ////////////////////////////////////////////////////////////////
    // SC2210 I2C内部信号
    ////////////////////////////////////////////////////////////////

    // 上电初始化I2C输出
    wire init_i2c_scl_o;
    wire init_i2c_sda_o;
    wire init_i2c_sda_oe;

    // 自动曝光运行时I2C输出
    wire ae_i2c_scl_o;
    wire ae_i2c_scl_oe;
    wire ae_i2c_sda_o;
    wire ae_i2c_sda_oe;

    // 自动曝光I2C状态
    wire ae_i2c_busy;
    wire ae_i2c_ack_error;
    
	i2c_timing_ctrl_reg16_dat8_wronly
	#(
	    .CLK_FREQ           (CLOCK_MAIN),                              //  100 MHz
	    .I2C_FREQ           (50_000    )                               //  10 KHz(<= 400KHz)
	) u_i2c_timing_ctrl_16bit (
	    //  global clock
	    .clk                (clk_sys                 ),                          //  96MHz
	    .rst_n              (rstn_sys                ),                          //  system reset

	    //  i2c interface
	    .i2c_sclk           (init_i2c_scl_o               ),                          //  i2c clock
	    .i2c_sdat_IN        (csi_sda_i               ),
	    .i2c_sdat_OUT       (init_i2c_sda_o               ),
	    .i2c_sdat_OE        (init_i2c_sda_oe              ),

	    //  i2c config data
	    .i2c_config_index   (sc2210_i2c_config_index        ),                          //  i2c config reg index, read 2 reg and write xx reg
	    .i2c_config_data    ({8'h60, sc2210_i2c_config_data}),                     //  i2c config data
	    .i2c_config_size    (sc2210_i2c_config_size         ),                          //  i2c config data counte
	    .i2c_config_done    (sc2210_i2c_config_done         )                          //  i2c config timing complete
	);
	//assign csi_scl_oe = 1; 

	//  I2C Configure Data of SC2210
	I2C_SC2210_19201080_4Lanes_Config u_I2C_SC2210_19201080_4Lanes_Config
	(
	    .LUT_INDEX  (sc2210_i2c_config_index   ),
	    .LUT_DATA   (sc2210_i2c_config_data    ),
	    .LUT_SIZE   (sc2210_i2c_config_size    )
	);
		
	
		
	//	CMOS Interface
	//input 			cmos_pclk,
	//input 			cmos_vsync,
	//input 			cmos_href,
	//input 	[7:0] 	cmos_data,
	//input 			cmos_ctl1,
	//output 			cmos_ctl2,
	//output 			cmos_ctl3,

	
	//	Output LED
	reg 	[3:0]		r_cmos_fv_o = 0; 
	reg 	[1:0] 	r_cmos_rx_vsync0_in = 0; 
	always @(posedge cmos_pclk) begin
		r_cmos_rx_vsync0_in <= {r_cmos_rx_vsync0_in, cmos_vsync}; 
		r_cmos_fv_o <= r_cmos_fv_o + ((r_cmos_rx_vsync0_in == 2'b01) ? 1 : 0); 
	end

	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	System Control. Can be removed for public. 
	
	localparam 	CLK_FREQ 	= 96_000_000; 	//	clk_sys is 96MHz. 
	localparam 	BAUD_RATE 	= 460_800; 		//	Use 460800-8-N-1. 
	
	
	//	SFR I/O Interface
	wire 	[7:0] 	w_sfr_addr_o; 	//	SFR Address (0xFF00 ~ 0xFFFF). 00:Power; 40~5F:Stream0; 60~7F:Stream1. 
	wire 	[7:0] 	w_sfr_wdata_o; 	//	SFR Write Data. 
	wire 			w_sfr_we_o; 		//	SFR WE. 
	reg 	[7:0] 	w_sfr_rdata_i; 	//	Must be valid after sfr_rd_o. 
	wire 			w_sfr_rd_o; 		//	SFR RD. 
	
	
	//	System Control Registers
	reg 			r_dsi_tx_rstn = 0; 	//	DSI TX Reset
	reg 	[7:0] 	r_dsi_pwm = 64; 		//	[6:0]PWM, [7]Pol
	reg 			r_dsi_resetn_o = 0; 	//	DSI Panel Reset
	reg 			r_dsi_data_rstn = 0; 	//	DSI TX Reset
	
	reg 	[3:0] 	r_dsi_lp_p_ovr = 0; 	
	reg 	[3:0] 	r_dsi_lp_n_ovr = 0; 	
	
	
	
	//	AXI-Lite Interface Bridge
	localparam 	CSI_AXILITE_ID 	= 0; 				//	Select DSI_TX when r_axi_sel = DSI_AXILITE_ID. 
	localparam 	DSI_AXILITE_ID 	= 1; 				//	Select DSI_TX when r_axi_sel = DSI_AXILITE_ID. 
	
	reg 	[7:0] 	r_axi_addr = 8'h18; 		//	0xE0 (RW)
	reg 	[31:0] 	r_axi_wdata = 32'h0000000A; 	//	0xE1~0xE4 (RW)
	wire 	[31:0] 	w_axi_rdata; 			//	0xE5~0xE8 (RO)
	reg 	[0:0] 	r_axi_sel = 1; 			//	0xE9[7:2] (RW)
	reg 			r_axi_r1w0 = 0; 			//	0xE9[1] (RW)
	reg 			r_axi_req = 0; 			//	0xE9[0] (WO, Single Cycle)
	reg 			r_axi_req_o = 0; 			//	Delayed of r_axi_req. 
	
	
	//	Buffered AXI Read Data
	reg 	[31:0] 	r_axi_rdata = 0; 		//	Use state machine
	reg 			r_axi_idle = 0; 		//	AXI Idle 
	
	reg 	[3:0] 	rs_axilite = 0; 		//	AXI Access
	wire 	[3:0] 	ws_axilite_idle = 0; 		
	wire 	[3:0] 	ws_axilite_write = 1; 
	wire 	[3:0] 	ws_axilite_read = 2; 
	wire 	[3:0] 	ws_axilite_endread = 3; 
	
	reg 			r_axi_awvalid = 0, r_axi_wvalid = 0, r_axi_arvalid = 0; 
	wire 			w_axi_awready, w_axi_wready, w_axi_arready, w_axi_rvalid; 
	
	
	reg 	[3:0] 	rc_axi_init = 0; 

	always @(posedge clk_sys or posedge rst_sys) begin
		if(rst_sys) begin
			r_dsi_tx_rstn <= 0; 
			r_dsi_pwm <= 64; 
			r_axi_req <= 0; 
			r_dsi_resetn_o <= 0; 
			r_dsi_data_rstn <= 0; 
			
			rs_axilite <= 0; 
			r_axi_awvalid <= 0; 
			r_axi_wvalid <= 0;
			r_axi_arvalid <= 0; 
			
			r_dsi_lp_p_ovr <= 0; 
			r_dsi_lp_n_ovr <= 0; 
			
			rc_axi_init <= 0; 
			r_axi_idle <= 0; 
			
		end else begin
			r_dsi_tx_rstn <= 1; 
			r_dsi_resetn_o <= 1; 
			r_dsi_data_rstn <= 1; 
			
		end
	end
	
	assign dsi_resetn_o = r_dsi_resetn_o; 
	
	assign csi_ctl0_oe = 0; 
	assign csi_ctl1_oe = 0; 
	
	
	PWMLite dsi_pwm (		//	#(.ENABLE_TICK(0), .PWM_BITS(7)) 
		.clk_i			(clk_sys),
		.rst_i			(rst_sys),
		.pwm_i			(r_dsi_pwm[6:0]),
		.pol_i			(r_dsi_pwm[7]), 
		.pwm_o			(dsi_pwm_o)
	);






	////////////////////////////////////////////////////////////////
	//	MIPI CSI RX
	
	//	The CSI RXC shall not be inverted. Data can be inverted with swapped LP data and flipped HS data. 
	localparam 	CSI_RXD_INV 	= 4'b1111; 
	localparam 	CSI_DATA_WIDTH 	= 32; 			
	localparam 	CSI_STRB_WIDTH 	= CSI_DATA_WIDTH / 8; 

	//	Current implementation supports RAW8 only. 
	wire 			w_csi_rx_clk; 
	wire 			w_csi_rx_vsync0, w_csi_rx_hsync0, w_csi_rx_dvalid; 
	wire 	[63:0] 	w_csi_rx_data; 
	wire 	[47:0] 	w_csi_rx_data_rel_raw; 
	
	//	AXI Interface
	wire 	[31:0] 	w_csi_axi_rdata; 
	wire 			w_csi_axi_awready, w_csi_axi_wready, w_csi_axi_arready, w_csi_axi_rvalid; 
	
	
	
`define PRI_MIPI_IP
	
	
`ifdef PRI_MIPI_IP
	wire 	[7:0] 	w_mipi_d0 = (CSI_RXD_INV[0] ? 8'hFF : 8'h00) ^ csi_rxd0_hs_i; 
	wire 	[7:0] 	w_mipi_d1 = (CSI_RXD_INV[1] ? 8'hFF : 8'h00) ^ csi_rxd1_hs_i; 
	wire 	[7:0] 	w_mipi_d2 = (CSI_RXD_INV[2] ? 8'hFF : 8'h00) ^ csi_rxd2_hs_i; 
	wire 	[7:0] 	w_mipi_d3 = (CSI_RXD_INV[3] ? 8'hFF : 8'h00) ^ csi_rxd3_hs_i; 
	MIPIRx4LaneFre mipi0_rx (
		.sclk_i			(clk_sys), 
		.srst_i			(rst_sys), 
		
		.mipi_rx_byteclk_i	(csi_rxc_i), 
		.mipi_rx_d0_i		({w_mipi_d0[0], w_mipi_d0[1], w_mipi_d0[2], w_mipi_d0[3], w_mipi_d0[4], w_mipi_d0[5], w_mipi_d0[6], w_mipi_d0[7]}), 
		.mipi_rx_d1_i		({w_mipi_d1[0], w_mipi_d1[1], w_mipi_d1[2], w_mipi_d1[3], w_mipi_d1[4], w_mipi_d1[5], w_mipi_d1[6], w_mipi_d1[7]}), 
		.mipi_rx_d2_i		({w_mipi_d2[0], w_mipi_d2[1], w_mipi_d2[2], w_mipi_d2[3], w_mipi_d2[4], w_mipi_d2[5], w_mipi_d2[6], w_mipi_d2[7]}), 
		.mipi_rx_d3_i		({w_mipi_d3[0], w_mipi_d3[1], w_mipi_d3[2], w_mipi_d3[3], w_mipi_d3[4], w_mipi_d3[5], w_mipi_d3[6], w_mipi_d3[7]}), 
		.mipi_rx_clk_lp_p_i	(csi_rxc_lp_p_i), 
		.mipi_rx_clk_lp_n_i	(csi_rxc_lp_n_i), 
		.mipi_rx_d0_lp_p_i	(CSI_RXD_INV[0] ? csi_rxd0_lp_n_i : csi_rxd0_lp_p_i), 
		.mipi_rx_d0_lp_n_i	(CSI_RXD_INV[0] ? csi_rxd0_lp_p_i : csi_rxd0_lp_n_i), 
		.mipi_rx_rst_o		(), 
		.mipi_rx_rst_n_o		(), 
		.mipi_rx_clk_hs_en_o	(csi_rxc_hs_en_o), 
		.mipi_rx_dat_hs_en_o	(csi_rxd0_hs_en_o), 
		.mipi_rx_clk_term_en_o	(csi_rxc_hs_term_en_o), 
		.mipi_rx_dat_term_en_o	(csi_rxd0_hs_term_en_o), 
		
		.CLK				(w_csi_rx_clk), 
		.VSYNC			(w_csi_rx_vsync0), 
		.HSYNC			(w_csi_rx_hsync0), 
		.DE				(w_csi_rx_dvalid), 
		.DAT				(w_csi_rx_data_rel_raw)
	);
	assign w_csi_rx_data = {2{w_csi_rx_data_rel_raw[47:40], w_csi_rx_data_rel_raw[35:28], w_csi_rx_data_rel_raw[23:16], w_csi_rx_data_rel_raw[11:4]}}; 
	assign {csi_rxd3_hs_en_o, csi_rxd2_hs_en_o, csi_rxd1_hs_en_o} = {3{csi_rxd0_hs_en_o}}; 
	assign {csi_rxd3_hs_term_en_o, csi_rxd2_hs_term_en_o, csi_rxd1_hs_term_en_o} = {3{csi_rxd0_hs_term_en_o}}; 
	
	
`else	
	
	//	Reset pixel 16 cycles after ~vsync. 
	reg 			r_reset_pixen_n = 0; 
	reg 	[1:0] 	r_csi_rx_vsync0_i = 0; 
	always @(posedge w_csi_rx_clk or negedge rstn_sys) begin
		if(~rstn_sys) begin
			r_reset_pixen_n <= 0; 
			r_csi_rx_vsync0_i <= 0; 
		end else begin
			r_csi_rx_vsync0_i <= {r_csi_rx_vsync0_i, w_csi_rx_vsync0}; 
			r_reset_pixen_n <= (r_csi_rx_vsync0_i == 2'b10) ? 1'b0 : 1'b1; 
		end
	end
	
	assign w_csi_rx_clk = clk_sys; 
	csi_rx mipi_rx_0(
		.reset_n			(rstn_sys), 
		.clk				(w_csi_rx_clk), 
		.reset_byte_HS_n		(rstn_sys), 
		.clk_byte_HS		(csi_rxc_i), 
		.reset_pixel_n		(r_reset_pixen_n), 	//rstn_sys), 
		.clk_pixel			(w_csi_rx_clk), 
		.Rx_LP_CLK_P		(csi_rxc_lp_p_i), 
		.Rx_LP_CLK_N		(csi_rxc_lp_n_i), 
		
		.Rx_HS_enable_C		(csi_rxc_hs_en_o), 
		.LVDS_termen_C		(csi_rxc_hs_term_en_o), 
		
		//	Lane inversion affects HS & LP data only. 
		.Rx_LP_D_P			({CSI_RXD_INV[3] ? csi_rxd3_lp_n_i : csi_rxd3_lp_p_i, CSI_RXD_INV[2] ? csi_rxd2_lp_n_i : csi_rxd2_lp_p_i, CSI_RXD_INV[1] ? csi_rxd1_lp_n_i : csi_rxd1_lp_p_i, CSI_RXD_INV[0] ? csi_rxd0_lp_n_i : csi_rxd0_lp_p_i}), 
		.Rx_LP_D_N			({CSI_RXD_INV[3] ? csi_rxd3_lp_p_i : csi_rxd3_lp_n_i, CSI_RXD_INV[2] ? csi_rxd2_lp_p_i : csi_rxd2_lp_n_i, CSI_RXD_INV[1] ? csi_rxd1_lp_p_i : csi_rxd1_lp_n_i, CSI_RXD_INV[0] ? csi_rxd0_lp_p_i : csi_rxd0_lp_n_i}), 
		.Rx_HS_D_0			((CSI_RXD_INV[0] ? 8'hFF : 8'h00) ^ csi_rxd0_hs_i), 
		.Rx_HS_D_1			((CSI_RXD_INV[1] ? 8'hFF : 8'h00) ^ csi_rxd1_hs_i), 
		.Rx_HS_D_2			((CSI_RXD_INV[2] ? 8'hFF : 8'h00) ^ csi_rxd2_hs_i), 
		.Rx_HS_D_3			((CSI_RXD_INV[3] ? 8'hFF : 8'h00) ^ csi_rxd3_hs_i), 
		.Rx_HS_D_4			(), 
		.Rx_HS_D_5			(), 
		.Rx_HS_D_6			(), 
		.Rx_HS_D_7			(), 
		
		.Rx_HS_enable_D		({csi_rxd3_hs_en_o, csi_rxd2_hs_en_o, csi_rxd1_hs_en_o, csi_rxd0_hs_en_o}), 
		.LVDS_termen_D		({csi_rxd3_hs_term_en_o, csi_rxd2_hs_term_en_o, csi_rxd1_hs_term_en_o, csi_rxd0_hs_term_en_o}), 
		.fifo_rd_enable		({csi_rxd3_fifo_rd_o, csi_rxd2_fifo_rd_o, csi_rxd1_fifo_rd_o, csi_rxd0_fifo_rd_o}), 
		.fifo_rd_empty		({csi_rxd3_fifo_empty_i, csi_rxd2_fifo_empty_i, csi_rxd1_fifo_empty_i, csi_rxd0_fifo_empty_i}), 
		.DLY_enable_D		(), 
		.DLY_inc_D			(), 
		.u_dly_enable_D		(0), 
		.u_dly_inc_D		(), 
		
		.vsync_vc1			(), 
		.vsync_vc15			(), 
		.vsync_vc12			(), 
		.vsync_vc9			(), 
		.vsync_vc7			(), 
		.vsync_vc14			(), 
		.vsync_vc13			(), 
		.vsync_vc11			(), 
		.vsync_vc10			(), 
		.vsync_vc8			(), 
		.vsync_vc6			(), 
		.vsync_vc4			(), 
		.vsync_vc0			(w_csi_rx_vsync0), 
		.vsync_vc5			(), 
		.vsync_vc3			(), 
		.vsync_vc2			(), 
	
		.irq				(), 
		
		.pixel_data_valid		(w_csi_rx_dvalid), 
		.pixel_data			(w_csi_rx_data), 
		.pixel_per_clk		(), 
		.datatype			(), 
		.shortpkt_data_field	(), 
		.word_count			(), 
		.vcx				(), 
		.vc				(), 
		.hsync_vc3			(), 
		.hsync_vc2			(), 
		.hsync_vc8			(), 
		.hsync_vc12			(), 
		.hsync_vc7			(), 
		.hsync_vc10			(), 
		.hsync_vc1			(), 
		.hsync_vc0			(w_csi_rx_hsync0), 
		.hsync_vc13			(), 
		.hsync_vc4			(), 
		.hsync_vc11			(), 
		.hsync_vc6			(), 
		.hsync_vc9			(), 
		.hsync_vc15			(), 
		.hsync_vc14			(), 
		.hsync_vc5			(), 
		
		.axi_clk			(clk_sys), 
		.axi_reset_n		(rstn_sys), 
		
		.axi_awaddr			(r_axi_addr), 
		.axi_awvalid		((r_axi_sel == CSI_AXILITE_ID) && r_axi_awvalid), 
		.axi_awready		(w_csi_axi_awready), 
	
		.axi_wvalid			((r_axi_sel == CSI_AXILITE_ID) && r_axi_wvalid), 
		.axi_wdata			(r_axi_wdata), 
		.axi_wready			(w_csi_axi_wready), 
	
		.axi_bvalid			(), 
		.axi_bready			(1), 
		
		.axi_araddr			(r_axi_addr), 
		.axi_arvalid		((r_axi_sel == CSI_AXILITE_ID) && r_axi_arvalid), 
		.axi_arready		(w_csi_axi_arready), 
		
		.axi_rready			(1), 
		.axi_rvalid			(w_csi_axi_rvalid), 
		.axi_rdata			(w_csi_axi_rdata)
		
	);
	
	assign csi_rxd0_rst_o = rst_sys; 
	assign csi_rxd1_rst_o = rst_sys; 
	assign csi_rxd2_rst_o = rst_sys; 
	assign csi_rxd3_rst_o = rst_sys; 
`endif
	
	
	
	//	Output LED
	reg 	[5:0]		r_csi_fv_o = 0; 
	reg 	[1:0] 	r_csi_rx_vsync0_in = 0; 
	always @(posedge w_csi_rx_clk) begin
		r_csi_rx_vsync0_in <= {r_csi_rx_vsync0_in, w_csi_rx_vsync0}; 
		r_csi_fv_o <= r_csi_fv_o + ((r_csi_rx_vsync0_in == 2'b01) ? 1 : 0); 
	end

	
	
	////////////////////////////////////////////////////////////////
	//	MIPI-CSI Crop
	
	wire			XYCrop_frame_vsync; 
	wire			XYCrop_frame_href;
	wire			XYCrop_frame_de;
	wire	[63:0]	XYCrop_frame_Gray;

	//Sensor_Image_XYCrop
	//#(
	//	.IMAGE_HSIZE_SOURCE (1920 / CSI_STRB_WIDTH),
	//	.IMAGE_VSIZE_SOURCE (1080	 ),
	//	.IMAGE_HSIZE_TARGET (1024 / CSI_STRB_WIDTH),
	//	.IMAGE_YSIZE_TARGET (600 	 ),
	//	.PIXEL_DATA_WIDTH	(CSI_DATA_WIDTH) 		//	32		 )
	//)
	//u_Sensor_Image_XYCrop
	//(
	//	//	globel clock
	//	.clk			(w_csi_rx_clk),			//	image pixel clock
	//	.rst_n		(rstn_sys),			//	system reset
	//	
	//	//CMOS Sensor interface
	//	.image_in_vsync (w_csi_rx_vsync0		),			//H : Data Valid; L : Frame Sync(Set it by register)
	//	.image_in_href	(w_csi_rx_hsync0		),			//H : Data vaild, L : Line Sync
	//	.image_in_de	(w_csi_rx_dvalid		), 			//H : Data Enable, L : Line Sync
	//	.image_in_data	({w_csi_rx_data[7:0], w_csi_rx_data[15:8], w_csi_rx_data[23:16], w_csi_rx_data[31:24], w_csi_rx_data[39:32], w_csi_rx_data[47:40], w_csi_rx_data[55:48], w_csi_rx_data[63:56]}),			//8 bits cmos data input
	//	
	//	.image_out_vsync(XYCrop_frame_vsync ),			//H : Data Valid; L : Frame Sync(Set it by register)
	//	.image_out_href (XYCrop_frame_href	),			//H : Data vaild, L : Line Sync
	//	.image_out_de	(XYCrop_frame_de	), 			//H : Data Enable, L : Line Sync
	//	.image_out_data (XYCrop_frame_Gray	)			//8 bits cmos data input	
	//);

	reg			r_XYCrop_frame_vsync = 0; 
	reg			r_XYCrop_frame_href = 0;
	reg			r_XYCrop_frame_de = 0;
	reg	[63:0]	r_XYCrop_frame_Gray = 0;
	
	always @(posedge w_csi_rx_clk) begin
		r_XYCrop_frame_vsync <= XYCrop_frame_vsync; 
		r_XYCrop_frame_href <= XYCrop_frame_href;
		r_XYCrop_frame_de <= XYCrop_frame_de;
		r_XYCrop_frame_Gray <= XYCrop_frame_Gray;
	end
	
	//	Data Write Assignment
	//wire			cmos_frame_vsync = r_XYCrop_frame_vsync;                     //  cmos frame data vsync valid signal
	//wire			cmos_frame_href = r_XYCrop_frame_href && r_XYCrop_frame_de;	 //  cmos frame data href vaild  signal
	//wire	[63:0]	cmos_frame_Gray = r_XYCrop_frame_Gray; 
	wire			cmos_frame_vsync = w_csi_rx_vsync0;                     //  cmos frame data vsync valid signal
	wire			cmos_frame_href = w_csi_rx_hsync0 && w_csi_rx_dvalid;	 //  cmos frame data href vaild  signal
	wire	[63:0]	cmos_frame_Gray = {w_csi_rx_data[7:0], w_csi_rx_data[15:8], w_csi_rx_data[23:16], w_csi_rx_data[31:24], w_csi_rx_data[39:32], w_csi_rx_data[47:40], w_csi_rx_data[55:48], w_csi_rx_data[63:56]}; 

	












	////////////////////////////////////////////////////////////////
	//	DDR R/W Control
	

	wire                            lcd_de;
	wire                            lcd_hs;      
	wire                            lcd_vs;
	wire 					  lcd_request; 
	wire            [7:0]           lcd_red, lcd_red2;
	wire            [7:0]           lcd_green, lcd_green2;
	wire            [7:0]           lcd_blue, lcd_blue2;
	wire            [15:0]          lcd_data;


	assign w_ddr3_awid = 0; 
	assign w_ddr3_wid = 0; 
	
	wire 			w_wframe_vsync; 
	wire 	[7:0] 	w_axi_tp; 
	
    // Change RECORD_FRAMES to 10 for a quick memory-range test, then 100.
    localparam integer RECORD_FRAMES=100;
    localparam integer PLAY_HOLD_FRAMES=6; // HDMI60Hz / 6 = replay10fps
    // Existing key pin mapping/debounce retained.
    wire ddr_replay_active,ddr_frame_ready,ddr_ae_allow;
    wire [2:0] ddr_replay_mode;
    wire [6:0] ddr_recorded_count,ddr_displayed_number;
    wire key1_pressed,key2_pressed,key1_short,key2_short,key1_long,key2_long;
    freeze_key_filter #(.CLK_HZ(CLOCK_MAIN)) u_key1(
      .clk(w_ddr3_ui_clk),.reset(w_ddr3_ui_rst),.key_n(key_data[0]),
      .pressed(key1_pressed),.short_pulse(key1_short),.long_pulse(key1_long));
    freeze_key_filter #(.CLK_HZ(CLOCK_MAIN)) u_key2(
      .clk(w_ddr3_ui_clk),.reset(w_ddr3_ui_rst),.key_n(key_data[1]),
      .pressed(key2_pressed),.short_pulse(key2_short),.long_pulse(key2_long));
    assign led_o[4]=~key1_pressed;
    assign led_o[5]=~key2_pressed;

    //============================================================
    // Global UI controller
    // M0: RGB before gray; M1: Gray|Sobel; M2: Shape; M3: DDR
    //============================================================
    wire [2:0] work_mode_ui;
    wire [7:0] sobel_threshold_ui;
    wire       shape_boxes_enable_ui;
    wire       ddr_key1_short, ddr_key1_long, ddr_key2_short, ddr_key2_long;

    system_ui_controller #(
        .THRESHOLD_INIT(8'd14),
        .SHORT_STEP(8'd1),
        .LONG_STEP(8'd5)
    ) u_system_ui_controller (
      .clk(w_ddr3_ui_clk), .reset(w_ddr3_ui_rst),
      .key1_short(key1_short), .key1_long(key1_long),
      .key2_short(key2_short), .key2_long(key2_long),
      .ddr_mode(ddr_replay_mode),
      .work_mode(work_mode_ui),
      .sobel_threshold(sobel_threshold_ui),
      .shape_boxes_enable(shape_boxes_enable_ui),
      .ddr_key1_short(ddr_key1_short), .ddr_key1_long(ddr_key1_long),
      .ddr_key2_short(ddr_key2_short), .ddr_key2_long(ddr_key2_long)
    );

	axi4_ctrl #(.RECORD_FRAMES(RECORD_FRAMES), .PLAY_HOLD_FRAMES(PLAY_HOLD_FRAMES), .C_RD_END_ADDR(1920 * 1080), .C_W_WIDTH(CSI_DATA_WIDTH), .C_R_WIDTH(8), .C_ID_LEN(4)) u_axi4_ctrl (

		.axi_clk        (w_ddr3_ui_clk            ),
		.axi_reset      (w_ddr3_ui_rst            ),
        .key1_short_i(ddr_key1_short && w_ddr3_cal_done && w_ddr3_cal_pass),
        .key1_long_i(ddr_key1_long),.key2_short_i(ddr_key2_short),.key2_long_i(ddr_key2_long),
        .replay_active_o(ddr_replay_active),.ae_allow_o(ddr_ae_allow),
        .replay_mode_o(ddr_replay_mode),
        .recorded_count_o(ddr_recorded_count),.displayed_number_o(ddr_displayed_number),
        .frame_ready_o(ddr_frame_ready),

		.axi_awaddr     (w_ddr3_awaddr       ),
		.axi_awlen      (w_ddr3_awlen        ),
		.axi_awvalid    (w_ddr3_awvalid      ),
		.axi_awready    (w_ddr3_awready      ),

		.axi_wdata      (w_ddr3_wdata        ),
		.axi_wstrb      (w_ddr3_wstrb        ),
		.axi_wlast      (w_ddr3_wlast        ),
		.axi_wvalid     (w_ddr3_wvalid       ),
		.axi_wready     (w_ddr3_wready       ),

		.axi_bid        (0          ),
		.axi_bresp      (0        ),
		.axi_bvalid     (1       ),

		.axi_arid       (w_ddr3_arid         ),
		.axi_araddr     (w_ddr3_araddr       ),
		.axi_arlen      (w_ddr3_arlen        ),
		.axi_arvalid    (w_ddr3_arvalid      ),
		.axi_arready    (w_ddr3_arready      ),

		.axi_rid        (w_ddr3_rid          ),
		.axi_rdata      (w_ddr3_rdata        ),
		.axi_rresp      (0        ),
		.axi_rlast      (w_ddr3_rlast        ),
		.axi_rvalid     (w_ddr3_rvalid       ),
		.axi_rready     (w_ddr3_rready       ),

		.wframe_pclk    (w_csi_rx_clk          ),
		.wframe_vsync   (cmos_frame_vsync), //w_wframe_vsync   ),		//	Writter VSync. Flush on rising edge. Connect to EOF. 
		.wframe_data_en (cmos_frame_href   ),
		.wframe_data    (cmos_frame_Gray),
		
		.rframe_pclk    (clk_pixel_2x            ),
		.rframe_vsync   (~lcd_vs             ),		//	Reader VSync. Flush on rising edge. Connect to ~EOF. 
		.rframe_data_en (lcd_request             ),
		.rframe_data    (lcd_data           ),
		
		.tp_o 		(w_axi_tp)
	);
	//assign led_o[3:2] = 2'b11; 
	// LED3：I2C ACK错误时点亮
    assign led_o[3] = ~ae_i2c_ack_error;

    // LED2暂时关闭
    assign led_o[2] = ~ddr_replay_active; // LED2: archive being displayed
	
	
	
	////////////////////////////////////////////////////////////////
	//  LCD Timing Driver
	
	lcd_driver u_lcd_driver
	(
	    //  global clock
	    .clk        (clk_pixel_2x   ),
	    .rst_n      (rstn_pixel), 
	    
	    //  lcd interface
	    .lcd_dclk   (               ),
	    .lcd_blank  (               ),
	    .lcd_sync   (               ),
	    .lcd_request(lcd_request    ), 	//	Request data 1 cycle ahead. 
	    .lcd_hs     (lcd_hs         ),
	    .lcd_vs     (lcd_vs         ),
	    .lcd_en     (lcd_de         ),
	    .lcd_rgb    ({lcd_red2,lcd_green2,lcd_blue2, lcd_red,lcd_green,lcd_blue}),
	    
	    //  user interface
	    .lcd_data   ({{3{lcd_data[15:8]}}, {3{lcd_data[7:0]}}}  )
	);
	
	
	

	wire 			w_rgb_vsync, w_rgb_hsync, w_rgb_href; 
	wire 	[7:0] 	w_rgb_r, w_rgb_g, w_rgb_b; 
	
	VIP_RAW8_RGB888 #(.IMG_HDISP(1920), .IMG_VDISP(1080)) bayer2rgb (
		.clk				(clk_pixel_2x),                //cmos video pixel clock
		.rst_n			(rstn_pixel),              //global reset
	    
		.mirror			(0),

		    //CMOS YCbCr444 data output
		.per_frame_vsync		(lcd_vs),    //Prepared Image data vsync valid signal. Reset on falling edge. 
		.per_frame_href		(lcd_de),     //Prepared Image data href vaild  signal
		.per_frame_hsync		(lcd_hs),     //Prepared Image data href vaild  signal
		.per_img_RAW		(lcd_green),        //Prepared Image data 8 Bit RAW Data

		.post_frame_vsync		(w_rgb_vsync),   //Processed Image data vsync valid signal
		.post_frame_href		(w_rgb_href),    //Processed Image data href vaild  signal
		.post_frame_hsync		(w_rgb_hsync),    //Processed Image data href vaild  signal
		.post_img_red		(w_rgb_r),       //Prepared Image green data to be processed 
		.post_img_green		(w_rgb_g),     //Prepared Image green data to be processed
		.post_img_blue		(w_rgb_b)       //Prepared Image blue data to be processed
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	Auto White Balance (AWB): fixed gain on R/B channels
	//	Inserted between bayer2rgb and rgb2dvi to correct green-dominant Bayer output
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	wire		w_wb_vsync;
	wire		w_wb_hsync;
	wire		w_wb_de;
	wire [7:0]	w_wb_r;
	wire [7:0]	w_wb_g;
	wire [7:0]	w_wb_b;

    //初始白平衡
	rgb_white_balance #(
		.R_GAIN		(10'd320),	// 初始1.25
		.G_GAIN		(10'd256),	// 初始1.00
		.B_GAIN		(10'd384)	// 初始1.50
	) u_rgb_white_balance (
		.clk		(clk_pixel_2x),
		.rst_n		(rstn_pixel),
		.in_vsync	(w_rgb_vsync),
		.in_hsync	(w_rgb_hsync),
		.in_de		(w_rgb_href),
		.in_r		(w_rgb_r),
		.in_g		(w_rgb_g),
		.in_b		(w_rgb_b),
		.out_vsync	(w_wb_vsync),
		.out_hsync	(w_wb_hsync),
		.out_de		(w_wb_de),
		.out_r		(w_wb_r),
		.out_g		(w_wb_g),
		.out_b		(w_wb_b)
	);

	wire [7:0]  ae_mean_luma;
    wire [12:0] ae_sample_count;
    wire [15:0] ae_exposure_lines;
    wire [2:0]  ae_gain_index;
    wire        ae_update_toggle;
    wire        ae_statistics_valid;
    wire        ae_too_dark;
    wire        ae_too_bright;
    
    reg [1:0] sc2210_init_done_pixel_sync;

    always @(posedge clk_pixel_2x or negedge rstn_pixel) begin
        if (!rstn_pixel)
            sc2210_init_done_pixel_sync <= 2'b00;
        else
            sc2210_init_done_pixel_sync <= {
                sc2210_init_done_pixel_sync[0],
                sc2210_i2c_config_done
            };
    end

    wire sc2210_init_done_pixel =
        sc2210_init_done_pixel_sync[1];

    // AE holds its current exposure during ARM/REC/replay. On returning
    // live, allow eight fresh frames to refresh statistics before enabling.
    (* async_reg="true" *) reg [1:0] replay_ae_sync;
    reg replay_ae_vs_d;
    reg [3:0] replay_ae_warmup;
    always @(posedge clk_pixel_2x or negedge rstn_pixel) begin
      if(!rstn_pixel) begin replay_ae_sync<=0;replay_ae_vs_d<=0;replay_ae_warmup<=0;end
      else begin
        replay_ae_sync<={replay_ae_sync[0],ddr_ae_allow};
        replay_ae_vs_d<=w_wb_vsync;
        if(!replay_ae_sync[1]) replay_ae_warmup<=0;
        else if(w_wb_vsync&&!replay_ae_vs_d && replay_ae_warmup<8)
          replay_ae_warmup<=replay_ae_warmup+1'b1;
      end
    end
    sc2210_auto_exposure #(
        .TARGET_LOW        (8'd76),
        .TARGET_HIGH       (8'd116),
        .EXPOSURE_MIN      (16'd64),
        .EXPOSURE_MAX      (16'd1108),
        .EXPOSURE_INIT     (16'd1108),
        .GAIN_INIT_INDEX   (3'd2),
        .GAIN_MAX_INDEX    (3'd4),
        .UPDATE_INTERVAL   (16),
        .ADJUST_EXPOSURE   (1)
    ) u_sc2210_auto_exposure (
        .pclk               (clk_pixel_2x),
        .rst_n              (rstn_pixel),
        .enable             (sc2210_init_done_pixel && replay_ae_sync[1] && replay_ae_warmup==8),
        .in_vsync           (w_wb_vsync),
        .in_de              (w_wb_de),
        .in_r               (w_wb_r),
        .in_g               (w_wb_g),
        .in_b               (w_wb_b),
        .mean_luma          (ae_mean_luma),
        .sample_count_debug (ae_sample_count),
        .exposure_lines     (ae_exposure_lines),
        .gain_index         (ae_gain_index),
        .ae_update_toggle   (ae_update_toggle),
        .statistics_valid   (ae_statistics_valid),
        .too_dark           (ae_too_dark),
        .too_bright         (ae_too_bright)
    );

////////////////////////////////////////////////////////////////
// SC2210自动曝光运行时I2C
////////////////////////////////////////////////////////////////

    sc2210_ae_i2c_bridge #(
        .CLK_HZ (CLOCK_MAIN),

        .I2C_HZ (100_000)
    ) u_sc2210_ae_i2c_bridge (
        // 系统时钟域
        .clk_sys                 (clk_sys),
        .rst_n                   (rstn_sys),

        // 原初始化完成后才允许运行时写寄存器
        .init_done               (sc2210_i2c_config_done),

        // 来自像素时钟域的AE结果
        .ae_update_toggle_async  (ae_update_toggle),
        .exposure_lines_async    (ae_exposure_lines),
        .gain_index_async        (ae_gain_index),

        // 运行时I2C接口
        .i2c_scl_o               (ae_i2c_scl_o),
        .i2c_scl_oe              (ae_i2c_scl_oe),
        .i2c_sda_o               (ae_i2c_sda_o),
        .i2c_sda_oe              (ae_i2c_sda_oe),
        .i2c_sda_i               (csi_sda_i),

        // 调试状态
        .update_busy             (ae_i2c_busy),
        .ack_error_sticky        (ae_i2c_ack_error)
    );

////////////////////////////////////////////////////////////////
// 初始化I2C/自动曝光I2C复用
////////////////////////////////////////////////////////////////

// 初始化完成前：使用原初始化I2C
// 初始化完成后：切换到AE运行时I2C

    assign csi_scl_o =
        sc2210_i2c_config_done ?
        ae_i2c_scl_o :
        init_i2c_scl_o;

    assign csi_scl_oe =
        sc2210_i2c_config_done ?
        ae_i2c_scl_oe :
        1'b1;

    assign csi_sda_o =
        sc2210_i2c_config_done ?
        ae_i2c_sda_o :
        init_i2c_sda_o;

    assign csi_sda_oe =
        sc2210_i2c_config_done ?
        ae_i2c_sda_oe :
        init_i2c_sda_oe;

	
	wire ae_count_ok;

    assign ae_count_ok =
        ae_statistics_valid &&
        (ae_sample_count == 13'd4096);
	

    
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //============================================================
    // UI clock -> pixel clock synchronization for slow controls
    //============================================================
    (* async_reg="true" *) reg [2:0] work_mode_meta, work_mode_pix;
    (* async_reg="true" *) reg [7:0] threshold_meta, threshold_pix;
    (* async_reg="true" *) reg boxes_meta, boxes_pix;
    always @(posedge clk_pixel_2x or negedge rstn_pixel) begin
      if(!rstn_pixel) begin
        work_mode_meta<=0; work_mode_pix<=0;
        threshold_meta<=8'd14; threshold_pix<=8'd14;
        boxes_meta<=1'b1; boxes_pix<=1'b1;
      end else begin
        work_mode_meta<=work_mode_ui; work_mode_pix<=work_mode_meta;
        threshold_meta<=sobel_threshold_ui; threshold_pix<=threshold_meta;
        boxes_meta<=shape_boxes_enable_ui; boxes_pix<=boxes_meta;
      end
    end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	RGB TO GRAY + SOBEL 边缘检测 + 左右分屏
	//	AWB 输出 → rgb2gray → sobel_edge → gray_sobel_split → rgb2dvi
	//	AE 模块仍接 w_wb_*（旁路统计，不改变像素流）
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	wire		w_gray_vsync;
	wire		w_gray_hsync;
	wire		w_gray_de;
	wire [7:0]	w_gray_r;
	wire [7:0]	w_gray_g;
	wire [7:0]	w_gray_b;
	wire [7:0]	w_gray_data;
	
	rgb2gray #(
		.R_COEF		(10'd77),
		.G_COEF		(10'd150),
		.B_COEF		(10'd29)
	) u_rgb2gray (
		.clk		(clk_pixel_2x),
		.rst_n		(rstn_pixel),
		.in_vsync	(w_wb_vsync),
		.in_hsync	(w_wb_hsync),
		.in_de		(w_wb_de),
		.in_r		(w_wb_r),
		.in_g		(w_wb_g),
		.in_b		(w_wb_b),
		.out_vsync	(w_gray_vsync),
		.out_hsync	(w_gray_hsync),
		.out_de		(w_gray_de),
		.out_r		(w_gray_r),
		.out_g		(w_gray_g),
		.out_b		(w_gray_b),
		.out_gray	(w_gray_data)
	);
    
    wire       w_gauss_vsync;
    wire       w_gauss_hsync;
    wire       w_gauss_de;
    wire [7:0] w_gauss_gray;
    
    gray_gaussian_3x3 #(
    .IMG_HDISP (14'd1920),
    .IMG_VDISP (14'd1080)
) u_gray_gaussian_3x3 (
    .clk       (clk_pixel_2x),
    .rst_n     (rstn_pixel),

    .in_vsync  (w_gray_vsync),
    .in_hsync  (w_gray_hsync),
    .in_de     (w_gray_de),
    .in_gray   (w_gray_data),

    .out_vsync (w_gauss_vsync),
    .out_hsync (w_gauss_hsync),
    .out_de    (w_gauss_de),
    .out_gray  (w_gauss_gray)
);
    
    //==================================================================
    // Sobel边缘检测
    //==================================================================
    wire       w_sobel_vsync;
    wire       w_sobel_hsync;
    wire       w_sobel_de;

    wire [7:0] w_sobel_r;
    wire [7:0] w_sobel_g;
    wire [7:0] w_sobel_b;
    wire [7:0] w_sobel_edge;

    // 和Sobel边缘严格对齐的灰度像素
    wire [7:0] w_sobel_gray_aligned;

    // Shared runtime Sobel threshold for modes 001/002/003.
    // A threshold adjusted in mode 001 is retained when entering 003.
    wire [7:0] sobel_threshold_effective = threshold_pix;

    sobel_edge #(
        .IMG_HDISP (14'd1920),
        .IMG_VDISP (14'd1080)
    ) u_sobel_edge (
        .clk              (clk_pixel_2x),
        .rst_n            (rstn_pixel),

        .in_vsync         (w_gauss_vsync),
        .in_hsync         (w_gauss_hsync),
        .in_de            (w_gauss_de),
        .in_gray          (w_gauss_gray),
        .threshold        (sobel_threshold_effective),

        .out_vsync        (w_sobel_vsync),
        .out_hsync        (w_sobel_hsync),
        .out_de           (w_sobel_de),

        .out_r            (w_sobel_r),
        .out_g            (w_sobel_g),
        .out_b            (w_sobel_b),

        .out_edge         (w_sobel_edge),
        .out_gray_aligned (w_sobel_gray_aligned)
    );

    wire       w_clean_vsync;
    wire       w_clean_hsync;
    wire       w_clean_de;

    wire [7:0] w_clean_edge;
    wire [7:0] w_clean_gray_aligned;
    
    sobel_despike_3x3 #(
    .IMG_HDISP     (14'd1920),
    .IMG_VDISP     (14'd1080),

    // 第一次先用1，尽量保留细边缘
    .MIN_NEIGHBORS (4'd2)
) u_sobel_despike (
    .clk                 (clk_pixel_2x),
    .rst_n               (rstn_pixel),

    .in_vsync            (w_sobel_vsync),
    .in_hsync            (w_sobel_hsync),
    .in_de               (w_sobel_de),

    .in_edge             (w_sobel_edge),
    .in_gray_aligned     (w_sobel_gray_aligned),

    .out_vsync           (w_clean_vsync),
    .out_hsync           (w_clean_hsync),
    .out_de              (w_clean_de),

    .out_edge            (w_clean_edge),
    .out_gray_aligned    (w_clean_gray_aligned)
);
    
    
    //==================================================================
    // 左右分屏
    //
    // 左半屏：源画面左半部分灰度
    // 右半屏：源画面右半部分去噪后的Sobel边缘
    //==================================================================
    wire       w_split_vsync;
    wire       w_split_hsync;
    wire       w_split_de;

    wire [7:0] w_split_r;
    wire [7:0] w_split_g;
    wire [7:0] w_split_b;

    gray_sobel_split #(
    .SRC_WIDTH  (1920),
    .HALF_WIDTH (960)
) u_gray_sobel_split (
    .clk        (clk_pixel_2x),
    .rst_n      (rstn_pixel),

    .in_vsync   (w_clean_vsync),
    .in_hsync   (w_clean_hsync),
    .in_de      (w_clean_de),

    .in_gray    (w_clean_gray_aligned),
    .in_edge    (w_clean_edge),

    .out_vsync  (w_split_vsync),
    .out_hsync  (w_split_hsync),
    .out_de     (w_split_de),

    .out_r      (w_split_r),
    .out_g      (w_split_g),
    .out_b      (w_split_b)
);
    
wire [7:0]  shape2_valid;
wire [23:0] shape2_class;
wire [95:0] shape2_xmin;
wire [95:0] shape2_xmax;
wire [95:0] shape2_ymin;
wire [95:0] shape2_ymax;

wire        shape2_toggle;
wire        shape2_error;
wire        shape2_busy;
wire [15:0] shape2_skipped;
wire [15:0] shape2_components;

edge_shape_components #(
    .MAX_OBJECTS          (8),
    .MIN_EDGE             (24),
    .MIN_SIZE             (8),
    .SIDE_TOL             (3),
    .RECT_FIT_PERCENT     (82),
    .RECT_MIN_SIDE        (16),
    .RECT_MAX_ASPECT      (2),
    .RECT_MIN_BINS        (5),
    .RECT_CORNER_TOL      (4),
    .RECT_CORNER_POINTS   (1),
    .RECT_ADAPTIVE_TOL    (1),
    .RECT_SIDE_TOL_MAX    (10),
    .RECT_CORNER_TOL_MAX  (12),
    .POLY_FIT_PERCENT     (84),
    .POLY_MAX_TOL_Q8      (1280),
    .RECT_STRICT_PERCENT  (65),
    .CIRCLE_FIT_PERCENT   (74),
    .QUEUE_AW             (11),
    .POINT_AW             (11)
) u_edge_shape_components (
    .clk                   (clk_pixel_2x),
    .rst_n                 (rstn_pixel),

    // 去噪后的边缘及其同拍同步信号
    .in_vsync              (w_clean_vsync),
    .in_de                 (w_clean_de),
    .in_edge               (w_clean_edge),

    .object_valid          (shape2_valid),
    .object_class          (shape2_class),
    .object_xmin           (shape2_xmin),
    .object_xmax           (shape2_xmax),
    .object_ymin           (shape2_ymin),
    .object_ymax           (shape2_ymax),

    .result_toggle         (shape2_toggle),
    .frame_error           (shape2_error),
    .skipped_frames        (shape2_skipped),
    .component_count_debug (shape2_components),
    .analysis_busy         (shape2_busy)
);

//============================================================
// 分屏画面叠加识别颜色
// 使用优化后的 edge_shape_boxes.v：删除逐像素面积乘法/最小面积比较，
// 采用流水处理，仅给实际边缘像素按类别着色，不画黄色框。
// 模块端口保持不变，因此顶层连接无需改动。
//============================================================
wire       shape2_vsync;
wire       shape2_hsync;
wire       shape2_de;
wire [7:0] shape2_r;
wire [7:0] shape2_g;
wire [7:0] shape2_b;

edge_shape_boxes #(
    .MAX_OBJECTS (8)
) u_edge_shape_boxes (
    .clk         (clk_pixel_2x),
    .rst_n       (rstn_pixel),

    .in_vsync    (w_split_vsync),
    .in_hsync    (w_split_hsync),
    .in_de       (w_split_de),
    .in_r        (w_split_r),
    .in_g        (w_split_g),
    .in_b        (w_split_b),

    .object_valid(shape2_valid),
    .object_class(shape2_class),
    .object_xmin (shape2_xmin),
    .object_xmax (shape2_xmax),
    .object_ymin (shape2_ymin),
    .object_ymax (shape2_ymax),

    .out_vsync   (shape2_vsync),
    .out_hsync   (shape2_hsync),
    .out_de      (shape2_de),
    .out_r       (shape2_r),
    .out_g       (shape2_g),
    .out_b       (shape2_b)
);
    
    

    //==================================================================
    // Mode 003: LP40111 plate-hole geometry inspection
    // Uses the same cleaned Sobel edge map as modes 001/002.
    // The three modules below are the user's already verified geometry chain.
    // Analysis is enabled only while mode 003 is selected.
    //==================================================================
    // Mode 003: keep plate inspection independent of DDR/AE replay state.
    // AE/replay gating belongs to exposure control and must not suppress
    // the plate-analysis / diagnostic-overlay chain.
    // Run the verified plate analysis continuously after camera/AE warm-up,
    // as in the known-good version. Only the overlay is shown in mode 003.
    wire plate_analysis_enable = sc2210_init_done_pixel &&
                                 replay_ae_sync[1] &&
                                 (replay_ae_warmup == 4'd8);
    wire plate_show_enable = (work_mode_pix == 3'd3);

    wire plate_features_ready, plate_done, plate_busy, plate_error, plate_map_bit;
    wire [4:0] plate_hole_count, plate_result_holes;
    wire [175:0] plate_hole_x, plate_hole_y;
    wire [127:0] plate_hole_diameter;
    wire [17:0] plate_map_addr;
    wire [15:0] plate_skipped;
    wire plate_detected, plate_passed, plate_toggle;
    wire [3:0] plate_fault;
    wire [11:0] plate_box_valid;
    wire [143:0] plate_xmin, plate_xmax, plate_ymin, plate_ymax;

    plate_edge_features u_plate_edge_features (
        .clk(clk_pixel_2x), .rst_n(rstn_pixel), .enable(plate_analysis_enable),
        .in_vsync(w_clean_vsync), .in_de(w_clean_de), .in_edge(w_clean_edge),
        .features_ready(plate_features_ready), .hole_count(plate_hole_count),
        .hole_x(plate_hole_x), .hole_y(plate_hole_y), .hole_diameter(plate_hole_diameter),
        .client_done(plate_done), .client_addr(plate_map_addr), .client_bit(plate_map_bit),
        .busy(plate_busy), .analysis_error(plate_error), .skipped_frames(plate_skipped)
    );

    // Timing-pipelined plate_geometry_check uses the same external interface
    // and the same geometry/tolerance semantics as the verified version.
    plate_geometry_check #(
        .POSITION_TOL_MM(3),
        .MIN_MISS_RUN(4),
        .MAX_MISSING_PERCENT(8)
    ) u_plate_geometry_check (
        .clk(clk_pixel_2x), .rst_n(rstn_pixel),
        .start(plate_features_ready), .source_error(plate_error),
        .hole_count(plate_hole_count), .hole_x(plate_hole_x),
        .hole_y(plate_hole_y), .hole_diameter(plate_hole_diameter),
        .done(plate_done), .map_addr(plate_map_addr), .map_bit(plate_map_bit),
        .detected(plate_detected), .passed(plate_passed),
        .result_toggle(plate_toggle), .fault_code(plate_fault),
        .result_hole_count(plate_result_holes),
        .box_valid(plate_box_valid), .box_xmin(plate_xmin), .box_xmax(plate_xmax),
        .box_ymin(plate_ymin), .box_ymax(plate_ymax)
    );

    wire plate_vsync, plate_hsync, plate_de;
    wire [7:0] plate_r, plate_g, plate_b;

    plate_geometry_overlay u_plate_geometry_overlay (
        .clk(clk_pixel_2x), .rst_n(rstn_pixel), .show_enable(plate_show_enable),
        .in_vsync(w_split_vsync), .in_hsync(w_split_hsync), .in_de(w_split_de),
        .in_r(w_split_r), .in_g(w_split_g), .in_b(w_split_b),
        .detected(plate_detected), .passed(plate_passed), .result_toggle(plate_toggle),
        .raw_fault(plate_fault), .hole_count(plate_result_holes),
        .box_valid(plate_box_valid), .box_xmin(plate_xmin), .box_xmax(plate_xmax),
        .box_ymin(plate_ymin), .box_ymax(plate_ymax),
        .out_vsync(plate_vsync), .out_hsync(plate_hsync), .out_de(plate_de),
        .out_r(plate_r), .out_g(plate_g), .out_b(plate_b)
    );

	//	LVDS Output 
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	HDMI requires specific timing, thus is not compatible with LCD & LVDS & DSI. Must implement standalone. 
	
    //============================================================
    // Video mode MUX:
    // 000 RGB, 001 Gray|Sobel, 002 Shape, 003 Plate geometry, 004~006 DDR
    //============================================================
    reg mode_vsync, mode_hsync, mode_de;
    reg [7:0] mode_r, mode_g, mode_b;
    always @* begin
      mode_vsync=w_wb_vsync; mode_hsync=w_wb_hsync; mode_de=w_wb_de;
      mode_r=w_wb_r; mode_g=w_wb_g; mode_b=w_wb_b;
      case(work_mode_pix)
        3'd0: begin
          mode_vsync=w_wb_vsync; mode_hsync=w_wb_hsync; mode_de=w_wb_de;
          mode_r=w_wb_r; mode_g=w_wb_g; mode_b=w_wb_b;
        end
        3'd1: begin
          mode_vsync=w_split_vsync; mode_hsync=w_split_hsync; mode_de=w_split_de;
          mode_r=w_split_r; mode_g=w_split_g; mode_b=w_split_b;
        end
        3'd2: begin
          if(boxes_pix) begin
            mode_vsync=shape2_vsync; mode_hsync=shape2_hsync; mode_de=shape2_de;
            mode_r=shape2_r; mode_g=shape2_g; mode_b=shape2_b;
          end else begin
            mode_vsync=w_split_vsync; mode_hsync=w_split_hsync; mode_de=w_split_de;
            mode_r=w_split_r; mode_g=w_split_g; mode_b=w_split_b;
          end
        end
        3'd3: begin
          mode_vsync=plate_vsync; mode_hsync=plate_hsync; mode_de=plate_de;
          mode_r=plate_r; mode_g=plate_g; mode_b=plate_b;
        end
        3'd4: begin
          // Preserve the previously verified DDR display source.
          mode_vsync=shape2_vsync; mode_hsync=shape2_hsync; mode_de=shape2_de;
          mode_r=shape2_r; mode_g=shape2_g; mode_b=shape2_b;
        end
        default: begin
          mode_vsync=w_wb_vsync; mode_hsync=w_wb_hsync; mode_de=w_wb_de;
          mode_r=w_wb_r; mode_g=w_wb_g; mode_b=w_wb_b;
        end
      endcase
    end

    wire replay_osd_vs,replay_osd_hs,replay_osd_de;
    wire [7:0] replay_osd_r,replay_osd_g,replay_osd_b;
    replay_status_osd_mode #(.TOTAL_FRAMES(RECORD_FRAMES)) u_replay_status_osd (
      .ui_clk(w_ddr3_ui_clk),.ui_reset(w_ddr3_ui_rst),
      .enable_ui(work_mode_ui==3'd4),
      .mode_ui(ddr_replay_mode),.count_ui(ddr_recorded_count),.number_ui(ddr_displayed_number),
      .pclk(clk_pixel_2x),.rst_n(rstn_pixel),
      .in_vsync(mode_vsync),.in_hsync(mode_hsync),.in_de(mode_de),
      .in_r(mode_r),.in_g(mode_g),.in_b(mode_b),
      .out_vsync(replay_osd_vs),.out_hsync(replay_osd_hs),.out_de(replay_osd_de),
      .out_r(replay_osd_r),.out_g(replay_osd_g),.out_b(replay_osd_b)
    );

    wire mode_num_vs,mode_num_hs,mode_num_de;
    wire [7:0] mode_num_r,mode_num_g,mode_num_b;
    mode_number_osd u_mode_number_osd (
      .pclk(clk_pixel_2x),.rst_n(rstn_pixel),
      .work_mode(work_mode_pix),.ddr_mode(ddr_replay_mode),.threshold(threshold_pix),
      .in_vsync(replay_osd_vs),.in_hsync(replay_osd_hs),.in_de(replay_osd_de),
      .in_r(replay_osd_r),.in_g(replay_osd_g),.in_b(replay_osd_b),
      .out_vsync(mode_num_vs),.out_hsync(mode_num_hs),.out_de(mode_num_de),
      .out_r(mode_num_r),.out_g(mode_num_g),.out_b(mode_num_b)
    );

	assign hdmi_txd0_rst_o = rst_pixel; 
	assign hdmi_txd1_rst_o = rst_pixel; 
	assign hdmi_txd2_rst_o = rst_pixel; 
	assign hdmi_txc_rst_o = rst_pixel; 
	
	assign hdmi_txd0_oe = 1'b1; 
	assign hdmi_txd1_oe = 1'b1; 
	assign hdmi_txd2_oe = 1'b1; 
	assign hdmi_txc_oe = 1'b1; 
	
	//-------------------------------------
	//Digilent HDMI-TX IP Modified by CB elec.
	rgb2dvi #(.ENABLE_OSERDES(0)) u_rgb2dvi 
	(
		.oe_i 		(1), 			//	Always enable output
		.bitflip_i 		(4'b0000), 		//	Reverse clock & data lanes. 
		
		.aRst			(1'b0), 
		.aRst_n		(1'b1), 
		
		.PixelClk		(clk_pixel_2x        ),//pixel clk = 74.25M
		.SerialClk		(     ),//pixel clk *5 = 371.25M
		
		.vid_pVSync		(mode_num_vs), 
		.vid_pHSync		(mode_num_hs), 
		.vid_pVDE		(mode_num_de), 
		.vid_pData		({mode_num_r,mode_num_g,mode_num_b}), 
		
		.txc_o		(hdmi_txc_o), 
		.txd0_o		(hdmi_txd0_o), 
		.txd1_o		(hdmi_txd1_o), 
		.txd2_o		(hdmi_txd2_o)
	); 
			
	
	
endmodule



// Active-low key; short event on release, one long event per hold.
module freeze_key_filter #(
 parameter integer CLK_HZ=96000000,
 parameter integer DEBOUNCE_MS=20,
 parameter integer LONG_MS=1000
)(input wire clk,reset,key_n,
 output wire pressed,output reg short_pulse,output reg long_pulse);
 localparam integer DB_TICKS=(CLK_HZ/1000)*DEBOUNCE_MS;
 localparam integer LONG_TICKS=(CLK_HZ/1000)*LONG_MS;
 (* async_reg="true" *) reg key_meta,key_sync;
 reg stable_n,long_sent;
 reg [31:0] db_count,hold_count;
 assign pressed=~stable_n;
 always @(posedge clk or posedge reset) begin
  if(reset) begin key_meta<=1;key_sync<=1;end
  else begin key_meta<=key_n;key_sync<=key_meta;end
 end
 always @(posedge clk or posedge reset) begin
  if(reset) begin
   stable_n<=1;long_sent<=0;db_count<=0;hold_count<=0;
   short_pulse<=0;long_pulse<=0;
  end else begin
   short_pulse<=0;long_pulse<=0;
   if(key_sync==stable_n) db_count<=0;
   else if(db_count>=DB_TICKS-1) begin
    db_count<=0;stable_n<=key_sync;
   end else db_count<=db_count+1'b1;
   if(stable_n) begin hold_count<=0;long_sent<=0;end
   else if(key_sync && db_count>=DB_TICKS-1) begin
    if(!long_sent) short_pulse<=1;
    hold_count<=0;
   end else if(!long_sent) begin
    if(hold_count>=LONG_TICKS-1) begin
     long_pulse<=1;long_sent<=1;
    end else hold_count<=hold_count+1'b1;
   end
  end
 end
endmodule
