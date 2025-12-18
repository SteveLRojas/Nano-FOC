module nano_foc_top
	(
		input wire clk,	//25MHz
		input wire[3:0] button_n,
		output wire[3:0] led,
		output wire int_out,
		
		output wire pwm_ux1_h,
		output wire pwm_vx2_h,
		output wire pwm_wy1_h,
		output wire pwm_y2_h,
		output wire pwm_ux1_l,
		output wire pwm_vx2_l,
		output wire pwm_wy1_l,
		output wire pwm_y2_l,
		
		input wire adc_miso_u,
		input wire adc_miso_w,
		output wire adc_sck_u,
		output wire adc_sck_w,
		output wire adc_ncs_u,
		output wire adc_ncs_w,
		
		input wire hall_u,
		input wire hall_v,
		input wire hall_w,
		
		input wire spi_sck,
		input wire spi_ncs,
		input wire spi_mosi,
		output wire spi_miso
	);
// rpm = 60 * target_velocity * 25e6 / (2^21 * 2^5 * npp)
// target_velocity = rpm * 2^21 * 2^5 * npp / (60 * 25e6)
// PID settings for 42BLF02: Kp = 16'h0200, Ki = 16'h0020, Kd = 16'h0000
// PID shift factors: Kp >> 10, Ki >> 14, Kd >> 10

//Address map for RI:
// 0x00 to 0x0F	Status Block	(read write)
// 0x10 to 0x1F	Syscon Block	(read write)
// 0x20 to 0x2F	Hall Block		(read write)
// 0x30 to 0x3F	Phicon Block	(read write)
// 0x40 to 0x4F ADC Block		(read write)
// 0x50 to 0x5F FOC Block		(read write)

	localparam CPOL = 1'b0;
	localparam CPHA = 1'b1;

//####### PLL #################################################################
	wire clk_25;
	wire clk_250;

	PLL pll_i(
		.inclk0(clk),
		.c0(clk_25),
		.c1(clk_250));
//#############################################################################

