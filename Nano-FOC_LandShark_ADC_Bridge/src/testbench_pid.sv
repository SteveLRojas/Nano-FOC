`timescale 1ns / 1ps

module testbench_pid;
	reg clk;
	reg rst;
	wire signed[9:0] pv;
	wire signed[9:0] cv;
	wire done;
	
	reg[23:0] accum;

	always @(posedge clk)
	begin
		if(rst)
			accum <= 24'h000000;
		else
			accum <= accum + {{14{cv[9]}}, cv};
	end
	
	assign pv = accum[23:14];
	
//#############################################################################
	pid_control
	#(
		.NUM_BITS(10),
		.ACCUM_EXTRA_BITS(1),
		.KP_SHIFT_FACTOR(6),
		.KI_SHIFT_FACTOR(6),
		.KD_SHIFT_FACTOR(6)
	) uut
	(
		.clk(clk),
		.rst(rst),
		.trigger(1'b1),
		.sp(10'd300),
		.pv(pv),
		.kp(10'h1FF),
		.ki(10'h010),
		.kd(10'h000),
		.cv(cv),
		.done(done)
	);
//#############################################################################

	always
	begin
		#10 clk = ~clk;
	end

	initial begin
		// Initialize Inputs
		clk = 1'b0;
		rst = 1'b1;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		rst = 1'b0;

	end
	
endmodule
