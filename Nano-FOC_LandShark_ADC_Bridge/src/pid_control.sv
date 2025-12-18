module pid_control
	#(
		parameter NUM_BITS = 16,
		parameter ACCUM_EXTRA_BITS = 4,
		parameter KP_SHIFT_FACTOR = 8,
		parameter KI_SHIFT_FACTOR = 8,
		parameter KD_SHIFT_FACTOR = 8
	)
	(
		input wire clk,
		input wire rst,
		input wire trigger,
		input wire signed[NUM_BITS - 1 : 0] sp,	//set point
		input wire signed[NUM_BITS - 1 : 0] pv,	//process variable
		input wire signed[NUM_BITS - 1 : 0] kp,	//proportional gain factor
		input wire signed[NUM_BITS - 1 : 0] ki,	//integral gain factor
		input wire signed[NUM_BITS - 1 : 0] kd,	//differential gain factor
		output reg signed[NUM_BITS - 1 : 0] cv,	//control variable
		output reg done
	);
	localparam ERROR_BITS = NUM_BITS + 1;
	localparam PRODUCT_BITS = NUM_BITS * 2;
	localparam ACCUM_BITS = PRODUCT_BITS + ACCUM_EXTRA_BITS + 1;
	localparam ADD_PID_BITS = NUM_BITS + 2;
	
	
	reg signed[ERROR_BITS - 1 : 0] error;
	
	reg signed[NUM_BITS - 1 : 0  ] p_result;
	
	reg signed[ACCUM_BITS - 1 : 0] i_accum;
	reg signed[NUM_BITS - 1 : 0  ] i_result;
	
	reg signed[NUM_BITS - 1 : 0  ] prev_error;
	reg signed[ERROR_BITS - 1 : 0] delta_error;
	reg signed[NUM_BITS - 1 : 0  ] d_result;
	
	reg signed[ADD_PID_BITS - 1 : 0] add_pid;
	
	reg signed[NUM_BITS - 1 : 0] mul_in_a;
	reg signed[NUM_BITS - 1 : 0] mul_in_b;
	reg signed[PRODUCT_BITS - 1 : 0] mul_res;
	
	enum logic[3:0] {
			S_CALC_E,
			S_CLIP_E,
			S_CALC_1,
			S_CALC_2,
			S_CALC_3,
			S_CALC_4,
			S_ADD,
			S_CLIP} state;

	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			cv <= {NUM_BITS{1'b0}};
			done <= 1'b0;
			error <= {ERROR_BITS{1'b0}};
			p_result <= {NUM_BITS{1'b0}};
			i_accum <= {ACCUM_BITS{1'b0}};
			i_result <= {NUM_BITS{1'b0}};
			prev_error <= {NUM_BITS{1'b0}};
			delta_error <= {ERROR_BITS{1'b0}};
			d_result <= {NUM_BITS{1'b0}};
			add_pid <= {ADD_PID_BITS{1'b0}};
			mul_in_a <= {NUM_BITS{1'b0}};
			mul_in_b <= {NUM_BITS{1'b0}};
			mul_res <= {PRODUCT_BITS{1'b0}};
			state <= S_CALC_E;
		end
		else
		begin
			mul_res <= mul_in_a * mul_in_b;
			
			case(state)
				S_CALC_E:
				begin
					done <= 1'b0;
					
					if(trigger)
					begin
						error <= sp - pv;
						state <= S_CLIP_E;
					end
				end
				S_CLIP_E:
				begin
					mul_in_a <= ki;
					
					// clip error
					if(&error[ERROR_BITS - 1 : ERROR_BITS - 2] || ~|error[ERROR_BITS - 1 : ERROR_BITS - 2])
					begin
						mul_in_b <= error[NUM_BITS - 1 : 0];
					end
					else
					begin
						error <= {{2{error[ERROR_BITS - 1]}}, {(ERROR_BITS - 2){~error[ERROR_BITS - 1]}}};
						mul_in_b <= {error[ERROR_BITS - 1], {(NUM_BITS - 1){~error[ERROR_BITS - 1]}}};
					end
					
					state <= S_CALC_1;
				end
				S_CALC_1:
				begin
					mul_in_a <= kp;
					
					prev_error <= error[NUM_BITS - 1 : 0];
					delta_error <= error - prev_error;
					
					state <= S_CALC_2;
				end
				S_CALC_2:
				begin
					i_accum <= i_accum + mul_res;
					mul_in_a <= kd;
					
					// clip delta_error
					if(&delta_error[ERROR_BITS - 1 : ERROR_BITS - 2] || ~|delta_error[ERROR_BITS - 1 : ERROR_BITS - 2])
						mul_in_b <= delta_error[NUM_BITS - 1 : 0];
					else
						mul_in_b <= {delta_error[ERROR_BITS - 1], {(NUM_BITS - 1){~delta_error[ERROR_BITS - 1]}}};
					
					state <= S_CALC_3;
				end
				S_CALC_3:
				begin
					// clip p_result
					if(&mul_res[PRODUCT_BITS - 1 : NUM_BITS + KP_SHIFT_FACTOR - 1] || ~|mul_res[PRODUCT_BITS - 1 : NUM_BITS + KP_SHIFT_FACTOR - 1])
						p_result <= mul_res[NUM_BITS + KP_SHIFT_FACTOR - 1 : KP_SHIFT_FACTOR];
					else
						p_result <= {mul_res[PRODUCT_BITS - 1], {(NUM_BITS - 1){~mul_res[PRODUCT_BITS - 1]}}};
					
					// clip i_accum
					if(!(&i_accum[ACCUM_BITS - 1 : ACCUM_BITS - 2] || ~|i_accum[ACCUM_BITS - 1 : ACCUM_BITS - 2]))
						i_accum <= {{2{i_accum[ACCUM_BITS - 1]}}, {(ACCUM_BITS - 2){~i_accum[ACCUM_BITS - 1]}}};
					
					// clip i_result
					if(&i_accum[ACCUM_BITS - 1 : NUM_BITS + KI_SHIFT_FACTOR - 1] || ~|i_accum[ACCUM_BITS - 1 : NUM_BITS + KI_SHIFT_FACTOR - 1])
						i_result <= i_accum[NUM_BITS + KI_SHIFT_FACTOR - 1 : KI_SHIFT_FACTOR];
					else
						i_result <= {i_accum[ACCUM_BITS - 1], {(NUM_BITS - 1){~i_accum[ACCUM_BITS - 1]}}};
					
					state <= S_CALC_4;
				end
				S_CALC_4:
				begin
					// clip d_result
					if(&mul_res[PRODUCT_BITS - 1 : NUM_BITS + KD_SHIFT_FACTOR - 1] || ~|mul_res[PRODUCT_BITS - 1 : NUM_BITS + KD_SHIFT_FACTOR - 1])
						d_result <= mul_res[NUM_BITS + KD_SHIFT_FACTOR - 1 : KD_SHIFT_FACTOR];
					else
						d_result <= {mul_res[PRODUCT_BITS - 1], {(NUM_BITS - 1){~mul_res[PRODUCT_BITS - 1]}}};
					
					state <= S_ADD;
				end
				S_ADD:
				begin
					add_pid <= p_result + i_result + d_result;
					state <= S_CLIP;
				end
				S_CLIP:
				begin
					// clip cv
					if(&add_pid[ADD_PID_BITS - 1 : NUM_BITS - 1] || ~|add_pid[ADD_PID_BITS - 1 : NUM_BITS - 1])
						cv <= add_pid[NUM_BITS - 1 : 0];
					else
						cv <= {add_pid[ADD_PID_BITS - 1], {(NUM_BITS - 1){~add_pid[ADD_PID_BITS - 1]}}};
						
					done <= 1'b1;
					state <= S_CALC_E;
				end
				default: ;
			endcase
		end
	end
	
endmodule
