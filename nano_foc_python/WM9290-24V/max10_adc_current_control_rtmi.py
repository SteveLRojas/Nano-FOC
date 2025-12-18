import sys
import serial
import time

from queue import Queue
import matplotlib.pyplot as plt
import numpy as np

baud = 115200
port = "COM7"
debug = 0
ser = serial.Serial()

rtmi_responses = []
for i in range(8):
    rtmi_responses.append(Queue(maxsize = 1000000))

def nano_configure_rtmi(trigger_mode, trigger_channel, num_channels, continuous_sampling, trigger, num_samples, threshold):
    if(debug):
        print("configure RTMI")
    address = 0xFFF5
    bytes = address.to_bytes(2, 'big') + threshold.to_bytes(2, 'big')
    ser.write(bytes)
    address = 0xFFF6
    bytes = address.to_bytes(2, 'big') + num_samples.to_bytes(2, 'big')
    ser.write(bytes)
    address = 0xFFF7
    value = trigger & 0x01
    value = (value << 1) | (continuous_sampling & 0x01)
    value = value << 2
    value = (value << 4) | (num_channels & 0x0F)
    value = (value << 4) | (trigger_channel & 0x0F)
    value = (value << 4) | (trigger_mode & 0x0F)
    bytes = address.to_bytes(2, 'big') + value.to_bytes(2, 'big')
    ser.write(bytes)

def nano_write_reg(address, value):
    if(debug):
        print("write")
    address = address | 0x8000
    bytes = address.to_bytes(2, 'big') + value.to_bytes(2, 'big')
    ser.write(bytes)

def nano_read_reg(address):
    if(debug):
        print("read")
    bytes = address.to_bytes(2, 'big')
    ser.write(bytes)
    response = ser.read(3)
    return int.from_bytes(response[1:], 'big')

def nano_process_rtmi_responses():
    if(debug):
        print("process RTMI")
    while ser.in_waiting >= 3:
        response = ser.read(3)
        channel_id = int.from_bytes(response[0:1], 'big')
        value = int.from_bytes(response[1:3], 'big')
        if(debug):
            print(f"channel_id: 0x{channel_id:02X}")
            print(f"value: 0x{value:04X}")
        if(channel_id > 7):
            print(f"Bad channel ID: 0x{channel_id:02X}, Value: 0x{value:04X}")
        else:
            rtmi_responses[channel_id].put(value)

