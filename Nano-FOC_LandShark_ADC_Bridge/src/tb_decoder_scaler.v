`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   19:51:35 03/06/2026
// Design Name:   decoder_scaler
// Module Name:   /media/dragomir/Dogfish_USB/shared_workspace/ip_dev/src/tb_decoder_scaler.v
// Project Name:  ip_dev
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: decoder_scaler
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_decoder_scaler;

	// Inputs
	reg clk;
	reg rst;
	wire trig;
	reg [23:0] cpr_inv;
	reg [13:0] decoder_phi;

	// Outputs
	wire [13:0] scaled_phi;
	wire done;

	// Instantiate the Unit Under Test (UUT)
	decoder_scaler uut (
		.clk(clk), 
		.rst(rst), 
		.trig(trig), 
		.cpr_inv(cpr_inv), 
		.decoder_phi(decoder_phi), 
		.scaled_phi(scaled_phi), 
		.done(done)
	);
	
	always
	begin
		#10 clk = ~clk;
	end
	
	
	reg active;
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			decoder_phi <= 14'h0000;
			active <= 1'b0;
		end
		else
		begin
			if(done)
				decoder_phi <= (decoder_phi >= 14'd199) ? 14'h0000 : (decoder_phi + 14'h0001);
			active <= ~done;
		end
	end
	assign trig = ~active;

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 0;
		cpr_inv = 0;

		// Wait 100 ns for global reset to finish
		#20 rst = 1'b1;
		#100 rst = 1'b0;
        
		// Add stimulus here
		cpr_inv = 2**28 / 200;
	end
      
endmodule

