module landshark_adc_bridge_controller(
		input wire clk,
		input wire rst,
		input wire trig,
		input wire adc_miso_x1,
		input wire adc_miso_x2,
		input wire adc_miso_y1,
		input wire adc_miso_y2,
		output reg adc_sck,
		output wire adc_ncs,
		output reg[13:0] i_x1,
		output reg[13:0] i_x2,
		output reg[13:0] i_y1,
		output reg[13:0] i_y2,
		output wire done
	);
	
	reg do_dummy_sample;
	reg[3:0] acq_timer;
	reg trigger_ff;
	reg transfer_active;
	reg[17:0] shift_reg_x1;
	reg[15:0] shift_reg_x2;
	reg[15:0] shift_reg_y1;
	reg[15:0] shift_reg_y2;
	reg conv_done;
	
	wire acq_end;
	wire conv_trigger;
	
	assign adc_ncs = ~transfer_active;
	assign acq_end = acq_timer == 4'd10;
	assign conv_trigger = trig | acq_end;
	assign done = conv_done & ~do_dummy_sample;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			adc_sck <= 1'b0;
			i_x1 <= 14'h0000;
			i_x2 <= 14'h0000;
			i_y1 <= 14'h0000;
			i_y2 <= 14'h0000;
			do_dummy_sample <= 1'b0;
			acq_timer <= 4'h0;
			trigger_ff <= 1'b0;
			transfer_active <= 1'b0;
			shift_reg_x1 <= 18'h00000;
			shift_reg_x2 <= 16'h0000;
			shift_reg_y1 <= 16'h0000;
			shift_reg_y2 <= 16'h0000;
			conv_done <= 1'b0;
		end
		else
		begin
			do_dummy_sample <= (do_dummy_sample | trig) & ~conv_done;
			if(|acq_timer | (conv_done & do_dummy_sample))
				acq_timer <= acq_end ? 4'h0 : (acq_timer + 4'h1);
		
			trigger_ff <= conv_trigger;
			transfer_active <= (transfer_active | conv_trigger) & ~shift_reg_x1[17];
			adc_sck <= transfer_active & ~adc_sck;
			conv_done <= shift_reg_x1[17];
			
			if((transfer_active & ~adc_sck) | shift_reg_x1[17])
			begin
				if(shift_reg_x1[17])
				begin
					shift_reg_x1 <= {17'h00000, adc_miso_x1 | trigger_ff};
					i_x1 <= shift_reg_x1[15:2];
					i_x2 <= shift_reg_x2[15:2];
					i_y1 <= shift_reg_y1[15:2];
					i_y2 <= shift_reg_y2[15:2];
				end
				else
				begin
					shift_reg_x1 <= {shift_reg_x1[16:0], adc_miso_x1 | trigger_ff};
				end
				shift_reg_x2 <= {shift_reg_x2[14:0], adc_miso_x2};
				shift_reg_y1 <= {shift_reg_y1[14:0], adc_miso_y1};
				shift_reg_y2 <= {shift_reg_y2[14:0], adc_miso_y2};
			end
		end
	end
	
endmodule
