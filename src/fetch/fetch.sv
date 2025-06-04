`ifndef __FETCH_SV
`define __FETCH_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "include/csr.sv"
`else

`endif

module fetch
    import common::*;
    import pipes::*;
    import csr_pkg::*;(

        input logic clk, reset,
        input u64 pc,
        input u2 mode,
        output ibus_req_t ireq,
        input ibus_resp_t iresp,
        input satp_t satp,
        output fetch_data_t dataF,
        output u1 finish_pc,
        output u1 pc_change
        
    );
    
    // state machine
    u3 state;
    
    always_ff @(posedge clk) begin
        if(reset) begin
            state <= 3'b100;
            pc_change <= 1'b0;
        end

        case(state)
            3'b000: begin    
                pc_change <= 1'b0;
                if(mode == 2'b00 && satp[63:60] == 4'b1000) begin
                    state <= 3'b001;
                end else begin
                    state <= 3'b100;
                end
            end

            3'b001: begin
                pc_change <= 1'b0;
                if(iresp.data_ok) begin
                    state <= 3'b010;
                end else begin
                    if(mode == 2'b11)begin
                        state <= 3'b100;
                    end else begin
                        state <= 3'b001;
                    end
                end
            end
            
            3'b010: begin
                if(iresp.data_ok) begin
                    if(mode == 2'b11)begin
                        state <= 3'b000;
                        pc_change <= 1'b1;
                    end else begin
                        state <= 3'b011;
                        pc_change <= 1'b0;
                    end
                end else begin
                    state <= 3'b010;
                    pc_change <= 1'b0;
                end
            end

            3'b011: begin
                if(iresp.data_ok) begin
                    if(mode == 2'b11)begin
                        state <= 3'b000;
                        pc_change <= 1'b1;
                    end else begin
                        state <= 3'b101;
                        pc_change <= 1'b0;
                    end
                end else begin
                    state <= 3'b011;
                    pc_change <= 1'b0;
                end
            end

            3'b100: begin
                pc_change <= 1'b0;
                if(iresp.data_ok) begin
                    state <= 3'b000;
                end else begin
                    state <= 3'b100;
                end
            end

            3'b101: begin
                pc_change <= 1'b0;
                if(iresp.data_ok) begin
                    state <= 3'b000;
                end else begin
                    state <= 3'b101;
                end
            end

            default: begin
                pc_change <= 1'b0;
                state <= 3'b000;
            end
        endcase
    end

    u1 start;

    always_comb begin
        finish_pc = 1'b1;
        start = 1'b0;

        if(state == 3'b000) begin
            ireq.addr = 0;
            finish_pc = 1'b0;
            ireq.valid = 1'b0;
        end else if(state == 3'b001) begin
            ireq.addr = {8'b0, satp.ppn, 12'b0} + {52'b0, pc[38:30],3'b0};
            finish_pc = 1'b0;
            ireq.valid = 1'b1;
            start = ~iresp.data_ok;
        end else if(state == 3'b010) begin
            ireq.addr = {8'b0, MMU_data[53:10], 12'b0} + {52'b0, pc[29:21],3'b0};
            finish_pc = 1'b0;
            ireq.valid = 1'b1;
            start = ~iresp.data_ok;
        end else if(state == 3'b011) begin
            ireq.addr = {8'b0, MMU_data[53:10], 12'b0} + {52'b0, pc[20:12],3'b0};
            finish_pc = 1'b0;
            ireq.valid = 1'b1;
            start = ~iresp.data_ok;
        end else if(state == 3'b100)begin
            ireq.addr = pc;
            finish_pc = iresp.data_ok;
            ireq.valid = 1'b1;
            start = ~iresp.data_ok;
        end else if(state == 3'b101) begin
            ireq.addr = {8'b0, MMU_data[53:10], pc[11:0]};
            finish_pc = iresp.data_ok;
            ireq.valid = 1'b1;
            start = ~iresp.data_ok;
        end else begin
            ireq.addr = 0;
            finish_pc = 1'b1;
            ireq.valid = 1'b0;
        end
    end

    word_t MMU_data, MMU_data_nxt;
    assign MMU_data_nxt = iresp.data;

    always_ff @(posedge clk) begin
        if(reset) begin
            MMU_data <= 0;
        end else if(start) begin
            MMU_data <= MMU_data;
        end else begin
            MMU_data <= MMU_data_nxt;
        end
    end
    //
    

	u32 raw_instr;
	assign raw_instr = ireq.addr[2] ? iresp.data[63:32] : iresp.data[31:0];
    //

    assign dataF.raw_instr = raw_instr;
    assign dataF.pc = pc;

endmodule

`endif