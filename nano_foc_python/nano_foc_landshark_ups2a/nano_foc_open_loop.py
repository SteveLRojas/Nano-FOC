import time
import nano_foc_landshark_ups_platform as nano
import matplotlib.pyplot as plt

def main():
	nano.power_off = 1
	unique_id = nano.init()
	if unique_id == 0:
		print("Could not find Nano-FOC test device!")
		exit(1)

	#Turn off power stage to make sure there is no current
	nano.write_reg(nano.regs.R_STATUS, 0x0000)    #power stage off
	time.sleep(0.1)

	#setup RTMI. It is important to set the trigger to be the start of the calculation, because the calculation never ends while the power stage is off
	nano.write_reg(nano.regs.R_INT_OUT_CTRL, 0x1809)    #enable interrupt output, at start of calculation, toggle mode, PWM freq / 10
	nano.write_reg(nano.regs.FR_RTMI_CHANNEL_0, nano.regs.R_I_U_RAW)  #RTMI channel 0 set to i_u_raw
	nano.write_reg(nano.regs.FR_RTMI_CHANNEL_1, nano.regs.R_I_W_RAW)  #RTMI channel 1 set to i_w_raw
	nano.configure_rtmi(6, 0, 2, 0, 1, 32, 0)  #unconditional, ch0, 2 channels, not continuous, triggered, 32 samples, 0 threshold

	#collect RTMI responses
	for t in range(20):
		time.sleep(0.1)
		nano.process_rtmi_responses()

	print(f"Captured {nano.rtmi_responses[0].qsize()} samples.")

	#calculate ADC offsets
	iu_avg = 0
	iw_avg = 0
	for d in range(32):
		iu_avg = iu_avg + nano.rtmi_responses[0].queue[d]    #read i_u_raw
		iw_avg = iw_avg + nano.rtmi_responses[1].queue[d]    #read i_w_raw
	iu_avg = int(iu_avg / 32)
	iw_avg = int(iw_avg / 32)
	iu_avg_neg = (-iu_avg) & 0xFFFF
	iw_avg_neg = (-iw_avg) & 0xFFFF

	#apply ADC offsets
	nano.write_reg(nano.regs.R_I_U_OFFSET, iu_avg_neg)    #write i_u_offset
	nano.write_reg(nano.regs.R_I_W_OFFSET, iw_avg_neg)    #write i_w_offset

	print(f"i_u average: 0x{iu_avg:04X}")
	print(f"i_w average: 0x{iw_avg:04X}")
	print(f"i_u negative: 0x{iu_avg_neg:04X}")
	print(f"i_w negative: 0x{iw_avg_neg:04X}")
	print(f"i_u after offset: 0x{nano.read_reg(nano.regs.R_I_U_KCL):04X}") #read i_u_kcl
	print(f"i_v after offset: 0x{nano.read_reg(nano.regs.R_I_V_KCL):04X}") #read_i_v_kcl
	print(f"i_w after offset: 0x{nano.read_reg(nano.regs.R_I_W_KCL):04X}") #read_i_w_kcl

	nano.force_ol_velocity_zero()
	vu_vv_vw_source = 0	#internal
	vd_vq_source = 0	#internal
	phi_source = 2	#ol_phi, hall_phi routed to extrapolator
	nano.write_reg(nano.regs.R_SOURCE_CTRL, (vu_vv_vw_source << 4) | (vd_vq_source << 3) | phi_source)
	pwm_freq = 30000
	step_size = round(pwm_freq * 2**14 / 250000000)
	nano.write_reg(nano.regs.R_PWM_STEP_SIZE, step_size)
	nano.write_reg(nano.regs.R_PWM_DEAD_TIME, 0x0001)    #set dead time to 1 (4 ns)
	nano.write_reg(nano.regs.R_OL_ACCELERATION, 1)    #ol_acceleration
	nano.write_reg(nano.regs.R_OL_TARGET_VELOCITY, 20)    #ol_target_velocity
	nano.write_reg(nano.regs.R_V_D_EXT, 700)    #v_d_ext
	nano.write_reg(nano.regs.R_STATUS, 0x0000)    #clear faults
	nano.write_reg(nano.regs.R_STATUS, 0x0008)    #power stage on

	time.sleep(3)
	nano.flush_rtmi()
	#setup RTMI. It is important to set the trigger to be the start of the calculation, because the calculation never ends while the power stage is off
	int_out_div = 29 #sample_rate = pwm_freq / (int_out_div + 1)
	int_out_mode = 0    #1 for pulse mode, 0 for toggle
	int_out_pol = 1 #1 to trigger at start of calculation, 0 to start at the end
	int_out_en = 1
	int_out_ctrl = int_out_div | (int_out_mode << 10) | (int_out_pol << 11) | (int_out_en << 12)
	nano.write_reg(nano.regs.R_INT_OUT_CTRL, int_out_ctrl)
	nano.write_reg(nano.regs.FR_RTMI_CHANNEL_0, nano.regs.R_I_U_KCL)
	nano.write_reg(nano.regs.FR_RTMI_CHANNEL_1, nano.regs.R_I_V_KCL)
	nano.write_reg(nano.regs.FR_RTMI_CHANNEL_2, nano.regs.R_I_W_KCL)
	nano.configure_rtmi(6, 0, 3, 0, 1, 1024, 0)  #unconditional, ch0, 3 channels, not continuous, triggered, 1024 samples, 0 threshold

	#collect RTMI responses
	for t in range(20):
		time.sleep(0.1)
		nano.process_rtmi_responses()

	print(f"Captured {nano.rtmi_responses[0].qsize()} samples.")

	print(f"Status: 0x{nano.read_reg(nano.regs.R_STATUS):04X}")
	nano.write_reg(nano.regs.R_V_D_EXT, 0x0000)    #v_d_ext = 14'd0

	print("Done!")
	nano.stop()

	#sign extend
	num_valid_samples = min(nano.rtmi_responses[0].qsize(), nano.rtmi_responses[1].qsize())
	num_valid_samples = min(num_valid_samples, nano.rtmi_responses[2].qsize())
	current_u = []
	current_v = []
	current_w = []
	for idx in range(num_valid_samples):
		response = nano.rtmi_responses[0].queue[idx]
		response = (response & 0x1FFF) - (response & 0x2000)
		current_u.append(response)
		response = nano.rtmi_responses[1].queue[idx]
		response = (response & 0x1FFF) - (response & 0x2000)
		current_v.append(response)
		response = nano.rtmi_responses[2].queue[idx]
		response = (response & 0x1FFF) - (response & 0x2000)
		current_w.append(response)

	#plot RTMI responses
	plt.plot(current_u, label='I_U')
	plt.plot(current_v, label='I_V')
	plt.plot(current_w, label='I_W')
	plt.legend()
	plt.show()


if __name__ == "__main__":
	main()