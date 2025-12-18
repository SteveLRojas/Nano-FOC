import sys
import serial
import time

baud = 115200
port = "COM7"
debug = 0
ser = serial.Serial()

def nano_write_reg(address, value):
    if(debug):
        print("write")
    address = address | 0x80
    bytes = address.to_bytes(1, 'big') + value.to_bytes(2, 'big')
    ser.write(bytes)

def nano_read_reg(address):
    if(debug):
        print("read")
    bytes = address.to_bytes(1, 'big')
    ser.write(bytes)
    response = ser.read(2)
    return int.from_bytes(response, 'big')

def main():
    if(debug):
        print("debug enabled")

    ser.baudrate = baud
    ser.port = port
    ser.dsrdtr = False
    ser.dtr = False
    ser.timeout = 1
    ser.open()

    #calculate and set the ADC offsets
    nano_write_reg(0x00, 0x0000)    #power stage off
    time.sleep(0.1)

    iu_avg = 0
    iw_avg = 0
    for d in range(20):
    	iu_avg = iu_avg + nano_read_reg(0x40)	#read i_u_raw
    	iw_avg = iw_avg + nano_read_reg(0x41)	#read i_w_raw
    iu_avg = int(iu_avg / 20)
    iw_avg = int(iw_avg / 20)
    iu_avg_neg = (-iu_avg) & 0xFFFF
    iw_avg_neg = (-iw_avg) & 0xFFFF

    nano_write_reg(0x42, iu_avg_neg)	#write i_u_offset
    nano_write_reg(0x43, iw_avg_neg)	#write i_w_offset

    if(debug):
        print(f"i_u average: 0x{iu_avg:04X}")
        print(f"i_w average: 0x{iw_avg:04X}")
        print(f"i_u negative: 0x{iu_avg_neg:04X}")
        print(f"i_w negative: 0x{iw_avg_neg:04X}")
        print(f"i_u after offset: 0x{nano_read_reg(0x44):04X}")	#read i_u_kcl
        print(f"i_v after offset: 0x{nano_read_reg(0x45):04X}")	#read_i_v_kcl
        print(f"i_w after offset: 0x{nano_read_reg(0x46):04X}")	#read_i_w_kcl

    nano_write_reg(0x10, 0x0001)    #phi_source = 2'b01 (ol_phi), vd_vq_source = 1'b0 (internal), vu_vv_vw_source = 1'b0 (internal)
    nano_write_reg(0x11, 0x0002)    #set PWM speed to 2 (30.5 KHz)
    nano_write_reg(0x12, 0x0001)    #set dead time to 1 (4 ns)
    nano_write_reg(0x30, 0x0014)    #ol_acceleration = 10'd20
    nano_write_reg(0x54, 0x0B00)    #set flux target
    nano_write_reg(0x55, 0x0100)    #set flux kp
    nano_write_reg(0x56, 0x0020)    #set flux ki
    nano_write_reg(0x57, 0x0000)    #set flux kd
    nano_write_reg(0x5A, 0x0000)    #set torque target
    nano_write_reg(0x5B, 0x0100)    #set torque kp
    nano_write_reg(0x5C, 0x0020)    #set torque ki
    nano_write_reg(0x5D, 0x0000)    #set torque kd
    nano_write_reg(0x00, 0x0000)    #clear faults
    nano_write_reg(0x00, 0x0008)    #power stage on
    nano_write_reg(0x31, 0x0100)    #ol_target_velocity

    time.sleep(3)
    nano_write_reg(0x31, 0x0000)    #set target velocity to 0
    nano_write_reg(0x00, 0x0000)    #power stage off

    print("Done!")
    ser.close()


if __name__ == "__main__":
	main()