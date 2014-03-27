// define the properties of the memory
`define MEM_DEPTH 14 // 2^14 words = 64KB
`define DISPLAY_ADDR 32'hffff000c
`define CONTROLLER_ADDR 32'hffff0004

// opcodes
`define SPECIAL     6'h0 // used for R format instructions
`define BLTZ_GEZ    6'h1
`define J           6'h2
`define JAL         6'h3
`define BEQ         6'h4
`define BNE         6'h5
`define BLEZ        6'h6
`define BGTZ        6'h7
`define ADDI        6'h8
`define ADDIU       6'h9
`define SLTI        6'ha
`define SLTIU       6'hb
`define ANDI        6'hc
`define ORI         6'hd
`define XORI        6'he
`define LUI         6'hf
`define LW          6'h23
`define SW          6'h2b

// special $rt codes for BLTZ_GEZ
`define BLTZ        5'h0
`define BGEZ        5'h1
`define BLTZAL      5'h10
`define BGEZAL      5'h11

// function codes
`define SLL         6'h0
`define SRL         6'h2
`define SRA         6'h3
`define SLLV        6'h4
`define SRLV        6'h6
`define SRAV        6'h7
`define JR          6'h8
`define JALR        6'h9
/*
`define MFHI        6'h10 // not implemented!
`define MTHI        6'h11 // not implemented!
`define MFLO        6'h12 // not implemented!
`define MTLO        6'h13 // not implemented!
`define MULT        6'h18 // not implemented!
`define MULTU       6'h19 // not implemented!
`define DIV         6'h1a // not implemented!
`define DIVU        6'h1b // not implemented!
*/
`define ADD         6'h20
`define ADDU        6'h21
`define SUB         6'h22
`define SUBU        6'h23
`define AND         6'h24
`define OR          6'h25
`define XOR         6'h26
`define NOR         6'h27
`define SLT         6'h2a
`define SLTU        6'h2b
`define DC6         6'hxx

// Register names
`define ZERO        5'd0
`define AT          5'd1
`define V0          5'd2
`define V1          5'd3
`define A0          5'd4
`define A1          5'd5
`define A2          5'd6
`define A3          5'd7
`define T0          5'd8
`define T1          5'd9
`define T2          5'd10
`define T3          5'd11
`define T4          5'd12
`define T5          5'd13
`define T6          5'd14
`define T7          5'd15
`define S0          5'd16
`define S1          5'd17
`define S2          5'd18
`define S3          5'd19
`define S4          5'd20
`define S5          5'd21
`define S6          5'd22
`define S7          5'd23
`define T8          5'd24
`define T9          5'd25
`define K0          5'd26
`define K1          5'd27
`define GP          5'd28
`define SP          5'd29
`define FP          5'd30
`define RA          5'd31

`define NULL        5'd0 // same as ZERO, but indicate that it's not used, e.g., rt in a bltz

`define NOP         32'b0 // same as sll $zero, $zero, 0

`define LI `ADDI, `ZERO // a pseudo-pseudo-instruction

// opcodes for the ALU
`define ALU_ADDU    4'd0
`define ALU_AND     4'd1
`define ALU_XOR     4'd2
`define ALU_OR      4'd3
`define ALU_NOR     4'd4
`define ALU_SUBU    4'd5
`define ALU_SLTU    4'd6
`define ALU_SLT     4'd7
`define ALU_SRL     4'd8
`define ALU_SRA     4'd9
`define ALU_SLL     4'd10
`define ALU_PASSX   4'd11
`define ALU_PASSY   4'd12
`define ALU_ADD     4'd13
`define ALU_SUB     4'd14

