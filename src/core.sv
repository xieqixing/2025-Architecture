`ifndef __CORE_SV
`define __CORE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "include/csr.sv"
`include "src/fetch/fetch.sv"
`include "src/fetch/pcselect.sv"
`include "src/decode/decode.sv"
`include "src/regfile/regfile.sv"
`include "src/regfile/csr.sv"
`include "src/execute/execute.sv"
`include "src/memory/memory.sv"
`include "src/execute/forward.sv"

`else

`endif

module core import common::*;
			import csr_pkg::*;
			import pipes::*;(
	input  logic       clk, reset,
	output ibus_req_t  ireq,
	input  ibus_resp_t iresp,
	output dbus_req_t  dreq,
	input  dbus_resp_t dresp,
	input  logic       trint, swint, exint
);
	/* TODO: Add your CPU-Core here. */

	// update PC
	u64 pc_nxt, pc;
	fetch_data_t dataF, dataF_nxt;
	decode_data_t dataD, dataD_nxt;
	execute_data_t dataE, dataE_nxt;
	branch_data_t dataB, dataB_nxt, dataPB, dataPB_nxt;
	pre_branch_data_t pre_branch, pre_branch_nxt;
	memory_data_t dataM, dataM_nxt;
	csr_flush_data_t dataCF, dataCF_nxt;
	creg_addr_t ra1, ra2;
	csr_addr_t ra3;
	word_t rd1, rd2, rd3;
	u64 mepc, mtvec;
	u64 current_pc;

	u1 conflict, busy;
	u1 pc_change;
	u2 mode;
	u2 false_branch;
	u1 finish_pc;
	u1 stallpc;
	u1 memeory_stall, finish;
	u1 interrupt;
	u1 amo;
	
	assign stallpc = ~finish_pc;
	assign current_pc = dataM.pc_instr.pc != 0 ? dataM.pc_instr.pc : 
		                dataE.pc_instr.pc != 0 ? dataE.pc_instr.pc :
						dataD.pc_instr.pc != 0 ? dataD.pc_instr.pc :
						dataF.pc != 0 ? dataF.pc : 
						dataCF.branch ? dataCF.pcplus4 : pc;

	pcselect pcselect(
		.dataB(dataB),
		.dataPB(dataPB),
		.pcplus4(pc + 4),
		.pcselected(pc_nxt)
	);



	always_ff @(posedge clk) begin
		if (reset) begin
			pc <= 64'h8000_0000;
		end else if (stallpc || conflict || memeory_stall || busy) begin
			if(dataCF.branch && pc_change == 1'b1) begin
				pc <= dataCF.pcplus4;
			end else begin
				pc <= pc;
			end
		end else if(dataCF.branch)begin
			pc <= dataCF.pcplus4;
		end else begin
			pc <= pc_nxt;
		end
	end


	//fetch

	fetch fetch(
		.clk, .reset,
		.ireq(ireq),
		.iresp(iresp),
		.mode(mode),
		.satp(dataD_nxt.satp),
		.pc(pc),
		.dataF(dataF_nxt),
		.finish_pc(finish_pc),
		.pc_change(pc_change)
	);

	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			mode <= 2'b11;
		end else begin
			mode <= dataD_nxt.privilegeMode;
		end
	end


	always_ff @(posedge clk) begin
		if (conflict || memeory_stall || busy) begin
			dataF <= dataF;
		end else if(reset || stallpc || dataB.branch || dataCF.branch || dataPB.branch) begin
			dataF <= 0;
		end else begin
			dataF <= dataF_nxt;
		end
	end


	//decode

	decode decode(
		.clk, .reset,
		.dataF(dataF),
		.dataE(dataE),
		.dataM(dataM),
		.dataD(dataD_nxt),
		.pre_branch(pre_branch_nxt),
		.dataPB(dataPB_nxt),
		.false_branch((memeory_stall || busy) ? 2'b10 : false_branch),
		.ra1, .ra2, .ra3, .rd1, .rd2, .rd3
	);

	assign conflict = (dataE_nxt.ctl.memread) && ((ra1 != 0 && ra1 == dataE_nxt.dst) || (ra2 != 0 && ra2 == dataE_nxt.dst)) ||
					  ((dataD_nxt.ctl.op == J && dataD_nxt.ctl.alusrc == 1'b1) && (ra1 != 0 && ra1 == dataE_nxt.dst));
					  

	regfile regfile(
		.clk, .reset,
		.ra1, .ra2, .rd1, .rd2,
		.wvalid(dataM.ctl.regwrite),
		.wa(dataM.dst),
		.wd(dataM.memout)
	);

	csr csr(
		.clk, .reset,
		.ra(ra3),
		.rd(rd3),
		.mode(dataD_nxt.privilegeMode),
		.mepc(mepc),
		.mtvec(mtvec),
		.satp(dataD_nxt.satp),
		.dataM(dataM),
		.trint(trint),
		.swint(swint),
		.exint(exint),
		.current_pc(current_pc),
		.interrupt(interrupt),
		.amo(amo)
	);

	always_ff @(posedge clk) begin
		if(memeory_stall || busy ) begin
			dataD <= dataD;
			pre_branch <= pre_branch;
		end else if(reset || conflict || dataB.branch || dataM_nxt.ctl.csrwrite || dataCF.branch) begin
			dataD <= '0;
			pre_branch <= '0;
		end else begin
			dataD <= dataD_nxt;
			pre_branch <= pre_branch_nxt;
		end
	end

	always_ff @(posedge clk) begin
		if(reset) begin
			dataPB <= '0;
		end else if(dataPB.branch == 0 || stallpc == 0)begin
			dataPB <= dataPB_nxt;
		end
	end


	//execute

	execute execute(
		.clk, .reset,
		.dataD(dataD),
		.dataE(dataE),
		.dataM(dataM),
		.pre_branch(pre_branch),
		.dataE_nxt(dataE_nxt),
		.dataB(dataB_nxt),
		.busy(busy),
		.false_branch(false_branch)
	);

	always_ff @(posedge clk) begin
		if(reset) begin
			dataB <= '0;
		end else if(dataB.branch == 0 || stallpc == 0)begin
			dataB <= dataB_nxt;
		end
	end

	always_ff @(posedge clk) begin
		if(reset || dataM_nxt.ctl.csrwrite || dataCF.branch) begin
			dataE <= '0;
		end else if(memeory_stall) begin
			dataE <= dataE;
		end else if(busy)begin
			dataE <= '0;
		end else begin
		dataE <= dataE_nxt;
		end
	end


	//memory

	memory memory(
		.clk, .reset,
		.dataE(dataE),
		.dreq(dreq),
		.dresp(dresp),
		.dataM(dataM_nxt),
		.satp(dataD_nxt.satp),
		.dataE_nxt(dataE_nxt),
		.finish(finish)
	);

	assign memeory_stall = ~finish;
	

	always_ff @(posedge clk) begin
		if(reset || memeory_stall) begin
			dataM <= '0;
		end else begin
		dataM <= dataM_nxt;
		end
	end

	assign amo = dataM.ctl.amo && dataE.ctl.amo;
	assign dataCF_nxt.branch = !amo && (interrupt || dataM.store_misaligned || dataM.load_misaligned || dataM.ctl.csrwrite || dataM.ctl.mret || dataM.ctl.ecall || (dataM.pc_instr.pc != 0 && dataM.ctl.address_error) || dataM.ctl.address_not_aligned);
	always_comb begin
		if(interrupt || dataM.store_misaligned || dataM.load_misaligned || dataM.ctl.ecall || dataM.ctl.address_error || dataM.ctl.address_not_aligned)begin
			dataCF_nxt.pcplus4 = mtvec;
		end else if(dataM.ctl.mret)begin
			dataCF_nxt.pcplus4 = mepc;
		end else begin
			dataCF_nxt.pcplus4 = dataM.pc_instr.pc + 4;
		end
	end


	always_ff @(posedge clk) begin
		if(reset) begin
			dataCF <= '0;
		end else if(dataCF.branch == 0 || (stallpc == 0 && memeory_stall == 0) || interrupt == 1'b1) begin
			dataCF <= dataCF_nxt;
		end
	end


	// 分支预测
	real total_branch, succ_branch, total_branch1,succ_branch1;
    logic[30:0] print_cnt;
    always_ff @(posedge clk)begin
        if(print_cnt[24] == 1)begin // 每隔固定的时间输出结果
            $display("total_branch:%.2f ", total_branch);
			$display("succ_branch:%.2f ", succ_branch);
			$display("branch success:%.2f%%", (succ_branch/total_branch)*100);
			print_cnt <= '0;	
        end else begin
            print_cnt <= print_cnt + 1;
        end

		if(dataD.ctl.branchorjump && ~(memeory_stall || busy)) begin // stall 的时候不要重复计数指令
			total_branch <= total_branch + 1;
            if(!dataB_nxt.branch)begin // 分支指令方向预测正确
				succ_branch <= succ_branch + 1;              
			end
		end

		// if(dataM.ctl.branchorjump) begin
		// 	total_branch1 <= total_branch1 + 1;
		// end

		// if(~(memeory_stall || busy) && false_branch == 2'b11) begin
		// 	succ_branch1 <= succ_branch1 + 1; // 分支指令方向预测正确
		// end

	end



`ifdef VERILATOR
	DifftestInstrCommit DifftestInstrCommit(
		.clock              (clk),
		.coreid             (csr.dataC_nxt.mhartid[7:0]),
		.index              (0),
		.valid              (dataM.pc_instr != 0),
		.pc                 (dataM.pc_instr.pc),
		.instr              (dataM.pc_instr.raw_instr),
		.skip               (((dataM.ctl.memwrite | dataM.ctl.memread) & dataM.memaddr[31] == 0)),
		.isRVC              (0),
		.scFailed           (0),
		.wen                (dataM.ctl.regwrite),
		.wdest              ({3'b0, dataM.dst}),
		.wdata              (dataM.memout)
	);

	DifftestArchIntRegState DifftestArchIntRegState (
		.clock              (clk),
		.coreid             (csr.dataC_nxt.mhartid[7:0]),
		.gpr_0              (regfile.rf_nxt[0]),
		.gpr_1              (regfile.rf_nxt[1]),
		.gpr_2              (regfile.rf_nxt[2]),
		.gpr_3              (regfile.rf_nxt[3]),	
		.gpr_4              (regfile.rf_nxt[4]),
		.gpr_5              (regfile.rf_nxt[5]),
		.gpr_6              (regfile.rf_nxt[6]),
		.gpr_7              (regfile.rf_nxt[7]),
		.gpr_8              (regfile.rf_nxt[8]),
		.gpr_9              (regfile.rf_nxt[9]),
		.gpr_10             (regfile.rf_nxt[10]),
		.gpr_11             (regfile.rf_nxt[11]),
		.gpr_12             (regfile.rf_nxt[12]),
		.gpr_13             (regfile.rf_nxt[13]),
		.gpr_14             (regfile.rf_nxt[14]),
		.gpr_15             (regfile.rf_nxt[15]),	
		.gpr_16             (regfile.rf_nxt[16]),
		.gpr_17             (regfile.rf_nxt[17]),
		.gpr_18             (regfile.rf_nxt[18]),
		.gpr_19             (regfile.rf_nxt[19]),
		.gpr_20             (regfile.rf_nxt[20]),
		.gpr_21             (regfile.rf_nxt[21]),
		.gpr_22             (regfile.rf_nxt[22]),
		.gpr_23             (regfile.rf_nxt[23]),
		.gpr_24             (regfile.rf_nxt[24]),
		.gpr_25             (regfile.rf_nxt[25]),
		.gpr_26             (regfile.rf_nxt[26]),
		.gpr_27             (regfile.rf_nxt[27]),
		.gpr_28             (regfile.rf_nxt[28]),
		.gpr_29             (regfile.rf_nxt[29]),
		.gpr_30             (regfile.rf_nxt[30]),
		.gpr_31             (regfile.rf_nxt[31])
	);


    DifftestTrapEvent DifftestTrapEvent(
		.clock              (clk),
		.coreid             (csr.dataC_nxt.mhartid[7:0]),
		.valid              (0),
		.code               (0),
		.pc                 (0),
		.cycleCnt           (0),
		.instrCnt           (0)
	);

	DifftestCSRState DifftestCSRState(
		.clock              (clk),
		.coreid             (csr.dataC_nxt.mhartid[7:0]),
		.priviledgeMode     (csr.privilegeMode_nxt),
		.mstatus            (csr.dataC_nxt.mstatus),
		.sstatus            (csr.dataC_nxt.mstatus & SSTATUS_MASK),
		.mepc               (csr.dataC_nxt.mepc),
		.sepc               (0),
		.mtval              (csr.dataC_nxt.mtval),
		.stval              (0),
		.mtvec              (csr.dataC_nxt.mtvec),
		.stvec              (0),
		.mcause             (csr.dataC_nxt.mcause),
		.scause             (0),
		.satp               (csr.dataC_nxt.satp),
		.mip                (csr.dataC_nxt.mip),
		.mie                (csr.dataC_nxt.mie),
		.mscratch           (csr.dataC_nxt.mscratch),
		.sscratch           (0),
		.mideleg            (0),
		.medeleg            (0)
	);
`endif

endmodule
`endif