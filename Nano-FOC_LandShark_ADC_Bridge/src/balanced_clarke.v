module balanced_clarke(
		input wire clk,
		input wire rst,
		input trig,
		input wire signed[13:0] in_u,
		input wire signed[13:0] in_v,
		input wire signed[13:0] in_w,
		output reg signed[13:0] alpha,
		output reg signed[13:0] beta,
		output reg done
	);
// alpha = (2/3) * (in_u - (1/2) * in_v - (1/2) * in_w)
// beta = (2/3) * ((sqrt(3) / 2) * in_v - (sqrt(3) / 2) * in_w)

// alpha = (1/3) * (2 * in_u - in_v - in_w)
// beta = (sqrt(3)/3) * (in_v - in_w)

	reg[3:0] state;
	reg signed[15:0] alpha_t1;
	
	reg signed[15:0] mul_in_a;
	reg signed[15:0] mul_in_b;
	reg signed[31:0] mul_res;
	
	parameter S_CALC1 = 4'h0;
	parameter S_CALC2 = 4'h1;
	parameter S_CLIP_BETA = 4'h2;
	parameter S_CLIP_ALPHA = 4'h3;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			alpha <= 14'h0000;
			beta <= 14'h0000;
			done <= 1'b0;
			state <= S_CALC1;
			alpha_t1 <= 16'h0000;
			mul_in_a <= 16'h0000;
			mul_in_b <= 16'h0000;
			mul_res <= 32'h00000000;
		end
		else
		begin
			mul_res <= mul_in_a * mul_in_b;
			
			case(state)
				S_CALC1:
				begin
					done <= 1'b0;
					alpha_t1 <= {in_u[13], in_u[13:0], 1'b0} - {{2{in_v[13]}}, in_v[13:0]};	// 2 * in_u - in_v
					mul_in_a <= {{2{in_v[13]}}, in_v[13:0]} - {{2{in_w[13]}}, in_w[13:0]};	// in_v - in_w
					mul_in_b <= 16'h49E7;	// 2^15 * sqrt(3)/3
					if(trig)
						state <= S_CALC2;
				end
				S_CALC2:
				begin
					mul_in_a <= alpha_t1 - {{2{in_w[13]}}, in_w[13:0]};	// 2 * in_u - in_v - in_w
					mul_in_b <= 16'h5555;	// 2^16 * 1/3
					state <= S_CLIP_BETA;
				end
				S_CLIP_BETA:
				begin
					if(&mul_res[30:28] || ~|mul_res[30:28])
						beta <= mul_res[28:15];
					else
						beta <= {mul_res[31], {13{~mul_res[31]}}};
					state <= S_CLIP_ALPHA;
				end
				S_CLIP_ALPHA:
				begin
					if(&mul_res[31:29] || ~|mul_res[31:29])
						alpha <= mul_res[29:16];
					else
						alpha <= {mul_res[31], {13{~mul_res[31]}}};
					done <= 1'b1;
					state <= S_CALC1;
				end
				default: ;
			endcase
		end
	end
endmodule
