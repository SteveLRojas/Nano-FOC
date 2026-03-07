`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   22:58:07 03/03/2026
// Design Name:   abz_decoder
// Module Name:   /media/dragomir/Dogfish_USB/shared_workspace/ip_dev/src/tb_abz_decoder.v
// Project Name:  ip_dev
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: abz_decoder
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_abz_decoder;

	// Inputs
	reg clk;
	reg rst;
	wire enc_a;
	wire enc_b;
	wire enc_z;
	reg z_clear_en;
	reg combined_z_pulse;
	reg [13:0] max_count;
	reg max_count_wren;

	// Outputs
	wire [13:0] abz_phi;
	wire abz_step;
	wire abz_dir;
	wire fault;
	
	reg dir;
	reg step;
	reg[15:0] emu_max_count;
	abn_emulator abn_emulator_i(
		.clk(clk),
		.rst(rst),
		.dir(dir),
		.step(step),
		.max_count(emu_max_count),
		.abn_a(enc_a),
		.abn_b(enc_b),
		.abn_n(enc_z)
	);

	// Instantiate the Unit Under Test (UUT)
	abz_decoder uut (
		.clk(clk), 
		.rst(rst), 
		.enc_a(enc_a), 
		.enc_b(enc_b), 
		.enc_z(enc_z), 
		.z_clear_en(z_clear_en), 
		.combined_z_pulse(combined_z_pulse), 
		.max_count(max_count), 
		.max_count_wren(max_count_wren), 
		.abz_phi(abz_phi), 
		.abz_step(abz_step), 
		.abz_dir(abz_dir), 
		.fault(fault)
	);

	always
	begin
		#10 clk = ~clk;
	end
	
	initial begin
		// Initialize Inputs
		clk = 1'b0;
		rst = 1'b0;
		z_clear_en = 1'b1;
		combined_z_pulse = 1'b0;
		max_count = 14'd500;
		max_count_wren = 1'b0;
		dir <= 1'b0;
		step <= 1'b0;
		emu_max_count <= 16'd300;

		// Wait 100 ns for global reset to finish
		#20 rst = 1'b1;
		#100 rst = 1'b0;
        
		// Add stimulus here
		step = 1'b1;
		#8000 dir = 1'b1;
		#8000 step = 1'b0;
	end
      
endmodule

