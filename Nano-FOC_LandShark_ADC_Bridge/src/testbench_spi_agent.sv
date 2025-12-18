`timescale 1ns / 1ps

module testbench_spi_agent;
	reg clk_25;
	reg rst;
	
	reg ncs;
	wire sck;
	wire mosi;
	wire miso;

//####### SPI Host ############################################################
	reg transfer_req;
	wire transfer_ready;
	wire transfer_done;
	reg[7:0] to_agent;
	wire[7:0] from_agent;
	
	spi_host spi_host_i(
		.clk(clk_25),
		.rst(rst),

		.clk_div(8'h08),
		.cpol(1'b0),
		.cpha(1'b0),

		.sck(sck),
		.mosi(mosi),
		.miso(miso),

		.transfer_req(transfer_req),
		.transfer_ready(transfer_ready),
		.transfer_done(transfer_done),
		.to_agent(to_agent),
		.from_agent(from_agent)
	);
//#############################################################################

//#############################################################################
	wire[23:0] from_host;
	wire start;
	wire done;
	
	spi_agent
	#(
		.IMPLEMENTATION(0),
		.CPOL(1'b0),
		.CPHA(1'b0),
		.NUM_BITS(24)
	) uut
	(
		.clk(clk_25),
		.rst(rst),
		.sck(sck),
		.ncs(ncs),
		.mosi(mosi),
		.miso(miso),
		.to_host(from_host),
		.from_host(from_host),
		.start(start),
		.done(done)
	);

//#############################################################################

	always
	begin
		#20 clk_25 = ~clk_25;
	end
	
	/*always
	begin
		#2 clk_250 = ~clk_250;
	end*/

	initial
	begin
		// Initialize Inputs
		clk_25 = 1'b0;
		//clk_250 = 1'b0;
		rst = 1'b1;
		ncs = 1'b1;
		transfer_req = 1'b0;
		to_agent = 8'h00;

		#80;
        
		// Add stimulus here
		rst = 1'b0;
		#40 to_agent = 8'h55;
		#640 ncs = 1'b0;
		#40 transfer_req = 1'b1;
		#40 transfer_req = 1'b0;
		
		#6400 to_agent = 8'hAA;
		#40 transfer_req = 1'b1;
		#40 transfer_req = 1'b0;
		
		#6400 to_agent = 8'h5A;
		#40 transfer_req = 1'b1;
		#40 transfer_req = 1'b0;
		
		#6400 ncs = 1'b1;
		
		#640 ncs = 1'b0;
		#40 to_agent = 8'h00;
		#40 transfer_req = 1'b1;
		#40 transfer_req = 1'b0;
		
		#6400 transfer_req = 1'b1;
		#40 transfer_req = 1'b0;
		
		#6400 transfer_req = 1'b1;
		#40 transfer_req = 1'b0;
		
		#6400 ncs = 1'b1;

	end
	
endmodule
