`timescale 1ns / 1ps

module testbench_inverse_clarke;
	real PI;
	real phase_u;
	real phase_v;
	real phase_w;
	integer int_u;
	integer int_v;
	integer int_w;
	reg[15:0] phi;
	reg start;
	
	assign PI = 3.14159265358979323846;
	assign phase_u = $cos(($itor(phi) / 65536.0) * 2 * PI);
	assign phase_v = $cos(($itor(phi) / 65536.0 - 1.0 / 3.0) * 2 * PI);
	assign phase_w = $cos(($itor(phi) / 65536.0 + 1.0 / 3.0) * 2 * PI);
	assign int_u = $rtoi(8191.0 * phase_u);
	assign int_v = $rtoi(8191.0 * phase_v);
	assign int_w = $rtoi(8191.0 * phase_w);
	
	reg clk_25;
	reg rst;

	wire signed[13:0] alpha;
	wire signed[13:0] beta;
	wire clarke_done;
	
	wire signed[13:0] out_u;
	wire signed[13:0] out_v;
	wire signed[13:0] out_w;
	wire i_clarke_done;
	
	always @(posedge clk_25)
	begin
		if(rst)
		begin
			phi <= 16'h0000;
			start <= 1'b1;
		end
		else
		begin
			phi <= phi + 16'h0001;
			start <= 1'b0;
		end
	end

//#############################################################################
	balanced_clarke balanced_clarke_i(
		.clk(clk_25),
		.rst(rst),
		.trig(i_clarke_done | start),
		.in_u(int_u[13:0]),
		.in_v(int_v[13:0]),
		.in_w(int_w[13:0]),
		.alpha(alpha),
		.beta(beta),
		.done(clarke_done)
	);
	
	inverse_clarke uut(
		.clk(clk_25),
		.rst(rst),
		.trig(clarke_done),
		.in_alpha(alpha),
		.in_beta(beta),
		.out_u(out_u),
		.out_v(out_v),
		.out_w(out_w),
		.done(i_clarke_done)
	);
//#############################################################################

	always
	begin
		#20 clk_25 = ~clk_25;
	end

	initial
	begin
		// Initialize Inputs
		clk_25 = 1'b0;
		rst = 1'b1;

		// Wait 100 ns for global reset to finish
		#80;
        
		// Add stimulus here
		rst = 1'b0;

	end
	
endmodule
