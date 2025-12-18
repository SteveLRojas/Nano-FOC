module dt_control
	#(
		parameter NUM_CHANNELS = 3,
		parameter TIMER_BITS = 8
	)
	(
		input wire clk,
		input wire rst,
		input wire shutdown,
		input wire[TIMER_BITS - 1 : 0] dt_val,
		input wire[NUM_CHANNELS - 1 : 0] dt_in,
		output wire[NUM_CHANNELS - 1 : 0] dt_out_h,
		output wire[NUM_CHANNELS - 1 : 0] dt_out_l
	);

	reg[NUM_CHANNELS - 1 : 0] out_h;
	reg[NUM_CHANNELS - 1 : 0] out_l;
	reg[TIMER_BITS - 1 : 0] timer[NUM_CHANNELS - 1 : 0];
	reg prev_in[NUM_CHANNELS - 1 : 0];
	reg delayed_in[NUM_CHANNELS - 1 : 0];
	
	wire timer_nz[NUM_CHANNELS - 1 : 0];
	
	assign dt_out_h = out_h;
	assign dt_out_l = out_l;
	
	genvar d;
	generate
		for(d = 0; d < NUM_CHANNELS; d = d + 1)
		begin : comb_assign
			assign timer_nz[d] = |timer[d];
		end
	endgenerate
	
	
	integer i;
	always @(posedge clk or posedge rst)
	begin
		for(i = 0; i < NUM_CHANNELS; i = i + 1)
		begin
			if(rst)
			begin			
				out_h[i] <= 1'b0;
				out_l[i] <= 1'b0;
				timer[i] <= {TIMER_BITS{1'b0}};
				prev_in[i] <= 1'b0;
				delayed_in[i] <= 1'b0;
			end
			else
			begin
				prev_in[i] <= dt_in[i];
				if(prev_in[i] ^ dt_in[i])
					timer[i] <= dt_val;
				else if(timer_nz[i])
					timer[i] <= timer[i] - {{(TIMER_BITS - 1){1'b0}}, 1'b1};
				
				if(~timer_nz[i])
					delayed_in[i] <= prev_in[i];
				
				out_h[i] <= ~shutdown & delayed_in[i] & prev_in[i];
				out_l[i] <= ~shutdown & ~delayed_in[i] & ~prev_in[i];
			end
		end
	end

endmodule
