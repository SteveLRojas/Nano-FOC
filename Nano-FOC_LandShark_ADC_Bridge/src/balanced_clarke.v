`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Esteban Looser-Rojas (ELR)
// 
// Create Date:    14:10:50 03/21/2023
// Design Name:    balanced_clarke
// Module Name:    balanced_clarke
// Project Name:   Nano-FOC
// Target Devices: Cyclone IV, Cyclone 10, MAX 10
// Tool versions:  ISE 14.7, Quartus 19.1 Lite
// Description:    Balanced Clarke transformation.
//
// Dependencies: None.
//
// Revision: 
// Revision 0.01 - File Created
// Revision 1.00 - Design completed.
// Revision 1.10 - Design parameterized.
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module balanced_clarke
	#(
		parameter NUM_BITS = 14
	)
	(
		input wire clk,
		input wire rst,
		input trig,
		input wire signed[NUM_BITS - 1 : 0] in_u,
		input wire signed[NUM_BITS - 1 : 0] in_v,
		input wire signed[NUM_BITS - 1 : 0] in_w,
		output reg signed[NUM_BITS - 1 : 0] alpha,
		output reg signed[NUM_BITS - 1 : 0] beta,
		output reg done
	);
// alpha = (2/3) * (in_u - (1/2) * in_v - (1/2) * in_w)
// beta = (2/3) * ((sqrt(3) / 2) * in_v - (sqrt(3) / 2) * in_w)

// alpha = (1/3) * (2 * in_u - in_v - in_w)
// beta = (sqrt(3)/3) * (in_v - in_w)
	localparam[63:0] SQRT3_BY_3 = 64'd5325116328314171701;	//2^63 * sqrt(3) / 3
	localparam[63:0] ONE_THIRD = 64'h5555555555555555;	//2^64 / 3

	reg[3:0] state;
	reg signed[NUM_BITS + 1 : 0] alpha_t1;
	
	reg signed[NUM_BITS + 1 : 0] mul_in_a;
	reg signed[NUM_BITS + 1 : 0] mul_in_b;
	reg signed[2 * (NUM_BITS + 2) - 1 : 0] mul_res;
	
	localparam S_CALC1 = 4'h0;
	localparam S_CALC2 = 4'h1;
	localparam S_CLIP_BETA = 4'h2;
	localparam S_CLIP_ALPHA = 4'h3;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			alpha <= {NUM_BITS{1'b0}};
			beta <= {NUM_BITS{1'b0}};
			done <= 1'b0;
			state <= S_CALC1;
			alpha_t1 <= {(NUM_BITS + 2){1'b0}};
			mul_in_a <= {(NUM_BITS + 2){1'b0}};
			mul_in_b <= {(NUM_BITS + 2){1'b0}};
			mul_res <= {(2 * (NUM_BITS + 2)){1'b0}};
		end
		else
		begin
			mul_res <= mul_in_a * mul_in_b;
			
			case(state)
				S_CALC1:
				begin
					done <= 1'b0;
					alpha_t1 <= {in_u[NUM_BITS - 1], in_u[NUM_BITS - 1 : 0], 1'b0} - {{2{in_v[NUM_BITS - 1]}}, in_v[NUM_BITS - 1 : 0]};	// 2 * in_u - in_v
					mul_in_a <= {{2{in_v[NUM_BITS - 1]}}, in_v[NUM_BITS - 1 : 0]} - {{2{in_w[NUM_BITS - 1]}}, in_w[NUM_BITS - 1 : 0]};	// in_v - in_w
					mul_in_b <= SQRT3_BY_3[63 : 64 - NUM_BITS - 2];
					if(trig)
						state <= S_CALC2;
				end
				S_CALC2:
				begin
					mul_in_a <= alpha_t1 - {{2{in_w[NUM_BITS - 1]}}, in_w[NUM_BITS - 1 : 0]};	// 2 * in_u - in_v - in_w
					mul_in_b <= ONE_THIRD[63 : 64 - NUM_BITS - 2];
					state <= S_CLIP_BETA;
				end
				S_CLIP_BETA:
				begin
					if(&mul_res[NUM_BITS * 2 + 2 : NUM_BITS * 2] || ~|mul_res[NUM_BITS * 2 + 2 : NUM_BITS * 2])
						beta <= mul_res[NUM_BITS * 2 : NUM_BITS + 1];
					else
						beta <= {mul_res[2 * (NUM_BITS + 2) - 1], {(NUM_BITS - 1){~mul_res[2 * (NUM_BITS + 2) - 1]}}};
					state <= S_CLIP_ALPHA;
				end
				S_CLIP_ALPHA:
				begin
					if(&mul_res[NUM_BITS * 2 + 3 : NUM_BITS * 2 + 1] || ~|mul_res[NUM_BITS * 2 + 3 : NUM_BITS * 2 + 1])
						alpha <= mul_res[NUM_BITS * 2 + 1 : NUM_BITS + 2];
					else
						alpha <= {mul_res[2 * (NUM_BITS + 2) - 1], {(NUM_BITS - 1){~mul_res[2 * (NUM_BITS + 2) - 1]}}};
					done <= 1'b1;
					state <= S_CALC1;
				end
				default: ;
			endcase
		end
	end
endmodule
