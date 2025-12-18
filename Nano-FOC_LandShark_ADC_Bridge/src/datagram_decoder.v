module datagram_decoder(
		input wire clk,
		input wire rst,
		
		output reg tx_req,
		output reg[7:0] tx_data,
		input wire[7:0] rx_data,
		input wire tx_ready,
		input wire rx_ready,
		
		output reg[15:0] to_ri,
		input wire[15:0] from_ri,
		output reg[6:0] ri_addr,
		output reg ri_wren
	);

	reg[3:0] state;
	reg[7:0] t_data;
	
	localparam[3:0] S_START = 3'h0;
	localparam[3:0] S_READ_START = 3'h1;
	localparam[3:0] S_READ_RESP = 3'h2;
	localparam[3:0] S_TX1 = 3'h3;
	localparam[3:0] S_TX2 = 3'h4;
	localparam[3:0] S_WRITE_RX1 = 3'h5;
	localparam[3:0] S_WRITE_RX2 = 3'h6;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			tx_req <= 1'b0;
			tx_data <= 8'h00;
			to_ri <= 16'h0000;
			ri_addr <= 7'h00;
			ri_wren <= 1'b0;
			state <= S_START;
			t_data <= 8'h00;
		end
		else
		begin
			case(state)
				S_START:
				begin
					ri_wren <= 1'b0;
					if(rx_ready)
					begin
						ri_addr <= rx_data[6:0];
						state <= rx_data[7] ? S_WRITE_RX1 : S_READ_START;
					end
				end
				S_READ_START:
				begin
					//ri_addr is valid here, get response in next cycle
					state <= S_READ_RESP;
				end
				S_READ_RESP:
				begin
					tx_req <= 1'b1;
					tx_data <= from_ri[15:8];
					t_data <= from_ri[7:0];
					state <= S_TX1;
				end
				S_TX1:
				begin
					tx_req <= 1'b0;
					if(tx_ready)
					begin
						tx_req <= 1'b1;
						tx_data <= t_data;
						state <= S_TX2;
					end
				end
				S_TX2:
				begin
					tx_req <= 1'b0;
					if(tx_ready)
					begin
						state <= S_START;
					end
				end
				
				S_WRITE_RX1:
				begin
					if(rx_ready)
					begin
						to_ri[15:8] <= rx_data;
						state <= S_WRITE_RX2;
					end
				end
				S_WRITE_RX2:
				begin
					if(rx_ready)
					begin
						to_ri[7:0] <= rx_data;
						ri_wren <= 1'b1;
						state <= S_START;
					end
				end
				
				default: ;
			endcase
		end
	end
	
endmodule
