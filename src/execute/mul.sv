`ifndef __MUL_SV
`define __MUL_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module mul
    import common::*;
    import pipes::*;(
        input logic clk, reset,
        input word_t a, b,
        input control_t ctl,
        output word_t c,
        output u1 busy, dur
    );

    u1 done, sign_32, sign_64, divide_by_zero;
    u32 unsigned_a_32, unsigned_b_32, signed_a_32, signed_b_32;
    u64 unsigned_a_64, unsigned_b_64, signed_a_64, signed_b_64;
    u128 tmp_a, tmp_b, tmp_c1, tmp_c, tmp_c2;

    u7 state;

    assign busy = ctl.mul_div && !done;
    assign divide_by_zero = (ctl.alufunc == ALU_DIV || ctl.alufunc == ALU_REM) && tmp_b == 0;

    assign sign_32 = a[31] ^ b[31]; // 0: if positive, 1: if negative
    assign sign_64 = a[63] ^ b[63]; // 0: if positive, 1: if negative

    assign unsigned_a_32 = a[31:0];
    assign unsigned_b_32 = b[31:0];
    assign signed_a_32 = a[31] ? ~a[31:0] + 1 : a[31:0];
    assign signed_b_32 = b[31] ? ~b[31:0] + 1 : b[31:0];

    assign unsigned_a_64 = a[63:0];
    assign unsigned_b_64 = b[63:0];
    assign signed_a_64 = a[63] ? ~a[63:0] + 1 : a[63:0];
    assign signed_b_64 = b[63] ? ~b[63:0] + 1 : b[63:0];

    always_comb begin
        if(ctl.immextend) begin
            if(ctl.unsign) begin
                tmp_a = {96'b0, unsigned_a_32};
                tmp_b = {96'b0, unsigned_b_32};
            end else  begin
                tmp_a = {96'b0, signed_a_32};
                tmp_b = {96'b0, signed_b_32};
            end
        end else begin
            if(ctl.unsign) begin
                tmp_a = {64'b0, unsigned_a_64};
                tmp_b = {64'b0, unsigned_b_64};
            end else  begin
                tmp_a = {64'b0, signed_a_64};
                tmp_b = {64'b0, signed_b_64};
            end
        end
    end

    always_ff @(posedge clk) begin
        if(ctl.mul_div && !done) begin
            dur <= 1;
            if(ctl.alufunc == ALU_MUL) begin
                tmp_c <= tmp_c + ((tmp_a * tmp_b[state]) << state) + ((tmp_a * tmp_b[state + 1]) << (state + 1)) + ((tmp_a * tmp_b[state + 2]) << (state + 2)) + ((tmp_a * tmp_b[state + 3]) << (state + 3));

                if((state == 60 && !ctl.immextend) || (state == 28 && ctl.immextend)) begin
                    state <= 0;
                    done <= 1;
                end else begin
                    state <= state + 4;
                    done <= 0;
                end

            end else if(ctl.alufunc == ALU_DIV) begin
                if(ctl.immextend) begin
                    if(state == 0) begin
                        if(tmp_a >= tmp_b << (31 - state)) begin
                            tmp_c1 <= tmp_a - (tmp_b << (31 - state));
                            tmp_c <= 1 << (31 - state);
                        end else begin
                            tmp_c1 <= tmp_a;
                            tmp_c <= 0;
                        end
                    end else begin
                        if(tmp_c1 >= tmp_b << (31 - state)) begin
                            tmp_c1 <= tmp_c1 - (tmp_b << (31 - state));
                            tmp_c <= tmp_c | (1 << (31 - state));
                        end
                    end
                    

                    if(state == 31) begin
                        state <= 0;
                        done <= 1;
                    end else begin
                        state <= state + 1;
                        done <= 0;
                    end
                end else begin
                    if(state == 0) begin
                        if(tmp_a >= tmp_b << (63 - state)) begin
                            tmp_c1 <= tmp_a - (tmp_b << (63 - state));
                            tmp_c <= 1 << (63 - state);
                        end else begin
                            tmp_c1 <= tmp_a;
                            tmp_c <= 0;
                        end
                    end else begin
                        if(tmp_c1 >= tmp_b << (63 - state)) begin
                            tmp_c1 <= tmp_c1 - (tmp_b << (63 - state));
                            tmp_c <= tmp_c | (1 << (63 - state));
                        end
                    end

                    if(state == 63) begin
                        state <= 0;
                        done <= 1;
                    end else begin
                        state <= state + 1;
                        done <= 0;
                    end
          
                end
            end else if(ctl.alufunc == ALU_REM) begin
                if(ctl.immextend) begin
                    if(state == 0) begin
                        if(tmp_a >= tmp_b << (31 - state)) begin
                            tmp_c1 <= tmp_a - (tmp_b << (31 - state));
                            tmp_c <= tmp_a - (tmp_b << (31 - state));
                        end else begin
                            tmp_c1 <= tmp_a;
                            tmp_c <= tmp_a;
                        end
                    end else begin
                        if(tmp_c1 >= tmp_b << (31 - state)) begin
                            tmp_c1 <= tmp_c1 - (tmp_b << (31 - state));
                            tmp_c <= tmp_c1 - (tmp_b << (31 - state));
                        end
                    end

                    if(state == 31) begin
                        state <= 0;
                        done <= 1;
                    end else begin
                        state <= state + 1;
                        done <= 0;
                    end
                end else begin
                    if(state == 0) begin
                        if(tmp_a >= tmp_b << (63 - state)) begin
                            tmp_c1 <= tmp_a - (tmp_b << (63 - state));
                            tmp_c <= tmp_a - (tmp_b << (63 - state));
                        end else begin
                            tmp_c1 <= tmp_a;
                            tmp_c <= tmp_a;
                        end
                    end else begin
                        if(tmp_c1 >= tmp_b << (63 - state)) begin
                            tmp_c1 <= tmp_c1 - (tmp_b << (63 - state));
                            tmp_c <= tmp_c1 - (tmp_b << (63 - state));
                        end
                    end

                    if(state == 63) begin
                        state <= 0;
                        done <= 1;  
                    end else begin
                        state <= state + 1;
                        done <= 0;
                    end
                end
            end
        end else begin
            dur <= 0;
            state <= 0;
            tmp_c <= 0;
            done <= 0;
        end

    end

    always_comb begin
        if(divide_by_zero) begin
            tmp_c2 = '0;
            if(ctl.alufunc == ALU_DIV) c = ~0;
            else c = a;
            
        end else begin
            if(ctl.unsign) begin
                tmp_c2 = '0;
                c = tmp_c[63:0];
            end else begin
                tmp_c2 = ~tmp_c + 1;
                if(ctl.immextend) begin 
                    if(ctl.alufunc == ALU_REM && !a[31]) c = {{32{tmp_c[31]}}, tmp_c[31:0]}; 
                    else if(ctl.alufunc == ALU_REM && a[31]) c = {{32{tmp_c2[31]}}, tmp_c2[31:0]};
                    else c = sign_32 ? {{32{tmp_c2[31]}}, tmp_c2[31:0]}: {{32{tmp_c[31]}}, tmp_c[31:0]}; 
                end else begin
                    if(ctl.alufunc == ALU_REM && !a[63]) c = tmp_c[63:0]; 
                    else if(ctl.alufunc == ALU_REM && a[63]) c = tmp_c2[63:0];
                    else c = sign_64 ? tmp_c2[63:0] : tmp_c[63:0];
                end
            end
        end
    end

endmodule

`endif