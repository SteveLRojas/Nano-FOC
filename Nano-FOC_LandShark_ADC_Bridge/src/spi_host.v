module spi_host(
		input wire clk,
		input wire rst,

		input wire[7:0] clk_div,
		input wire cpol,
		input wire cpha,

		output reg sck,
		output wire mosi,
		input wire miso,

		input wire transfer_req,
		output wire transfer_ready,
		output reg transfer_done,
		input wire[7:0] to_agent,
		output wire[7:0] from_agent);
		
	wire timer_pulse;
	wire last_cycle;
	
	wire load_en;
	wire shift_en;
	wire next_load_en;
	wire next_shift_en;
	wire[7:0] load_data;
	
	reg[3:0] cycle_count;
	reg[7:0] timer;
	reg transfer_active;
	
	reg load_en_ff;
	reg shift_en_ff;
	reg[7:0] load_data_hold;
	
	reg[7:0] tx_shift;
	reg[7:0] rx_shift;
	
	assign timer_pulse = ~|timer;
	assign last_cycle = &cycle_count;
	
	assign next_load_en = last_cycle & transfer_req;
	assign load_en = cpha ? load_en_ff : next_load_en;
	assign next_shift_en = transfer_active & cycle_count[0];
	assign shift_en = cpha ? shift_en_ff : next_shift_en;
	assign load_data = cpha ? load_data_hold : to_agent;
	
	assign mosi = tx_shift[7];
	assign transfer_ready = last_cycle & timer_pulse;
	assign from_agent = rx_shift;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			sck <= 1'b0;
			transfer_done <= 1'b0;
			cycle_count <= 4'hF;
			timer <= 8'h00;
			transfer_active <= 1'b0;
			load_en_ff <= 1'b0;
			shift_en_ff <= 1'b0;
			load_data_hold <= 8'h00;
			tx_shift <= 8'h00;
			rx_shift <= 8'h00;
		end
		else
		begin
			if(timer_pulse)
			begin
				if(last_cycle & transfer_req)
					cycle_count <= 4'h0;
				else if(~last_cycle)
					cycle_count <= cycle_count + 4'h1;
			end
			
			if(timer == clk_div || (transfer_ready & ~transfer_req))
				timer <= 8'h0;
			else
				timer <= timer + 8'h01;

			if(transfer_ready)
				transfer_active <= transfer_req;
			
			if(timer_pulse)
			begin
				load_en_ff <= next_load_en;
				shift_en_ff <= next_shift_en;
				load_data_hold <= to_agent;
			end
			
			if(shift_en & timer_pulse)
				tx_shift <= {tx_shift[6:0], load_data[0]};
			if((shift_en ^ cpha) & timer_pulse)
				rx_shift <= {rx_shift[6:0], miso};
			if(load_en & timer_pulse)
				tx_shift <= load_data;
			
			if(timer_pulse)
			begin
				if(last_cycle)
					sck <= cpol;
				else
					sck <= ~sck;
			end
			
			transfer_done <= transfer_active & last_cycle & timer_pulse;
		end
	end
		
endmodule
