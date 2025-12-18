`timescale 1ns / 1ps

module testbench_park_transform;
	reg clk;
	reg rst;
	reg[13:0] phi;
	
	wire lut_done;
	wire signed[13:0] sin_ref;
	wire signed[13:0] cos_ref;
	
	wire signed[13:0] sin_offset;
	wire signed[13:0] cos_offset;
	
	wire signed[13:0] out_d;
	wire signed[13:0] out_q;
	wire park_done;
	
	always @(posedge clk)
	begin
		if(rst)
			phi <= 14'd0;
		else if(lut_done)
			phi <= phi + 14'd1;
	end
	
	sin_cos_lut lut_ref(
		.clk(clk),
		.rst(rst),
		.trig(1'b1),
		.phi(phi),
		.sin(sin_ref),
		.cos(cos_ref),
		.done(lut_done)
	);
	
	sin_cos_lut lut_offset(
		.clk(clk),
		.rst(rst),
		.trig(1'b1),
		.phi(phi + 14'h0100),
		.sin(sin_offset),
		.cos(cos_offset),
		.done()
	);
//#############################################################################
	park_transform uut(
		.clk(clk),
		.rst(rst),
		.trig(lut_done),
		.in_x(cos_offset),
		.in_y(sin_offset),
		.cos_phi(cos_ref),
		.sin_phi(sin_ref),
		.out_d(out_d),
		.out_q(out_q),
		.done(park_done)
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
