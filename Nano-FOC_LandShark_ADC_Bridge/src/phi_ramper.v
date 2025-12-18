module phi_ramper
	#(
		parameter ACCEL_BITS = 10,
		parameter VEL_DIV_BITS = 12,
		parameter VEL_COUNTER_BITS = 20,
		parameter VEL_BITS = 10,
		parameter PHI_DIV_BITS = 5,
		parameter PHI_COUNTER_BITS = 21,
		parameter PHI_BITS = 11
	)
	(
		input wire clk,
		input wire rst,
		input wire[ACCEL_BITS - 1 : 0] acceleration,
		input wire signed[VEL_BITS - 1 : 0] target_velocity,
		output wire signed[VEL_BITS - 1 : 0] actual_velocity,
		output reg target_reached,
		output wire[PHI_BITS - 1 : 0] phi
	);
	
	// Vel updates
	reg[VEL_DIV_BITS - 1 : 0] vel_count_timer;
	reg signed[VEL_COUNTER_BITS - 1 : 0] vel_counter;
	wire do_vel_count;
	//wire signed[VEL_BITS - 1 : 0] velocity;
	assign do_vel_count = &vel_count_timer;
	assign actual_velocity = vel_counter[VEL_COUNTER_BITS - 1 : VEL_COUNTER_BITS - VEL_BITS]; // Vel
	
	// Phi updates
	reg[PHI_DIV_BITS - 1 : 0] phi_count_timer;
	reg[PHI_COUNTER_BITS - 1 : 0] phi_counter;
	wire do_phi_count;
	assign do_phi_count = &phi_count_timer;
	assign phi = phi_counter[PHI_COUNTER_BITS - 1 : PHI_COUNTER_BITS - PHI_BITS]; // Out
	
	wire target_vel_greater;
	wire target_vel_less;
	assign target_vel_greater = actual_velocity < target_velocity;
	assign target_vel_less = actual_velocity > target_velocity;
	
	always @(posedge clk or posedge rst)
	begin 
		if(rst)
		begin
			target_reached <= 1'b0;
			vel_count_timer <= {VEL_DIV_BITS{1'b0}};
			vel_counter <= {VEL_COUNTER_BITS{1'b0}};
			phi_count_timer <= {PHI_DIV_BITS{1'b0}};
			phi_counter <= {PHI_COUNTER_BITS{1'b0}};
		end
		else
		begin
			// Vel updates
			vel_count_timer <= vel_count_timer + { {(VEL_DIV_BITS - 1){1'b0}}, 1'b1 };
			target_reached <= ~(target_vel_greater | target_vel_less);
			
			if(do_vel_count)
			begin
				if(target_vel_greater)
					vel_counter <= vel_counter + { {(VEL_COUNTER_BITS - ACCEL_BITS){1'b0}}, acceleration };
				else if(target_vel_less) 
					vel_counter <= vel_counter - { {(VEL_COUNTER_BITS - ACCEL_BITS){1'b0}}, acceleration };
			end
								
			// Phi updates
			phi_count_timer <= phi_count_timer + { {(PHI_DIV_BITS - 1){1'b0}}, 1'b1 };
			
			if(do_phi_count)
				phi_counter <= phi_counter + { {(PHI_COUNTER_BITS - VEL_BITS){actual_velocity[VEL_BITS - 1]}}, actual_velocity[VEL_BITS - 1 : 0] };	
		end
	end
	
endmodule
