module hall_ri(
		input wire clk,
		input wire rst,
		input wire enable,
		input wire wren,
		input wire[3:0] addr,
		input wire[15:0] to_ri,
		output reg[15:0] from_ri,
		
		input wire[2:0] hall_sector,
		input wire[13:0] hall_phi,
		input wire[13:0] extpol_phi,
		output reg[13:0] hall_phi_s0,
		output reg[13:0] hall_phi_s1,
		output reg[13:0] hall_phi_s2,
		output reg[13:0] hall_phi_s3,
		output reg[13:0] hall_phi_s4,
		output reg[13:0] hall_phi_s5
	);
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			from_ri <= 16'h0000;
			hall_phi_s0 <= 14'h0000;
			hall_phi_s1 <= 14'h0000;
			hall_phi_s2 <= 14'h0000;
			hall_phi_s3 <= 14'h0000;
			hall_phi_s4 <= 14'h0000;
			hall_phi_s5 <= 14'h0000;
		end
		else
		begin
			//ri reads
			case(addr)
				4'h0: from_ri <= {13'h0000, hall_sector};
				4'h1: from_ri <= {2'b00, hall_phi};
				4'h2: from_ri <= {2'b00, extpol_phi};
				4'h3: from_ri <= {2'b00, hall_phi_s0};
				4'h4: from_ri <= {2'b00, hall_phi_s1};
				4'h5: from_ri <= {2'b00, hall_phi_s2};
				4'h6: from_ri <= {2'b00, hall_phi_s3};
				4'h7: from_ri <= {2'b00, hall_phi_s4};
				4'h8: from_ri <= {2'b00, hall_phi_s5};
				default: from_ri <= 14'hXXXX;
			endcase
			
			//ri writes
			if(enable & wren)
			begin
				case(addr)
					4'h3: hall_phi_s0 <= to_ri[13:0];
					4'h4: hall_phi_s1 <= to_ri[13:0];
					4'h5: hall_phi_s2 <= to_ri[13:0];
					4'h6: hall_phi_s3 <= to_ri[13:0];
					4'h7: hall_phi_s4 <= to_ri[13:0];
					4'h8: hall_phi_s5 <= to_ri[13:0];
					default: ;
				endcase
			end
		end
	end
	
endmodule
