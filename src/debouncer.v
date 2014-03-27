//******************************************************************************
// EE108A MIPS verilog model
//
// debouncer.v 
//
// from EE183 library
//
// debounces the input 
//
//******************************************************************************

module debouncer(clk, in, out, rst, en);

	input clk, rst, en;
	input in;
	
	output out;
	reg out;

	parameter WIDTH = 20;

	reg counter_reset, counter_enable;
	
	wire [WIDTH-1:0] counter_out;
	
	dffre #(WIDTH) counter(.clk(clk), .d(counter_out+1'b1), .q(counter_out), .r(counter_reset | rst), .en(counter_enable & en));


	// *** DEBOUNCING FSM ***
	// Define our states-- I've selected one-hot encoding
	`define LOW 2'b00
	`define WAIT_HIGH 2'b01
	`define HIGH 2'b11
	`define WAIT_LOW 2'b10

	// next_state_d is a reg because we want to assign combinational logic to it
	reg [1:0] next_state_d;

	// current_state_q is a wire becaues we just want to route it to our case statement.
	wire [1:0] current_state_q;

	// Next state logic
	always @(current_state_q or in or counter_out[WIDTH-1])
		begin
		   case (current_state_q)

		  	// LOW: We are currently low and are outputing a 0
			//  unless the in goes high. Then we want to go and 
			//  output a high ignoring any changes until the counter
			//  resets. Notice that we are keepign the couter
			//  reset and disabled.

		   	`LOW: begin
				out = 1'b0;
				counter_reset = 1'b1;
				counter_enable = 1'b0;
				if (in) begin
					next_state_d = `WAIT_HIGH;
					end
				else begin
					next_state_d = `LOW;
					end
				end

			// WAIT_HIGH: We are waiting to go high after a low-to-high
			//  transition. Here we are ignoring the input (and keeping 
			//  the output high) until the timer expires. Then we will
			//  go and wait for a high-to-low transition.

			`WAIT_HIGH : begin
				out = 1'b1;
				counter_reset = 1'b0;
				counter_enable = 1'b1;
				if (counter_out[WIDTH-1]) begin
					next_state_d = `HIGH;
					end
				else begin
					next_state_d = `WAIT_HIGH;
					end
				end

			// HIGH: This is the same as LOW but with the output being high.
			//  I.e., we are waiting for a high-to-low transition.

			`HIGH : begin
				out = 1'b1;
				counter_reset = 1'b1;
				counter_enable = 1'b0;
				if (~in) begin
					next_state_d = `WAIT_LOW;
					end
				else begin
					next_state_d = `HIGH;
					end
				end

			// WAIT_LOW: Here we got a high-to-low transition so we output a 0
			//  and ignore the input until the counter expires, then we go back
			//  to waiting for a low-to-high transition.

			`WAIT_LOW : begin
				out = 1'b0;
				counter_reset = 1'b0;
				counter_enable = 1'b1;
				if (counter_out[WIDTH-1]) begin
					next_state_d = `LOW;
					end
				else begin
					next_state_d = `WAIT_LOW;
					end
				end

			// We have the default case in here because we will start up
			//  with all FFs being 0, so we need to get into our initial 
			//  LOW (0001) state.

			default : begin
				out = 1'b0;
				counter_reset = 1'b1;
				counter_enable = 1'b0;
				next_state_d = `LOW;
				end
			endcase
		end

	// State register
	dffre #(2) state(.clk(clk), .d(next_state_d), .q(current_state_q), .r(rst), .en(en));

endmodule
