module pwm_comp
	#(parameter NUM_BITS = 10)
	(
		input wire clk,
		input wire rst,
		input wire[NUM_BITS - 1 : 0] pwm_ramp,
		input wire[NUM_BITS - 1 : 0] duty_cycle,
		output reg pwm
	);
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
			pwm <= 1'b0;
		else
			pwm <= (duty_cycle > pwm_ramp);
	end
	
endmodule
