`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    21:55:46 03/03/2026 
// Design Name:    abz_decoder
// Module Name:    abz_decoder 
// Project Name:   ip_dev
// Target Devices: Spartan 6, Cyclone IV
// Tool versions:  ISE 14.7 Quartus 19.1 Lite
// Description:    ABZ decoder
//
// Dependencies: None
//
// Revision: 
// Revision 0.01 - File Created
// Revision 1.00 - Added inv_dir input
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module abz_decoder
	#(
		parameter NUM_BITS = 14
	)(
		input wire clk,
		input wire rst,
		input wire enc_a,
		input wire enc_b,
		input wire enc_z,
		input wire z_clear_en,
		input wire combined_z_pulse,
		input wire inv_dir,
		input wire[NUM_BITS - 1 : 0] max_count,
		input wire max_count_wren,
		output reg[NUM_BITS - 1 : 0] abz_phi,
		output reg abz_step,
		output reg abz_dir,
		output reg fault
    );

	reg enc_a_prev;
	reg enc_b_prev;
	reg count_up;
	reg count_down;
	reg count_up_selected;
	reg count_down_selected;
	reg z_clear;
	
	wire rising_a;
	wire rising_b;
	wire falling_a;
	wire falling_b;
	wire count_event;
	wire count_over;
	wire count_under;

	assign rising_a = enc_a & ~enc_a_prev;
	assign rising_b = enc_b & ~enc_b_prev;
	assign falling_a = ~enc_a & enc_a_prev;
	assign falling_b = ~enc_b & enc_b_prev;

	assign count_event = count_up_selected ^ count_down_selected;
	assign count_over = ~|(abz_phi ^ max_count) & count_up_selected;
	assign count_under = ~|abz_phi & count_down_selected;

	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			abz_phi <= {NUM_BITS{1'b0}};
			abz_step <= 1'b0;
			abz_dir <= 1'b0;
			fault <= 1'b0;
			enc_a_prev <= 1'b0;
			enc_b_prev <= 1'b0;
			count_up <= 1'b0;
			count_down <= 1'b0;
			count_up_selected <= 1'b0;
			count_down_selected <= 1'b0;
			z_clear <= 1'b0;
		end
		else
		begin
			enc_a_prev <= enc_a;
			enc_b_prev <= enc_b;
			count_up <= (rising_a & enc_b) | (rising_b & ~enc_a) | (falling_a & ~enc_b) | (falling_b & enc_a);
			count_down <= (rising_a & ~enc_b) | (rising_b & enc_a) | (falling_a & enc_b) | (falling_b & ~enc_a);
			count_up_selected <= inv_dir ? count_down : count_up;
			count_down_selected <= inv_dir ? count_up : count_down;
			z_clear <= z_clear_en & enc_z & ((enc_a & enc_b) | ~combined_z_pulse);
			
			if(count_event | max_count_wren | z_clear)
			begin
				if(max_count_wren | z_clear | count_over | count_under)
				begin
					abz_phi <= {NUM_BITS{~(max_count_wren | z_clear | count_over)}} & max_count;
				end
				else
				begin
					abz_phi <= abz_phi + {{(NUM_BITS - 1){count_down_selected}}, 1'b1};
				end
			end
			
			abz_step <= count_event;
			abz_dir <= (abz_dir | count_down_selected) & ~count_up_selected;
			fault <= count_up_selected & count_down_selected;
		end
	end
endmodule
