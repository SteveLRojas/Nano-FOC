module current_calc
	#(
		parameter SETUP_BITS = 6,
		parameter HOLD_BITS = 3
	)
	(
		input wire clk,
		input wire rst,
		input wire[SETUP_BITS - 1 : 0] setup_cycles,
		input wire[HOLD_BITS - 1 : 0] hold_cycles,
		input wire pwm_u_l,
		input wire pwm_v_l,
		input wire pwm_w_l,
		input wire adc_trig,
		input wire adc_done,
		input wire signed[13:0] i_u_neg,	//not negative, just all bits flipped
		input wire signed[13:0] i_v_neg,
		input wire signed[13:0] i_w_neg,
		output reg signed[13:0] i_u,
		output reg signed[13:0] i_v,
		output reg signed[13:0] i_w,
		output reg calc_done
	);
	
	reg[SETUP_BITS - 1 : 0] setup_timer_u;
	reg[SETUP_BITS - 1 : 0] setup_timer_v;
	reg[SETUP_BITS - 1 : 0] setup_timer_w;
	reg[HOLD_BITS - 1 : 0] hold_timer_u;
	reg[HOLD_BITS - 1 : 0] hold_timer_v;
	reg[HOLD_BITS - 1 : 0] hold_timer_w;
	reg setup_met_u;
	reg setup_met_v;
	reg setup_met_w;
	reg hold_met_u;
	reg hold_met_v;
	reg hold_met_w;
	
	wire setup_timer_u_nz;
	wire setup_timer_v_nz;
	wire setup_timer_w_nz;
	wire hold_timer_u_nz;
	wire hold_timer_v_nz;
	wire hold_timer_w_nz;
	
	wire i_u_neg_valid;
	wire i_v_neg_valid;
	wire i_w_neg_valid;
	
	assign setup_timer_u_nz = |setup_timer_u;
	assign setup_timer_v_nz = |setup_timer_v;
	assign setup_timer_w_nz = |setup_timer_w;
	assign hold_timer_u_nz = |hold_timer_u;
	assign hold_timer_v_nz = |hold_timer_v;
	assign hold_timer_w_nz = |hold_timer_w;
	
	assign i_u_neg_valid = setup_met_u & hold_met_u;
	assign i_v_neg_valid = setup_met_v & hold_met_v;
	assign i_w_neg_valid = setup_met_w & hold_met_w;

	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			i_u <= 14'h0000;
			i_v <= 14'h0000;
			i_w <= 14'h0000;
			calc_done <= 1'b0;
			setup_timer_u <= {SETUP_BITS{1'b0}};
			setup_timer_v <= {SETUP_BITS{1'b0}};
			setup_timer_w <= {SETUP_BITS{1'b0}};
			hold_timer_u <= {HOLD_BITS{1'b0}};
			hold_timer_v <= {HOLD_BITS{1'b0}};
			hold_timer_w <= {HOLD_BITS{1'b0}};
			setup_met_u <= 1'b0;
			setup_met_v <= 1'b0;
			setup_met_w <= 1'b0;
			hold_met_u <= 1'b0;
			hold_met_v <= 1'b0;
			hold_met_w <= 1'b0;
		end
		else
		begin
			setup_timer_u <= pwm_u_l ? (setup_timer_u + {SETUP_BITS{setup_timer_u_nz}}) : setup_cycles;
			setup_timer_v <= pwm_v_l ? (setup_timer_v + {SETUP_BITS{setup_timer_v_nz}}) : setup_cycles;
			setup_timer_w <= pwm_w_l ? (setup_timer_w + {SETUP_BITS{setup_timer_w_nz}}) : setup_cycles;
			
			hold_timer_u <= adc_trig ? hold_cycles : (hold_timer_u + {HOLD_BITS{1'b1}});
			hold_timer_v <= adc_trig ? hold_cycles : (hold_timer_v + {HOLD_BITS{1'b1}});
			hold_timer_w <= adc_trig ? hold_cycles : (hold_timer_w + {HOLD_BITS{1'b1}});
			
			setup_met_u <= ((~setup_timer_u_nz & adc_trig) | setup_met_u) & ~adc_done;
			setup_met_v <= ((~setup_timer_v_nz & adc_trig) | setup_met_v) & ~adc_done;
			setup_met_w <= ((~setup_timer_w_nz & adc_trig) | setup_met_w) & ~adc_done;
			
			hold_met_u <= (~hold_timer_u_nz | hold_met_u) & ~adc_trig;
			hold_met_v <= (~hold_timer_v_nz | hold_met_v) & ~adc_trig;
			hold_met_w <= (~hold_timer_w_nz | hold_met_w) & ~adc_trig;
			
			if(adc_done)
			begin
				i_u <= i_u_neg_valid ? (~i_u_neg) : (i_v_neg + i_w_neg + 14'h2);
				i_v <= i_v_neg_valid ? (~i_v_neg) : (i_u_neg + i_w_neg + 14'h2);
				i_w <= i_w_neg_valid ? (~i_w_neg) : (i_u_neg + i_v_neg + 14'h2);
			end
			
			calc_done <= adc_done;
		end
	end
endmodule
