module hall_ri(
		input wire clk,
		input wire rst,
		input wire enable,
		input wire wren,
		input wire[1:0] addr,
		input wire[15:0] to_ri,
		output reg[15:0] from_ri,
		
		input wire[2:0] hall_sector,
		input wire[13:0] hall_phi,
		input wire[13:0] extpol_phi,
		output reg[13:0] hall_offset
	);
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			from_ri <= 16'h0000;
			hall_offset <= 14'h0000;
		end
		else
		begin
			//ri reads
			case(addr)
				3'h0: from_ri <= {13'h0000, hall_sector};
				3'h1: from_ri <= {2'h0, hall_phi};
				3'h2: from_ri <= {2'h0, extpol_phi};
				3'h3: from_ri <= {2'h0, hall_offset};
				default: ;
			endcase
			
			//ri writes
			if(enable & wren & (addr == 2'b11))
			begin
				hall_offset <= to_ri[13:0];
			end
		end
	end
	
endmodule
