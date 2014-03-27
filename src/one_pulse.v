//	one_pulse
//	26-Jan-2007 David Black-Schaffer
//   Simple one_pulse module.
//   Asserts out for one cycle when the input goes high.
//   Does nothing when it goes low.
//

module one_pulse(
    input clk,
    input rst,
    input in,
    output out
    );
    
    wire last_value;
    dffr last_value_storage (.clk(clk), .r(rst), .d(in), .q(last_value));
    
    assign out = ~last_value & in;
    
endmodule
