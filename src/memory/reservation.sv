`ifndef __RESERVATION_SV
`define __RESERVATION_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/csr.sv"
`include "include/pipes.sv"
`else

`endif

module reservation
    import common::*;
    import pipes::*;
    import csr_pkg::*;(
        input logic clk, reset,
        input word_t write_data, write_address,
        input control_t ctl,
        output u1 reservation_set
    );

    word_t reservation_address[1:0], reservation_address_nxt[1:0];
    u1 valid[1:0], valid_nxt[1:0];

    always_comb begin
        reservation_set = 1'b0;
        for(int i = 0; i < 2; i++) begin
            if(ctl.lrw && valid[i] == 1'b0) begin
                reservation_address_nxt[i[0]] = write_data;
                valid_nxt[i] = 1'b1;
            end else if(ctl.sc && valid[i[0]] == 1'b1 && reservation_address[i[0]] == write_address) begin
                valid_nxt[0] = 1'b0;
                valid_nxt[1] = 1'b0;
                reservation_address_nxt[i[0]] = 64'b0;
                reservation_set = 1'b1;
            end else begin
                reservation_address_nxt[i[0]] = reservation_address[i[0]];
                valid_nxt[i[0]] = valid[i[0]];
            end
        end
    end

    always_ff @(posedge clk) begin
        if(reset) begin
            reservation_address[0] <= 64'b0;
            reservation_address[1] <= 64'b0;
            valid[0] <= 1'b0;
            valid[1] <= 1'b0;
        end else begin
            reservation_address[0] <= reservation_address_nxt[0];
            reservation_address[1] <= reservation_address_nxt[1];
            valid[0] <= valid_nxt[0];
            valid[1] <= valid_nxt[1];
        end
    end



endmodule



`endif 