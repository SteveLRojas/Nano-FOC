`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:00:12 03/04/2026 
// Design Name:    decoder_scaler
// Module Name:    decoder_scaler 
// Project Name:   ip_dev
// Target Devices: Spartan-6, Cyclone IV, MAX10
// Tool versions:  ISE 14.7 Quartus 19.1 Lite
// Description:    Computes cpr_inv * decoder_phi / 2 ^ PHI_BITS.
//
// Dependencies: None.
//
// Revision: 
// Revision 0.01 - File Created
// Revision 1.00 - Optimization complete
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module decoder_scaler
	#(
		parameter MUL_WIDTH = 8,
		parameter PHI_BITS = 14
	)(
		input wire clk,
		input wire rst,
		input wire trig,
		input wire[MUL_WIDTH * 3 - 1 : 0] cpr_inv,
		input wire[PHI_BITS - 1 : 0] decoder_phi,
		output wire[PHI_BITS - 1 : 0] scaled_phi,
		output wire done
    );
	localparam SUM_FF_BITS = (PHI_BITS > (2 * MUL_WIDTH)) ? PHI_BITS : (2 * MUL_WIDTH);
	
	reg[3:0] state;
	reg trig_hold;
	reg done_ff;
	reg[PHI_BITS - 1 : 0] mul_in_a;
	reg[MUL_WIDTH - 1 : 0] mul_in_b;
	reg[MUL_WIDTH + PHI_BITS - 1 : 0] mul_res;
	reg[SUM_FF_BITS - 1 : 0] sum_res_ff;
	reg[PHI_BITS - 1 : 0] scaled_phi_ff;
	
	wire[SUM_FF_BITS + MUL_WIDTH - 1 : 0] sum_res;
	generate
		if(PHI_BITS >= (2 * MUL_WIDTH))
			assign sum_res = {{MUL_WIDTH{1'b0}}, sum_res_ff[PHI_BITS - 1 : 0]} + mul_res;
		else
			assign sum_res = {{{MUL_WIDTH{1'b0}}, sum_res_ff[SUM_FF_BITS - 1 : SUM_FF_BITS - PHI_BITS]} + mul_res, sum_res_ff[SUM_FF_BITS - PHI_BITS - 1 : 0]};
	endgenerate
	
	assign scaled_phi = scaled_phi_ff;
	assign done = done_ff;
	
	localparam[3:0] S_MUL_1 = 4'h0;
	localparam[3:0] S_MUL_2 = 4'h1;
	localparam[3:0] S_MUL_3 = 4'h2;
	localparam[3:0] S_SUM_2 = 4'h3;
	localparam[3:0] S_SUM_3 = 4'h4;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			state <= S_MUL_1;
			trig_hold <= 1'b0;
			done_ff <= 1'b0;
			mul_in_a <= {PHI_BITS{1'b0}};
			mul_in_b <= {MUL_WIDTH{1'b0}};
			mul_res <= {(PHI_BITS + MUL_WIDTH){1'b0}};
			sum_res_ff <= {SUM_FF_BITS{1'b0}};
			scaled_phi_ff <= {PHI_BITS{1'b0}};
		end
		else
		begin
			trig_hold <= trig_hold | trig;
			done_ff <= 1'b0;
			mul_res <= mul_in_a * mul_in_b;
			sum_res_ff <= sum_res[SUM_FF_BITS + MUL_WIDTH - 1 : MUL_WIDTH];
			
			case(state)
				S_MUL_1:
				begin
					trig_hold <= 1'b0;
					if(trig_hold | trig)
					begin
						mul_in_a <= decoder_phi;
						mul_in_b <= cpr_inv[MUL_WIDTH - 1 : 0];
						state <= S_MUL_2;
					end
				end
				S_MUL_2:
				begin
					mul_in_b <= cpr_inv[MUL_WIDTH * 2 - 1 : MUL_WIDTH];
					sum_res_ff <= {SUM_FF_BITS{1'b0}};
					state <= S_MUL_3;
				end
				S_MUL_3:
				begin
					mul_in_b <= cpr_inv[MUL_WIDTH * 3 - 1 : MUL_WIDTH * 2];
					state <= S_SUM_2;
				end
				S_SUM_2:
				begin
					state <= S_SUM_3;
				end
				S_SUM_3:
				begin
					scaled_phi_ff <= sum_res[PHI_BITS - 1 : 0];
					done_ff <= 1'b1;
					state <= S_MUL_1;
				end
			endcase
		end
	end
endmodule
