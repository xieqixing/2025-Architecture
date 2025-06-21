`ifndef __MEMORY_SV
`define __MEMORY_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "include/csr.sv"
`include "src/memory/reservation.sv"
`else

`endif

module memory
    import common::*;
    import pipes::*;
    import csr_pkg::*;(
        input logic clk, reset,
        input execute_data_t dataE, dataE_nxt,
        input satp_t satp,
        output dbus_req_t dreq,
        input dbus_resp_t dresp,
        output memory_data_t dataM,
        output u1 finish
    );

    //assign dataM.aluout = dataE.aluout;
	assign dataM.ctl = dataE.ctl;
	assign dataM.dst = dataE.dst;
	assign dataM.pc_instr = dataE.pc_instr;


    // write memory
    word_t write_data, aluout;
    u8 strobe;
    u1 block, reservation_set;

    assign aluout = dataE.ctl.amo ? dataE.srca : dataE.aluout;
    assign write_data = dataE.memwrite_data;
    always_comb begin
        if(dataE.ctl.memwrite) begin
            case(dataE.ctl.size) 
                MSIZE1: strobe = 8'b1;
                MSIZE2: strobe = 8'b11;
                MSIZE4: strobe = 8'b1111;
                MSIZE8: strobe = 8'b11111111;
                default: strobe = 8'b0;
            endcase
            
        end else begin
            strobe = 8'b0;
        end
    end

    reservation reservation(
        .clk(clk),
        .reset(reset),
        .write_data(write_data),
        .write_address(aluout),
        .ctl(dataE.ctl),
        .reservation_set(reservation_set)
    );

    // state machine
    word_t raw_memdata, MMU_data, MMU_data_nxt;
    u3 state;

    always_ff @( posedge clk) begin 
        if(reset) begin
            state <= 3'b000;
        end

        case(state)
            3'b000: begin
                if(dataE_nxt.ctl.memread || dataE_nxt.ctl.memwrite) begin
                    if(dataE_nxt.privilegeMode == 2'b00  && satp[63:60] == 4'b1000) begin
                        state <= 3'b001;
                    end else begin
                        if(dataE.ctl.sc && reservation_set) begin
                            state <= 3'b000;
                        end else begin
                            state <= 3'b100;
                        end
                    end
                end else begin
                    state <= 3'b000;
                end
            end

            3'b001: begin
                if(dresp.data_ok) begin
                    state <= 3'b010;
                end else begin
                    state <= 3'b001;
                end
            end

            3'b010: begin
                if(dresp.data_ok) begin
                    state <= 3'b011;
                end else begin
                    state <= 3'b010;
                end
            end

            3'b011: begin
                if(dresp.data_ok) begin
                    state <= 3'b100;
                end else begin
                    state <= 3'b011;
                end
            end

            3'b100: begin
                if(dresp.data_ok) begin
                    if(dataE.ctl.lrw || dataE.ctl.sc) begin
                        state <= 3'b000;
                    end else if(dataE.ctl.amo == 1'b1) begin
                        state <= 3'b101;
                    end else begin
                        state <= 3'b000;
                    end
                    
                end else begin
                    state <= 3'b100;
                end
            end

            3'b101: begin
                state <= 3'b110; 
            end

            3'b110: begin
                if(dresp.data_ok) begin
                    state <= 3'b000;
                end else begin
                    state <= 3'b110;
                end
            end

            default: begin
                state <= 3'b000;

            end

        endcase
    end

    u1 start;

    always_comb begin 
        case(state)
            3'b000: begin
                dreq.valid = 1'b0;
                dreq.addr = 0;
                dreq.size = MSIZE8;
                dreq.data = 0;
                dreq.strobe = 0;
                finish = 1'b1;
                start = 1'b0;
                block = 1'b0;
                
            end

            3'b001: begin
                dreq.valid = 1'b1;
                dreq.addr = {8'b0, dataE.satp.ppn, 12'b0} + {52'b0, dataE.aluout[38:30],3'b0};
                dreq.size = MSIZE8;
                dreq.data = 0;
                dreq.strobe = 8'b0;
                finish = 1'b0;
                start = ~dresp.data_ok;
                block = 1'b0;
            end

            3'b010: begin
                dreq.valid = 1'b1;
                dreq.addr = {8'b0, MMU_data[53:10], 12'b0} + {52'b0, dataE.aluout[29:21],3'b0};
                dreq.size = MSIZE8;
                dreq.data = 0;
                dreq.strobe = 8'b0;
                finish = 1'b0;
                start = ~dresp.data_ok;
                block = 1'b0;
            end

            3'b011: begin
                dreq.valid = 1'b1;
                dreq.addr = {8'b0, MMU_data[53:10], 12'b0} + {52'b0, dataE.aluout[20:12],3'b0};
                dreq.size = MSIZE8;
                dreq.data = 0;
                dreq.strobe = 8'b0;
                finish = 1'b0;
                start = ~dresp.data_ok;
                block = 1'b0;
            end

            3'b100: begin
                if(dataE_nxt.privilegeMode == 2'b11)begin
                    dreq.valid = 1'b1;
                    dreq.addr = aluout;
                    dreq.size = dataE.ctl.size;
                    dreq.data = write_data << (aluout[2:0] * 8);
                    dreq.strobe = (dataE.ctl.amo && !dataE.ctl.sc) ? 8'b0 : strobe << aluout[2:0];
                    finish = (dataE.ctl.amo && !dataE.ctl.lrw && !dataE.ctl.sc) ? 1'b0 : dresp.data_ok;
                    start = ~dresp.data_ok;
                    block = 1'b0;
                end else begin
                    
                    dreq.valid = 1'b1;
                    dreq.addr = {8'b0, MMU_data[53:10], dataE.aluout[11:0]};
                    dreq.size = dataE.ctl.size;
                    dreq.data = write_data << (dataE.aluout[2:0] * 8);
                    dreq.strobe = strobe << dataE.aluout[2:0];
                    finish = dresp.data_ok;
                    start = ~dresp.data_ok;
                    block = 1'b0;
                end
            end

            3'b101: begin
                dreq.valid = 1'b0;
                dreq.addr = 0;
                dreq.size = MSIZE8;
                dreq.data = 0;
                dreq.strobe = 0;
                finish = 1'b0;
                start = 1'b0;
                block = 1'b1;
            end

            3'b110: begin
                dreq.valid = 1'b1;
                dreq.addr = aluout;
                dreq.size = dataE.ctl.size;
                dreq.data = amo_result << (aluout[2:0] * 8);
                dreq.strobe = strobe << aluout[2:0];
                finish = dresp.data_ok;
                start = ~dresp.data_ok;
                block = 1'b1;
            end


            default: begin
                dreq.valid = 1'b0;
                dreq.addr = 0;
                dreq.size = MSIZE8;
                dreq.data = 0;
                dreq.strobe = 0;
                finish = 1'b1;
                start = 1'b0;
                block = 1'b0;
            end     
        endcase    
    end

    // assign dreq.valid = dataE.ctl.memread || dataE.ctl.memwrite;	// 需要写和读的时候发送请求
    // assign dreq.addr = dataE.aluout;	// 地址是由ALU计算出来的
    // assign dreq.size = dataE.ctl.size;	//根据指令指定操作字节数
    // assign dreq.data = write_data << (dataE.aluout[2:0] * 8);	// 对齐数据
    // assign dreq.strobe = strobe << dataE.aluout[2:0];	// 确认哪些字节是有效的

    word_t memdata, processed_data, address;
    assign address = dreq.addr;
    //assign raw_memdata = dresp.data;
    assign MMU_data_nxt = dresp.data;

    always_ff @(posedge clk) begin
        if(reset) begin
            MMU_data <= 0;
        end else if(start)begin
            MMU_data <= MMU_data;
        end else begin
            MMU_data <= MMU_data_nxt;
        end
    end
    //u1 extend;
    //assign extend = dataE.ctl.memread && dataE.ctl.memextend;

    always_comb begin
       if(reset) begin
            raw_memdata = 0;
       end else if(block == 1'b0) begin
            raw_memdata = dresp.data;
       end

        memdata = raw_memdata >> (dataE.aluout[2:0] * 8);

        if(dataE.ctl.memread)begin

            case(dataE.ctl.size)
                MSIZE1: begin
                if(dataE.ctl.memextend) processed_data = {{56{memdata[7]}},memdata[7:0]};
                else processed_data = {56'b0,memdata[7:0]};
                end

                MSIZE2: begin
                if(dataE.ctl.memextend) processed_data = {{48{memdata[15]}},memdata[15:0]};
                else processed_data = {48'b0,memdata[15:0]};
                end

                MSIZE4: begin
                if(dataE.ctl.memextend) processed_data = {{32{memdata[31]}},memdata[31:0]};
                else processed_data = {32'b0,memdata[31:0]};
                end
                
                default: processed_data = memdata;
            endcase

        end else begin
            processed_data = memdata;
        end
    end

    always_comb begin
        if(dataE.ctl.memread)begin
            case(dataE.ctl.size)
                MSIZE1: begin
                    dataM.load_misaligned = 1'b0;
                end

                MSIZE2: begin
                    if(address[0] != 1'b0) dataM.load_misaligned = 1'b1;
                    else dataM.load_misaligned = 1'b0;
                end

                MSIZE4: begin
                    if(address[1:0] != 2'b00) dataM.load_misaligned = 1'b1;
                    else dataM.load_misaligned = 1'b0;
                end
                
                MSIZE8: begin
                    if(address[2:0] != 3'b000) dataM.load_misaligned = 1'b1;
                    else dataM.load_misaligned = 1'b0;
                end  

                default: dataM.load_misaligned = 1'b0;
            endcase
        end else dataM.load_misaligned = 1'b0;
    end

    always_comb begin
        if(dataE.ctl.memwrite)begin
            case(dataE.ctl.size)
                MSIZE1: begin
                    dataM.store_misaligned = 1'b0;
                end

                MSIZE2: begin
                    if(address[0] != 1'b0) dataM.store_misaligned = 1'b1;
                    else dataM.store_misaligned = 1'b0;
                end

                MSIZE4: begin
                    if(address[1:0] != 2'b00) dataM.store_misaligned = 1'b1;
                    else dataM.store_misaligned = 1'b0;
                end
                
                MSIZE8: begin
                    if(address[2:0] != 3'b000) dataM.store_misaligned = 1'b1;
                    else dataM.store_misaligned = 1'b0;
                end  

                default: dataM.store_misaligned = 1'b0;
            endcase
        end else dataM.store_misaligned = 1'b0;
    end

    word_t amo_result;
    always_ff @(posedge clk) begin
        case(dataE.ctl.alufunc)
            ALU_ADD: amo_result <= processed_data + write_data;
            ALU_OR: amo_result <= processed_data | write_data;
            ALU_AND: amo_result <= processed_data & write_data;
            ALU_XOR: amo_result <= processed_data ^ write_data;
            ALU_SWAP: amo_result <= write_data;
            ALU_MIN: amo_result <= ($signed(processed_data) < $signed(write_data)) ? processed_data : write_data;
            ALU_MAX: amo_result <= ($signed(processed_data) > $signed(write_data)) ? processed_data : write_data;
            ALU_MINU: amo_result <= (processed_data < write_data) ? processed_data : write_data;
            ALU_MAXU: amo_result <= (processed_data > write_data) ? processed_data : write_data;
            default: amo_result <= 0;
        endcase
    end

    assign dataM.memout = dataE.ctl.sc ? (reservation_set ? {63'b0, 1'b1} : 64'b0) :
                          dataE.ctl.memread ? processed_data : dataE.aluout;
    assign dataM.memaddr = dataE.aluout;
    assign dataM.csrout = dataE.csrout;
    assign dataM.csr_addr = dataE.csr_addr;


endmodule
`endif