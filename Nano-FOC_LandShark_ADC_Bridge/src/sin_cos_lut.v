module sin_cos_lut(
		input wire clk,
		input wire rst,
		input wire trig,
		input wire[13:0] phi,
		output reg signed[13:0] sin,
		output reg signed[13:0] cos,
		output reg done
	);
	
	localparam[3:0] S_START_SIN = 4'h0;
	localparam[3:0] S_START_COS = 4'h1;
	localparam[3:0] S_INTERPOLATE_1 = 4'h2;
	localparam[3:0] S_INTERPOLATE_2 = 4'h3;
	localparam[3:0] S_INTERPOLATE_3 = 4'h4;
	localparam[3:0] S_INTERPOLATE_4 = 4'h5;
	
	reg[3:0] state;
	
	reg[13:0] current_phi;
	reg sin_sign;
	//reg cos_sign;
	reg[8:0] lut_dout_a_ff;
	reg[8:0] prev_lut_dout_a;
	reg signed[8:0] mul_in_a;
	reg signed[4:0] mul_in_b;
	reg signed[13:0] mul_res;
	
	wire[8:0] next_phi;
	wire[7:0] phi_idx;
	wire[7:0] next_phi_idx;
	
	wire[8:0] lut_dout_a;
	wire[8:0] lut_dout_b;
	
	assign next_phi = current_phi[12:4] + 9'h01;
	assign phi_idx = current_phi[11:4] ^ {8{current_phi[12]}}; // -> <- -> <-
	assign next_phi_idx = next_phi[7:0] ^ {8{next_phi[8]}};
	
	sin_lut_bram sin_lut_bram_i(
		.address_a(phi_idx),
		.address_b(next_phi_idx),
		.clock(clk),
		.q_a(lut_dout_a),
		.q_b(lut_dout_b)
	);
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			sin <= 14'h0000;
			cos <= 14'h0000;
			done <= 1'b0;
			state <= S_START_SIN;
			current_phi <= 14'h0000;
			sin_sign <= 1'b0;
			lut_dout_a_ff <= 9'h000;
			prev_lut_dout_a <= 9'h000;
			mul_in_a <= 9'h000;
			mul_in_b <= 5'h00;
			mul_res <= 14'h0000;
		end
		else
		begin
			mul_res <= mul_in_a * mul_in_b;
			lut_dout_a_ff <= lut_dout_a;
			prev_lut_dout_a <= lut_dout_a_ff;
			
			case(state)
				S_START_SIN:
				begin
					done <= 1'b0;
					current_phi <= phi;
					
					if(trig)
						state <= S_START_COS;
				end
				S_START_COS:
				begin
					sin_sign <= current_phi[13];
					mul_in_b <= {1'b0, current_phi[3:0]};
					current_phi <= current_phi + 14'h1000;
					state <= S_INTERPOLATE_1;
				end
				S_INTERPOLATE_1:
				begin
					mul_in_a <= (lut_dout_b - lut_dout_a);				
					state <= S_INTERPOLATE_2;
				end
				S_INTERPOLATE_2:
				begin
					mul_in_a <= (lut_dout_b - lut_dout_a);
					mul_in_b <= {1'b0, current_phi[3:0]};
					state <= S_INTERPOLATE_3;
				end
				S_INTERPOLATE_3:
				begin
					sin <= (({1'b0, prev_lut_dout_a, 4'h0} + mul_res[13:0]) ^ {14{sin_sign}}) + sin_sign; // ^ ^ v v 
					state <= S_INTERPOLATE_4;
				end
				S_INTERPOLATE_4:
				begin
					cos <= (({1'b0, prev_lut_dout_a, 4'h0} + mul_res[13:0]) ^ {14{current_phi[13]}}) + current_phi[13]; // ^ ^ v v 
					done <= 1'b1;
					state <= S_START_SIN;
				end
				default: ;
			endcase
		end
	end
	
endmodule
