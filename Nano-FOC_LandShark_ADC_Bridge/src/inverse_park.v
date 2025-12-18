module inverse_park(
		input wire clk,
		input wire rst,
		input wire trig,
		input wire signed[13:0] in_d,
		input wire signed[13:0] in_q,
		input wire signed[13:0] cos_phi,
		input wire signed[13:0] sin_phi,
		output reg signed[13:0] out_x,
		output reg signed[13:0] out_y,
		output reg done
	);
// out_x = cos_phi * in_d - sin_phi * in_q
// out_y = sin_phi * in_d + cos_phi * in_q
	
	reg[3:0] state;
	
	reg signed[13:0] mul_in_a;
	reg signed[13:0] mul_in_b;
	reg signed[27:0] mul_res;
	
	reg signed[14:0] t_product;
	reg signed[14:0] t_sum;
	
	parameter S_MUL1 = 4'h0;
	parameter S_MUL2 = 4'h1;
	parameter S_MUL3_P1 = 4'h2;
	parameter S_MUL4_P2_ADD1 = 4'h3;
	parameter S_P3_CLIP1 = 4'h4;
	parameter S_P4_ADD2 = 4'h5;
	parameter S_CLIP2 = 4'h6;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			out_x <= 14'h0000;
			out_y <= 14'h0000;
			done <= 1'b0;
			state <= S_MUL1;
			mul_in_a <= 14'h0000;
			mul_in_b <= 14'h0000;
			mul_res <= 28'h0000000;
			t_product <= 15'h0000;
			t_sum <= 15'h0000;
		end
		else
		begin
			mul_res <= mul_in_a * mul_in_b;
			
			case(state)
				S_MUL1:
				begin
					done <= 1'b0;
					mul_in_a <= cos_phi;
					mul_in_b <= in_d;
					if(trig)
						state <= S_MUL2;
				end
				S_MUL2:
				begin
					mul_in_a <= sin_phi;
					mul_in_b <= in_q;
					state <= S_MUL3_P1;
				end
				S_MUL3_P1:
				begin
					t_product <= mul_res[27:13];
					mul_in_a <= sin_phi;
					mul_in_b <= in_d;
					state <= S_MUL4_P2_ADD1;
				end
				S_MUL4_P2_ADD1:
				begin
					t_sum <= t_product - mul_res[27:13];
					mul_in_a <= cos_phi;
					mul_in_b <= in_q;
					state <= S_P3_CLIP1;
				end
				S_P3_CLIP1:
				begin
					t_product <= mul_res[27:13];
					
					if(^t_sum[14:13])
						out_x <= {t_sum[14], {13{~t_sum[14]}}};
					else
						out_x <= t_sum[13:0];
					
					state <= S_P4_ADD2;
				end
				S_P4_ADD2:
				begin
					t_sum <= t_product + mul_res[27:13];	//HINT: this operation overflows if all inputs are -8192 (min value)...
					state <= S_CLIP2;
				end
				S_CLIP2:
				begin
					if(^t_sum[14:13])
						out_y <= {t_sum[14], {13{~t_sum[14]}}};
					else
						out_y <= t_sum[13:0];
					
					done <= 1'b1;
					state <= S_MUL1;
				end
				default: ;
			endcase
		end
	end
	
endmodule
