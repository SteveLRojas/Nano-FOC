`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   08:31:54 10/29/2025
// Design Name:   landshark_adc_bridge_controller
// Module Name:   /home/ise/VM_share/ip_dev2/src/tb_landshark_adc_bridge_controller.v
// Project Name:  ip_dev2
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: landshark_adc_bridge_controller
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_landshark_adc_bridge_controller;

	// Inputs
	reg clk;
	reg rst;
	reg trig;
	reg adc_miso_x1;
	reg adc_miso_x2;
	reg adc_miso_y1;
	reg adc_miso_y2;

	// Outputs
	wire adc_sck;
	wire adc_ncs;
	wire [13:0] i_x1;
	wire [13:0] i_x2;
	wire [13:0] i_y1;
	wire [13:0] i_y2;
	wire done;

	// Instantiate the Unit Under Test (UUT)
	landshark_adc_bridge_controller uut (
		.clk(clk), 
		.rst(rst), 
		.trig(trig), 
		.adc_miso_x1(adc_miso_x1), 
		.adc_miso_x2(adc_miso_x2), 
		.adc_miso_y1(adc_miso_y1), 
		.adc_miso_y2(adc_miso_y2), 
		.adc_sck(adc_sck), 
		.adc_ncs(adc_ncs), 
		.i_x1(i_x1), 
		.i_x2(i_x2), 
		.i_y1(i_y1), 
		.i_y2(i_y2), 
		.done(done)
	);
	
	always #10 clk = ~clk;

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 1'b1;
		trig = 0;
		adc_miso_x1 = 0;
		adc_miso_x2 = 0;
		adc_miso_y1 = 0;
		adc_miso_y2 = 0;

		// Wait 100 ns for global reset to finish
		#100;
		rst = 1'b0;
		#20 trig = 1'b1;
		#20 trig = 1'b0;
		
		#1860 adc_miso_x1 = 1'b1;
		adc_miso_x2 = 1'b1;
		adc_miso_y1 = 1'b1;
		adc_miso_y2 = 1'b1;
		#20 trig = 1'b1;
		#20 trig = 1'b0;
        
		// Add stimulus here

	end
      
endmodule

