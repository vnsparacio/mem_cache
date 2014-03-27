//=============================================================================
// EE108B
//
// MIPS Memory Module
//=============================================================================

`include "mips_defines.v"

module memory_top (
    input clk,
    input memclk,
    input rst,
    input we,
    input re,
    input [31:0] addr,
    input [31:0] data_in,
    input [31:0] controller_data,
    
    output wire [31:0] data_out,
    output wire display_we,
    output wire [13:0] display_data,
    output wire mem_stall
);

    wire isDisplayAddr = addr == `DISPLAY_ADDR;
    wire isControllerAddr = addr == `CONTROLLER_ADDR;

    wire dram_we = we & ~isDisplayAddr;
    wire dram_re = re & ~isControllerAddr;
    wire complete;
    wire [31:0] dram_data;

    cache data_cache (.clk(clk),
                      .memclk(memclk),
                      .rst(rst),
                      .addr(addr),
                      .dout(dram_data),
                      .re(dram_re),
                      .din(data_in),
                      .we(dram_we),
                      .complete(complete));

    assign mem_stall = ~complete;

    //dataram dmem (.clk(clk), .addr(addr[`MEM_DEPTH+1:2]), .din(data_in), .dout(dram_data), .we(dram_we));

    assign data_out = isControllerAddr ? controller_data : dram_data;

    assign display_we = we & isDisplayAddr;
    assign display_data = {data_in[18:16], data_in[13:8], data_in[4:0]};

endmodule
