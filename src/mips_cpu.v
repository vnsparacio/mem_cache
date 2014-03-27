//=============================================================================
// EE108B Lab 2
//
// MIPS CPU Module. Contains the five stages in the single-cycle MIPS CPU.
//=============================================================================

module mips_cpu (
    input clk,
    input memclk,
    input rst,
    input en,
    input trap,
    input [31:0] controller_data,
    output [13:0] display_data,
    output display_we
);

    wire [31:0] pc, instr;
    wire [4:0] rs_addr, rt_addr;
    wire [31:0] rs_data, rt_data;
    wire reg_write_en;
    wire [4:0] reg_write_addr;
    wire [31:0] reg_write_data;
    wire branch_en, jump_en, jump_reg_en;
    wire alu_overflow;
    wire [3:0] alu_opcode;
    wire [31:0] alu_op_x, alu_op_y, alu_result;
    wire mem_write_en, mem_read_en;
    wire [31:0] mem_read_data;

    wire mem_stall;

    instruction_fetch if_stage (
        .clk            (clk),
        .rst            (rst), 
        .en             (en & ~mem_stall),
        .branch_en      (branch_en),
        .jump_en        (jump_en),
        .jump_reg_en    (jump_reg_en),
        .jump_reg_pc    (rs_data),
        .trap_en        (trap | alu_overflow),
        .trap_pc        ({30'd500, 2'b0}),

        .pc             (pc),
        .instr          (instr)
    );

    decode d_stage (
        .pc             (pc),
        .instr          (instr),
        .alu_result     (alu_result),
        .rs_data        (rs_data),
        .rt_data        (rt_data),

        .reg_write_addr (reg_write_addr),
        .branch_en      (branch_en),
        .jump_en        (jump_en),
        .jump_reg_en    (jump_reg_en),
        .alu_opcode     (alu_opcode),
        .alu_op_x       (alu_op_x),
        .alu_op_y       (alu_op_y),
        .mem_write_en   (mem_write_en),
        .mem_read_en    (mem_read_en),
        .reg_write_en   (reg_write_en),
        .rs_addr        (rs_addr),
        .rt_addr        (rt_addr)
    );

    alu x_stage (
        .alu_opcode     (alu_opcode),
        .alu_op_x       (alu_op_x),
        .alu_op_y       (alu_op_y),

        .alu_result     (alu_result),
        .alu_overflow   (alu_overflow)
    );

    memory_top m_stage (
        .clk        (clk),
        .memclk         (memclk),
        .rst            (rst),
        .we             (en & mem_write_en),
        .re             (en & mem_read_en),
        .addr           (alu_result),
        .data_in        (rt_data),
        .controller_data(controller_data),    // eventually hook up a controller to the FPGA and do memory-mapped input

        .data_out       (mem_read_data),
        .display_we     (display_we),
        .display_data   (display_data),
        .mem_stall      (mem_stall)
    );

    assign reg_write_data = mem_read_en ? mem_read_data : alu_result;

    regfile w_stage (
        .clk            (clk),
        .we             (en & reg_write_en & ~mem_stall),
        .write_addr     (reg_write_addr),
        .write_data     (reg_write_data),
        .rs_addr        (rs_addr),
        .rt_addr        (rt_addr),

        .rs_data        (rs_data),
        .rt_data        (rt_data)
    );

endmodule