//####### IO Control ##########################################################
	wire rst;
	wire[3:0] button_d;

	reg hall_u_sync[1:0];
	reg hall_v_sync[1:0];
	reg hall_w_sync[1:0];
	
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
		begin
			hall_u_sync[0] <= 1'b0;
			hall_u_sync[1] <= 1'b0;
			hall_v_sync[0] <= 1'b0;
			hall_v_sync[1] <= 1'b0;
			hall_w_sync[0] <= 1'b0;
			hall_w_sync[1] <= 1'b0;
		end
		else
		begin
			hall_u_sync[0] <= hall_u;
			hall_u_sync[1] <= hall_u_sync[0];
			hall_v_sync[0] <= hall_v;
			hall_v_sync[1] <= hall_v_sync[0];
			hall_w_sync[0] <= hall_w;
			hall_w_sync[1] <= hall_w_sync[0];
		end
	end
	
	button_debounce
	#(
		.INVERT_BUTTONS(1'b1),
		.NUM_BUTTONS(4),
		.CLK_DIV_BITS(15)	//25MHz
	) button_debounce_i
	(
		.clk(clk_25),
		.rst_in(1'b1),
		.button_in(button_n),
		.rst_out(rst),
		.button_out(button_d)
	);
	
	reg rst_250;	//needed for recovery timing reasons
	always @(posedge clk_250)
	begin
		rst_250 <= rst;
	end
//#############################################################################

//####### Register Interface ##################################################
	wire power_fault;
	wire hall_fault;
	reg pwm_trig_25;
	wire adc_done;
	reg ocp_flag;
	wire current_calc_done;
	wire clarke_done;
	wire park_done;
	wire pid_torque_flux_done;
	wire inverse_park_done;
	wire inverse_clarke_done;

	//system control block
	wire[1:0] phi_source;
	wire vd_vq_source;
	wire vu_vv_vw_source;
	wire[9:0] pwm_step_size_25;
	wire[7:0] pwm_dead_time;
	wire signed[13:0] v_u_ext;
	wire signed[13:0] v_v_ext;
	wire signed[13:0] v_w_ext;
	wire[9:0] int_out_div;
	wire int_out_mode;
	wire int_out_pol;
	wire int_out_en;
	
	// Hall block
	wire[2:0] hall_sector;
	wire[13:0] hall_phi;
	wire[13:0] extpol_phi;
	wire[13:0] hall_offset;
	
	// Phi control block
	wire[9:0] ol_acceleration;
	wire signed[11:0] ol_target_velocity;
	wire signed[11:0] ol_actual_velocity;
	wire ol_target_reached;
	wire[13:0] ol_phi;
	wire[13:0] ext_phi;
	wire[13:0] selected_phi;
	
	//ADC monitor block
	wire signed[13:0] i_x1;	//i_u_raw
	wire signed[13:0] i_y1;	//i_w_raw
	wire signed[13:0] i_u_offset;
	wire signed[13:0] i_w_offset;
	reg signed[13:0] i_u;	//i_u_kcl
	reg signed[13:0] i_v;	//i_v_kcl
	reg signed[13:0] i_w;	//i_w_kcl
	
	//Smashed status block (implement on top level)
	reg[14:0] from_status_ri;
	reg hall_fault_flag;
	reg power_stage_en;
	reg adc_done_flag;
	reg kcl_done_flag;
	reg clarke_done_flag;
	reg park_done_flag;
	reg pid_done_flag;
	reg i_park_done_flag;
	reg i_clarke_done_flag;
	
	//FOC block
	wire signed[13:0] i_alpha;
	wire signed[13:0] i_beta;
	wire signed[13:0] i_d;	//flux
	wire signed[13:0] i_q;	//torque
	wire signed[13:0] flux_target;
	wire signed[13:0] flux_kp;
	wire signed[13:0] flux_ki;
	wire signed[13:0] flux_kd;
	wire signed[13:0] v_d;	//flux_pid_out
	wire signed[13:0] v_d_ext;
	wire signed[13:0] torque_target;
	wire signed[13:0] torque_kp;
	wire signed[13:0] torque_ki;
	wire signed[13:0] torque_kd;
	wire signed[13:0] v_q;	//torque_pid_out
	wire signed[13:0] v_q_ext;
	
	//SPI
	wire[23:0] spi_to_host;
	wire[23:0] spi_from_host;
	wire spi_start;
	wire spi_done;
	
	spi_agent
	#(
		.IMPLEMENTATION(3),
		.LOAD_MODE(1'b0),
		.CPOL(CPOL),
		.CPHA(CPHA),
		.NUM_BITS(24)
	) spi_i
	(
		.clk(clk_25),
		.rst(rst),
		.sck(spi_sck),
		.ncs(spi_ncs),
		.mosi(spi_mosi),
		.miso(spi_miso),
		.to_host(spi_to_host),
		.from_host(spi_from_host),
		.start(spi_start),
		.done(spi_done)
	);
	
	//ri bus
	wire[15:0] to_ri;
	wire[15:0] from_ri;
	wire[6:0] ri_addr;
	wire ri_wren;
	
	spi_controller spi_controller_i(
		.clk(clk_25),
		.rst(rst),
		
		.to_host(spi_to_host),
		.from_host(spi_from_host),
		.start(spi_start),
		.done(spi_done),
		
		.status({1'b0, from_status_ri}),
		.to_ri(to_ri),
		.from_ri(from_ri),
		.ri_addr(ri_addr),
		.ri_wren(ri_wren)
	);
	
	//status ri
	wire status_ri_en;
	wire clear_ocp;
	
	assign clear_ocp = status_ri_en & ri_wren & ~to_ri[0];
	
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
		begin
			from_status_ri <= 15'h0000;
			hall_fault_flag <= 1'b0;
			power_stage_en <= 1'b0;
			adc_done_flag <= 1'b0;
			kcl_done_flag <= 1'b0;
			clarke_done_flag <= 1'b0;
			park_done_flag <= 1'b0;
			pid_done_flag <= 1'b0;
			i_park_done_flag <= 1'b0;
			i_clarke_done_flag <= 1'b0;
		end
		else
		begin
			from_status_ri[0] <= ocp_flag;
			from_status_ri[1] <= 1'b0;	//UVP flag
			from_status_ri[2] <= hall_fault_flag;
			from_status_ri[3] <= power_stage_en;
			from_status_ri[4] <= adc_done_flag;
			from_status_ri[5] <= kcl_done_flag;
			from_status_ri[6] <= clarke_done_flag;
			from_status_ri[7] <= park_done_flag;
			from_status_ri[8] <= pid_done_flag;
			from_status_ri[9] <= i_park_done_flag;
			from_status_ri[10] <= i_clarke_done_flag;
			from_status_ri[14:11] <= button_d;
			
			if(hall_fault | (status_ri_en & ri_wren))
				hall_fault_flag <= hall_fault | (hall_fault_flag & to_ri[2]);
			if(power_fault | (status_ri_en & ri_wren))
				power_stage_en <= ~power_fault & to_ri[3];
			adc_done_flag <= ~pwm_trig_25 & (adc_done_flag | adc_done);
			kcl_done_flag <= ~pwm_trig_25 & (kcl_done_flag | current_calc_done);
			clarke_done_flag <= ~pwm_trig_25 & (clarke_done_flag | clarke_done);
			park_done_flag <= ~pwm_trig_25 & (park_done_flag | park_done);
			pid_done_flag <= ~pwm_trig_25 & (pid_done_flag | pid_torque_flux_done);
			i_park_done_flag <= ~pwm_trig_25 & (i_park_done_flag | inverse_park_done);
			i_clarke_done_flag <= ~pwm_trig_25 & (i_clarke_done_flag | inverse_clarke_done);
		end
	end
	
	wire syscon_ri_en;
	wire hall_ri_en;
	wire phicon_ri_en;
	wire adc_ri_en;
	wire foc_ri_en;
	
	wire[15:0] from_syscon_ri;
	wire[15:0] from_hall_ri;
	wire[15:0] from_phicon_ri;
	wire[15:0] from_adc_ri;
	wire[15:0] from_foc_ri;
	
	//Address Decoding
	assign status_ri_en = (ri_addr[6:4] == 3'h0);
	assign syscon_ri_en = (ri_addr[6:4] == 3'h1);
	assign hall_ri_en   = (ri_addr[6:4] == 3'h2);
	assign phicon_ri_en = (ri_addr[6:4] == 3'h3);
	assign adc_ri_en    = (ri_addr[6:4] == 3'h4);
	assign foc_ri_en    = (ri_addr[6:4] == 3'h5);
	
	syscon_ri syscon_ri_i(
		.clk(clk_25),
		.rst(rst),
		.enable(syscon_ri_en),
		.wren(ri_wren),
		.addr(ri_addr[2:0]),
		.to_ri(to_ri),
		.from_ri(from_syscon_ri),
		
		.phi_source(phi_source),
		.vd_vq_source(vd_vq_source),
		.vu_vv_vw_source(vu_vv_vw_source),
		.pwm_step_size(pwm_step_size_25),
		.pwm_dead_time(pwm_dead_time),
		.v_u_ext(v_u_ext),
		.v_v_ext(v_v_ext),
		.v_w_ext(v_w_ext),
		.int_out_div(int_out_div),
		.int_out_mode(int_out_mode),
		.int_out_pol(int_out_pol),
		.int_out_en(int_out_en)
	);
	
	hall_ri hall_ri_i(
		.clk(clk_25),
		.rst(rst),
		.enable(hall_ri_en),
		.wren(ri_wren),
		.addr(ri_addr[1:0]),
		.to_ri(to_ri),
		.from_ri(from_hall_ri),
		
		.hall_sector(hall_sector),
		.hall_phi(hall_phi),
		.extpol_phi(extpol_phi),
		.hall_offset(hall_offset)
	);
	
	phicon_ri phicon_ri_i(
		.clk(clk_25),
		.rst(rst),
		.enable(phicon_ri_en),
		.wren(ri_wren),
		.addr(ri_addr[2:0]),
		.to_ri(to_ri),
		.from_ri(from_phicon_ri),
		
		.ol_acceleration(ol_acceleration),
		.ol_target_velocity(ol_target_velocity),
		.ol_actual_velocity(ol_actual_velocity),
		.ol_target_reached(ol_target_reached),
		.ol_phi(ol_phi),
		.ext_phi(ext_phi),
		.selected_phi(selected_phi)
	);
	
	adc_ri adc_ri_i(
		.clk(clk_25),
		.rst(rst),
		.enable(adc_ri_en),
		.wren(ri_wren),
		.addr(ri_addr[2:0]),
		.to_ri(to_ri),
		.from_ri(from_adc_ri),
		
		.i_u_raw(i_x1),
		.i_w_raw(i_y1),
		.i_u_offset(i_u_offset),
		.i_w_offset(i_w_offset),
		.i_u_kcl(i_u),
		.i_v_kcl(i_v),
		.i_w_kcl(i_w)
	);
	
	foc_ri foc_ri_i(
		.clk(clk_25),
		.rst(rst),
		.enable(foc_ri_en),
		.wren(ri_wren),
		.addr(ri_addr[3:0]),
		.to_ri(to_ri),
		.from_ri(from_foc_ri),
		
		.i_alpha(i_alpha),
		.i_beta(i_beta),
		.flux(i_d),
		.torque(i_q),
		.flux_target(flux_target),
		.flux_kp(flux_kp),
		.flux_ki(flux_ki),
		.flux_kd(flux_kd),
		.flux_pid_out(v_d),
		.v_d_ext(v_d_ext),
		.torque_target(torque_target),
		.torque_kp(torque_kp),
		.torque_ki(torque_ki),
		.torque_kd(torque_kd),
		.torque_pid_out(v_q),
		.v_q_ext(v_q_ext)
	);
	
	reg status_ri_en_ff;
	reg syscon_ri_en_ff;
	reg hall_ri_en_ff;
	reg phicon_ri_en_ff;
	reg adc_ri_en_ff;
	reg foc_ri_en_ff;
	
	wire[15:0] m_from_status_ri;
	wire[15:0] m_from_syscon_ri;
	wire[15:0] m_from_hall_ri;
	wire[15:0] m_from_phicon_ri;
	wire[15:0] m_from_adc_ri;
	wire[15:0] m_from_foc_ri;
	
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
		begin
			status_ri_en_ff <= 1'b0;
			syscon_ri_en_ff <= 1'b0;
			hall_ri_en_ff <= 1'b0;
			phicon_ri_en_ff <= 1'b0;
			adc_ri_en_ff <= 1'b0;
			foc_ri_en_ff <= 1'b0;
		end
		else
		begin
			status_ri_en_ff <= status_ri_en;
			syscon_ri_en_ff <= syscon_ri_en;
			hall_ri_en_ff <= hall_ri_en;
			phicon_ri_en_ff <= phicon_ri_en;
			adc_ri_en_ff <= adc_ri_en;
			foc_ri_en_ff <= foc_ri_en;
		end
	end
	
	assign m_from_status_ri = {1'b0, {15{status_ri_en_ff}} & from_status_ri};
	assign m_from_syscon_ri = {16{syscon_ri_en_ff}} & from_syscon_ri;
	assign m_from_hall_ri = {16{hall_ri_en_ff}} & from_hall_ri;
	assign m_from_phicon_ri = {16{phicon_ri_en_ff}} & from_phicon_ri;
	assign m_from_adc_ri = {16{adc_ri_en_ff}} & from_adc_ri;
	assign m_from_foc_ri = {16{foc_ri_en_ff}} & from_foc_ri;
	
	assign from_ri = m_from_status_ri | m_from_syscon_ri | m_from_hall_ri | m_from_phicon_ri | m_from_adc_ri | m_from_foc_ri;
	
	assign led[3] = ol_target_reached;
	assign led[2] = power_stage_en;
//#############################################################################

//####### Hall Decoder ########################################################
	wire[13:0] hall_phi_raw;
	assign hall_phi = hall_phi_raw + hall_offset;
	
	hall_decoder hall_decoder_i(
		.clk(clk_25),
		.rst(rst),
		.hall_u(hall_u_sync[1]),
		.hall_v(hall_v_sync[1]),
		.hall_w(hall_w_sync[1]),
		.hall_sector(hall_sector),
		.hall_phi(hall_phi_raw),
		.hall_step(),
		.hall_dir(),
		.fault(hall_fault)
	);
//#############################################################################

//####### Phi Extrapolator ####################################################
	phi_extrapolator phi_extrapolator_i(
		.clk(clk_25),
		.rst(rst),
		.phi_in(hall_phi),
		.phi_out(extpol_phi)
	);
//#############################################################################

//####### Phi Control #########################################################
	wire signed[13:0] sine_wave[2:0];

	phi_ramper
	#(
		.ACCEL_BITS(10),
		.VEL_DIV_BITS(12),
		.VEL_COUNTER_BITS(20),
		.VEL_BITS(12),
		.PHI_DIV_BITS(5),
		.PHI_COUNTER_BITS(21),
		.PHI_BITS(14)
	) phi_ramper_i
	(
		.clk(clk_25),
		.rst(rst),
		.acceleration(ol_acceleration),
		.target_velocity(ol_target_velocity),
		.actual_velocity(ol_actual_velocity),
		.target_reached(ol_target_reached),
		.phi(ol_phi)
	);
//#############################################################################

//####### ADC Control #########################################################
	wire adc_sck;
	wire adc_ncs;
	
	assign adc_sck_u = adc_sck;
	assign adc_sck_w = adc_sck;
	assign adc_ncs_u = adc_ncs;
	assign adc_ncs_w = adc_ncs;
	
	landshark_adc_bridge_controller adc_controller_i(
		.clk(clk_25),
		.rst(rst),
		.trig(pwm_trig_25),
		.adc_miso_x1(adc_miso_u),
		.adc_miso_x2(1'b0),
		.adc_miso_y1(adc_miso_w),
		.adc_miso_y2(1'b0),
		.adc_sck(adc_sck),
		.adc_ncs(adc_ncs),
		.i_x1(i_x1),
		.i_x2(),
		.i_y1(i_y1),
		.i_y2(),
		.done(adc_done)
	);
//#############################################################################

//####### Fault Detection #####################################################
	wire overcurrent_x1;
	wire overcurrent_y1;
	
	assign overcurrent_x1 = (&i_x1[13:0]) | (~|i_x1[13:0]);
	assign overcurrent_y1 = (&i_y1[13:0]) | (~|i_y1[13:0]);
	
	assign power_fault = ocp_flag;
	assign led[1:0] = {hall_fault_flag, ocp_flag};
	
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
		begin
			ocp_flag <= 1'b0;
		end
		else
		begin			
			if(adc_done & (overcurrent_x1 | overcurrent_y1))
				ocp_flag <= 1'b1;
			else if(clear_ocp)
				ocp_flag <= 1'b0;
		end
	end
//#############################################################################

//####### Current Calculation #################################################
	reg signed[13:0] i_x1_adjusted;
	reg signed[13:0] i_y1_adjusted;
	reg offset_done;
	
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
		begin
			i_u <= 14'h0000;
			i_v <= 14'h0000;
			i_w <= 14'h0000;
			current_calc_done <= 1'b0;
			i_x1_adjusted <= 14'h0000;
			i_y1_adjusted <= 14'h0000;
			offset_done <= 1'b0;
		end
		else
		begin
			i_x1_adjusted <= i_x1 + i_u_offset;
			i_y1_adjusted <= i_y1 + i_w_offset;
			offset_done <= adc_done;
			
			if(offset_done)
			begin
				i_u <= i_x1_adjusted;
				i_v <= ~i_x1_adjusted + ~i_y1_adjusted + 14'h2;	//TODO: this should probably be clipped
				i_w <= i_y1_adjusted;
			end
			current_calc_done <= offset_done;
		end
	end
//#############################################################################

//####### Phi Selection, Sine and Cosine Calculation ##########################
	wire signed[13:0] sin_phi;
	wire signed[13:0] cos_phi;
	
	assign selected_phi = phi_source[1] ? (phi_source[0] ? extpol_phi : hall_phi) : (phi_source[0] ? ol_phi : ext_phi);
	
	sin_cos_lut sin_cos_lut_i(
		.clk(clk_25),
		.rst(rst),
		.trig(pwm_trig_25),
		.phi(selected_phi),
		.sin(sin_phi),
		.cos(cos_phi),
		.done()
	);
//#############################################################################

//####### Clarke Transformation ###############################################
	balanced_clarke clarke_i(
		.clk(clk_25),
		.rst(rst),
		.trig(current_calc_done),
		.in_u(i_u),
		.in_v(i_v),
		.in_w(i_w),
		.alpha(i_alpha),
		.beta(i_beta),
		.done(clarke_done)
	);
//#############################################################################

//####### Park Transformation #################################################
	park_transform park_transform_i(
		.clk(clk_25),
		.rst(rst),
		.trig(clarke_done),
		.in_x(i_alpha),
		.in_y(i_beta),
		.cos_phi(cos_phi),
		.sin_phi(sin_phi),
		.out_d(i_d),
		.out_q(i_q),
		.done(park_done)
	);
//#############################################################################

//####### Torque and Flux PID Control #########################################
	reg prev_vd_vq_source;
	reg prev_vu_vv_vw_source;
	reg pid_reset_extra;
	wire pid_reset;
	
	assign pid_reset = rst | pid_reset_extra;
	
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
		begin
			prev_vd_vq_source <= 1'b0;
			prev_vu_vv_vw_source <= 1'b0;
			pid_reset_extra <= 1'b0;
		end
		else
		begin
			prev_vd_vq_source <= vd_vq_source;
			prev_vu_vv_vw_source <= vu_vv_vw_source;
			pid_reset_extra <= ~power_stage_en | (prev_vd_vq_source ^ vd_vq_source) | (prev_vu_vv_vw_source ^ vu_vv_vw_source);
		end
	end
	
	pid_control
	#(
		.NUM_BITS(14),
		.ACCUM_EXTRA_BITS(0),
		.KP_SHIFT_FACTOR(10),
		.KI_SHIFT_FACTOR(14),
		.KD_SHIFT_FACTOR(10)
	) pid_flux
	(
		.clk(clk_25),
		.rst(pid_reset),
		.trigger(park_done),
		.sp(flux_target),
		.pv(i_d),
		.kp(flux_kp),
		.ki(flux_ki),
		.kd(flux_kd),
		.cv(v_d),
		.done()
	);
	
	pid_control
	#(
		.NUM_BITS(14),
		.ACCUM_EXTRA_BITS(0),
		.KP_SHIFT_FACTOR(10),
		.KI_SHIFT_FACTOR(14),
		.KD_SHIFT_FACTOR(10)
	) pid_torque
	(
		.clk(clk_25),
		.rst(pid_reset),
		.trigger(park_done),
		.sp(torque_target),
		.pv(i_q),
		.kp(torque_kp),
		.ki(torque_ki),
		.kd(torque_kd),
		.cv(v_q),
		.done(pid_torque_flux_done)
	);
//#############################################################################

//####### Inverse Park Transformation #########################################
	wire signed[13:0] selected_v_d;
	wire signed[13:0] selected_v_q;
	wire signed[13:0] v_alpha;
	wire signed[13:0] v_beta;
	
	assign selected_v_d = vd_vq_source ? v_d_ext : v_d;
	assign selected_v_q = vd_vq_source ? v_q_ext : v_q;
	
	inverse_park inverse_park_i(
		.clk(clk_25),
		.rst(rst),
		.trig(pid_torque_flux_done),
		.in_d(selected_v_d),
		.in_q(selected_v_q),
		.cos_phi(cos_phi),
		.sin_phi(sin_phi),
		.out_x(v_alpha),
		.out_y(v_beta),
		.done(inverse_park_done)
	);
//#############################################################################

//####### Inverse Clarke Transformation #######################################
	wire signed[13:0] v_u;
	wire signed[13:0] v_v;
	wire signed[13:0] v_w;
	
	inverse_clarke inverse_clarke_i(
		.clk(clk_25),
		.rst(rst),
		.trig(inverse_park_done),
		.in_alpha(v_alpha),
		.in_beta(v_beta),
		.out_u(v_u),
		.out_v(v_v),
		.out_w(v_w),
		.done(inverse_clarke_done)
	);
//#############################################################################

//####### PWM Control #########################################################
	reg[9:0] pwm_step_size_250;	//for timing reasons
	reg pwm_trig_hold;
	wire pwm_trig_250;
	wire[13:0] pwm_ramp;
	wire[2:0] pwm;
	
	wire signed[13:0] selected_v_u;
	wire signed[13:0] selected_v_v;
	wire signed[13:0] selected_v_w;
	
	reg[13:0] duty_cycle_u;
	reg[13:0] duty_cycle_v;
	reg[13:0] duty_cycle_w;
	
	assign selected_v_u = vu_vv_vw_source ? v_u_ext : v_u;
	assign selected_v_v = vu_vv_vw_source ? v_v_ext : v_v;
	assign selected_v_w = vu_vv_vw_source ? v_w_ext : v_w;
	
	//PWM trig clock domain crossing
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
			pwm_trig_25 <= 1'b0;
		else
			pwm_trig_25 <= pwm_trig_hold;
	end
	
	always @(posedge clk_250 or posedge rst_250)
	begin
		if(rst_250)
		begin
			pwm_trig_hold <= 1'b0;
			pwm_step_size_250 <= 10'h000;
			duty_cycle_u <= 14'h0000;
			duty_cycle_v <= 14'h0000;
			duty_cycle_w <= 14'h0000;
		end
		else
		begin
			pwm_trig_hold <= (pwm_trig_hold | pwm_trig_250) & ~pwm_trig_25;
			pwm_step_size_250 <= pwm_step_size_25;
			duty_cycle_u <= {~selected_v_u[13], selected_v_u[12:0]};	//selected_v_u + 8192
			duty_cycle_v <= {~selected_v_v[13], selected_v_v[12:0]};
			duty_cycle_w <= {~selected_v_w[13], selected_v_w[12:0]};
		end
	end
	
	pwm_ramp
	#(
		.NUM_BITS(14),
		.USE_FAST_LOGIC(1'b1)
	) pwm_ramp_i
	(
		.clk(clk_250),
		.rst(rst_250),
		.step_size({3'b000, pwm_step_size_250}),
		.pwm_ramp(pwm_ramp),
		.pwm_trig(pwm_trig_250)
	);
	
	pwm_comp
	#(.NUM_BITS(14)) pwm_comp_u
	(
		.clk(clk_250),
		.rst(rst_250),
		.pwm_ramp(pwm_ramp),
		.duty_cycle(duty_cycle_u),
		.pwm(pwm[0])
	);
	
	pwm_comp
	#(.NUM_BITS(14)) pwm_comp_v
	(
		.clk(clk_250),
		.rst(rst_250),
		.pwm_ramp(pwm_ramp),
		.duty_cycle(duty_cycle_v),
		.pwm(pwm[1])
	);
	
	pwm_comp
	#(.NUM_BITS(14)) pwm_comp_w
	(
		.clk(clk_250),
		.rst(rst_250),
		.pwm_ramp(pwm_ramp),
		.duty_cycle(duty_cycle_w),
		.pwm(pwm[2])
	);
//#############################################################################

//####### Deadtime Control ####################################################
	wire[2:0] dt_out_h;
	wire[2:0] dt_out_l;
	
	dt_control
	#(
		.NUM_CHANNELS(3),
		.TIMER_BITS(8)
	) dt_control_i
	(
		.clk(clk_250),
		.rst(rst_250),
		.shutdown(power_fault | ~power_stage_en),
		.dt_val(pwm_dead_time),
		.dt_in(pwm),
		.dt_out_h(dt_out_h),
		.dt_out_l(dt_out_l)
	);
	
	assign pwm_ux1_h = dt_out_h[0];
	assign pwm_vx2_h = dt_out_h[1];
	assign pwm_wy1_h = dt_out_h[2];
	
	assign pwm_ux1_l = dt_out_l[0];
	assign pwm_vx2_l = dt_out_l[1];
	assign pwm_wy1_l = dt_out_l[2];
	
	assign pwm_y2_h = 1'b0;
	assign pwm_y2_l = 1'b0;
//#############################################################################

//####### Interrupt Output ####################################################
	reg int_trig_en_ff;
	reg int_pulse_ff;
	reg int_tog_ff;
	reg int_out_ff;
	reg[9:0] int_count;
	wire int_trig_en;
	
	assign int_trig_en = int_count >= int_out_div;
	assign int_out = int_out_ff;
	
	always @(posedge clk_25 or posedge rst)
	begin
		if(rst)
		begin
			int_trig_en_ff <= 1'b0;
			int_pulse_ff <= 1'b0;
			int_tog_ff <= 1'b0;
			int_out_ff <= 1'b0;
			int_count <= 10'h000;
		end
		else
		begin
			int_trig_en_ff <= int_trig_en;
			int_pulse_ff <= ~pwm_trig_25 & (int_pulse_ff | (int_trig_en_ff & inverse_clarke_done));
			
			if(int_out_pol ? pwm_trig_25 : inverse_clarke_done)
				int_tog_ff <= int_tog_ff ^ int_trig_en_ff;
			
			if(pwm_trig_25)
			begin
				if(int_trig_en)
					int_count <= 10'h000;
				else
					int_count <= int_count + 10'h001;
			end
			
			int_out_ff <= int_out_pol ^ (int_out_en & (int_out_mode ? int_pulse_ff : int_tog_ff));
		end
	end
//#############################################################################

endmodule
