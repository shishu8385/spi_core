`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SCiMOS
// Engineer: Vipin.vc  (veeYceeY)
// 
// Create Date:    21:06:56 01/25/2017 
// Design Name: 
// Module Name:    spi_v2 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module spi_v2(
				clk_i,rst_i,cpol_i,cpha_i,start_i,miso_i,mosi_o,sck_o,ss_o,txdata_i,rxdata_o,buzy
    );

	parameter DATA_SIZE 		= 8;    //Data size to be operated on
	
	input 		clk_i;								//input clock for core
	input 		rst_i;								//asynchronous reset 
	input 		cpol_i;								//Clock polarity selection
	input 		cpha_i;								//Clock phase selection 
	input			start_i; 							//start one data transfer cycle
	input 		miso_i;								//MISO master in slave out
	output reg	mosi_o;								//MOSI master out slave in
	output 		sck_o;								//MOSI master out slave in
	output reg	ss_o;								//spi clock
	input			[DATA_SIZE-1:0] txdata_i;		//data input to be transmitted
	output reg	[DATA_SIZE-1:0] rxdata_o;		//data oputput to be transmitted
	output 		buzy;//core buzy
	
	reg[5:0] state;
	reg [7:0] count;
	reg [1:0]start_reg;
	parameter IDLE			=6'b000001;
	parameter SCKALIGN	=6'b000010;
	parameter START		=6'b000100;
	parameter REST			=6'b001000;
	parameter STOP			=6'b010000;
	parameter END			=6'b100000;
	
	parameter MAX_COUNT = DATA_SIZE*2;
	
	reg [DATA_SIZE-1:0] 	tx_buff,rx_buff;
	reg sck_t,sckn_t;
	wire sck_s;
	reg clk_align;
	reg tx_en,tx_load,rx_en,rx_load,rx_load_d,tx_load_d;
	wire tx_load_s,rx_load_s;
	reg start_rst;
	wire start_lth;
	reg ss_d;
/////////////////////////////////////////////////////////////////	
	always@(posedge clk_i) begin :st_machine
		if(~rst_i) begin			
			ss_d		<=1'b1;
			rx_load	<=1'b0;
			tx_load	<=1'b0;
			tx_en		<=1'b0;
			rx_en		<=1'b0;
			clk_align<=1'b0;
			state<=IDLE;
		end else begin
			case (state)
			IDLE: begin
				ss_d		<=1'b1;
				rx_load	<=1'b0;
				tx_load	<=1'b0;
				tx_en		<=1'b0;
				rx_en		<=1'b0;
				clk_align<=1'b1;
				if(start_lth) begin
					state		<=SCKALIGN;
				end else begin
					state		<=IDLE;
				end
			end
			SCKALIGN: begin
				clk_align<=1'b0;
				tx_load	<=1'b1;
				state<=START;
			end
			START: begin
				ss_d		<=1'b0;
				tx_en		<=1'b1;
				rx_en		<=1'b1;
				tx_load	<=1'b1;
				clk_align<=1'b1;
				count<=0;
				state<=REST;
			end
			REST: begin
				clk_align<=1'b1;
				tx_load	<=1'b0;
				if(count<MAX_COUNT-1) begin
					count<=count+1;
				end else begin
					state<=STOP;
				end
			end
			STOP: begin
				ss_d<=1'b1;
				rx_load<=1'b1;
				state<=END;
			end
			END: begin
				state<=IDLE;
			end
			endcase
		end
	end
	assign buzy=~ss_o;
	///////////////////////////////start detector/////////////////////////////////////////
	always@(posedge clk_i or negedge rst_i) begin
		if(!rst_i) begin
			start_reg<=2'b11;
		end else begin
			start_reg<={start_reg[0],start_i};
		end
	end
	assign start_lth=start_reg==2'b01;
	/////////////////////////////RX and TX shift registers////////////////////////////////
	//////////////////TX/////////////////////////////
	always@(negedge sck_s or posedge tx_load_s) begin :tx_shifter
		if(tx_load_s) begin
				tx_buff<=txdata_i;
		end else begin
			if(tx_load_s) begin
				
			end else begin
				tx_buff<={1'b0,tx_buff[DATA_SIZE-1:1]};
				mosi_o<=tx_buff[0];
			end
		end
	end
	//assign mosi = tx_buff[0];
	/////////////////////////////////////////////////
	////////////////RX///////////////////////////////
	always@(posedge(sck_s) or negedge(rst_i) ) begin :rx_shifter
		if(~rst_i) begin
			rxdata_o<=0;
			rx_buff<=0;
		end else begin
			if(rx_load_s) begin
				rxdata_o<=rx_buff;
			end else begin
				rx_buff<={miso_i,rx_buff[DATA_SIZE-1:1]};
			end
		end
	end
	//////////////////////////////////////////////////////////////////////////////////////////
	
	////////////////////////////SCK generator/////////////////////////////////////////////////
	always@(posedge clk_i or negedge clk_align) begin
		if(~clk_align) begin
			sck_t<=1'b0;
			sckn_t<=1'b1;
		end else begin
			sck_t<=~sck_t;
			sckn_t<=~sckn_t;
		end
	end
	//////////////////////////Clock selectors//////////////////////////////////////////////////
	assign S = cpol_i ^ cpha_i;
	BUFGMUX BUFGMUX_sck_s (
		.O		(sck_s),
		.I0	(sckn_t),
		.I1	(sck_t),
		.S		(cpha_i)
	);
	BUFGMUX BUFGMUX_scko (
		.O		(sck_o),
		.I0	(sckn_t),
		.I1	(sck_t),
		.S		(cpol_i)
	);
	////////////////////////////////////slave select delay////////////////////////////////////////////
	
	always@(posedge clk_i or negedge rst_i) begin
		if(~rst_i) begin
			ss_o<=1'b1;
		end else begin
			ss_o<=ss_d;
		end
	end
	
	////////////////////load signal shift////////
	always@(posedge clk_i or negedge rst_i) begin
		if(~rst_i) begin
			rx_load_d<=1'b0;
			tx_load_d<=1'b0;
		end else begin
			rx_load_d<=rx_load;
			tx_load_d<=tx_load;
		end
	end
	MUXCY MUXCY_tlphase (
		.O		(tx_load_s),
		.DI	(tx_load), 
		.CI	(tx_load_d),
		.S		(cpha_i)
	);
	MUXCY MUXCY_rlphase (
		.O		(rx_load_s),
		.DI	(rx_load),
		.CI	(rx_load_d),
		.S		(cpha_i)
	);
	//////////////////////////////////////////////////////////////////////////////////////////////
endmodule
