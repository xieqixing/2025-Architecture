`ifndef __EXECUTE_SV
`define __EXECUTE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "src/execute/alu.sv"
`include "src/execute/forward.sv"
`include "src/execute/branch.sv"
`include "src/execute/mul.sv"
`else

`endif

module execute
    import common::*;
    import pipes::*;(
        input logic clk, reset,
        input decode_data_t dataD,
        input memory_data_t dataM,
        input execute_data_t dataE, 
        input pre_branch_data_t pre_branch,
        output execute_data_t dataE_nxt,
        output branch_data_t dataB,
        output u1 busy,
        output u2 false_branch

    );

    u64 fwdA, fwdB;
    forward forward(
        .dataE(dataE),
        .dataM(dataM),
        .dataD(dataD),
        .fwdA(fwdA),
        .fwdB(fwdB)
    );

    word_t upper_imm;
    assign upper_imm = {{44{dataD.pc_instr.raw_instr[31]}}, dataD.pc_instr.raw_instr[31:12]} << 12;

    u1 during_mul;
    u64 alusrca, alusrcb, alusrca_nxt, alusrcb_nxt, aluout, c, _c;
    always_comb begin
        if(during_mul)begin
            alusrcb = alusrcb_nxt;
        end else if(dataD.ctl.alusrc)begin
            alusrcb = dataD.ctl.memwrite ? dataD.imm2 : dataD.imm;
        end else if(dataD.ctl.auipc)begin
            alusrcb = upper_imm;
        end else if(dataD.ctl.shamt)begin
            alusrcb = {58'b0, dataD.pc_instr.raw_instr[25:20]};
        end else if(dataD.ctl.csrsrc)begin
            alusrcb = dataD.srccsr;
        end else begin
            alusrcb = fwdB;
        end
    end
    //assign alusrcb = dataD.ctl.alusrc ? (dataD.ctl.memwrite ? dataD.imm2 : dataD.imm) : fwdB;

    always_comb begin
        if(during_mul) begin
            alusrca = alusrca_nxt;
        end else if(dataD.ctl.csrimm)begin
            alusrca = dataD.imm3;
        end else begin
            alusrca = fwdA;
        end
    end

    always_ff @(posedge clk) begin
        alusrca_nxt <= alusrca;
        alusrcb_nxt <= alusrcb;      
    end

    CCR_t ccr;
    alu alu(
		.a(alusrca),
		.b(alusrcb),
		.alufunc(dataD.ctl.alufunc),
		.c(c),
        .ccr(ccr)
	); 

    mul mul(
        .clk(clk),
        .reset(reset),
        .a(alusrca),
        .b(alusrcb),
        .ctl(dataD.ctl),
        .c(_c),
        .busy(busy),
        .dur(during_mul)
    );

    //assign aluout = dataD.ctl.lui ? upper_imm : c;
    always_comb begin
        if(dataD.ctl.lui)begin
            aluout = upper_imm;
        end else if(dataD.ctl.slt)begin
            if(dataD.pc_instr.raw_instr[14:12] == 3'b011)begin
                aluout = {63'b0, ~(ccr.c | ccr.z)};
            end else begin
                aluout = {63'b0, (ccr.n ^ ccr.v)};
            end
        end else if(dataD.ctl.csrsrc)begin
            aluout = dataD.srccsr;
        end else if(dataD.ctl.mul_div)begin
            aluout = _c;
        end else if (dataD.ctl.amo) begin
            aluout = alusrca;
        end else begin
            aluout = c;
        end
    end

    //assign dataE_nxt.aluout = (dataD.ctl.immextend) ? {{32{aluout[31]}}, aluout[31:0]} : aluout;
    always_comb begin
        if(dataD.ctl.op == J)begin
            dataE_nxt.aluout = dataD.pc_instr.pc + 4;
        end else begin
            dataE_nxt.aluout = (dataD.ctl.immextend) ? {{32{aluout[31]}}, aluout[31:0]} : aluout;
        end
    end

	assign dataE_nxt.ctl = dataD.ctl;
	assign dataE_nxt.dst = dataD.dst;
    assign dataE_nxt.pc_instr = dataD.pc_instr;
    assign dataE_nxt.memwrite_data = fwdB;
    assign dataE_nxt.csr_addr = dataD.csr_addr;
    assign dataE_nxt.csrout = dataD.ctl.csrout ? alusrca : c;
    assign dataE_nxt.privilegeMode = dataD.privilegeMode;
    assign dataE_nxt.srca = dataD.srca;

    branch branch(
        .dataD(dataD),
        .aluout(aluout),
        .ccr(ccr),
        .pre_branch(pre_branch),
        .dataB(dataB),
        .false_branch(false_branch)
    );

endmodule
`endif