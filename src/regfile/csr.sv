`ifndef __CSR_SV
`define __CSR_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "include/csr.sv"
`else

`endif

module csr
    import common::*;
    import csr_pkg::*;
    import pipes::*;(
        input  logic       clk, reset,
        input  csr_addr_t  ra,
        input  u64         current_pc,
        output u64         rd, mepc, mtvec, 
        output satp_t      satp,
        output u2          mode,
        input  memory_data_t dataM,
        input u1           trint, swint, exint,
        output u1           interrupt
);

    csr_data_t dataC, dataC_nxt;
    u64 mtimecmp;
    u2 privilegeMode, privilegeMode_nxt;
    u1 inter_pre;
    u1 interrupt_judge, interrupt_judge_nxt;
    
    assign inter_pre = ((trint || dataC.mcycle > mtimecmp)| swint | exint) | interrupt_judge;
    assign interrupt_judge_nxt = (dataM.ctl.mret) || (dataM.ctl.csrwrite && (dataM.csr_addr == CSR_MIE || dataM.csr_addr == CSR_MIP || dataM.csr_addr == CSR_MSTATUS ));

    always_comb begin
        if(((privilegeMode == 2'b11 && dataC.mstatus.mie == 1'b1) || privilegeMode == 2'b00 ) && inter_pre == 1'b1 ) begin
            if(trint && dataC.mie[7] == 1'b1 && dataC.mip[7] == 1'b1)begin
                interrupt = 1'b1;
            end else if(swint && dataC.mie[3] == 1'b1 && dataC.mip[3] == 1'b1)begin
                interrupt = 1'b1;
            end else if(exint && dataC.mie[11] == 1'b1 && dataC.mip[11] == 1'b1)begin
                interrupt = 1'b1;
            end else begin
                interrupt = 1'b0;
            end
        end
        else interrupt = 1'b0;
    end
    // CSR register
    always_comb begin

        privilegeMode_nxt = privilegeMode;
        dataC_nxt = dataC;

        if(interrupt || dataM.store_misaligned || dataM.load_misaligned || dataM.ctl.address_not_aligned == 1'b1 || dataM.ctl.ecall == 1'b1 || (dataM.pc_instr.pc != 0 && dataM.ctl.address_error == 1'b1))begin
            if(dataM.ctl.ecall == 1'b1)begin
                dataC_nxt.mcause = {{60{1'b0}}, 4'b1000};
                dataC_nxt.mepc = dataM.pc_instr.pc;
            end else if(dataM.ctl.address_not_aligned == 1'b1) begin
                dataC_nxt.mcause = {{62{1'b0}}, 2'b00};
                dataC_nxt.mepc = dataM.pc_instr.pc;
            end else if(dataM.pc_instr.pc != 0 && dataM.ctl.address_error == 1'b1) begin
                dataC_nxt.mcause = {{62{1'b0}}, 2'b10};
                dataC_nxt.mepc = dataM.pc_instr.pc;
            end else if(dataM.load_misaligned == 1'b1) begin
                dataC_nxt.mcause = {{61{1'b0}}, 3'b100};
                dataC_nxt.mepc = dataM.pc_instr.pc;
            end else if(dataM.store_misaligned == 1'b1) begin
                dataC_nxt.mcause = {{61{1'b0}}, 3'b110};
                dataC_nxt.mepc = dataM.pc_instr.pc;
            end else if(interrupt == 1'b1) begin
                if(swint == 1'b1 && dataC.mie[3] == 1'b1) begin
                    dataC_nxt.mcause = {1'b1,{60{1'b0}}, 3'b011};
                    dataC_nxt.mepc = current_pc;
                end else if(exint == 1'b1 && dataC.mie[11] == 1'b1)begin
                    dataC_nxt.mcause = {1'b1,{59{1'b0}}, 4'b1011};
                    dataC_nxt.mepc = current_pc;
                end else if(trint == 1'b1 && dataC.mie[7] == 1'b1) begin
                    dataC_nxt.mcause = {1'b1,{60{1'b0}}, 3'b111};
                    //if(dataC.mcycle > {40'b0, 24'b001011110000000000000000} && dataC.mcycle < {40'b0, 24'b100010000000000000000000}) dataC_nxt.mepc = {32'b0, 32'b10000000000000001000000001001000};
                    dataC_nxt.mepc = current_pc;
                    
                end else begin
                    dataC_nxt.mcause = {1'b1,{60{1'b0}}, 3'b000};
                    dataC_nxt.mepc = dataM.pc_instr.pc;
                end
                //dataC_nxt.mcause = {1'b1,{60{1'b0}}, 3'b111};
            end 
            
            
            dataC_nxt.mstatus.mpp = privilegeMode;
            dataC_nxt.mstatus.mie = 1'b0;
            privilegeMode_nxt = 2'b11;
            dataC_nxt.mstatus.mpie = dataC.mstatus.mie;
        end else if(dataM.ctl.mret == 1'b0) begin
            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MIE)begin
                dataC_nxt.mie = dataM.csrout;
            end else begin
                dataC_nxt.mie = dataC.mie;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MTVEC)begin
                dataC_nxt.mtvec = dataM.csrout & MTVEC_MASK;
            end else begin
                dataC_nxt.mtvec = dataC.mtvec;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MSTATUS)begin
                dataC_nxt.mstatus = dataM.csrout & MSTATUS_MASK;
            end else begin
                dataC_nxt.mstatus = dataC.mstatus;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MEPC)begin
                dataC_nxt.mepc = dataM.csrout;
            end else begin
                dataC_nxt.mepc = dataC.mepc;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MCAUSE)begin
                dataC_nxt.mcause = dataM.csrout;
            end else begin
                dataC_nxt.mcause = dataC.mcause;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MIP)begin
                dataC_nxt.mip = dataM.csrout & MIP_MASK;
            end else if(trint) begin
                dataC_nxt.mip = dataC.mip | {56'b0, 8'b10000000};
            end else if(swint) begin
                dataC_nxt.mip = dataC.mip | {60'b0, 4'b1000};
            end else if(exint)begin
                dataC_nxt.mip = dataC.mip | {52'b0, 12'b100000000000};
            end else begin
                dataC_nxt.mip = dataC.mip;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MSCRATCH)begin
                dataC_nxt.mscratch = dataM.csrout;
            end else begin
                dataC_nxt.mscratch = dataC.mscratch;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MHARTID)begin
                dataC_nxt.mhartid = dataM.csrout;
            end else begin
                dataC_nxt.mhartid = dataC.mhartid;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_SATP)begin
                dataC_nxt.satp = dataM.csrout;
            end else begin
                dataC_nxt.satp = dataC.satp;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MCYCLE)begin
                dataC_nxt.mcycle = dataM.csrout;
            end else begin
                dataC_nxt.mcycle = dataC.mcycle + 1;
            end

            if(dataM.ctl.csrwrite && dataM.csr_addr == CSR_MTVAL)begin
                dataC_nxt.mtval = dataM.csrout;
            end else begin
                dataC_nxt.mtval = dataC.mtval;
            end
        end else begin
            privilegeMode_nxt = dataC.mstatus.mpp;
            dataC_nxt.mstatus.mie = dataC.mstatus.mpie;
            dataC_nxt.mstatus.mpie = 1'b1;
            dataC_nxt.mstatus.mpp = privilegeMode;
            dataC_nxt.mstatus.xs = 2'b00;
        end
    end

    always_ff @( posedge clk or posedge reset ) begin 
        if (reset) begin
            dataC <= '0;
            privilegeMode <= 2'b11;
            mtimecmp <= 64'b1;
            interrupt_judge <= 1'b0;
        end else begin
            dataC <= dataC_nxt;
            privilegeMode <= privilegeMode_nxt;
            mtimecmp <= mtimecmp;
            interrupt_judge <= interrupt_judge_nxt;
        end
        
    end

    assign rd = (ra == CSR_MTVEC) ? dataC.mtvec :
                (ra == CSR_MSTATUS) ? dataC.mstatus :
                (ra == CSR_MEPC) ? dataC.mepc :
                (ra == CSR_MCAUSE) ? dataC.mcause :
                (ra == CSR_MIP) ? dataC.mip :
                (ra == CSR_MSCRATCH) ? dataC.mscratch :
                (ra == CSR_MHARTID) ? dataC.mhartid :
                (ra == CSR_SATP) ? dataC.satp :
                (ra == CSR_MCYCLE) ? dataC.mcycle :
                (ra == CSR_MTVAL) ? dataC.mtval : 
                (ra == CSR_MIE) ? dataC.mie : 64'b0;
    
    assign mepc = dataC.mepc;
    assign mtvec = dataC.mtvec;
    assign mode = privilegeMode_nxt;
    assign satp = dataC.satp;
    
endmodule

`endif 