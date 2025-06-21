`ifndef __PIPES_SV
`define __PIPES_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/csr.sv"
`endif

package pipes;
    import common::*;
    import csr_pkg::*;
/* define instruction decoding rules here */

// parameter F7_RI = 7'bxxxxxxx;
parameter F7_ADDI = 7'b0010011;
parameter F3_ADDI = 3'b000;
parameter F3_XORI = 3'b100;
parameter F3_ORI = 3'b110;
parameter F3_ANDI = 3'b111;
parameter F3_SLLI = 3'b001;
parameter F3_SLTI = 3'b010;
parameter F3_SLTIU = 3'b011;
parameter F3_SRAI = 3'b101;

parameter F7_ADD = 7'b0110011;
parameter F3_ADD = 3'b000;
parameter F3_XOR = 3'b100;
parameter F3_OR = 3'b110;
parameter F3_AND = 3'b111;
parameter F3_SLL = 3'b001;
parameter F3_SLT = 3'b010;
parameter F3_SLTU = 3'b011;
parameter F3_SRA = 3'b101;


parameter F7_ADDIW = 7'b0011011;
parameter F3_ADDIW = 3'b000;
parameter F3_SLLIW = 3'b001;
parameter F3_SRAIW = 3'b101;

parameter F7_ADDW = 7'b0111011;
parameter F3_ADDW = 3'b000;
parameter F3_SLLW = 3'b001;
parameter F3_SRAW = 3'b101;
parameter F3_DIVW = 3'b100;
parameter F3_REMW = 3'b110;
parameter F3_REMUW = 3'b111;

parameter F7_LOAD = 7'b0000011;
parameter F3_LB = 3'b000;
parameter F3_LBU = 3'b100;
parameter F3_LD = 3'b011;
parameter F3_LH = 3'b001;
parameter F3_LHU = 3'b101;
parameter F3_LW = 3'b010;
parameter F3_LWU = 3'b110;

parameter F7_LUI = 7'b0110111;

parameter F7_STORE = 7'b0100011;
parameter F3_SB = 3'b000;
parameter F3_SD = 3'b011;
parameter F3_SH = 3'b001;
parameter F3_SW = 3'b010;

parameter F7_BEQ = 7'b1100011;
parameter F3_BEQ = 3'b000;
parameter F3_BNE = 3'b001;
parameter F3_BLT = 3'b100;
parameter F3_BGE = 3'b101;
parameter F3_BLTU = 3'b110;
parameter F3_BGEU = 3'b111;

parameter F7_AUIPC = 7'b0010111;

parameter F7_JALR = 7'b1100111;

parameter F7_JAL = 7'b1101111;

parameter F7_CSRRC = 7'b1110011;
parameter F3_CSRRC = 3'b011;
parameter F3_CSRRCI = 3'b111;
parameter F3_CSRRS = 3'b010;
parameter F3_CSRRSI = 3'b110;
parameter F3_CSRRW = 3'b001;
parameter F3_CSRRWI = 3'b101;
parameter F3_MRET = 3'b000;

parameter F7_AMO = 7'b0101111;
parameter F5_AMOSWAP = 5'b00001;
parameter F5_AMOADD = 5'b00000;
parameter F5_AMOXOR = 5'b00100;
parameter F5_AMOAND = 5'b01100;
parameter F5_AMOOR = 5'b01000;
parameter F5_AMOMIN = 5'b10000;
parameter F5_AMOMAX = 5'b10100;
parameter F5_AMOMINU = 5'b11000;
parameter F5_AMOMAXU = 5'b11100;
parameter F5_LRW = 5'b00010;
parameter F5_SC = 5'b00011;


/* define pipeline structure here */

typedef struct packed {
    u32 raw_instr;
    u64 pc;
} fetch_data_t;

typedef enum logic [5:0]{
    I, R, S, B, U, J
} decode_op_t;

typedef enum logic [4:0]{
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_SLL, ALU_SRL, ALU_SRA, ALU_SLLW, ALU_SRAW, ALU_SRLW,
    ALU_AND_NEG, ALU_MUL, ALU_DIV, ALU_REM, 
    ALU_MIN, ALU_MAX, ALU_MINU, ALU_MAXU, ALU_SWAP
} alufunc_t;

typedef struct packed {
    u1 branch;   // 分支预测
    u64 pc_branch;  // 分支跳转的地址
    u64 pcplus4;    // 下一条指令地址
} pre_branch_data_t;

typedef struct packed {
    decode_op_t op;	// 指令的类型
    alufunc_t alufunc;	// 指令所需的ALU操作
    u1 regwrite;	// 是否要写入寄存器
    u1 alusrc;  // 对alu运算的第二个数进行选择，0: srcb, 1: imm
    u1 mul_div; // 是否是乘除法指令
    u1 immextend; // 判断alu运算完之后是否需要符号拓展，支持addw, addiw, subw
    u1 unsign;  // 是否是无符号数运算
    u1 memread;     // 是否对内存进行写操作
    u1 memwrite;    // 是否对内存进行读操作
    u1 memextend;   // 是否需要将从内存中读取的数进行符号拓展1: lwu, lbu, lhu
    u1 lui;         // 加载立即数的指令 1: lui
    u1 auipc;       // 加载立即数的指令 1: auipc
    u1 slt;         // 比较指令 1: slt
    u1 shamt;       // 移位指令
    u1 csrsrc, csrwrite, csrout, csrimm, csrcut;      // csr指令
    u1 mret, ecall;   // mret, ecall指令
    u1 address_error; // 地址错误
    u1 address_not_aligned; // 地址未对齐
    u1 branchorjump;  // 分支或跳转指令
    u1 amo;          // 原子操作指令
    u1 lrw, sc; // lrw, sc指令

    msize_t size;   // 内存写入的大小

} control_t;

typedef struct packed {
    u1 z, n, v, c;
} CCR_t;


typedef struct packed {
    word_t srca, srcb, srccsr, imm, imm2, imm3;	// 寄存器里读出来的两个值，两种方法读取立即数
    satp_t satp;	// satp寄存器
    control_t ctl;	// 控制单元
    creg_addr_t dst;	// 写入寄存器地址
    creg_addr_t ra1, ra2;	// 读取寄存器地址
    csr_addr_t csr_addr;    // csr寄存器地址
    u2 privilegeMode;    // 特权模式

    fetch_data_t pc_instr;	//pc以及指令
} decode_data_t;

typedef struct packed {
    word_t aluout, memwrite_data, csrout, srca;
    satp_t satp;
    control_t ctl;
    creg_addr_t dst;
    csr_addr_t csr_addr;
    u2 privilegeMode;

    fetch_data_t pc_instr;
} execute_data_t;

typedef struct packed {
    word_t memout, memaddr, csrout;
    control_t ctl;
    creg_addr_t dst;
    csr_addr_t csr_addr;
    u1 load_misaligned, store_misaligned;

    fetch_data_t pc_instr;
} memory_data_t;

typedef struct packed {
    u64 pc_branch;
    u1 branch;
} branch_data_t;

typedef struct packed {
    u64 mtvec, mip, mie, mscratch, mcause, mtval, mepc, mcycle, mhartid;
    mstatus_t mstatus;
    satp_t satp;
} csr_data_t;

typedef struct packed {
    u64 pcplus4;
    u1 branch;
} csr_flush_data_t;

endpackage

`endif