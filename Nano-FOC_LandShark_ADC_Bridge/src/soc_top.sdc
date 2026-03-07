create_clock -period 20.0 [get_ports clk]
derive_pll_clocks
derive_clock_uncertainty

create_clock -name adc_clk_u -period 40.000 -waveform { 0.000 20.000 } [get_ports adc_sck_u]
create_clock -name adc_clk_w -period 40.000 -waveform { 0.000 20.000 } [get_ports adc_sck_w]

create_clock -name sck_clock -period 20.0 [get_ports spi_sck]
create_clock -name ncs_clock -period 160.0 [get_ports spi_ncs]

#SPI mode 0
#set_input_delay -clock sck_clock -clock_fall -max 1.0 [get_ports spi_mosi]
#set_input_delay -clock sck_clock -clock_fall -min -1.0 [get_ports spi_mosi]
#set_output_delay -clock sck_clock -max 2.0 [get_ports spi_miso]
#set_output_delay -clock sck_clock -min -0.5 [get_ports spi_miso]

#SPI mode 1
set_false_path -from spi_controller:spi_controller_i|to_host[*] -to spi_agent:spi_i|to_host_ff[*]
set_false_path -from spi_agent:spi_i|from_host_ff[*] -to spi_agent:spi_i|from_host[*]
set_input_delay -clock sck_clock -max 1.0 [get_ports spi_mosi]
set_input_delay -clock sck_clock -min -1.0 [get_ports spi_mosi]
set_output_delay -clock sck_clock -clock_fall -max 2.0 [get_ports spi_miso]
set_output_delay -clock sck_clock -clock_fall -min -0.5 [get_ports spi_miso]

set_false_path -from * -to [get_ports {led* pwm_* int_out}]
set_false_path -from [get_ports {button_n* hall_* abz_*}] -to *

# board delay + Tco(max) of external devices (ADC)
set_input_delay -clock adc_clk_u -max 12.0 [get_ports adc_miso_u]
set_input_delay -clock adc_clk_w -max 12.0 [get_ports adc_miso_w]
# board delay + Tco(min) of external devices
set_input_delay -clock adc_clk_u -min 8.0 [get_ports adc_miso_u]
set_input_delay -clock adc_clk_w -min 8.0 [get_ports adc_miso_w]
# board delay + Tsu of external devices
set_output_delay -clock adc_clk_u -max 2.0 [get_ports {adc_ncs_u}]
set_output_delay -clock adc_clk_w -max 2.0 [get_ports {adc_ncs_w}]
# board delay - Th of external devices
set_output_delay -clock adc_clk_u -min 2.0 [get_ports {adc_ncs_u}]
set_output_delay -clock adc_clk_w -min 2.0 [get_ports {adc_ncs_w}]
