import time
from queue import Queue
import matplotlib.pyplot as plt
import nano_foc_landshark_ups_regs as regs
import nano_foc_landshark_ups_platform as plat

def main():
    plat.nano_init()

    #Turn off power stage to make sure there is no current
    plat.nano_write_reg(regs.R_STATUS, 0x0000)    #power stage off
    time.sleep(0.1)

    #setup RTMI. It is important to set the trigger to be the start of the calculation, because the calculation never ends while the power stage is off
    plat.nano_write_reg(regs.R_INT_OUT_CTRL, 0x1809)    #enable interrupt output, at start of calculation, toggle mode, PWM freq / 10
    plat.nano_write_reg(regs.FR_RTMI_CHANNEL_0, regs.R_I_U_RAW)  #RTMI channel 0 set to i_u_raw
    plat.nano_write_reg(regs.FR_RTMI_CHANNEL_1, regs.R_I_W_RAW)  #RTMI channel 1 set to i_w_raw
    time.sleep(0.1)
    plat.nano_flush_rtmi()
    plat.nano_configure_rtmi(6, 0, 2, 0, 1, 32, 0)  #unconditional, ch0, 2 channels, not continuous, triggered, 32 samples, 0 threshold

    #collect RTMI responses
    for t in range(20):
        time.sleep(0.1)
        plat.nano_process_rtmi_responses()

    print(f"Captured {plat.rtmi_responses[0].qsize()} samples.")

    #calculate ADC offsets
    iu_avg = 0
    iw_avg = 0
    for d in range(32):
        iu_avg = iu_avg + plat.rtmi_responses[0].queue[d]    #read i_u_raw
        iw_avg = iw_avg + plat.rtmi_responses[1].queue[d]    #read i_w_raw
    iu_avg = int(iu_avg / 32)
    iw_avg = int(iw_avg / 32)
    iu_avg_neg = (-iu_avg) & 0xFFFF
    iw_avg_neg = (-iw_avg) & 0xFFFF

    #apply ADC offsets
    plat.nano_write_reg(regs.R_I_U_OFFSET, iu_avg_neg)    #write i_u_offset
    plat.nano_write_reg(regs.R_I_W_OFFSET, iw_avg_neg)    #write i_w_offset

    print(f"i_u average: 0x{iu_avg:04X}")
    print(f"i_w average: 0x{iw_avg:04X}")
    print(f"i_u negative: 0x{iu_avg_neg:04X}")
    print(f"i_w negative: 0x{iw_avg_neg:04X}")
    print(f"i_u after offset: 0x{plat.nano_read_reg(regs.R_I_U_KCL):04X}") #read i_u_kcl
    print(f"i_v after offset: 0x{plat.nano_read_reg(regs.R_I_V_KCL):04X}") #read_i_v_kcl
    print(f"i_w after offset: 0x{plat.nano_read_reg(regs.R_I_W_KCL):04X}") #read_i_w_kcl

    #spin the motor
    plat.nano_force_ol_velocity_zero()
    vu_vv_vw_source = 0	#internal
    vd_vq_source = 0	#internal
    phi_source = 3	#ol_phi, sclaed_abz_phi routed to extrapolator
    plat.nano_write_reg(regs.R_SOURCE_CTRL, (vu_vv_vw_source << 4) | (vd_vq_source << 3) | phi_source)
    pwm_freq = 30000
    step_size = round(pwm_freq * 2**14 / 250000000)
    plat.nano_write_reg(regs.R_PWM_STEP_SIZE, step_size)
    plat.nano_write_reg(regs.R_PWM_DEAD_TIME, 0x0001)    #set dead time to 1 (4 ns)
    plat.nano_write_reg(regs.R_FLUX_TARGET, 3000)    #set flux target
    plat.nano_write_reg(regs.R_FLUX_KP, 0x0100)    #set flux kp
    plat.nano_write_reg(regs.R_FLUX_KI, 0x0020)    #set flux ki
    plat.nano_write_reg(regs.R_FLUX_KD, 0x0000)    #set flux kd
    plat.nano_write_reg(regs.R_TORQUE_TARGET, 0x0000)    #set torque target
    plat.nano_write_reg(regs.R_TORQUE_KP, 0x0100)    #set torque kp
    plat.nano_write_reg(regs.R_TORQUE_KI, 0x0020)    #set torque ki
    plat.nano_write_reg(regs.R_TORQUE_KD, 0x0000)    #set torque kd
    plat.nano_write_reg(regs.R_STATUS, 0x0000)    #clear faults
    plat.nano_write_reg(regs.R_STATUS, 0x0008)    #power stage on
    time.sleep(0.25)
    plat.nano_write_reg(regs.R_OL_ACCELERATION, 3)    #ol_acceleration
    plat.nano_write_reg(regs.R_OL_TARGET_VELOCITY, 200)    #ol_target_velocity

    #configure ABZ decoder
    plat.nano_write_reg(regs.R_ENC_OFFSET, 0)
    abz_inv_dir = 1
    abz_combined_z_pulse = 0
    abz_clear_en = 1
    plat.nano_write_reg(regs.R_ABZ_CONF, (abz_inv_dir << 2) | (abz_combined_z_pulse << 1) | abz_clear_en)
    abz_num_lines = 256
    abz_cpr = abz_num_lines * 4
    abz_num_pole_pairs = 6
    abz_cpr_inv = abz_num_pole_pairs * 2**28 // abz_cpr
    plat.nano_write_reg(regs.R_ABZ_CPR_INV_L, abz_cpr_inv & 0xFFFF)
    plat.nano_write_reg(regs.R_ABZ_CPR_INV_H, abz_cpr_inv >> 16)
    plat.nano_write_reg(regs.R_ABZ_MAX_COUNT, abz_cpr - 1)
    time.sleep(1)

    #setup RTMI
    plat.nano_flush_rtmi()
    int_out_div = 9
    int_out_mode = 0
    int_out_pol = 0 #1 to trigger at start of calculation, 0 to start at the end
    int_out_en = 1
    int_out_ctrl = int_out_div | (int_out_mode << 10) | (int_out_pol << 11) | (int_out_en << 12)
    plat.nano_write_reg(regs.R_INT_OUT_CTRL, int_out_ctrl)
    plat.nano_write_reg(regs.FR_RTMI_CHANNEL_0, regs.R_OL_PHI)
    plat.nano_write_reg(regs.FR_RTMI_CHANNEL_1, regs.R_ENC_PHI)
    plat.nano_write_reg(regs.FR_RTMI_CHANNEL_2, regs.R_ABZ_PHI)
    plat.nano_configure_rtmi(6, 0, 3, 0, 1, 2048, 0)  #unconditional, ch0, 3 channels, not continuous, triggered, 2048 samples, 0 threshold

    #collect RTMI responses
    for t in range(20):
        time.sleep(0.1)
        plat.nano_process_rtmi_responses()

    print(f"Captured {plat.rtmi_responses[0].qsize()} samples.")

    #compute offset
    rtmi_num_samples = min(plat.rtmi_responses[0].qsize(), plat.rtmi_responses[1].qsize())
    phi_dif_avg = 0;
    for idx in range(rtmi_num_samples):
        sext_dif = plat.rtmi_responses[0].queue[idx] - plat.rtmi_responses[1].queue[idx]
        sext_dif = (sext_dif & 0x1FFF) - (sext_dif & 0x2000)
        phi_dif_avg = phi_dif_avg + sext_dif
    phi_dif_avg = round(phi_dif_avg / rtmi_num_samples)
    print(f"enc offset: {phi_dif_avg}")

    #apply the offset
    plat.nano_write_reg(regs.R_ENC_OFFSET, phi_dif_avg & 0xFFFF)

    #plot RTMI responses
    plt.plot(plat.rtmi_responses[0].queue, label='OL_PHI')
    plt.plot(plat.rtmi_responses[1].queue, label='SELECTED_PHI')
    plt.plot(plat.rtmi_responses[2].queue, label='ABZ_PHI')
    plt.legend()
    plt.show()

    #setup RTMI
    plat.nano_flush_rtmi()
    int_out_div = 9
    int_out_mode = 0
    int_out_pol = 0 #1 to trigger at start of calculation, 0 to start at the end
    int_out_en = 1
    int_out_ctrl = int_out_div | (int_out_mode << 10) | (int_out_pol << 11) | (int_out_en << 12)
    plat.nano_write_reg(regs.R_INT_OUT_CTRL, int_out_ctrl)
    plat.nano_write_reg(regs.FR_RTMI_CHANNEL_0, regs.R_OL_PHI)
    plat.nano_write_reg(regs.FR_RTMI_CHANNEL_1, regs.R_ENC_PHI)
    plat.nano_configure_rtmi(6, 0, 2, 0, 1, 2048, 0)  #unconditional, ch0, 2 channels, not continuous, triggered, 2048 samples, 0 threshold

    #collect RTMI responses
    for t in range(20):
        time.sleep(0.1)
        plat.nano_process_rtmi_responses()

    print(f"Captured {plat.rtmi_responses[0].qsize()} samples.")

    #plot RTMI responses
    plt.plot(plat.rtmi_responses[0].queue, label='OL_PHI')
    plt.plot(plat.rtmi_responses[1].queue, label='SELECTED_PHI')
    plt.legend()
    plt.show()

    plat.nano_stop()

if __name__ == "__main__":
	main()