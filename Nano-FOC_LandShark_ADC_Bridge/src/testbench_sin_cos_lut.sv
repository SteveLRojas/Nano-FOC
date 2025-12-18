`timescale 1ns / 1ps

module testbench_sin_cos_lut;
	reg clk;
	reg rst;
	reg[13:0] phi;
	
	wire done;
	wire signed[13:0] sin;
	wire signed[13:0] cos;
	
	always @(posedge clk)
	begin
		if(rst)
			phi <= 14'd0;
		else if(done)
			phi <= phi + 14'd1;
	end
	
//#############################################################################
	sin_cos_lut uut(
		.clk(clk),
		.rst(rst),
		.trig(1'b1),
		.phi(phi),
		.sin(sin),
		.cos(cos),
		.done(done)
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
