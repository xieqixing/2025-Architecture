`ifndef __DECODER_SV
`define __DECODER_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module decoder
    import common::*;
    import pipes::*;(

        input u32 raw_instr,
        //input u64 pc,
        output control_t ctl
        
    );

    wire [6:0] f7 = raw_instr[6:0];
    wire [2:0] f3 = raw_instr[14:12];


    always_comb begin
        ctl = '0;

        unique case(f7)
            F7_ADDI: begin

                ctl.op = I;
                ctl.regwrite = 1'b1;
                //ctl.pc = pc;

                unique case(f3)
                    F3_ADDI: begin
                        ctl.alufunc = ALU_ADD;
                        ctl.alusrc = 1'b1;
                    end

                    F3_XORI: begin
                        ctl.alufunc = ALU_XOR;
                        ctl.alusrc = 1'b1;
                    end

                    F3_ORI: begin
                        ctl.alufunc = ALU_OR;
                        ctl.alusrc = 1'b1;
                    end

                    F3_ANDI: begin
                        ctl.alufunc = ALU_AND;
                        ctl.alusrc = 1'b1;
                    end

                    F3_SLLI: begin
                        ctl.alufunc = ALU_SLL;
                        ctl.shamt = 1'b1;
                    end

                    F3_SRAI: begin
                        if(raw_instr[31:26] == 6'b010000) begin
                            ctl.alufunc = ALU_SRA;
                        end else begin
                            ctl.alufunc = ALU_SRL;
                        end
                        ctl.shamt = 1'b1;
                    end

                    F3_SLTI: begin
                        ctl.alufunc = ALU_SUB;
                        ctl.slt = 1'b1;
                        ctl.alusrc = 1'b1;
                    end

                    F3_SLTIU: begin
                        ctl.alufunc = ALU_SUB;
                        ctl.slt = 1'b1;
                        ctl.alusrc = 1'b1;
                    end

                    default: begin
                        
                    end
                endcase
            end

            F7_ADD: begin

                ctl.op = R;
                ctl.regwrite = 1'b1;
                //ctl.pc = pc;

                unique case(f3)
                F3_ADD: begin
                    if(raw_instr[31:25] == 7'b0000001) begin
                        ctl.alufunc = ALU_MUL;
                        ctl.mul_div = 1'b1;
                    end else if(raw_instr[31:25] == 7'b0000000) begin
                        ctl.alufunc = ALU_ADD;
                    end else begin
                        ctl.alufunc = ALU_SUB;
                    end
                end

                F3_AND: begin
                    if(raw_instr[31:25] == 7'b0000001) begin
                        ctl.alufunc = ALU_REM;
                        ctl.mul_div = 1'b1;
                        ctl.unsign = 1'b1;
                    end else begin
                        ctl.alufunc = ALU_AND;
                    end
                end

                F3_XOR: begin
                    if(raw_instr[31:25] == 7'b0000000) begin
                        ctl.alufunc = ALU_XOR;
                    end else begin
                        ctl.alufunc = ALU_DIV;
                        ctl.mul_div = 1'b1;
                    end
                end

                F3_OR: begin
                    if(raw_instr[31:25] == 7'b0000001) begin
                        ctl.alufunc = ALU_REM;
                        ctl.mul_div = 1'b1;
                    end else begin
                        ctl.alufunc = ALU_OR;
                    end
                end

                F3_SLL: begin
                    ctl.alufunc = ALU_SLL;
                end

                F3_SLT: begin
                    ctl.alufunc = ALU_SUB;
                    ctl.slt = 1'b1;
                end

                F3_SLTU: begin
                    ctl.alufunc = ALU_SUB;
                    ctl.slt = 1'b1;
                end

                F3_SRA: begin
                    if(raw_instr[31:25] == 7'b0000001) begin
                        ctl.alufunc = ALU_DIV;
                        ctl.mul_div = 1'b1;
                        ctl.unsign = 1'b1;
                    end else if(raw_instr[31:25] == 7'b0100000) begin
                        ctl.alufunc = ALU_SRA;
                    end else begin
                        ctl.alufunc = ALU_SRL;
                    end
                end

                default: begin

                end
                endcase
                    
            end

            F7_ADDIW: begin

                ctl.op = I;
                ctl.regwrite = 1'b1;
                ctl.immextend = 1'b1;
                //ctl.pc = pc;

                unique case(f3)
                    F3_ADDIW: begin
                        ctl.alufunc = ALU_ADD;
                        ctl.alusrc = 1'b1;
                    end

                    F3_SLLIW: begin
                        ctl.alufunc = ALU_SLLW;
                        ctl.shamt = 1'b1;
                    end

                    F3_SRAIW: begin
                        if(raw_instr[31:26] == 6'b010000) begin
                            ctl.alufunc = ALU_SRAW;
                        end else begin
                            ctl.alufunc = ALU_SRLW;
                        end
                        ctl.shamt = 1'b1;
                    end

                    default: begin
                        
                    end
                endcase

            end

            F7_ADDW: begin
                
                ctl.op = R;
                ctl.regwrite = 1'b1;
                ctl.immextend = 1'b1;
                //ctl.pc = pc;

                unique case(f3)
                    F3_ADDW: begin
                        if(raw_instr[31:25] == 7'b0000001) begin
                            ctl.alufunc = ALU_MUL;
                            ctl.mul_div = 1'b1;
                        end else if(raw_instr[31:25] == 7'b0000000) begin
                            ctl.alufunc = ALU_ADD;
                        end else begin
                            ctl.alufunc = ALU_SUB;
                        end
                    end

                    F3_SLLW: begin
                        ctl.alufunc = ALU_SLLW;
                    end

                    F3_SRAW: begin
                        if(raw_instr[31:25] == 7'b0000001) begin
                            ctl.alufunc = ALU_DIV;
                            ctl.mul_div = 1'b1;
                            ctl.unsign = 1'b1;
                        end else if(raw_instr[31:25] == 7'b0100000) begin
                            ctl.alufunc = ALU_SRAW;
                        end else begin
                            ctl.alufunc = ALU_SRLW;
                        end
                    end

                    F3_DIVW: begin
                        ctl.alufunc = ALU_DIV;
                        ctl.mul_div = 1'b1;
                    end

                    F3_REMW: begin
                        ctl.alufunc = ALU_REM;
                        ctl.mul_div = 1'b1;
                    end

                    F3_REMUW: begin
                        ctl.alufunc = ALU_REM;
                        ctl.mul_div = 1'b1;
                        ctl.unsign = 1'b1;
                    end

                    default: begin
                        
                    end
                endcase
            end

            F7_LOAD: begin

                ctl.op = I;
                ctl.regwrite = 1'b1;
                ctl.alusrc = 1'b1;
                ctl.alufunc = ALU_ADD;
                ctl.memread = 1'b1;

                unique case(f3) 
                    F3_LB: begin
                        ctl.size = MSIZE1;
                        ctl.memextend = 1'b1;
                    end

                    F3_LBU: begin
                        ctl.size = MSIZE1;
                        //ctl.memextend = 1'b1;
                    end

                    F3_LH: begin
                        ctl.size = MSIZE2;
                        ctl.memextend = 1'b1;
                    end

                    F3_LHU: begin
                        ctl.size = MSIZE2;
                        //ctl.memextend = 1'b1;
                    end

                    F3_LW: begin
                        ctl.size = MSIZE4;
                        ctl.memextend = 1'b1;
                    end

                    F3_LWU: begin
                        ctl.size = MSIZE4;
                        //ctl.memextend = 1'b1;
                    end

                    F3_LD: begin
                        ctl.size = MSIZE8;
                    end

                    default: begin
                        
                    end
                endcase
            end
                
            F7_LUI: begin

                ctl.op = U;
                ctl.regwrite = 1'b1;
                ctl.lui = 1'b1;

            end

            F7_STORE: begin

                ctl.op = S;
                ctl.alusrc = 1'b1;
                ctl.alufunc = ALU_ADD;
                ctl.memwrite = 1'b1;

                unique case(f3)
                    F3_SB: begin
                        ctl.size = MSIZE1;
                    end

                    F3_SH: begin
                        ctl.size = MSIZE2;
                    end

                    F3_SW: begin
                        ctl.size = MSIZE4;
                    end

                    F3_SD: begin
                        ctl.size = MSIZE8;
                    end

                    default begin
                        
                    end
                endcase
            end

            F7_BEQ: begin

                ctl.op = B;
                ctl.branchorjump = 1'b1;

                unique case(f3)
                    F3_BEQ: begin
                        ctl.alufunc = ALU_SUB;
                    end

                    F3_BNE: begin
                        ctl.alufunc = ALU_SUB;
                    end

                    F3_BLT: begin
                        ctl.alufunc = ALU_SUB;
                    end

                    F3_BGE: begin
                        ctl.alufunc = ALU_SUB;
                    end

                    F3_BLTU: begin
                        ctl.alufunc = ALU_SUB;
                    end

                    F3_BGEU: begin
                        ctl.alufunc = ALU_SUB;
                    end

                    default: begin
                        
                    end
                endcase
            end

            F7_AUIPC: begin

                ctl.op = U;
                ctl.regwrite = 1'b1;
                ctl.auipc = 1'b1;
                //ctl.pc = pc;

            end

            F7_JAL: begin

                ctl.op = J;
                ctl.regwrite = 1'b1;
                ctl.branchorjump = 1'b1;
                ctl.alufunc = ALU_ADD;
                

            end

            F7_JALR: begin

                ctl.op = J;
                ctl.regwrite = 1'b1;
                ctl.branchorjump = 1'b1;
                ctl.alufunc = ALU_ADD;
                ctl.alusrc = 1'b1;
            end

            F7_CSRRC: begin

                ctl.op = I;
                ctl.regwrite = 1'b1;
                ctl.csrsrc = 1'b1;
                ctl.csrwrite = 1'b1;

                unique case(f3)
                    F3_CSRRC: begin
                        ctl.alufunc = ALU_AND_NEG;
                    end

                    F3_CSRRCI: begin
                        ctl.alufunc = ALU_AND_NEG;
                        ctl.csrimm = 1'b1;
                        ctl.csrcut = 1'b1;
                    end

                    F3_CSRRS: begin
                        ctl.alufunc = ALU_OR;
                    end

                    F3_CSRRSI: begin
                        ctl.alufunc = ALU_OR;
                        ctl.csrimm = 1'b1;
                        ctl.csrcut = 1'b1;
                    end

                    F3_CSRRW: begin
                        ctl.alufunc = ALU_ADD;
                        ctl.csrout = 1'b1;
                    end

                    F3_CSRRWI: begin
                        ctl.alufunc = ALU_ADD;  
                        ctl.csrout = 1'b1;   
                        ctl.csrimm = 1'b1;        
                    end

                    F3_MRET: begin
                        if(raw_instr[31:25] == 7'b0011000)begin
                            ctl.regwrite = 1'b0;
                            ctl.csrsrc = 1'b0;
                            ctl.csrwrite = 1'b0;
                            ctl.mret = 1'b1;
                        end else if(raw_instr[31:25] == 7'b0000000) begin
                            ctl.regwrite = 1'b0;
                            ctl.csrsrc = 1'b0;
                            ctl.csrwrite = 1'b0; // ecall
                            ctl.ecall = 1'b1;
                        end else begin
                            ctl.regwrite = 1'b0;
                            ctl.csrsrc = 1'b0;
                            ctl.csrwrite = 1'b0;
                        end
                        
                    end

                    default: begin
                        
                    end
                endcase
            end

            F7_AMO: begin
                ctl.op = R;
                ctl.regwrite = 1'b1;
                ctl.memread = 1'b1;
                ctl.immextend = 1'b1;
                ctl.amo = 1'b1;
                ctl.size = MSIZE4;
                ctl.memwrite = 1'b1;

                unique case(raw_instr[31:27])
                    F5_AMOSWAP: begin
                        ctl.alufunc = ALU_SWAP;
                    end
                    
                    F5_AMOADD: begin
                        ctl.alufunc = ALU_ADD;
                    end

                    F5_AMOXOR: begin
                        ctl.alufunc = ALU_XOR;
                    end

                    F5_AMOAND: begin
                        ctl.alufunc = ALU_AND;
                    end

                    F5_AMOOR: begin
                        ctl.alufunc = ALU_OR;
                    end

                    F5_AMOMIN: begin
                        ctl.alufunc = ALU_MIN;
                    end

                    F5_AMOMAX: begin
                        ctl.alufunc = ALU_MAX;
                    end

                    F5_AMOMINU: begin
                        ctl.alufunc = ALU_MINU;
                    end

                    F5_AMOMAXU: begin
                        ctl.alufunc = ALU_MAXU;
                    end

                    F5_LRW: begin
                        ctl.memwrite = 1'b0;
                        ctl.memextend = 1'b1;
                        ctl.lrw = 1'b1;
                    end

                    F5_SC: begin
                        ctl.memread = 1'b0;
                        ctl.sc = 1'b1;
                    end

                    default: begin
                        
                    end
                endcase
                
            end


            default: begin
                ctl.address_error = 1'b1;
            end
        endcase
    end

    

endmodule

`endif