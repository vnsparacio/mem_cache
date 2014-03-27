// button_press_unit
// 26-Jan-2007 David Black-Schaffer
//
// This module synchronizes, debounces, and one-pulses a button input.
//
module button_press_unit(
   clk,
   rst,
   in,
   out
   );
   
	// The WIDTH parameter determines how long to wait for the bouncing to stop.
   parameter WIDTH = 20;

	// Standard system clock and reset
   input clk;
   input rst;

	// The async, bouncy input
   input in;
	// The synchronous, clean, one-pulsed output
   output out;
   
   // Synchronize our input
   wire button_sync;
   brute_force_synchronizer sync(.clk(clk), .in(in), .out(button_sync));
   
   // Debounce our synchronized input
   wire button_debounced;
   debouncer #(WIDTH) debounce(.clk(clk), .rst(rst), .en(1'b1), .in(button_sync), .out(button_debounced));
   
   // One-pulse our debounced input
   one_pulse one_pulse(.clk(clk), .rst(rst), .in(button_debounced), .out(out));

endmodule
   
