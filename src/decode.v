//=============================================================================
// EE108B Lab 2
//
// Decode module. Determines what to do with an instruction.
//=============================================================================

`include "mips_defines.v"

module decode (
    input [31:0] pc,
    input [31:0] instr,
    input [31:0] alu_result,
    input [31:0] rs_data,
    input [31:0] rt_data,

    output wire [4:0] reg_write_addr,
    output wire branch_en,
    output wire jump_en,
    output wire jump_reg_en,
    output reg [3:0] alu_opcode,
    output wire [31:0] alu_op_x,
    output wire [31:0] alu_op_y,
    output wire mem_write_en,
    output wire mem_read_en,
    output wire reg_write_en,
    output wire [4:0] rs_addr,
    output wire [4:0] rt_addr
);

//******************************************************************************
// instruction field
//******************************************************************************

    wire [5:0] op = instr[31:26];
    assign rs_addr = instr[25:21];
    assign rt_addr = instr[20:16];
    wire [4:0] rd_addr = instr[15:11];
    wire [4:0] shamt = instr[10:6];
    wire [5:0] funct = instr[5:0];
    wire [15:0] immediate = instr[15:0];

//******************************************************************************
// branch instructions decode
//******************************************************************************

    wire isBEQ  = op == `BEQ;
    wire isBNE  = op == `BNE;
    wire isBGTZ = op == `BGTZ;
    wire isBLEZ = op == `BLEZ;
    wire isBGEZ = (op == `BLTZ_GEZ) & rt_addr[0];
    wire isBLTZ = (op == `BLTZ_GEZ) & ~rt_addr[0];
    wire isBranch = |{isBEQ, isBNE, isBGTZ, isBLEZ, isBGEZ, isBLTZ};
    
    wire isBranchLink = |{isBGEZ, isBLTZ} & rt_addr[4];
    
    // determine if branch is taken
    
    wire rs_zero = ~|rs_data;
    wire rs_neg = rs_data[31];
    wire rs_pos = ~rs_zero & ~rs_neg;

    wire alu_zero = ~|alu_result;

    assign branch_en = |{isBEQ & alu_zero, isBNE & ~alu_zero,
                         isBGTZ & rs_pos, isBLEZ & ~rs_pos,
                         isBGEZ & ~rs_neg, isBLTZ & rs_neg};

//******************************************************************************
// jump instructions decode
//******************************************************************************

    wire isJ    = (op == `J);
    wire isJAL  = (op == `JAL);
    wire isJALR = (op == `SPECIAL) & (funct == `JALR);  
    wire isJR   = (op == `SPECIAL) & (funct == `JR);
    
    assign jump_en = isJ | isJAL;
    assign jump_reg_en = isJALR | isJR;
    
    // determine if the next pc will need to be stored
    wire isLink = isJALR | isJAL | isBranchLink;

//******************************************************************************
// shift instruction decode
//******************************************************************************

    wire isSLL = (op == `SPECIAL) & (funct == `SLL);
    wire isSRA = (op == `SPECIAL) & (funct == `SRA);
    wire isSRL = (op == `SPECIAL) & (funct == `SRL);
    wire isSLLV = (op == `SPECIAL) & (funct == `SLLV);
    wire isSRAV = (op == `SPECIAL) & (funct == `SRAV);
    wire isSRLV = (op == `SPECIAL) & (funct == `SRLV);
    
    wire isShiftImm = isSLL | isSRA | isSRL;
    wire isShift = isShiftImm | isSLLV | isSRAV | isSRLV;

//******************************************************************************
// ALU instructions decode / control signal for ALU datapath
//******************************************************************************
    
    always @* begin
        casex({op, funct})
            {`ADDI, `DC6}:      alu_opcode = `ALU_ADD;
            {`ADDIU, `DC6}:     alu_opcode = `ALU_ADDU;
            {`SLTI, `DC6}:      alu_opcode = `ALU_SLT;
            {`SLTIU, `DC6}:     alu_opcode = `ALU_SLTU;	
            {`ANDI, `DC6}:      alu_opcode = `ALU_AND;
            {`ORI, `DC6}:       alu_opcode = `ALU_OR;
            {`XORI, `DC6}:      alu_opcode = `ALU_XOR;
            {`LW, `DC6}:        alu_opcode = `ALU_ADD;
            {`SW, `DC6}:        alu_opcode = `ALU_ADD;
            {`BEQ, `DC6}:       alu_opcode = `ALU_SUBU;
            {`BNE, `DC6}:       alu_opcode = `ALU_SUBU;
            {`SPECIAL, `ADD}:   alu_opcode = `ALU_ADD;
            {`SPECIAL, `ADDU}:  alu_opcode = `ALU_ADDU;
            {`SPECIAL, `SUB}:   alu_opcode = `ALU_SUB;
            {`SPECIAL, `SUBU}:  alu_opcode = `ALU_SUBU;
            {`SPECIAL, `AND}:   alu_opcode = `ALU_AND;
            {`SPECIAL, `OR}:    alu_opcode = `ALU_OR;
            {`SPECIAL, `XOR}:   alu_opcode = `ALU_XOR;
            {`SPECIAL, `NOR}:   alu_opcode = `ALU_NOR;
            {`SPECIAL, `SLT}:   alu_opcode = `ALU_SLT;
            {`SPECIAL, `SLTU}:  alu_opcode = `ALU_SLTU;
            {`SPECIAL, `SLL}:   alu_opcode = `ALU_SLL;
            {`SPECIAL, `SRL}:   alu_opcode = `ALU_SRL;
            {`SPECIAL, `SRA}:   alu_opcode = `ALU_SRA;
            {`SPECIAL, `SLLV}:  alu_opcode = `ALU_SLL;
            {`SPECIAL, `SRLV}:  alu_opcode = `ALU_SRL;
            {`SPECIAL, `SRAV}:  alu_opcode = `ALU_SRA;
            // compare rs data to 0, only care about 1 operand
            {`BGTZ, `DC6}:      alu_opcode = `ALU_PASSX;
            {`BLEZ, `DC6}:      alu_opcode = `ALU_PASSX;
            {`BLTZ_GEZ, `DC6}: begin
                if (isBranchLink)
                    alu_opcode = `ALU_PASSY; // pass link address for mem stage
                else
                    alu_opcode = `ALU_PASSX;
            end
            // pass link address to be stored in $ra
            {`JAL, `DC6}:       alu_opcode = `ALU_PASSY;
            {`SPECIAL, `JALR}:  alu_opcode = `ALU_PASSY;
            // or immediate with 0
            {`LUI, `DC6}:       alu_opcode = `ALU_PASSY;
            default:            alu_opcode = `ALU_PASSX;
    	endcase
    end

//******************************************************************************
// Compute value for 32 bit immediate data
//******************************************************************************

    wire use_imm = &{op != `SPECIAL, op != `BNE, op != `BEQ};
    
    wire [31:0] imm_sign_extend = {{16{immediate[15]}}, immediate};  
    wire [31:0] imm_zero_extend = {16'b0, immediate};	
    wire [31:0] imm_upper = {immediate, 16'b0};
    
    reg [31:0] imm;
    always @* begin
        if (op == `LUI)
            imm = imm_upper;
        else if (|{op == `ORI, op == `ANDI, op == `XORI})
            imm = imm_zero_extend;
        else
            imm = imm_sign_extend;
    end

//******************************************************************************
// Determine ALU inputs and register writeback address
//******************************************************************************

    // for shift operations, use either shamt field or lower 5 bits of rs
    // otherwise use rs

    wire [31:0] shift_amount = isShiftImm ? shamt : rs_data[4:0];
    assign alu_op_x = isShift ? shift_amount : rs_data;
    //
    // for link operations, use next pc (current pc + 4)
    // for immediate operations, use imm
    // otherwise use rt
    assign alu_op_y = isLink ? pc + 3'h4 : (use_imm ? imm : rt_data);
    assign reg_write_addr = isLink ? `RA : (use_imm ? rt_addr : rd_addr);
    
    // determine when to write back to a register
    // (any operation that isn't a non-linking branch or jump, or a store)
    assign reg_write_en = isLink | ~|{mem_write_en, isJ, isJR, isBranch};
  
//******************************************************************************
// Memory control
//******************************************************************************
    assign mem_write_en = op == `SW;    // write to memory
    assign mem_read_en = op == `LW;     // read from memory

endmodule
