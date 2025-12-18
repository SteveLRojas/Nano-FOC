`timescale 1ns / 1ps

module testbench_phi_extrapolator;
	reg clk;
	reg rst;
	
	reg[13:0] phi_in;
	wire[13:0] phi_out;
	
	reg[23:0] update_timer;
	
	always @(posedge clk)
	begin
		if(rst)
		begin
			update_timer <= 24'h000000;
			phi_in <= 14'h0000;
		end
		else
		begin
			if(update_timer == 24'h000000)
			begin
				update_timer <= 24'h00FFFF;
				phi_in <= phi_in + 14'd2370;
			end
			else
			begin
				update_timer <= update_timer - 24'h000001;
			end
		end
	end
	
//#############################################################################
	phi_extrapolator uut(
		.clk(clk),
		.rst(rst),
		.phi_in(phi_in),
		.phi_out(phi_out)
	);
//#############################################################################

	always
	begin
		#10 clk = ~clk;
	end

	initial
	begin
		// Initialize Inputs
		clk = 1'b0;
		rst = 1'b1;

		// Wait 100 ns for global reset to finish
		#80;
        
		// Add stimulus here
		rst = 1'b0;

	end
	
endmodule
