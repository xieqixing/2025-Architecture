`ifndef __PCSELECT_SV
`define __PCSELECT_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module pcselect
    import common::*;
    import pipes::*;(

        input u64 pcplus4,
        input branch_data_t dataB, dataPB,
        output u64 pcselected
        
    );

    always_comb begin
        if(dataB.branch)begin
            pcselected = dataB.pc_branch;
        end else if(dataPB.branch)begin
            pcselected = dataPB.pc_branch;
        end else begin
            pcselected = pcplus4;
        end
    end
    
    

endmodule

`endif