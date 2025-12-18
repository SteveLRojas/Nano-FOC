module spi_controller(
		input wire clk,
		input wire rst,
		
		output reg[23:0] to_host,
		input wire[23:0] from_host,
		input wire start,
		input wire done,
		
		input wire[15:0] status,
		output reg[15:0] to_ri,
		input wire[15:0] from_ri,
		output reg[6:0] ri_addr,
		output reg ri_wren
	);

	reg ri_ren;
	reg prev_ri_ren;
	wire[7:0] brief_status;
	assign brief_status = {status[10], status[8], status[5:4], status[3:0]};
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			to_host <= 24'h000000;
			to_ri <= 16'h0000;
			ri_addr <= 7'h00;
			ri_wren <= 1'b0;
			ri_ren <= 1'b0;
			prev_ri_ren <= 1'b0;
		end
		else
		begin
			prev_ri_ren <= ri_ren;
			if(start | prev_ri_ren)
			begin
				to_host[23:16] <= brief_status;
				to_host[15:0] <= prev_ri_ren ? from_ri : status;
			end
			
			ri_wren <= 1'b0;
			ri_ren <= 1'b0;
			if(done)
			begin
				to_ri <= from_host[15:0];
				ri_addr <= from_host[22:16];
				ri_wren <= from_host[23];
				ri_ren <= ~from_host[23];
			end
		end
	end
	
endmodule
