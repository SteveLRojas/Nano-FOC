module pwm_ramp
	#(
		parameter NUM_BITS = 10,
		parameter USE_FAST_LOGIC = 1'b0
	)
	(
		input wire clk,
		input wire rst,
		input wire[NUM_BITS - 2 : 0] step_size,
		output reg[NUM_BITS - 1 : 0] pwm_ramp,
		output reg pwm_trig
	);
	
	generate
		if(USE_FAST_LOGIC)
		begin
			reg[NUM_BITS - 1 : 0] pwm_count;
	
			always @(posedge clk or posedge rst)
			begin
				if(rst)
				begin
					pwm_ramp <= {NUM_BITS{1'b0}};
					pwm_trig <= 1'b0;
					pwm_count <= {NUM_BITS{1'b0}};
				end
				else
				begin
					pwm_count <= pwm_count + {1'b0, step_size};
					pwm_ramp <= {pwm_count[NUM_BITS - 2 : 0] ^ {(NUM_BITS - 1){pwm_count[NUM_BITS - 1]}}, pwm_count[NUM_BITS - 1]};
					pwm_trig <= pwm_count[NUM_BITS - 1] & ~pwm_ramp[0];
				end
			end
		end
		else	//Use normal logic
		begin
			wire[NUM_BITS:0] add_res;
			assign add_res = pwm_ramp + ({NUM_BITS{pwm_ramp[0]}} ^ {step_size, 1'b0}) + pwm_ramp[0];
			
			always @(posedge clk or posedge rst)
			begin
				if(rst)
				begin
					pwm_ramp <= {NUM_BITS{1'b0}};
					pwm_trig <= 1'b0;
				end
				else
				begin
					pwm_ramp <= (add_res[NUM_BITS - 1 : 0] | {NUM_BITS{add_res[NUM_BITS] & ~pwm_ramp[0]}}) & {NUM_BITS{~pwm_ramp[0] | add_res[NUM_BITS]}};
					pwm_trig <= ~pwm_ramp[0] & add_res[NUM_BITS];
				end
			end
		end
	endgenerate
endmodule
