module enc_ri(
		input wire clk,
		input wire rst,
		input wire enable,
		input wire wren,
		input wire[3:0] addr,
		input wire[15:0] to_ri,
		output reg[15:0] from_ri,
		
		input wire[13:0] enc_phi,
		output reg[13:0] enc_offset,
		
		input wire[2:0] hall_sector,
		input wire[13:0] hall_phi,
		output reg[13:0] hall_phi_s0,
		output reg[13:0] hall_phi_s1,
		output reg[13:0] hall_phi_s2,
		output reg[13:0] hall_phi_s3,
		output reg[13:0] hall_phi_s4,
		output reg[13:0] hall_phi_s5,
		
		input wire[13:0] abz_phi,
		output reg abz_clear_en,
		output reg abz_combined_z_pulse,
		output reg abz_inv_dir,
		output reg[23:0] abz_cpr_inv,
		output reg[13:0] abz_max_count,
		output reg abz_max_count_wren
	);
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			from_ri <= 16'h0000;
			enc_offset <= 14'h0000;
			hall_phi_s0 <= 14'h0000;
			hall_phi_s1 <= 14'h0000;
			hall_phi_s2 <= 14'h0000;
			hall_phi_s3 <= 14'h0000;
			hall_phi_s4 <= 14'h0000;
			hall_phi_s5 <= 14'h0000;
			abz_clear_en <= 1'b0;
			abz_combined_z_pulse <= 1'b0;
			abz_inv_dir <= 1'b0;
			abz_cpr_inv <= 24'h000000;
			abz_max_count <= 14'h0000;
			abz_max_count_wren <= 1'b0;
		end
		else
		begin
			//ri reads
			case(addr)
				4'h0: from_ri <= {2'b00, enc_phi};
				4'h1: from_ri <= {2'b00, enc_offset};
				4'h2: from_ri <= {13'h0000, hall_sector};
				4'h3: from_ri <= {2'b00, hall_phi};
				4'h4: from_ri <= {2'b00, hall_phi_s0};
				4'h5: from_ri <= {2'b00, hall_phi_s1};
				4'h6: from_ri <= {2'b00, hall_phi_s2};
				4'h7: from_ri <= {2'b00, hall_phi_s3};
				4'h8: from_ri <= {2'b00, hall_phi_s4};
				4'h9: from_ri <= {2'b00, hall_phi_s5};
				4'hA: from_ri <= {2'b00, abz_phi};
				4'hB: from_ri <= {13'h0000, abz_inv_dir, abz_combined_z_pulse, abz_clear_en};
				4'hC: from_ri <= abz_cpr_inv[15:0];
				4'hD: from_ri <= {8'h00, abz_cpr_inv[23:16]};
				4'hE: from_ri <= {2'b00, abz_max_count};
				default: from_ri <= 14'hXXXX;
			endcase
			
			abz_max_count_wren <= 1'b0;
			
			//ri writes
			if(enable & wren)
			begin
				case(addr)
					4'h1: enc_offset <= to_ri[13:0];
					4'h4: hall_phi_s0 <= to_ri[13:0];
					4'h5: hall_phi_s1 <= to_ri[13:0];
					4'h6: hall_phi_s2 <= to_ri[13:0];
					4'h7: hall_phi_s3 <= to_ri[13:0];
					4'h8: hall_phi_s4 <= to_ri[13:0];
					4'h9: hall_phi_s5 <= to_ri[13:0];
					4'hB: {abz_inv_dir, abz_combined_z_pulse, abz_clear_en} <= to_ri[2:0];
					4'hC: abz_cpr_inv[15:0] <= to_ri;
					4'hD: abz_cpr_inv[23:16] <= to_ri[7:0];
					4'hE:
					begin
						abz_max_count <= to_ri[13:0];
						abz_max_count_wren <= 1'b1;
					end
					default: ;
				endcase
			end
		end
	end
	
endmodule
