module inverse_clarke(
		input wire clk,
		input wire rst,
		input wire trig,
		input wire signed[13:0] in_alpha,
		input wire signed[13:0] in_beta,
		output reg signed[13:0] out_u,
		output reg signed[13:0] out_v,
		output reg signed[13:0] out_w,
		output reg done
	);
// out_u = in_alpha
// out_v = (sqrt(3) / 2) * in_beta - (1 / 2) * in_alpha
// out_w = -(1 / 2) * in_alpha - (sqrt(3) / 2) * in_beta
	
	reg[3:0] state;
	
	reg signed[14:0] mul_in_a;
	reg signed[14:0] mul_in_b;
	reg signed[29:0] mul_res;
	
	reg signed[14:0] t_product;
	reg signed[15:0] t_sum;
	
	parameter S_MUL1 = 4'h0;
	parameter S_MUL2 = 4'h1;
	parameter S_P1 = 4'h2;
	parameter S_P2_ADD1 = 4'h3;
	parameter S_ADD2_CLIP_V = 4'h4;
	parameter S_CLIP_W = 4'h5;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			out_u <= 14'h0000;
			out_v <= 14'h0000;
			out_w <= 14'h0000;
			done <= 1'b0;
			state <= S_MUL1;
			mul_in_a <= 15'h0000;
			mul_in_b <= 15'h0000;
			mul_res <= 30'h00000000;
			t_product <= 15'h0000;
			t_sum <= 16'h0000;
		end
		else
		begin
			mul_res <= mul_in_a * mul_in_b;
			
			case(state)
				S_MUL1:
				begin
					done <= 1'b0;
					out_u <= in_alpha;
					mul_in_a <= {in_beta[13], in_beta};
					mul_in_b <= 15'd14189;	// 2^14 * sqrt(3) / 2
					
					if(trig)
						state <= S_MUL2;
				end
				S_MUL2:
				begin
					mul_in_a <= {in_alpha[13], in_alpha};
					mul_in_b <= 15'd16384;	// 2^15 * (-1 / 2)
					state <= S_P1;
				end
				S_P1:
				begin
					t_product <= mul_res[28:14];
					state <= S_P2_ADD1;
				end
				S_P2_ADD1:
				begin
					t_sum <= {t_product[14], t_product} + {mul_res[29], mul_res[29:15]};
					state <= S_ADD2_CLIP_V;
				end
				S_ADD2_CLIP_V:
				begin
					t_sum <= {mul_res[29], mul_res[29:15]} - {t_product[14], t_product};
					
					if(&t_sum[15:13] || ~|t_sum[15:13])
						out_v <= t_sum[13:0];
					else
						out_v <= {t_sum[15], {13{~t_sum[15]}}};
					
					state <= S_CLIP_W;
				end
				S_CLIP_W:
				begin
					if(&t_sum[15:13] || ~|t_sum[15:13])
						out_w <= t_sum[13:0];
					else
						out_w <= {t_sum[15], {13{~t_sum[15]}}};
					
					done <= 1'b1;
					state <= S_MUL1;
				end
				default: ;
			endcase
		end
	end
	
endmodule
