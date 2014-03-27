//=============================================================================
// EE108B Lab 2
//
// Instruction fetch module. Maintains PC and updates it. Reads from the
// instruction ROM.
//=============================================================================

module instruction_fetch (
    input clk,
    input rst,
    input en,
    input branch_en,
    input jump_en,
    input jump_reg_en,
    input [31:0] jump_reg_pc,
    input trap_en,
    input [31:0] trap_pc,
     
    output [31:0] pc,
    output [31:0] instr
);

    wire [31:0] inc_pc = pc + 3'h4;
    wire [31:0] branch_pc = inc_pc + {{14{instr[15]}}, instr[15:0], 2'b0};
    wire [31:0] jump_pc = {inc_pc[31:28], instr[25:0], 2'b0};

    reg [31:0] next_pc;

    always @*
        casex ({trap_en, branch_en, jump_en, jump_reg_en})
            4'b1xxx: next_pc = trap_pc;
            4'b0100: next_pc = branch_pc;
            4'b0010: next_pc = jump_pc;
            4'b0001: next_pc = jump_reg_pc;
            default: next_pc = inc_pc;
        endcase

    dffare #(32) pc_reg (.clk(clk), .r(rst), .en(en), .d(next_pc), .q(pc));

    irom instr_mem (.addr(pc[10:2]), .dout(instr));

endmodule 
