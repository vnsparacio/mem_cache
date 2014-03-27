//=============================================================================
// EE108B Lab 2
//
// MIPS Register File Module
//=============================================================================

`include "mips_defines.v"

module regfile (
    input clk,
    input we,
    input [4:0] write_addr,
    input [31:0] write_data,
    input [4:0] rs_addr,
    input [4:0] rt_addr,

    output wire [31:0] rs_data,
    output wire [31:0] rt_data
);

    reg [31:0] regs [31:0];

    always @(posedge clk)
        if (we)
            regs[write_addr] <= write_data;

    assign rs_data = rs_addr == `ZERO ? 32'b0 : regs[rs_addr];
    assign rt_data = rt_addr == `ZERO ? 32'b0 : regs[rt_addr];

endmodule
