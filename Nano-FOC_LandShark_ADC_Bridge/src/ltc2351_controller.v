module ltc2351_controller
	#(
		parameter USE_TIMER = 1'b0
	)
	(
		input wire adc_clk,
		input wire rst,
		input wire trigger_in,
		input wire adc_miso,
		output reg adc_conv,
		output reg[13:0] i_x1,
		output reg[13:0] i_x2,
		output reg[13:0] i_y1,
		output reg[13:0] i_y2,
		output reg[13:0] v_vm,
		output reg conv_done
	);
	//designed for sel2 = 1, sel1 = 0, sel0 = 0, BIP = 1
	//Channel 0: I_X1 (U)
	//Channel 1: I_X2 (V)
	//Channel 2: I_Y1 (W)
	//Channel 3: I_Y2
	//Channel 4: VM
	
	reg transfer_active;
	reg[80:0] shift_reg;
	wire trigger;
	
	
	generate
		if(USE_TIMER)
		begin
			wire timer_end;
			reg[6:0] timer;
			
			assign timer_end = (timer == 7'd83);
			assign trigger = timer_end;
			
			always @(posedge adc_clk or posedge rst)
			begin
				if(rst)
				begin
					timer <= 7'h00;
				end
				else
				begin
					if(timer_end)
						timer <= 7'd0;
					else
						timer <= timer + 7'd1;
				end
			end
		end
		else
		begin
			assign trigger = trigger_in;
		end
	endgenerate
	
	always @(posedge adc_clk or posedge rst)
	begin
		if(rst)
		begin
			adc_conv <= 1'b0;
			i_x1 <= 14'h0000;
			i_x2 <= 14'h0000;
			i_y1 <= 14'h0000;
			i_y2 <= 14'h0000;
			v_vm <= 14'h0000;
			conv_done <= 1'b0;
			transfer_active <= 1'b0;
			shift_reg <= 81'h0;
		end
		else
		begin
			adc_conv <= trigger;
			transfer_active <= (transfer_active | trigger) & ~shift_reg[80];
			conv_done <= shift_reg[80];
			
			if(shift_reg[80])
			begin
				shift_reg <= 81'd0;
				v_vm <= shift_reg[13:0];
				i_y2 <= shift_reg[29:16];
				i_y1 <= shift_reg[45:32];
				i_x2 <= shift_reg[61:48];
				i_x1 <= shift_reg[77:64];
			end
			else
			begin
				shift_reg <= {shift_reg[79:0], ((adc_miso & transfer_active) | adc_conv)};
			end
		end
	end
	
endmodule
