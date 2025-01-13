module ps2 (
	input        clk           ,
	input        rst_n         ,
	input        ps2_clk       ,
	input        ps2_data      ,	//data sent from the keyboard
	output [3:0] DIG           ,
   output [6:0] code          
);

	/* constants */
	localparam DEB_PARAMETER = 3;					//2^3 of the same values are enough for a stable signal

	localparam PARITY_REG_INITIAL_VALUE = 1'b1;			//the initial value for 'parity_reg' variable (odd parity)
	localparam ERROR_REG_INITIAL_VALUE  = 1'b0;			//the initial value for 'error_reg' variable
	localparam ERROR_OCCURED            = 1'b1;			//the value of 'error_reg' if there is an error in a package

	/* main variables */
	reg [10:0] package_reg, package_next;				//stores one whole package (STOP bit, PARITY bit, SCAN_CODE_BYTE[7:0] bits, START bit, respectively)
	reg [15:0] data_reg, data_next;					//stores the lowest two bytes of the scan code
	reg        parity_reg, parity_next;				//stores parity check result
	reg        error_reg, error_next;				//stores package error check result

	reg [3:0] cnt_reg, cnt_next;					//package bit counter (counts from 0 to 10)

	/* additional variables */
	reg ps2_clk_deb_previous_reg, ps2_clk_deb_previous_next;	//used for the ps2_clk_deb falling edge detection
	
	reg f0_flag_reg, f0_flag_next;					//indicates that the F0 byte has arrived
	reg e0_flag_reg, e0_flag_next;					//indicates that the E0 byte has arrived

	/* final state machine */
	localparam STATE_IDLE    = 1'b0;				//package is not being received
	localparam STATE_RECEIVE = 1'b1;				//package is being received

	reg state_reg, state_next;					//stores the current state
    wire byte_h_digit_h, byte_h_digit_l, byte_l_digit_h, byte_l_digit_l;
	/* displaying 'data_reg' on four 7SEG displays */
	hex hex_inst_1 (.clk(clk), .in(data_reg[15:12]), .out(byte_h_digit_h));
	hex hex_inst_2 (.clk(clk), .in(data_reg[11:8]),  .out(byte_h_digit_l));
	hex hex_inst_3 (.clk(clk), .in(data_reg[7:4]),   .out(byte_l_digit_h));
	hex hex_inst_4 (.clk(clk), .in(data_reg[3:0]),   .out(byte_l_digit_l));

    reg [25:0] cnt2 = 26'd0;
    enum reg [1:0] {SHN, FHN, SMN, FMN} state = FMN;

    always @(posedge clk) begin
		cnt2 <= cnt2 + 26'b1;
		if (cnt2 == 26'd5000) begin
			cnt2 <= 26'd0;
			case(state)
				FMN: begin
					DIG <= 4'b1110;
					code <= byte_l_digit_l;
					state <= SMN;
				end
				SMN: begin
					DIG <= 4'b1101;
					code <= byte_l_digit_h;
					state <= FHN;
				end
				FHN: begin
					DIG <= 4'b1011;
					code <= byte_h_digit_l;
					state <= SHN;
				end
				SHN: begin
					DIG <= 4'b0111;
					code <= byte_h_digit_h;
					state <= FMN;
				end
			endcase
		end
	end


	/* debouncer */
	wire ps2_clk_deb;

	deb #(DEB_PARAMETER) deb_inst (
		.rst_n(rst_n      ),
		.clk  (clk        ),
		.in   (ps2_clk    ),
		.out  (ps2_clk_deb)
	);
	
	/* sequential logic */
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			package_reg <= 11'b0;
			data_reg    <= 15'b0;
			parity_reg  <= PARITY_REG_INITIAL_VALUE;
			error_reg   <= ERROR_REG_INITIAL_VALUE;

			cnt_reg   <= 4'b0;
			state_reg <= STATE_IDLE;

			ps2_clk_deb_previous_reg <= 1'b0; //the initial value of 'ps2_clk_deb' is 1'b0
			f0_flag_reg              <= 1'b0;
			e0_flag_reg              <= 1'b0;
		end else begin
			package_reg <= package_next;
			data_reg    <= data_next;
			parity_reg  <= parity_next;
			error_reg   <= error_next;

			cnt_reg   <= cnt_next;
			state_reg <= state_next;

			ps2_clk_deb_previous_reg <= ps2_clk_deb_previous_next;
			f0_flag_reg              <= f0_flag_next;
			e0_flag_reg              <= e0_flag_next;
		end
	end

	/* combinational logic */
	always @(*) begin
		/* latch prevention*/
		package_next = package_reg;
		data_next    = data_reg;
		parity_next  = parity_reg;
		error_next   = error_reg;

		cnt_next   = cnt_reg;
		state_next = state_reg;

		f0_flag_next = f0_flag_reg;
		e0_flag_next = e0_flag_reg;

		/* implementation logic */
		case (state_reg)
			STATE_IDLE : begin
				if (~ps2_clk_deb && ps2_clk_deb_previous_reg) begin					//falling edge detection
					package_next = { ps2_data, package_reg[10:1] };					//right shift ps2_data (START bit) into the 'package_next' variable

					/* preparation to receive a new package */
					parity_next = PARITY_REG_INITIAL_VALUE;
					error_next  = ERROR_REG_INITIAL_VALUE;

					cnt_next   = 4'd0;								//there are 10 bits left to read
					state_next = STATE_RECEIVE;							//transition to the new state
				end
			end

			STATE_RECEIVE : begin
				if (~ps2_clk_deb && ps2_clk_deb_previous_reg) begin					//falling edge detection
					package_next = { ps2_data, package_reg[10:1] };					//right shift ps2_data

					/* evaluate the final value of 'parity_reg' and 'error_reg' */
					if (cnt_reg <= 4'd7) parity_next = parity_reg ^ ps2_data;			//ps2_data == SCAN_CODE_BYTE[0:7] for cnt_reg == [0:7]
					else if (cnt_reg == 4'd8) begin							//ps2_data == PARITY bit for cnt_reg == 4'd8
						if (parity_reg != ps2_data)	error_next = ERROR_OCCURED;		//there is an error, the PARITY bit does not match
					end else begin									//ps2_data == STOP bit for cnt_reg == 4'd9
						if (package_next[0] != 1'b0 || package_next[10] != 1'b1)		//START bit != 0 or STOP bit != 1
							error_next = ERROR_OCCURED;
					end
					cnt_next = cnt_reg + 4'b1;							//updating the counter
				end

				/* after the new package has been received */
				if (cnt_next == 4'd10 && error_next != ERROR_OCCURED) begin				//MUST use cnt_next and error_next (not cnt_reg and error_reg)
					case (package_next[8:1])
						8'hF0 : f0_flag_next = 1'b1;						//do not insert the F0 byte immediately, just mark that it has arrived
						8'hE0 : e0_flag_next = 1'b1;						//do not insert the E0 byte immediately, just mark that it has arrived

						default : begin
							data_next = { data_reg[7:0], package_next[8:1] };		//by default just insert the next byte of the scan code

							/* improving the 7SEG display fluidity */
							if (data_reg[15:8] == 8'hF0 || data_reg[15:8] == 8'hE0)
								data_next = { 8'b0, package_next[8:1] };
							else if (data_reg[7:0] == package_next[8:1] && data_reg[7:0] != 8'b0)
								data_next = { 8'b0, package_next[8:1] };

							/* insert the marked F0/E0 byte and the one that just arrived */
							if (f0_flag_reg == 1'b1) begin
								data_next    = { 8'hF0, package_next[8:1] };
								f0_flag_next = 1'b0;					//clear the f0_flag
								e0_flag_next = 1'b0;					//necessary due to the situation when we receive E0 F0 respectively (example: [make: E0 14 | break: E0 F0 14])
							end else if (e0_flag_reg == 1'b1) begin
								data_next    = { 8'hE0, package_next[8:1] };
								e0_flag_next = 1'b0;					//clear the e0_flag
								f0_flag_next = 1'b0;
							end
						end
					endcase
				end

				if (cnt_next == 4'd10) state_next = STATE_IDLE;						//return to the idle state
			end
		endcase

		ps2_clk_deb_previous_next = ps2_clk_deb;
	end

endmodule