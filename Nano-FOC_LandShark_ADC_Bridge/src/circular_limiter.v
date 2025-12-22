`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    10:51:55 12/20/2025 
// Design Name:    circular_limiter
// Module Name:    circular_limiter 
// Project Name:   ip_dev
// Target Devices: Virtex-II Pro, Cyclone IV, Cyclone V, Cyclone 10, MAX 10
// Tool versions:  ISE 10.1, Quartus 19.1 Lite
// Description:    Limits vector length to fit the number of bits without changing the angle.
//
// Dependencies:   inv_sqrt_restoring.v
//
// Revision: 1.00
// Revision 0.01 - File Created.
// Revision 1.00 - Design completed.
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module circular_limiter
	#(
		parameter NUM_BITS = 14,
		parameter LOG_NUM_SQRT_BITS = 5	//$clog2(NUM_BITS * 2 - 2)
	)
	(
		input wire clk,
		input wire rst,
		input wire trig,
		input wire signed[NUM_BITS - 1 : 0] x_in,
		input wire signed[NUM_BITS - 1 : 0] y_in,
		output reg signed[NUM_BITS - 1 : 0] x_out,
		output reg signed[NUM_BITS - 1 : 0] y_out,
		output reg done
    );
	
	reg[1:0] sqr_state;
	reg sqr_done;
	reg signed[NUM_BITS - 1 : 0] sqr_in;
	reg[NUM_BITS * 2 - 2 : 0] x_sqr;
	reg[NUM_BITS * 2 - 2 : 0] y_sqr;
	wire signed[NUM_BITS * 2 - 1 : 0] sqr_out;
	
	assign sqr_out = sqr_in * sqr_in;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			sqr_state <= 2'b0;
			sqr_done <= 1'b0;
			sqr_in <= {NUM_BITS{1'b0}};
			x_sqr <= {(NUM_BITS * 2 - 1){1'b0}};
			y_sqr <= {(NUM_BITS * 2 - 1){1'b0}};
		end
		else
		begin
			sqr_state <= {sqr_state[0], ~|sqr_state & trig};
			sqr_in <= sqr_state[0] ? y_in : x_in;
			if(sqr_state[0])
				x_sqr <= sqr_out[NUM_BITS * 2 - 2 : 0];
			if(sqr_state[1])
				y_sqr <= sqr_out[NUM_BITS * 2 - 2 : 0];
			sqr_done <= sqr_state[1];
		end
	end
	
	wire[NUM_BITS * 2 - 1 : 0] sum_sqr;
	wire[NUM_BITS * 2 - 3 : 0] inv_sqrt_res;
	wire inv_sqrt_done;
	
	assign sum_sqr = x_sqr + y_sqr;
	
	inv_sqrt_restoring
	#(
		.NUM_INPUT_BITS(NUM_BITS * 2),
		.NUM_OUTPUT_BITS(NUM_BITS * 2 - 2),
		.LOG_NUM_OUT_BITS(LOG_NUM_SQRT_BITS)
	) inv_sqrt_restoring_i
	(
		.clk(clk),
		.rst(rst),
		.trig(sqr_done),
		.radicand(sum_sqr),
		.quotient(inv_sqrt_res),
		.done(inv_sqrt_done)
	);
	
	reg[NUM_BITS - 1 : 0] scaling_factor;
	reg signed[NUM_BITS - 1 : 0] scale_in;
	reg[1:0] scale_state;
	wire signed[NUM_BITS * 2 : 0] scale_out;
	wire scale_clip;
	
	assign scale_out = $signed({1'b0, scaling_factor}) * scale_in;
	assign scale_clip = |inv_sqrt_res[NUM_BITS * 2 - 3 : NUM_BITS - 1];
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			x_out <= {NUM_BITS{1'b0}};
			y_out <= {NUM_BITS{1'b0}};
			done <= 1'b0;
			scaling_factor <= {NUM_BITS{1'b0}};
			scale_in <= {NUM_BITS{1'b0}};
			scale_state <= 2'b00;
		end
		else
		begin
			scaling_factor <= {scale_clip, {(NUM_BITS - 1){~scale_clip}} & inv_sqrt_res[NUM_BITS - 2 : 0]};
			scale_state <= {scale_state[0], inv_sqrt_done};
			scale_in <= scale_state[0] ? y_in : x_in;
			if(scale_state[0])
				x_out <= scale_out[NUM_BITS * 2 - 2 : NUM_BITS - 1];
			if(scale_state[1])
				y_out <= scale_out[NUM_BITS * 2 - 2 : NUM_BITS - 1];
			done <= scale_state[1];
		end
	end

endmodule
