`timescale 1ns / 1ps

module testbench_inverse_park;
	reg clk;
	reg rst;
	reg[13:0] phi_ref;
	reg[13:0] phi_offset;
	
	wire lut_done;
	wire signed[13:0] sin_ref;
	wire signed[13:0] cos_ref;
	
	wire signed[13:0] sin_offset;
	wire signed[13:0] cos_offset;
	
	wire signed[13:0] out_d;
	wire signed[13:0] out_q;
	wire park_done;
	
	wire signed[13:0] out_x;
	wire signed[13:0] out_y;
	wire i_park_done;
	
	always @(posedge clk)
	begin
		if(rst)
		begin
			phi_ref <= 14'd0;
			phi_offset <= 14'd0;
		end
		else if(lut_done)
		begin
			phi_ref <= phi_ref + 14'd2;
			phi_offset <= phi_offset + 14'd3;
		end
	end
	
	sin_cos_lut lut_ref(
		.clk(clk),
		.rst(rst),
		.trig(1'b1),
		.phi(phi_ref),
		.sin(sin_ref),
		.cos(cos_ref),
		.done(lut_done)
	);
	
	sin_cos_lut lut_offset(
		.clk(clk),
		.rst(rst),
		.trig(1'b1),
		.phi(phi_offset),
		.sin(sin_offset),
		.cos(cos_offset),
		.done()
	);
//#############################################################################
	park_transform park_transform_i(
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
	
	inverse_park uut(
		.clk(clk),
		.rst(rst),
		.trig(park_done),
		.in_d(out_d),
		.in_q(out_q),
		.cos_phi(cos_ref),
		.sin_phi(sin_ref),
		.out_x(out_x),
		.out_y(out_y),
		.done(i_park_done)
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
