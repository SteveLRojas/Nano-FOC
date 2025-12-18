module spi_agent
	#(
		parameter IMPLEMENTATION = 3,
		parameter LOAD_MODE = 0,
		parameter CPOL = 1'b0,
		parameter CPHA = 1'b0,
		parameter NUM_BITS = 24
	)
	(
		input wire clk,
		input wire rst,
		input wire sck,
		input wire ncs,
		input wire mosi,
		output wire miso,
		input wire[NUM_BITS - 1 : 0] to_host,
		output reg[NUM_BITS - 1 : 0] from_host,
		output reg start,
		output reg done
	);
	
	generate
		if(IMPLEMENTATION == 0)
		begin
			//latch based implementation
			reg[NUM_BITS - 1 : 0] i_latch_q;
			wire i_latch_en;
			wire[NUM_BITS - 1 : 0] i_latch_d;
			
			reg[NUM_BITS - 1 : 0] o_latch_q;
			wire o_latch_en;
			wire[NUM_BITS - 1 : 0] o_latch_d;
			
			always @(i_latch_en or i_latch_d)
			begin
				if(i_latch_en)
					i_latch_q <= i_latch_d;
			end
			
			always @(o_latch_en or o_latch_d)
			begin
				if(o_latch_en)
					o_latch_q <= o_latch_d;
			end
			
			assign i_latch_d = ncs ? to_host : {o_latch_q[NUM_BITS - 2 : 0], mosi};
			assign o_latch_d = i_latch_q;
			
			if(CPHA)
			begin
				assign i_latch_en = (sck ^ CPOL);
				assign o_latch_en = ~(sck ^ CPOL);
			end
			else
			begin
				assign i_latch_en = (sck ^ CPOL) | ncs;
				assign o_latch_en = ~((sck ^ CPOL) | ncs);
			end
			
			
			reg ncs_sync1;
			reg ncs_sync2;
			reg prev_ncs;
			
			wire ncs_pos_edge;
			wire ncs_neg_edge;
			assign ncs_pos_edge = ncs_sync2 & ~prev_ncs;
			assign ncs_neg_edge = ~ncs_sync2 & prev_ncs;
			
			always @(posedge clk or posedge rst)
			begin
				if(rst)
				begin
					from_host <= {NUM_BITS{1'b0}};
					start <= 1'b0;
					done <= 1'b0;
					ncs_sync1 <= 1'b1;
					ncs_sync2 <= 1'b1;
					prev_ncs <= 1'b1;
				end
				else
				begin
					ncs_sync1 <= ncs;
					ncs_sync2 <= ncs_sync1;
					prev_ncs <= ncs_sync2;
					
					if(ncs_pos_edge)
						from_host <= CPHA ? i_latch_q : o_latch_q;
					
					start <= ncs_neg_edge;
					done <= ncs_pos_edge;
				end
			end
			
			if(CPHA)
			begin
				reg miso_latch_q;
				wire miso_latch_en;
				wire miso_latch_d;
				
				assign miso_latch_en = i_latch_en;
				assign miso_latch_d = o_latch_q[NUM_BITS - 1];
				
				always @(miso_latch_en or miso_latch_d)
				begin
					if(miso_latch_en)
						miso_latch_q <= miso_latch_d;
				end
				
				assign miso = ncs ? 1'bz : miso_latch_q;
			end
			else
			begin
				assign miso = ncs ? 1'bz : o_latch_q[NUM_BITS - 1];
			end
		end
		else if(IMPLEMENTATION == 1)
		begin
			//avoids latches, but gates sck
			reg ncs_q;
			reg[NUM_BITS - 1 : 0] spi_shift;
			reg ncs_sync1;
			reg ncs_sync2;
			reg prev_ncs;
			
			wire sck_int;
			wire clk_shift;
			wire mosi_int;
			wire ncs_pos_edge;
			wire ncs_neg_edge;
			
			assign sck_int = sck ^ CPOL;
			assign clk_shift = ~(sck_int | ncs);
			assign ncs_pos_edge = ncs_sync2 & ~prev_ncs;
			assign ncs_neg_edge = ~ncs_sync2 & prev_ncs;

			if(CPHA)
			begin
				assign mosi_int = mosi;
			end
			else
			begin
				reg mosi_q;
				
				always @(posedge sck_int or posedge rst)
				begin
					if(rst)
						mosi_q <= 1'b0;
					else
						mosi_q <= mosi;
				end
				
				assign mosi_int = mosi_q;
			end

			always @(posedge sck_int or posedge ncs)
			begin
				if(ncs)
					ncs_q <= 1'b1;
				else
					ncs_q <= 1'b0;
			end
			
			always @(posedge clk_shift or posedge rst)
			begin
				if(rst)
					spi_shift <= {NUM_BITS{1'b0}};
				else if(ncs_q)
					spi_shift <= to_host;
				else
					spi_shift <= {spi_shift[NUM_BITS - 2 : 0], mosi_int};
			end
			
			always @(posedge clk or posedge rst)
			begin
				if(rst)
				begin
					from_host <= {NUM_BITS{1'b0}};
					start <= 1'b0;
					done <= 1'b0;
					ncs_sync1 <= 1'b1;
					ncs_sync2 <= 1'b1;
					prev_ncs <= 1'b1;
				end
				else
				begin
					ncs_sync1 <= ncs;
					ncs_sync2 <= ncs_sync1;
					prev_ncs <= ncs_sync2;
					
					if(ncs_pos_edge)
						from_host <= spi_shift;
					
					start <= ncs_neg_edge;
					done <= ncs_pos_edge;
				end
			end
			
			if(CPHA)
			begin
				reg miso_q;
				
				always @(posedge sck_int or posedge rst)
				begin
					if(rst)
						miso_q <= 1'b0;
					else
						miso_q <= spi_shift[NUM_BITS - 1];
				end
				
				assign miso = ncs ? 1'bz : miso_q;
			end
			else
			begin
				assign miso = ncs ? 1'bz : spi_shift[NUM_BITS - 1];
			end
		end
		else if(IMPLEMENTATION == 2)
		begin
			//synchronous implementation, sck, mosi, and ncs are sampled at system clock
			reg sck_sync1;
			reg sck_sync2;
			reg prev_sck;
			reg mosi_sync1;
			reg mosi_sync2;
			reg ncs_sync1;
			reg ncs_sync2;
			reg prev_ncs;
			reg[NUM_BITS - 1 : 0] spi_shift;
			reg miso_q;
			
			wire sck_in_edge;
			wire sck_out_edge;
			wire ncs_pos_edge;
			wire ncs_neg_edge;
			
			if(CPOL ^ CPHA)
			begin
				assign sck_in_edge = ~sck_sync2 & prev_sck;
				assign sck_out_edge = sck_sync2 & ~prev_sck;
			end
			else
			begin
				assign sck_in_edge = sck_sync2 & ~prev_sck;
				assign sck_out_edge = ~sck_sync2 & prev_sck;
			end
			assign ncs_pos_edge = ncs_sync2 & ~prev_ncs;
			assign ncs_neg_edge = ~ncs_sync2 & prev_ncs;
			
			always @(posedge clk or posedge rst)
			begin
				if(rst)
				begin
					from_host <= {NUM_BITS{1'b0}};
					start <= 1'b0;
					done <= 1'b0;
					sck_sync1 <= 1'b0;
					sck_sync2 <= 1'b0;
					prev_sck <= 1'b0;
					mosi_sync1 <= 1'b0;
					mosi_sync2 <= 1'b0;
					ncs_sync1 <= 1'b1;
					ncs_sync2 <= 1'b1;
					prev_ncs <= 1'b1;
					spi_shift <= {NUM_BITS{1'b0}};
				end
				else
				begin
					sck_sync1 <= sck;
					sck_sync2 <= sck_sync1;
					prev_sck <= sck_sync2;
					mosi_sync1 <= mosi;
					mosi_sync2 <= mosi_sync1;
					ncs_sync1 <= ncs;
					ncs_sync2 <= ncs_sync1;
					prev_ncs <= ncs_sync2;
					
					if(ncs_pos_edge)
						from_host <= spi_shift;
					
					if(ncs_sync2)
						spi_shift <= to_host;
					else if(sck_in_edge)
						spi_shift <= {spi_shift[NUM_BITS - 2 : 0], mosi};
					
					start <= ncs_neg_edge;
					done <= ncs_pos_edge;
				end
			end
			
			if(CPHA)
			begin
				always @(posedge clk or posedge rst)
				begin
					if(rst)
					begin
						miso_q <= 1'b0;
					end
					else
					begin
						if(sck_out_edge)
							miso_q <= spi_shift[NUM_BITS - 1];
					end
				end
			end
			else
			begin
				always @(posedge clk or posedge rst)
				begin
					if(rst)
					begin
						miso_q <= 1'b0;
					end
					else
					begin					
						if(ncs_sync2)
							miso_q <= to_host[NUM_BITS - 1];
						else if(sck_out_edge)
							miso_q <= spi_shift[NUM_BITS - 1];
					end
				end
			end
			
			assign miso = ncs ? 1'bz : miso_q;
		end
		else if(IMPLEMENTATION == 3)
		begin
			//FF based, emulated asynchronous load when CPHA = 0
			reg[NUM_BITS - 1 : 0] to_host_ff;
			reg[NUM_BITS - 1 : 0] from_host_ff;
			reg[NUM_BITS - 1 : 0] spi_shift;
			reg miso_q;
			reg load_clear;
			reg ncs_sync1;
			reg ncs_sync2;
			reg prev_ncs;
			
			wire sck_in;
			wire sck_out;
			wire ncs_pos_edge;
			wire ncs_neg_edge;
			wire[NUM_BITS - 1 : 0] spi_shift_effective;
			
			assign sck_in = sck ^ CPOL ^ CPHA;
			assign sck_out = ~sck ^ CPOL ^ CPHA;
			assign ncs_pos_edge = ncs_sync2 & ~prev_ncs;
			assign ncs_neg_edge = ~ncs_sync2 & ~prev_ncs;
			
			if(LOAD_MODE == 0)
			begin
				assign spi_shift_effective = spi_shift | to_host_ff;
			end
			else
			begin
				reg load_initial_val;
				always @(negedge ncs or posedge load_clear)
				begin
					if(load_clear)
						load_initial_val <= 1'b0;
					else
						load_initial_val <= 1'b1;
				end
				assign spi_shift_effective = load_initial_val ? to_host_ff : spi_shift;
			end
			
			always @(negedge ncs or posedge load_clear)
			begin
				if(load_clear)
					to_host_ff <= {NUM_BITS{1'b0}};
				else
					to_host_ff <= to_host;
			end
			
			always @(posedge ncs or posedge rst)
			begin
				if(rst)
					from_host_ff <= {NUM_BITS{1'b0}};
				else
					from_host_ff <= spi_shift;
			end
			
			if(LOAD_MODE == 0)
			begin
				always @(posedge sck_in or posedge ncs)
				begin
					if(ncs)
						spi_shift <= {NUM_BITS{1'b0}};
					else
						spi_shift <= {spi_shift_effective[NUM_BITS - 2 : 0], mosi};
				end
			end
			else
			begin
				always @(posedge sck_in or posedge rst)
				begin
					if(rst)
						spi_shift <= {NUM_BITS{1'b0}};
					else
						spi_shift <= {spi_shift_effective[NUM_BITS - 2 : 0], mosi};
				end
			end
			
			if(CPHA)
			begin
				always @(posedge sck_out or posedge ncs)
				begin
					if(ncs)
						miso_q <= 1'b0;
					else
						miso_q <= spi_shift_effective[NUM_BITS - 1];
				end
			end
			else
			begin
				always @(posedge sck_out or posedge ncs)
				begin
					if(ncs)
						miso_q <= 1'b0;
					else
						miso_q <= spi_shift[NUM_BITS - 1];
				end
			end
			
			if(CPHA)
			begin
				always @(posedge sck_in or posedge ncs)
				begin
					if(ncs)
						load_clear <= 1'b0;
					else
						load_clear <= 1'b1;
				end
			end
			else
			begin
				always @(posedge sck_out or posedge ncs)
				begin
					if(ncs)
						load_clear <= 1'b0;
					else
						load_clear <= 1'b1;
				end
			end
			
			always @(posedge clk or posedge rst)
			begin
				if(rst)
				begin
					from_host <= {NUM_BITS{1'b0}};
					start <= 1'b0;
					done <= 1'b0;
					ncs_sync1 <= 1'b1;
					ncs_sync2 <= 1'b1;
					prev_ncs <= 1'b1;
				end
				else
				begin
					ncs_sync1 <= ncs;
					ncs_sync2 <= ncs_sync1;
					prev_ncs <= ncs_sync2;
					
					if(ncs_pos_edge)
						from_host <= from_host_ff;
					
					start <= ncs_neg_edge;
					done <= ncs_pos_edge;
				end
			end
			
			if(CPHA)
				assign miso = ncs ? 1'bz : miso_q;
			else
				assign miso = ncs ? 1'bz : (miso_q | to_host_ff[NUM_BITS - 1]);
		end
	endgenerate
	
endmodule
