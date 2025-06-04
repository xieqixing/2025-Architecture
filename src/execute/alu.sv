`ifndef __ALU_SV
`define __ALU_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module alu
    import common::*;
    import pipes::*;(

        input u64 a, b,
        input alufunc_t alufunc,
        output u64 c,
        output CCR_t ccr
    );
    
    always_comb begin
        c = '0;

        unique case(alufunc)
            ALU_ADD: c = a + b;
            ALU_SUB: c = a - b;
            ALU_AND: c = a & b;
            ALU_OR: c = a | b;
            ALU_XOR: c = a ^ b;
            ALU_SLL: c = a << b[5:0];
            ALU_SRL: c = a >> b[5:0];
            ALU_SRA: c = $signed(a) >>> b[5:0];
            ALU_SLLW: c = {32'b0, a[31:0]} << b[4:0];
            ALU_SRLW: c = {32'b0, a[31:0]} >> b[4:0];
            ALU_SRAW: c =  {{32{a[31]}}, a[31:0]} >> b[4:0];
            ALU_AND_NEG: c = ~a & b;
            default: begin

            end
        endcase
    end

    assign ccr.z = (c == 0);
    assign ccr.n = c[63];
    assign ccr.c = a > b;   // unsigned minus
    assign ccr.v = (a[63] & ~b[63] & ~c[63]) | (~a[63] & b[63] & c[63]);

endmodule

`endif