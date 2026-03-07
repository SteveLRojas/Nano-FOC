module syscon_ri(
		input wire clk,
		input wire rst,
		input wire enable,
		input wire wren,
		input wire[2:0] addr,
		input wire[15:0] to_ri,
		output reg[15:0] from_ri,
		
		output reg[2:0] phi_source,
		output reg vd_vq_source,
		output reg vu_vv_vw_source,
		//output reg[5:0] adc_setup_time,
		//output reg[2:0] adc_hold_time,
		output reg[9:0] pwm_step_size,
		output reg[7:0] pwm_dead_time,
		output reg signed[13:0] v_u_ext,
		output reg signed[13:0] v_v_ext,
		output reg signed[13:0] v_w_ext,
		output reg[9:0] int_out_div,
		output reg int_out_mode,
		output reg int_out_pol,
		output reg int_out_en
	);

	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			from_ri <= 16'h0000;
			phi_source <= 3'b00;
			vd_vq_source <= 1'b0;
			vu_vv_vw_source <= 1'b0;
			//adc_setup_time <= 6'd30;
			//adc_hold_time <= 3'd3;
			pwm_step_size <= 10'd2;
			pwm_dead_time <= 8'd20;
			v_u_ext <= 14'h0000;
			v_v_ext <= 14'h0000;
			v_w_ext <= 14'h0000;
			int_out_div <= 10'h000;
			int_out_mode <= 1'b0;
			int_out_pol <= 1'b0;
			int_out_en <= 1'b0;
		end
		else
		begin
			//ri reads
			case(addr)
				3'h0: from_ri <= {2'b00, 3'h0, 6'h00, vu_vv_vw_source, vd_vq_source, phi_source};
				3'h1: from_ri <= {6'h00, pwm_step_size};
				3'h2: from_ri <= {8'h00, pwm_dead_time};
				3'h3: from_ri <= {2'b00, v_u_ext};
				3'h4: from_ri <= {2'b00, v_v_ext};
				3'h5: from_ri <= {2'b00, v_w_ext};
				3'h6: from_ri <= {3'b000, int_out_en, int_out_pol, int_out_mode, int_out_div};
				default: from_ri <= 16'h0000;
			endcase
			
			//ri writes
			if(enable & wren)
			begin
				case(addr)
					3'h0:
					begin
						phi_source <= to_ri[2:0];
						vd_vq_source <= to_ri[3];
						vu_vv_vw_source <= to_ri[4];
						//adc_setup_time <= to_ri[9:4];
						//adc_hold_time <= to_ri[12:10];
					end
					3'h1: pwm_step_size <= to_ri[9:0];
					3'h2: pwm_dead_time <= to_ri[7:0];
					3'h3: v_u_ext <= to_ri[13:0];
					3'h4: v_v_ext <= to_ri[13:0];
					3'h5: v_w_ext <= to_ri[13:0];
					3'h6:
					begin
						int_out_div <= to_ri[9:0];
						int_out_mode <= to_ri[10];
						int_out_pol <= to_ri[11];
						int_out_en <= to_ri[12];
					end
					default: ;
				endcase
			end
		end
	end
	
endmodule
