`ifndef __DECODE_SV
`define __DECODE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "src/decode/decoder.sv"
`include "src/decode/prebranch.sv"
`else

`endif

module decode
    import common::*;
    import pipes::*;(
        input logic clk, reset,
        input fetch_data_t dataF,
        input u2 false_branch,
        input memory_data_t dataM,
        input execute_data_t dataE, 
        output decode_data_t dataD,

        input word_t rd1, rd2, rd3,
        output creg_addr_t ra1, ra2,
        output csr_addr_t ra3,
        output branch_data_t dataPB,
        output pre_branch_data_t pre_branch
    );

    u1 branch;
    control_t ctl;
    word_t pc_branch, srca;
    
    decoder decoder(
        .raw_instr(dataF.raw_instr),
        //.pc(dataF.pc),
        .ctl(ctl)
    );

    always_comb begin
       if(dataE.ctl.regwrite && dataE.dst != 0 && dataE.dst == dataD.ra1) begin
            srca = dataE.aluout;
        end else if(dataM.ctl.regwrite && dataM.dst != 0 && dataM.dst == dataD.ra1 && dataE.dst != dataD.ra1)begin
            srca = dataM.memout;
        end else begin
            srca = rd1;
        end
    end

    prebranch prebranch(
        .clk(clk),
        .reset(reset),
        .false_branch(false_branch),
        .imm(dataD.imm),
        .srca(srca),
        .ctl(dataD.ctl),
        .pc_instr(dataD.pc_instr),
        .dataPB(dataPB),
        .pc_branch(pc_branch),
        .branch(branch)
    );

    assign dataD.ctl = ctl;
    //fetch_data_t pc_instr;
    //assign pc_instr = dataF;
    assign dataD.pc_instr = dataF;
    //assign dataD.pc = dataF.pc;
    //assign dataD.raw_instr = dataF.raw_instr;

    assign dataD.dst = dataF.raw_instr[11:7];
    assign ra3 = dataF.raw_instr[31:20];

    assign dataD.srca = rd1;
    assign dataD.srcb = rd2;
    assign dataD.srccsr = rd3;
    assign dataD.imm = {{52{dataF.raw_instr[31]}}, dataF.raw_instr[31:20]};
    assign dataD.imm2 ={{52{dataF.raw_instr[31]}}, dataF.raw_instr[31:25], dataF.raw_instr[11:7]};
    assign dataD.imm3 = {59'b0, dataF.raw_instr[19:15]};

    assign ra1 = dataF.raw_instr[19:15];
    assign ra2 = dataF.raw_instr[24:20];

    assign dataD.ra1 = ra1;
    assign dataD.ra2 = ra2;
    assign dataD.csr_addr = ra3;
    assign dataD.ctl.address_not_aligned = dataF.pc[1:0] != 2'b00;

    assign pre_branch.branch = branch;
    assign pre_branch.pc_branch = pc_branch;
    assign pre_branch.pcplus4 = dataF.pc + 4;
    

endmodule

`endif