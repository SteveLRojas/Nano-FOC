import serial
import time

from queue import Queue
import matplotlib.pyplot as plt
import numpy as np
import nano_foc_landshark_ups_regs as regs

baud = 1000000
port = "/dev/ttyACM0"
ser = serial.Serial()
debug = 0
power_off = 0

rtmi_responses = []
for i in range(8):
    rtmi_responses.append(Queue(maxsize = 1000000))

def nano_configure_rtmi(trigger_mode, trigger_channel, num_channels, continuous_sampling, trigger, num_samples, threshold):
    if(debug):
        print("configure RTMI")
    address = regs.FR_RTMI_THRESHOLD | 0x8000
    bytes = address.to_bytes(2, 'big') + threshold.to_bytes(2, 'big')
    ser.write(bytes)
    address = regs.FR_RTMI_NUM_SAMPLES | 0x8000
    bytes = address.to_bytes(2, 'big') + num_samples.to_bytes(2, 'big')
    ser.write(bytes)
    address = regs.FR_RTMI_CONTROL | 0x8000
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

def nano_force_ol_velocity_zero():
    acceleration = 0x3FFF
    nano_write_reg(regs.R_OL_TARGET_VELOCITY, 0x0000)
    for idx in range(13):
        nano_write_reg(regs.R_OL_ACCELERATION, acceleration)
        acceleration = acceleration >> 1

def main():
    if(debug):
        print("debug enabled")

    ser.baudrate = baud
    ser.port = port
    ser.dsrdtr = False
    ser.dtr = False
    ser.timeout = 1.0
    ser.write_timeout = 1.0
    ser.open()
    nano_write_reg(regs.R_INT_OUT_CTRL, 0x0000)
    nano_write_reg(regs.FR_RTMI_CONTROL, 0x0000)
    time.sleep(0.5)
    ser.reset_input_buffer()

    status = nano_read_reg(regs.R_STATUS)
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

if __name__ == "__main__":
    main()
