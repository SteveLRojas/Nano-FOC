module hall_decoder(
		input wire clk,
		input wire rst,
		input wire hall_u,
		input wire hall_v,
		input wire hall_w,
		output reg[2:0] hall_sector,
		output reg[13:0] hall_phi,
		output reg hall_step,
		output reg hall_dir,
		output reg fault
	);
	
	reg prev_u;
	reg prev_v;
	reg prev_w;
	
	wire rising_u;
	wire rising_v;
	wire rising_w;
	
	wire falling_u;
	wire falling_v;
	wire falling_w;
	
	wire count_up;
	wire count_down;
	
	assign rising_u = hall_u & ~prev_u;
	assign rising_v = hall_v & ~prev_v;
	assign rising_w = hall_w & ~prev_w;
	
	assign falling_u = ~hall_u & prev_u;
	assign falling_v = ~hall_v & prev_v;
	assign falling_w = ~hall_w & prev_w;
	
	assign count_up = (rising_v & hall_u) | (falling_u & hall_v) | (rising_w & hall_v) | (falling_v & hall_w) | (rising_u & hall_w) | (falling_w & hall_u);
	assign count_down = (falling_u & hall_w) | (rising_v & hall_w) | (falling_w & hall_v) | (rising_u & hall_v) | (falling_v & hall_u) | (rising_w & hall_u);

	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			hall_sector <= 3'h0;
			hall_phi <= 14'h0000;
			hall_step <= 1'b0;
			hall_dir <= 1'b0;
			fault <= 1'b0;
			prev_u <= 1'b0;
			prev_v <= 1'b0;
			prev_w <= 1'b0;
		end
		else
		begin
			fault <= 1'b0;
			prev_u <= hall_u;
			prev_v <= hall_v;
			prev_w <= hall_w;
			
			case({hall_u, hall_v, hall_w})
				3'b110: hall_sector <= 3'h0;
				3'b010: hall_sector <= 3'h1;
				3'b011: hall_sector <= 3'h2;
				3'b001: hall_sector <= 3'h3;
				3'b101: hall_sector <= 3'h4;
				3'b100: hall_sector <= 3'h5;
				default: fault <= 1'b1;
			endcase
			
			hall_step <= count_up | count_down;
			hall_dir <= (hall_dir | count_down) & ~count_up;
			
			case({hall_u, hall_v, hall_w})
				3'b110: hall_phi <= 14'd0;
				3'b010: hall_phi <= 14'd2730;
				3'b011: hall_phi <= 14'd5461;
				3'b001: hall_phi <= 14'd8192;
				3'b101: hall_phi <= 14'd10922;
				3'b100: hall_phi <= 14'd13653;
				default: ;
			endcase
		end
	end
	
endmodule
