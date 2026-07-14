import serial
import serial.tools.list_ports
import time
from queue import Queue
import nano_foc_landshark_ups_regs as regs

baud = 1000000
ser = serial.Serial()
power_off = 0

rtmi_responses = []
for i in range(8):
	rtmi_responses.append(Queue(maxsize = 1000000))

def configure_rtmi(trigger_mode, trigger_channel, num_channels, continuous_sampling, trigger, num_samples, threshold):
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

def write_reg(address, value):
	address = address | 0x8000
	bytes = address.to_bytes(2, 'big') + value.to_bytes(2, 'big')
	ser.write(bytes)

def read_reg(address):
	bytes = address.to_bytes(2, 'big')
	ser.write(bytes)
	response = ser.read(3)
	return int.from_bytes(response[1:], 'big')

def process_rtmi_responses():
	while ser.in_waiting >= 3:
		response = ser.read(3)
		channel_id = int.from_bytes(response[0:1], 'big')
		value = int.from_bytes(response[1:3], 'big')
		if(channel_id > 7):
			print(f"Bad channel ID: 0x{channel_id:02X}, Value: 0x{value:04X}")
		else:
			rtmi_responses[channel_id].put(value)

def force_ol_velocity_zero():
	acceleration = 0x3FFF
	write_reg(regs.R_OL_TARGET_VELOCITY, 0x0000)
	for idx in range(13):
		write_reg(regs.R_OL_ACCELERATION, acceleration)
		acceleration = acceleration >> 1

def flush_rtmi():
	process_rtmi_responses()
	for d in range(8):
		rtmi_responses[d].queue.clear()

def get_device_id():
	response = read_reg(regs.FR_DEVICE_ID_H)
	response = (response << 16) | read_reg(regs.FR_DEVICE_ID_L) 
	return response

def get_unique_id():
	response = read_reg(regs.FR_UNIQUE_ID_H)
	response = (response << 16) | read_reg(regs.FR_UNIQUE_ID_L)
	return response

def init(unique_id = 0):
	port_candidates = []
	ports = serial.tools.list_ports.comports()
	for port in ports:
		if hasattr(port, 'vid') and port.vid and (port.vid == 0x1A86) and (port.pid == 0xFE0C):
			port_candidates.append(port.device)
	
	ser.baudrate = baud
	ser.dsrdtr = False
	ser.dtr = False
	ser.timeout = 1.0
	ser.write_timeout = 1.0

	for port in port_candidates:
		try:
			ser.port = port
			ser.open()
			time.sleep(0.5)
			ser.reset_input_buffer()
		except Exception:
			continue
		
		device_id = get_device_id()
		if device_id != 0x434F464E:
			ser.close()
			continue
		current_unique_id = get_unique_id()
		if unique_id and (unique_id != current_unique_id):
			ser.close()
			continue
		write_reg(regs.R_INT_OUT_CTRL, 0x0000)
		write_reg(regs.FR_RTMI_CONTROL, 0x0000)
		time.sleep(0.5)
		ser.reset_input_buffer()
		return current_unique_id
	return 0

def stop():
	if ser.is_open:
		if power_off:
			try:
				write_reg(regs.R_OL_TARGET_VELOCITY, 0x0000)    #set target velocity to 0
				write_reg(regs.R_TORQUE_TARGET, 0x0000)    #set torque target to 0
				write_reg(regs.R_STATUS, 0x0000)    #power stage off
			except Exception:
				pass
		ser.close()
