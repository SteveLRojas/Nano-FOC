module phi_extrapolator(
		input wire clk,
		input wire rst,
		input wire[13:0] phi_in,
		output wire[13:0] phi_out
	);
	//K factor: the largest power of 2 that is less than or equal to delta T.
	//Delta T and delta phi are both divided by K factor to produce intermediate updates.
	
	reg[13:0] last_phi;
	reg[13:0] delta_phi;
	reg[23:0] delta_t;
	reg[23:0] delta_t_count;
	reg[23:0] delta_t_set_bits;
	reg[24:0] dt_accum;
	reg[15:0] k_shift;
	reg[15:0] k_factor;
	reg[24:0] k_accum;
	reg[36:0] phi_accum;
	reg[28:0] step_size;
	reg within_dt_limit;
	reg within_dif_limit;
	reg update_pulse;
	reg phi_change_ff;
	reg extpol_en;
	
	wire phi_change;
	wire[13:0] phi_in_out_dif;
	wire accum_comp;
	wire dt_limit_reached;
	
	assign phi_change = |(phi_in ^ last_phi);
	assign phi_in_out_dif = phi_out - last_phi;
	assign accum_comp = (k_accum >= dt_accum);
	assign dt_limit_reached = &delta_t_count;
	assign phi_out = phi_accum[36:23];
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			last_phi <= 14'h0000;
			delta_phi <= 14'h0000;
			delta_t <= 24'h000000;
			delta_t_count <= 24'h000000;
			delta_t_set_bits <= 24'h000000;
			dt_accum <= 25'h0000000;
			k_shift <= 16'h0000;
			k_factor <= 16'h0000;
			k_accum <= 25'h0000000;
			phi_accum <= 37'h0000000000;
			step_size <= 29'h00000000;
			within_dt_limit <= 1'b0;
			within_dif_limit <= 1'b0;
			update_pulse <= 1'b0;
			phi_change_ff <= 1'b0;
			extpol_en <= 1'b0;
		end
		else
		begin
			last_phi <= phi_in;
			within_dt_limit <= (phi_change | within_dt_limit) & ~dt_limit_reached;
			within_dif_limit <= ~^phi_in_out_dif[13:12];	//abs(phi_in_out_dif) < 2^14 / 4
			
			if(phi_change)
			begin
				delta_phi <= phi_in - last_phi;
				delta_t <= delta_t_count;
				delta_t_count <= 24'h000000;
				delta_t_set_bits <= 24'h000000;
				dt_accum <= 25'h0000000;
				k_shift <= 16'h0001;
				k_factor <= k_shift;
				k_accum <= 25'h0000000;
			end
			else
			begin
				if(~dt_limit_reached)
					delta_t_count <= delta_t_count + 24'h000001;
					
				delta_t_set_bits <= delta_t_set_bits | delta_t_count;
				
				if(|(delta_t_count[23:9] & ~delta_t_set_bits[23:9]))
					k_shift <= {k_shift[14:0], 1'b0};
				
				if(accum_comp)
					dt_accum <= {dt_accum[24] & ~k_accum[24], dt_accum[23:0]} + {1'b0, delta_t};
				else
					dt_accum <= {dt_accum[24] & ~k_accum[24], dt_accum[23:0]};
				
				k_accum <= {k_accum[24] & ~dt_accum[24], k_accum[23:0]} + {1'b0, k_factor, 8'h00};
			end
			
			update_pulse <= accum_comp;
			phi_change_ff <= phi_change;
			extpol_en <= (phi_change_ff | extpol_en) & within_dt_limit & within_dif_limit;
			step_size <= 
				{{14{k_factor[ 0]}} & delta_phi,                        15'b000000000000000} | 
				{{15{k_factor[ 1]}} & {delta_phi[13], delta_phi},       14'b00000000000000} | 
				{{16{k_factor[ 2]}} & {{ 2{delta_phi[13]}}, delta_phi}, 13'b0000000000000} | 
				{{17{k_factor[ 3]}} & {{ 3{delta_phi[13]}}, delta_phi}, 12'b000000000000} | 
				{{18{k_factor[ 4]}} & {{ 4{delta_phi[13]}}, delta_phi}, 11'b00000000000} | 
				{{19{k_factor[ 5]}} & {{ 5{delta_phi[13]}}, delta_phi}, 10'b0000000000} | 
				{{20{k_factor[ 6]}} & {{ 6{delta_phi[13]}}, delta_phi},  9'b000000000} | 
				{{21{k_factor[ 7]}} & {{ 7{delta_phi[13]}}, delta_phi},  8'b00000000} | 
				{{22{k_factor[ 8]}} & {{ 8{delta_phi[13]}}, delta_phi},  7'b0000000} | 
				{{23{k_factor[ 9]}} & {{ 9{delta_phi[13]}}, delta_phi},  6'b000000} | 
				{{24{k_factor[10]}} & {{10{delta_phi[13]}}, delta_phi},  5'b00000} | 
				{{25{k_factor[11]}} & {{11{delta_phi[13]}}, delta_phi},  4'b0000} | 
				{{26{k_factor[12]}} & {{12{delta_phi[13]}}, delta_phi},  3'b000} | 
				{{27{k_factor[13]}} & {{13{delta_phi[13]}}, delta_phi},  2'b00} | 
				{{28{k_factor[14]}} & {{14{delta_phi[13]}}, delta_phi},  1'b0} | 
				{{29{k_factor[15]}} & {{15{delta_phi[13]}}, delta_phi}      };
			
			if(update_pulse | (phi_change_ff | ~extpol_en))
			begin
				if(phi_change_ff | ~extpol_en)
					phi_accum <= {last_phi, 23'h000000};
				else
					phi_accum <= phi_accum + {{8{step_size[28]}}, step_size};
			end
		end
	end

endmodule
