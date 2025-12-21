`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   15:50:38 12/20/2025
// Design Name:   circular_limiter
// Module Name:   /media/dragomir/Dogfish_USB/shared_workspace/ip_dev/src/tb_circular_limiter.v
// Project Name:  ip_dev
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: circular_limiter
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_circular_limiter;

	// Inputs
	reg clk;
	reg rst;
	reg trig;
	reg [13:0] x_in;
	reg [13:0] y_in;

	// Outputs
	wire [13:0] x_out;
	wire [13:0] y_out;
	wire done;

	// Instantiate the Unit Under Test (UUT)
	circular_limiter
	#(
		.NUM_BITS(14),
		.LOG_NUM_SQRT_BITS(5)
	) uut
	(
		.clk(clk), 
		.rst(rst), 
		.trig(trig), 
		.x_in(x_in), 
		.y_in(y_in), 
		.x_out(x_out), 
		.y_out(y_out), 
		.done(done)
	);
	
	always
	begin
		#10 clk = ~clk;
	end

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 1'b1;
		trig = 0;
		x_in = 0;
		y_in = 0;

		// Wait 100 ns for global reset to finish
		#100;
		rst = 1'b0;
        
		// Add stimulus here
		#20 trig = 1'b1;
		x_in = 14'd0;
		y_in = 14'd0;
		#20 trig = 1'b0;
		
		#1000 trig = 1'b1;
		x_in = 14'd100;
		y_in = 14'd0;
		#20 trig = 1'b0;
		
		#1000 trig = 1'b1;
		x_in = 14'd0;
		y_in = 14'd100;
		#20 trig = 1'b0;
		
		#1000 trig = 1'b1;
		x_in = 14'd100;
		y_in = 14'd300;
		#20 trig = 1'b0;
		
		#1000 trig = 1'b1;
		x_in = 14'd16383;
		y_in = 14'd0;
		#20 trig = 1'b0;
		
		#1000 trig = 1'b1;
		x_in = 14'd16383;
		y_in = 14'd6000;
		#20 trig = 1'b0;
		
		#1000 trig = 1'b1;
		x_in = 14'd16383;
		y_in = 14'd16383;
		#20 trig = 1'b0;
		
		#1000 trig = 1'b1;
		x_in = 14'd16000;
		y_in = 14'd16000;
		#20 trig = 1'b0;
	end
      
endmodule

