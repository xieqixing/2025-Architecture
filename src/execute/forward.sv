`ifndef __FORWARD_SV
`define __FORWARD_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module forward
    import common::*;
    import pipes::*;(

        input execute_data_t dataE,
        input memory_data_t dataM,
        input decode_data_t dataD,
        output word_t fwdA, fwdB
    );

    always_comb begin
        if(dataD.ctl.auipc)begin
            fwdA = dataD.pc_instr.pc;
        end else if(dataE.ctl.regwrite && dataE.dst != 0 && dataE.dst == dataD.ra1) begin
            fwdA = dataE.aluout;
        end else if(dataM.ctl.regwrite && dataM.dst != 0 && dataM.dst == dataD.ra1 && dataE.dst != dataD.ra1)begin
            fwdA = dataM.memout;
        end else begin
            fwdA = dataD.srca;
        end

        if(dataE.ctl.regwrite && dataE.dst != 0 && dataE.dst == dataD.ra2) begin
            fwdB = dataE.aluout;
        end else if(dataM.ctl.regwrite && dataM.dst != 0 && dataM.dst == dataD.ra2 && dataE.dst != dataD.ra2)begin
            fwdB = dataM.memout;
        end else begin
            fwdB = dataD.srcb;
        end
    end

endmodule

`endif