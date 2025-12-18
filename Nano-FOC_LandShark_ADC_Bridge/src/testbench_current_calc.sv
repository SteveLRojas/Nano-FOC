`timescale 1ns / 1ps

module testbench_current_calc;
	real PI;
	real phase_u;
	real phase_v;
	real phase_w;
	integer int_u;
	integer int_v;
	integer int_w;
	reg[15:0] phi;
	
	assign PI = 3.14159265358979323846;
	assign phase_u = $sin(($itor(phi) / 65536.0) * 2 * PI);
	assign phase_v = $sin(($itor(phi) / 65536.0 + 1.0 / 3.0) * 2 * PI);
	assign phase_w = $sin(($itor(phi) / 65536.0 + 2.0 / 3.0) * 2 * PI);
	assign int_u = $rtoi(8191.0 * phase_u);
	assign int_v = $rtoi(8191.0 * phase_v);
	assign int_w = $rtoi(8191.0 * phase_w);
	
	reg clk_25;
	reg clk_250;
	reg rst;
	
	wire pwm_ux1_l;
	wire pwm_vx2_l;
	wire pwm_wy1_l;
	wire adc_conv;

	wire signed[13:0] i_u_ref;
	wire signed[13:0] i_v_ref;
	wire signed[13:0] i_w_ref;
	wire signed[13:0] i_u_test;
	wire signed[13:0] i_v_test;
	wire signed[13:0] i_w_test;
	wire signed[13:0] i_u_diff;
	wire signed[13:0] i_v_diff;
	wire signed[13:0] i_w_diff;
	wire calc_done;
	
	assign i_u_diff = i_u_test - i_u_ref;
	assign i_v_diff = i_v_test - i_v_ref;
	assign i_w_diff = i_w_test - i_w_ref;
	
	always @(posedge clk_25)
	begin
		if(rst)
			phi <= 16'h0000;
		else
			phi <= phi + 16'h0001;
	end

//####### ADC Control #########################################################
	reg pwm_trig_25;
	reg[1:0] adc_sample_timer;
	reg do_dummy_sample;
	wire adc_valid;
	
	wire adc_controller_start;
	wire conv_done;
	
	assign adc_controller_start = pwm_trig_25 | &adc_sample_timer;
	assign adc_valid = conv_done & ~do_dummy_sample;
	
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
		begin
			do_dummy_sample <= 1'b0;
			adc_sample_timer <= 2'b00;
		end
		else
		begin
			do_dummy_sample <= (do_dummy_sample | pwm_trig_25) & ~conv_done;
			if(|adc_sample_timer | (conv_done & do_dummy_sample))
				adc_sample_timer <= adc_sample_timer + 2'b01;
		end
	end
	
	ltc2351_controller ltc2351_controller_i(
		.adc_clk(clk_25),
		.rst(rst),
		.trigger_in(adc_controller_start),
		.adc_miso(1'b0),
		.adc_conv(adc_conv),
		.i_x1(),
		.i_x2(),
		.i_y1(),
		.i_y2(),
		.v_vm(),
		.conv_done(conv_done)
	);
//#############################################################################

//#############################################################################
	reg pwm_ux1_l_25;
	reg pwm_vx2_l_25;
	reg pwm_wy1_l_25;
	
	current_calc
	#(
		.SETUP_BITS(6),
		.HOLD_BITS(3)
	) uut_ref
	(
		.clk(clk_25),
		.rst(rst),
		.setup_cycles(6'd30),
		.hold_cycles(3'd3),
		.pwm_u_l(1'b1),
		.pwm_v_l(1'b1),
		.pwm_w_l(1'b1),
		.adc_trig(pwm_trig_25),
		.adc_done(adc_valid),
		.i_u_neg(~int_u[13:0]),	//not negative, just all bits flipped
		.i_v_neg(~int_v[13:0]),
		.i_w_neg(~int_w[13:0]),
		.i_u(i_u_ref),
		.i_v(i_v_ref),
		.i_w(i_w_ref),
		.calc_done()
	);
	
	current_calc
	#(
		.SETUP_BITS(6),
		.HOLD_BITS(3)
	) uut_test
	(
		.clk(clk_25),
		.rst(rst),
		.setup_cycles(6'd30),
		.hold_cycles(3'd3),
		.pwm_u_l(pwm_ux1_l_25),
		.pwm_v_l(pwm_vx2_l_25),
		.pwm_w_l(pwm_wy1_l_25),
		.adc_trig(pwm_trig_25),
		.adc_done(adc_valid),
		.i_u_neg(~int_u[13:0]),	//not negative, just all bits flipped
		.i_v_neg(~int_v[13:0]),
		.i_w_neg(~int_w[13:0]),
		.i_u(i_u_test),
		.i_v(i_v_test),
		.i_w(i_w_test),
		.calc_done(calc_done)
	);
//#############################################################################

//####### PWM Control #########################################################
	reg pwm_trig_hold;
	wire pwm_trig_250;
	wire[13:0] pwm_ramp;
	wire[13:0] duty_cycle[2:0];
	wire pwm[2:0];
	
	assign duty_cycle[0] = {~int_u[13], int_u[12:0]};	//scaled_sine_ff + 8192
	assign duty_cycle[1] = {~int_v[13], int_v[12:0]};
	assign duty_cycle[2] = {~int_w[13], int_w[12:0]};

	//PWM trig clock domain crossing
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
			pwm_trig_25 <= 1'b0;
		else
			pwm_trig_25 <= pwm_trig_hold;
	end
	
	always @(posedge clk_250 or posedge rst)
	begin
		if(rst)
			pwm_trig_hold <= 1'b0;
		else
			pwm_trig_hold <= (pwm_trig_hold | pwm_trig_250) & ~pwm_trig_25;
	end
	
	pwm_ramp
	#(
		.NUM_BITS(14),
		.USE_FAST_LOGIC(1'b0)
	) pwm_ramp_i
	(
		.clk(clk_250),
		.rst(rst),
		.step_size(13'd2),
		.pwm_ramp(pwm_ramp),
		.pwm_trig(pwm_trig_250)
	);
	
	pwm_comp
	#(.NUM_BITS(14)) pwm_comp_u
	(
		.clk(clk_250),
		.rst(rst),
		.pwm_ramp(pwm_ramp),
		.duty_cycle(duty_cycle[0]),
		.pwm(pwm[0])
	);
	
	pwm_comp
	#(.NUM_BITS(14)) pwm_comp_v
	(
		.clk(clk_250),
		.rst(rst),
		.pwm_ramp(pwm_ramp),
		.duty_cycle(duty_cycle[1]),
		.pwm(pwm[1])
	);
	
	pwm_comp
	#(.NUM_BITS(14)) pwm_comp_w
	(
		.clk(clk_250),
		.rst(rst),
		.pwm_ramp(pwm_ramp),
		.duty_cycle(duty_cycle[2]),
		.pwm(pwm[2])
	);
//#############################################################################

//####### Deadtime Control ####################################################
	wire dt_out_h[2:0];
	wire dt_out_l[2:0];
	
	//PWM clock domain crossing
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
		begin
			pwm_ux1_l_25 <= 1'b0;
			pwm_vx2_l_25 <= 1'b0;
			pwm_wy1_l_25 <= 1'b0;
		end
		else
		begin
			pwm_ux1_l_25 <= pwm_ux1_l;
			pwm_vx2_l_25 <= pwm_vx2_l;
			pwm_wy1_l_25 <= pwm_wy1_l;
		end
	end
	
	dt_control
	#(
		.NUM_CHANNELS(3),
		.TIMER_BITS(8)
	) dt_control_i
	(
		.clk(clk_250),
		.rst(rst),
		.shutdown(1'b0),
		.dt_val(8'd75),
		.dt_in(pwm),
		.dt_out_h(dt_out_h),
		.dt_out_l(dt_out_l)
	);
	
	assign pwm_ux1_l = dt_out_l[0];
	assign pwm_vx2_l = dt_out_l[1];
	assign pwm_wy1_l = dt_out_l[2];
//#############################################################################

	always
	begin
		#20 clk_25 = ~clk_25;
	end
	
	always
	begin
		#2 clk_250 = ~clk_250;
	end

	initial
	begin
		// Initialize Inputs
		clk_25 = 1'b0;
		clk_250 = 1'b0;
		rst = 1'b1;

		// Wait 100 ns for global reset to finish
		#80;
        
		// Add stimulus here
		rst = 1'b0;

	end
	
endmodule