def main():
    if(debug):
        print("debug enabled")

    ser.baudrate = baud
    ser.port = port
    ser.dsrdtr = False
    ser.dtr = False
    ser.timeout = 1
    ser.open()

    #Turn off power stage to make sure there is no current
    nano_write_reg(0x00, 0x0000)    #power stage off
    time.sleep(0.1)

    #setup RTMI. It is important to set the trigger to be the start of the calculation, because the calculation never ends while the power stage is off
    nano_write_reg(0x16, 0x1809)    #enable interrupt output, at start of calculation, toggle mode, PWM freq / 10
    nano_write_reg(0x7FF4, 0x0040)  #RTMI channel 0 set to i_u_raw
    nano_write_reg(0x7FF3, 0x0041)  #RTMI channel 1 set to i_w_raw
    nano_configure_rtmi(6, 0, 2, 0, 1, 32, 0)  #unconditional, ch0, 2 channels, not continuous, triggered, 32 samples, 0 threshold

    #collect RTMI responses
    for t in range(20):
        time.sleep(0.1)
        nano_process_rtmi_responses()

    print(f"Captured {rtmi_responses[0].qsize()} samples.")

    #calculate ADC offsets
    iu_avg = 0
    iw_avg = 0
    for d in range(32):
        iu_avg = iu_avg + rtmi_responses[0].queue[d]    #read i_u_raw
        iw_avg = iw_avg + rtmi_responses[1].queue[d]    #read i_w_raw
    iu_avg = int(iu_avg / 32)
    iw_avg = int(iw_avg / 32)
    iu_avg_neg = (-iu_avg) & 0xFFFF
    iw_avg_neg = (-iw_avg) & 0xFFFF

    #apply ADC offsets
    nano_write_reg(0x42, iu_avg_neg)    #write i_u_offset
    nano_write_reg(0x43, iw_avg_neg)    #write i_w_offset

    if(debug):
        print(f"i_u average: 0x{iu_avg:04X}")
        print(f"i_w average: 0x{iw_avg:04X}")
        print(f"i_u negative: 0x{iu_avg_neg:04X}")
        print(f"i_w negative: 0x{iw_avg_neg:04X}")
        print(f"i_u after offset: 0x{nano_read_reg(0x44):04X}") #read i_u_kcl
        print(f"i_v after offset: 0x{nano_read_reg(0x45):04X}") #read_i_v_kcl
        print(f"i_w after offset: 0x{nano_read_reg(0x46):04X}") #read_i_w_kcl

    #spin the motor
    nano_write_reg(0x10, 0x0001)    #phi_source = 2'b01 (ol_phi), vd_vq_source = 1'b0 (internal), vu_vv_vw_source = 1'b0 (internal)
    nano_write_reg(0x11, 0x0002)    #set PWM speed to 2 (30.5 KHz)
    nano_write_reg(0x12, 0x0001)    #set dead time to 1 (4 ns)
    nano_write_reg(0x54, 0x0A00)    #set flux target
    nano_write_reg(0x55, 0x0100)    #set flux kp
    nano_write_reg(0x56, 0x0020)    #set flux ki
    nano_write_reg(0x57, 0x0000)    #set flux kd
    nano_write_reg(0x5A, 0x0000)    #set torque target
    nano_write_reg(0x5B, 0x0100)    #set torque kp
    nano_write_reg(0x5C, 0x0020)    #set torque ki
    nano_write_reg(0x5D, 0x0000)    #set torque kd
    nano_write_reg(0x00, 0x0000)    #clear faults
    nano_write_reg(0x00, 0x0008)    #power stage on
    nano_write_reg(0x30, 0x0001)    #ol_acceleration
    nano_write_reg(0x31, 0x0100)    #ol_target_velocity

    #setup RTMI
    time.sleep(2)
    rtmi_responses[0].queue.clear()
    rtmi_responses[1].queue.clear()
    nano_write_reg(0x16, 0x101D)    #enable interrupt output, toggle mode, at end of calculation, PWM freq / 30
    nano_write_reg(0x7FF4, 0x0033)  #RTMI channel 0 set to ol_phi
    nano_write_reg(0x7FF3, 0x0022)  #RTMI channel 1 set to extpol_phi
    nano_configure_rtmi(6, 0, 2, 0, 1, 1024, 0)  #unconditional, ch0, 2 channels, not continuous, triggered, 1024 samples, 0 threshold

    #collect RTMI responses
    for t in range(20):
        time.sleep(0.1)
        nano_process_rtmi_responses()

    print(f"Captured {rtmi_responses[0].qsize()} samples.")

    time.sleep(3)
    nano_write_reg(0x31, 0x0000)    #set target velocity to 0
    nano_write_reg(0x00, 0x0000)    #power stage off

    print("Done!")
    ser.close()

    #plot RTMI responses
    plt.plot(np.array(rtmi_responses[0].queue))
    plt.plot(np.array(rtmi_responses[1].queue))
    plt.show()

    #check RTMI responses
    if(debug):
        while not rtmi_responses[0].empty():
            print(f"RTMI CH0 response: 0x{rtmi_responses[0].get():08X}")
        while not rtmi_responses[1].empty():
            print(f"RTMI CH1 response: 0x{rtmi_responses[1].get():08X}")
        while not rtmi_responses[2].empty():
            print(f"RTMI CH2 response: 0x{rtmi_responses[2].get():08X}")
        while not rtmi_responses[3].empty():
            print(f"RTMI CH3 response: 0x{rtmi_responses[3].get():08X}")
        while not rtmi_responses[7].empty():
            print(f"RTMI CH7 response: 0x{rtmi_responses[7].get():08X}")
        print(f"serial bytes available: 0x{ser.in_waiting:08X}")

if __name__ == "__main__":
	main()