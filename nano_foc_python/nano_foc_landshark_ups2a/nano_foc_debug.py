import nano_foc_landshark_ups_platform as nano

def main():
	nano.power_off = 0
	unique_id = nano.init()
	if unique_id == 0:
		print("Could not find Nano-FOC test device!")
		exit(1)

	status = nano.read_reg(nano.regs.R_STATUS)
	print(f"status: 0x{status:04X}")
	print(f"\tocp: {bool(status & 0x0001)}")
	print(f"\tuvp: {bool(status & 0x0002)}")
	print(f"\thall_fault: {bool(status & 0x0004)}")
	print(f"\tpower_stage_en: {bool(status & 0x0008)}")
	print(f"\tadc_done: {bool(status & 0x0010)}")
	print(f"\tkcl_done: {bool(status & 0x0020)}")
	print(f"\tclarke_done: {bool(status & 0x0040)}")
	print(f"\tpark_done: {bool(status & 0x0080)}")
	print(f"\tpid_done: {bool(status & 0x0100)}")
	print(f"\tlimiter_done: {bool(status & 0x0200)}")
	print(f"\ti_park_done: {bool(status & 0x0400)}")
	print(f"\ti_clarke_done: {bool(status & 0x0800)}")
	print(f"\tbutton_d: 0x{(status >> 12):01X}")

	print(f"i alpha: {nano.read_reg(nano.regs.R_I_ALPHA):04X}")
	print(f"i beta: {nano.read_reg(nano.regs.R_I_BETA):04X}")
	print(f"flux: {nano.read_reg(nano.regs.R_FLUX):04X}")
	print(f"torque: {nano.read_reg(nano.regs.R_TORQUE):04X}")
	print(f"flux target: {nano.read_reg(nano.regs.R_FLUX_TARGET):04X}")
	print(f"flux kp: {nano.read_reg(nano.regs.R_FLUX_KP):04X}")
	print(f"flux ki: {nano.read_reg(nano.regs.R_FLUX_KI):04X}")
	print(f"flux_kd: {nano.read_reg(nano.regs.R_FLUX_KD):04X}")
	print(f"flux pid out: {nano.read_reg(nano.regs.R_FLUX_PID_OUT):04X}")
	print(f"v d ext: {nano.read_reg(nano.regs.R_V_D_EXT):04X}")
	print(f"torque target: {nano.read_reg(nano.regs.R_TORQUE_TARGET):04X}")
	print(f"torque kp: {nano.read_reg(nano.regs.R_TORQUE_KP):04X}")
	print(f"torque ki: {nano.read_reg(nano.regs.R_TORQUE_KI):04X}")
	print(f"torque kd: {nano.read_reg(nano.regs.R_TORQUE_KD):04X}")
	print(f"torque pid out: {nano.read_reg(nano.regs.R_TORQUE_PID_OUT):04X}")
	print(f"v d ext: {nano.read_reg(nano.regs.R_V_Q_EXT):04X}")

	print("Done!")
	nano.stop()

if __name__ == "__main__":
	main()
