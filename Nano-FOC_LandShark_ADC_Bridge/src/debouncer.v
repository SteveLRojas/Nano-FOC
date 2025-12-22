module debouncer
	#(
		parameter ENABLE_SYNC = 1'b1,
		parameter NUM_CHANNELS = 3,
		parameter TIMER_BITS = 5
	)
	(
		input wire clk,
		input wire rst,
		input wire[NUM_CHANNELS - 1 : 0] debounce_in,
		output reg[NUM_CHANNELS - 1 : 0] debounce_out
	);
	
	wire[NUM_CHANNELS - 1 : 0] deb_sync;
	
	generate
		if(ENABLE_SYNC)
		begin: generate_sync
			reg[NUM_CHANNELS - 1 : 0] deb_s;
			reg[NUM_CHANNELS - 1 : 0] deb_s2;
			
			always @(posedge clk or posedge rst)
			begin
				if(rst)
				begin
					deb_s <= {NUM_CHANNELS{1'b0}};
					deb_s2 <= {NUM_CHANNELS{1'b0}};
				end
				else
				begin
					deb_s <= debounce_in;
					deb_s2 <= deb_s;
				end
			end
			assign deb_sync = deb_s2;
		end
		else
		begin
			assign deb_sync = debounce_in;
		end
	endgenerate
	
	reg[TIMER_BITS - 1 : 0] deb_count[NUM_CHANNELS - 1 : 0];
	wire deb_max[NUM_CHANNELS - 1 : 0];
	wire deb_min[NUM_CHANNELS - 1 : 0];
	wire deb_up[NUM_CHANNELS - 1 : 0];
	wire deb_down[NUM_CHANNELS - 1 : 0];
	
	genvar d;
	generate
		for(d = 0; d < NUM_CHANNELS; d = d + 1)
		begin: min_max_block
			assign deb_max[d] = &deb_count[d];
			assign deb_min[d] = ~|deb_count[d];
			
			assign deb_up[d] = deb_sync[d] & ~deb_max[d];
			assign deb_down[d] = ~deb_sync[d] & ~deb_min[d];
		end
	endgenerate
	
	integer i;
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			debounce_out <= {NUM_CHANNELS{1'b0}};
			for(i = 0; i < NUM_CHANNELS; i = i + 1)
			begin: deb_rst
				deb_count[i] <= {TIMER_BITS{1'b0}};
			end
		end
		else
		begin
			for(i = 0; i < NUM_CHANNELS; i = i + 1)
			begin: deb_logic
				if(deb_up[i] | deb_down[i])
					deb_count[i] <= deb_count[i] + {{(TIMER_BITS - 1){deb_down[i]}}, 1'b1};
				debounce_out[i] <= (debounce_out[i] | deb_max[i]) & ~deb_min[i];
			end
		end
	end

endmodule
