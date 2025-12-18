`timescale 1ns / 1ps

module testbench_ramper;
	reg clk;
	reg rst;
	
	wire[10:0] phi;
	
//#############################################################################
	phi_ramper
	#(
		.ACCEL_BITS(10),
		.VEL_DIV_BITS(12),
		.VEL_COUNTER_BITS(20),
		.VEL_BITS(10),
		.PHI_DIV_BITS(5),
		.PHI_COUNTER_BITS(21),
		.PHI_BITS(11)
	) uut
	(
		.clk(clk),
		.rst(rst),
		.acceleration(10'd80),
		.target_velocity(10'd511),
		.phi(phi)
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
