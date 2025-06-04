`ifndef __REGFILE_SV
`define __REGFILE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module regfile
    import common::*;
    import pipes::*;(

        input  logic       clk, reset,
        input  creg_addr_t ra1, ra2, wa,
        input  u1          wvalid,
        input  u64         wd,
        output u64         rd1, rd2
    );

    u64 rf[31:0];
    u64 rf_nxt[31:0];

    always_comb begin
        for(int i = 1; i < 32; i++) begin
            if(wvalid && (i[4:0] == wa)) begin
                rf_nxt[i[4:0]] = wd;
            end else begin
                rf_nxt[i[4:0]] = rf[i[4:0]];
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            for(int i = 0; i < 32; i++) begin
                rf[i[4:0]] <= 64'b0;
            end
        end else begin
            for(int i = 0; i < 32; i++) begin
                rf[i[4:0]] <= rf_nxt[i[4:0]];
            end
        end
    end

    assign rd1 = (ra1 != 0) ? rf_nxt[ra1] : 0;
    assign rd2 = (ra2 != 0) ? rf_nxt[ra2] : 0;  

endmodule

`endif