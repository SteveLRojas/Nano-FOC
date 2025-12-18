module phicon_ri(
		input wire clk,
		input wire rst,
		input wire enable,
		input wire wren,
		input wire[2:0] addr,
		input wire[15:0] to_ri,
		output reg[15:0] from_ri,
		
		output reg[9:0] ol_acceleration,
		output reg signed[11:0] ol_target_velocity,
		input wire signed[11:0] ol_actual_velocity,
		input wire ol_target_reached,
		input wire[13:0] ol_phi,
		output reg[13:0] ext_phi,
		input wire[13:0] selected_phi
	);

	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			from_ri <= 16'h0000;
			ol_acceleration <= 10'h000;
			ol_target_velocity <= 12'h000;
			ext_phi <= 14'h0000;
		end
		else
		begin
			//ri reads
			case(addr)
				3'h0: from_ri <= {6'h00, ol_acceleration};
				3'h1: from_ri <= {4'h0, ol_target_velocity};
				3'h2: from_ri <= {3'h0, ol_target_reached, ol_actual_velocity};
				3'h3: from_ri <= {2'h0, ol_phi};
				3'h4: from_ri <= {2'h0, ext_phi};
				3'h5: from_ri <= {2'h0, selected_phi};
				default: from_ri <= 16'h0000;
			endcase
			
			//ri writes
			if(enable & wren)
			begin
				case(addr)
					3'h0: ol_acceleration <= to_ri[9:0];
					3'h1: ol_target_velocity <= to_ri[11:0];
					3'h4: ext_phi <= to_ri[13:0];
					default: ;
				endcase
			end
		end
	end
	
endmodule
