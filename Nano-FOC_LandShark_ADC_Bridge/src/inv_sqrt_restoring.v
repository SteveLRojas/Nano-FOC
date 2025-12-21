`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    15:59:36 11/22/2025 
// Design Name:    inv_sqrt_restoring
// Module Name:    inv_sqrt_restoring
// Project Name:   ip_dev
// Target Devices: Virtex-II Pro, Spartan 3E, Spartan 6, Cyclone II, Cyclone IV
// Tool versions:  ISE 10.1, ISE 14.7
// Description:    Restoring shift/subtract integer inverse square root calculation.
//
// Dependencies:   None.
//
// Revision: 1.01
// Revision 0.01 - File Created.
// Revision 1.00 - Optimization complete.
// Revision 1.01 - Trimmed rad_res_accum, rewrite test_res to allow multi-operand optimizations.
// Additional Comments: 
//	Let W = Z ^ (-1 / 2) or equivalently 1 / sqrt(Z).
//	W may be computed digit-by-digit:
//		W = sum_{i=1..n} (w_i * 2 ^ -i), w_i in {0,1}.
//	Using the identity:
//		W ^ 2 * Z = 1.
//	During iteration we maintain a residual R_j:
//		R_j = 1 - Z * W_j ^ 2,
//	where W_j is the j-digit approximation:
//		W_j = W_(j - 1) + w_j * 2 ^ -j.
//	The recurrence is derived by expanding:
//		W_j ^ 2 = (W_(j - 1) + w_j * 2^-j) ^ 2
//		W_j ^ 2 = W_(j - 1) ^ 2 + 2 * W_(j - 1) * w_j * 2 ^ -j + w_j ^ 2 * 2 ^ (-2 * j).
//	Plugging this into the residual we get:
//		R_j = 1 - Z * (W_(j - 1) ^ 2 + 2 * W_(j - 1) * w_j * 2 ^ -j + w_j ^ 2 * 2 ^ (-2 * j)).
//		R_j = 1 - Z * W_(j - 1) ^ 2 - Z * 2 * W_(j - 1) * w_j * 2 ^ -j - Z * w_j ^ 2 * 2 ^ (-2 * j).
//	Noting the equality:
//		R_(j - 1) = 1 - Z * W_(j - 1) ^ 2
//	We can rewrite R_j as:
//		R_j = R_(j - 1) - Z * 2 * W_(j - 1) * w_j * 2 ^ -j - Z * w_j ^ 2 * 2 ^ (-2 * j).
//		R_j = R_(j - 1) - Z * (2 * W_(j - 1) * w_j * 2 ^ -j + w_j ^ 2 * 2 ^ (-2 * j)).
//	Because w_j is in {0,1} w_j ^ 2 can be replaced with w_j.
//
//	To decide the digit w_j, we tentatively test the case where w_j = 1:
//		R_tilde_j = R_(j - 1) - Z * (2 * W_(j - 1) * 2 ^ -j + 2 ^ (-2 * j)).
//	Then:
//		If R_tilde_j >= 0, choose w_j = 1 and set R_j = R_tilde_j.
//		Else choose w_j = 0 and set R_j = R_(j - 1).
//
//	Implementation notes for the term Z * 2 * W_(j - 1) * w_j * 2 ^ -j:
//	Let X_j = 2 ^ -j.
//		X_j = X_(j - 1) / 2.
//	Let T_j = Z * W_j * X_j.
//	Plugging in W_j = W_(j - 1) + w_j * 2 ^ -j and X_j = X_(j - 1) / 2:
//		T_j = Z * (W_(j - 1) + w_j * 2 ^ -j) * (X_(j - 1) / 2).
//		T_j = (Z * W_(j - 1) + Z * w_j * 2 ^ -j) * (X_(j - 1) / 2).
//		T_j = Z * W_(j - 1) * X_(j - 1) / 2 + Z * w_j * 2 ^ -j * X_(j - 1) / 2.
//	Noting that T_(j - 1) = Z * W_(j - 1) * X_(j - 1) and plugging in X_(j - 1) / 2 = 2 ^ -j:
//		T_j = T_(j - 1) / 2 + Z * w_j * 2 ^ -j * 2 ^ -j.
//		T_j = T_(j - 1) / 2 + Z * w_j * 2 ^ (-2 * j).
//	We can now replace the term Z * 2 * W_(j - 1) * w_j * 2 ^ -j with T_(j - 1) * w_j noting that:
//		T_(j - 1) = Z * W_(j - 1) * X_(j - 1).
//		T_(j - 1) = Z * W_(j - 1) * 2 * 2 ^ -j.
//		T_(j - 1) * w_j = Z * 2 * W_(j - 1) * w_j * 2 ^ -j.
//	Plugging into the residual and trial residual we get the final expressions:
//		R_j = R_(j - 1) - T_(j - 1) * w_j - Z * w_j ^ 2 * 2 ^ (-2 * j).
//		R_tilde_j = R_(j - 1) - T_(j - 1) - Z * 2 ^ (-2 * j).
//////////////////////////////////////////////////////////////////////////////////
module inv_sqrt_restoring
	#(
		parameter NUM_INPUT_BITS = 32,
		parameter NUM_OUTPUT_BITS = 16,
		parameter LOG_NUM_OUT_BITS = 4
	)(
		input wire clk,
		input wire rst,
		input wire trig,
		input wire[NUM_INPUT_BITS - 1 : 0] radicand,
		output reg[NUM_OUTPUT_BITS - 1 : 0] quotient,
		output reg done
	);
	//HINT: rad_res_accum remains 0 until radicand_shift is <= partial_remainder.
	// rad_res_accum accumulates radicand_shift, it only needs to have 1 more bit than partial_remainder.
	
	reg[NUM_INPUT_BITS + 2 * NUM_OUTPUT_BITS - 3 : 0] radicand_shift;
	reg[2 * NUM_OUTPUT_BITS + 1 : 0] rad_res_accum;
	reg[2 * NUM_OUTPUT_BITS : 0] partial_remainder;
	reg[LOG_NUM_OUT_BITS - 1 : 0] count;
	reg active;
	
	wire[LOG_NUM_OUT_BITS : 0] initial_count;
	//wire[NUM_INPUT_BITS + 2 * NUM_OUTPUT_BITS - 2 : 0] test_res_i;
	wire[NUM_INPUT_BITS + 2 * NUM_OUTPUT_BITS - 2 : 0] test_res;
	assign initial_count = NUM_OUTPUT_BITS[LOG_NUM_OUT_BITS : 0] - {{LOG_NUM_OUT_BITS{1'b0}}, 1'b1};
	//assign test_res_i = rad_res_accum + radicand_shift;
	//assign test_res = partial_remainder - test_res_i;
	assign test_res = partial_remainder - rad_res_accum - radicand_shift;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			quotient <= {NUM_OUTPUT_BITS{1'b0}};
			done <= 1'b0;
			radicand_shift <= {(NUM_INPUT_BITS + 2 * NUM_OUTPUT_BITS - 2){1'b0}};
			rad_res_accum <= {(2 * NUM_OUTPUT_BITS + 2){1'b0}};
			partial_remainder <= {(2 * NUM_OUTPUT_BITS + 1){1'b0}};
			count <= {LOG_NUM_OUT_BITS{1'b0}};
			active <= 1'b0;
		end
		else
		begin
			done <= active & ~|count;
			
			if(trig | active)
			begin
				active <= |count | trig;
				
				if(active)
				begin
					quotient <= {quotient[NUM_OUTPUT_BITS - 2 : 0], ~test_res[NUM_INPUT_BITS + 2 * NUM_OUTPUT_BITS - 2]};
					radicand_shift <= {2'b00, radicand_shift[NUM_INPUT_BITS + 2 * NUM_OUTPUT_BITS - 3 : 2]};
					
					if(~test_res[NUM_INPUT_BITS + 2 * NUM_OUTPUT_BITS - 2])
					begin
						partial_remainder <= test_res[2 * NUM_OUTPUT_BITS : 0];
						rad_res_accum <= {1'b0, rad_res_accum[2 * NUM_OUTPUT_BITS + 1 : 1]} + radicand_shift[2 * NUM_OUTPUT_BITS + 1 : 0];
					end
					else
					begin
						rad_res_accum <= {1'b0, rad_res_accum[2 * NUM_OUTPUT_BITS + 1 : 1]};
					end
					
					count <= count + {LOG_NUM_OUT_BITS{1'b1}};
				end
				else
				begin
					quotient <= {NUM_OUTPUT_BITS{1'b0}};
					radicand_shift <= {radicand, {(2 * NUM_OUTPUT_BITS - 2){1'b0}}};
					rad_res_accum <= {(2 * NUM_OUTPUT_BITS + 2){1'b0}};
					partial_remainder <= {1'b1, {2 * NUM_OUTPUT_BITS{1'b0}}};
					count <= initial_count[LOG_NUM_OUT_BITS - 1 : 0];
				end
			end
		end
	end

endmodule
