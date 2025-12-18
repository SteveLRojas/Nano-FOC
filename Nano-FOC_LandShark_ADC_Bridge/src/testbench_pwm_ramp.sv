`timescale 1ns / 1ps

module testbench_pwm_ramp;
	reg clk;
	reg rst;
	
	wire[9:0] pwm_ramp;
	wire pwm_trig;
	
//#############################################################################
	pwm_ramp
	#(
		.NUM_BITS(10),
		.USE_FAST_LOGIC(1'b0)
	) uut
	(
		.clk(clk),
		.rst(rst),
		.step_size(9'h01),
		.pwm_ramp(pwm_ramp),
		.pwm_trig(pwm_trig)
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
