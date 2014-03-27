`include "mips_defines.v"

// artificial latency cycles
// the CPI of memory instructions will become MEM_LATENCY + 1
`define MEM_LATENCY 32'd20

module dataram (
    input clk,
    input memclk,
    input rst,
    input we,
    input re,
    input [`MEM_DEPTH-3:0] addr,
    input [127:0] din,

    output reg [127:0] dout,
    output wire complete
);

    reg [127:0] mem [2**(`MEM_DEPTH-2)-1:0];

    wire [31:0] cycle_count;
    wire latency_done = cycle_count == `MEM_LATENCY;

    assign complete = ~(re | we) | latency_done;

    dffarre #(32) cycle_count_ff (.clk(clk),
                                  .ar(rst),
                                  .r(latency_done),
                                  .en(we | re),
                                  .d(cycle_count + 1'd1),
                                  .q(cycle_count));

    always @(posedge memclk) begin
        if (we & latency_done)
            mem[addr] <= din;
        if (re & latency_done)
            dout <= mem[addr];
    end
    
endmodule
