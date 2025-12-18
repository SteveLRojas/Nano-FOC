module foc_ri(
		input wire clk,
		input wire rst,
		input wire enable,
		input wire wren,
		input wire[3:0] addr,
		input wire[15:0] to_ri,
		output reg[15:0] from_ri,
		
		input wire signed[13:0] i_alpha,
		input wire signed[13:0] i_beta,
		input wire signed[13:0] flux,
		input wire signed[13:0] torque,
		output reg signed[13:0] flux_target,
		output reg signed[13:0] flux_kp,
		output reg signed[13:0] flux_ki,
		output reg signed[13:0] flux_kd,
		input wire signed[13:0] flux_pid_out,
		output reg signed[13:0] v_d_ext,
		output reg signed[13:0] torque_target,
		output reg signed[13:0] torque_kp,
		output reg signed[13:0] torque_ki,
		output reg signed[13:0] torque_kd,
		input wire signed[13:0] torque_pid_out,
		output reg signed[13:0] v_q_ext
	);

	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			from_ri <= 16'h0000;
			flux_target <= 14'h0000;
			flux_kp <= 14'h0000;
			flux_ki <= 14'h0000;
			flux_kd <= 14'h0000;
			v_d_ext <= 14'h0000;
			torque_target <= 14'h0000;
			torque_kp <= 14'h0000;
			torque_ki <= 14'h0000;
			torque_kd <= 14'h0000;
			v_q_ext <= 14'h0000;
		end
		else
		begin
			//ri reads
			case(addr)
				4'h0: from_ri <= {2'b00, i_alpha};
				4'h1: from_ri <= {2'b00, i_beta};
				4'h2: from_ri <= {2'b00, flux};
				4'h3: from_ri <= {2'b00, torque};
				4'h4: from_ri <= {2'b00, flux_target};
				4'h5: from_ri <= {2'b00, flux_kp};
				4'h6: from_ri <= {2'b00, flux_ki};
				4'h7: from_ri <= {2'b00, flux_kd};
				4'h8: from_ri <= {2'b00, flux_pid_out};
				4'h9: from_ri <= {2'b00, v_d_ext};
				4'hA: from_ri <= {2'b00, torque_target};
				4'hB: from_ri <= {2'b00, torque_kp};
				4'hC: from_ri <= {2'b00, torque_ki};
				4'hD: from_ri <= {2'b00, torque_kd};
				4'hE: from_ri <= {2'b00, torque_pid_out};
				4'hF: from_ri <= {2'b00, v_q_ext};
				default: from_ri <= 16'h0000;
			endcase
			
			//ri writes
			if(enable & wren)
			begin
				case(addr) 
					4'h4: flux_target <= to_ri[13:0];
					4'h5: flux_kp <= to_ri[13:0];
					4'h6: flux_ki <= to_ri[13:0];
					4'h7: flux_kd <= to_ri[13:0];
					4'h9: v_d_ext <= to_ri[13:0];
					4'hA: torque_target <= to_ri[13:0];
					4'hB: torque_kp <= to_ri[13:0];
					4'hC: torque_ki <= to_ri[13:0];
					4'hD: torque_kd <= to_ri[13:0];
					4'hF: v_q_ext <= to_ri[13:0];
					default: ;
				endcase
			end
		end
	end
	
endmodule
