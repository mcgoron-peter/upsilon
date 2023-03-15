m4_changequote(`⟨', `⟩')
m4_changecom(⟨/*⟩, ⟨*/⟩)
/*********************************************************/
/********************** M4 macros ************************/
/*********************************************************/
m4_define(m4_dac_wires, ⟨
	input [$1-1:0] dac_sel_$2,
	output dac_finished_$2,
	input dac_arm_$2,
	output [DAC_WID-1:0] from_dac_$2,
	input [DAC_WID-1:0] to_dac_$2,

	input wf_arm_$2,
	input wf_halt_on_finish_$2,
	output wf_finished_$2,
	input [WF_TIMER_WID-1:0] wf_time_to_wait_$2,
	input wf_refresh_start_$2,
	input [WF_RAM_WID-1:0] wf_start_addr_$2,
	output wf_refresh_finished_$2,

	output [WF_RAM_WID-1:0] wf_ram_dma_addr_$2,
	input [WF_RAM_WORD_WID-1:0] wf_ram_word_$2,
	output wf_ram_read_$2,
	input wf_ram_valid_$2
⟩)

m4_define(m4_adc_wires, ⟨
	output adc_finished_$2,
	input adc_arm_$2,
	output [$1-1:0] from_adc_$2
⟩)

m4_define(m4_dac_switch, ⟨
	wire [$1-1:0] mosi_port_$2;
	wire [$1-1:0] miso_port_$2;
	wire [$1-1:0] sck_port_$2;
	wire [$1-1:0] ss_L_port_$2;

	spi_switch #(
		.PORTS($1)
	) switch_$2 (
		.select(dac_sel_$2),
		.mosi(dac_mosi[$2]),
		.miso(dac_miso[$2]),
		.sck(dac_sck[$2]),
		.ss_L(dac_ss_L[$2]),

		.mosi_ports(mosi_port_$2),
		.miso_ports(miso_port_$2),
		.sck_ports(sck_port_$2),
		.ss_L_ports(ss_L_port_$2)
	);

	spi_master_ss #(
		.WID(DAC_WID),
		.WID_LEN(DAC_WID_SIZ),
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
		.POLARITY(DAC_POLARITY),
		.PHASE(DAC_PHASE),
		.SS_WAIT(DAC_SS_WAIT),
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
	) dac_master_$2 (
		.clk(clk),
		.mosi(mosi_port_$2[0]),
		.miso(miso_port_$2[0]),
		.sck_wire(sck_port_$2[0]),
		.ss_L(ss_L_port_$2[0]),
		.finished(dac_finished_$2),
		.arm(dac_arm_$2),
		.from_slave(from_dac_$2),
		.to_slave(to_dac_$2)
	);

	waveform #(
		.DAC_WID(DAC_WID),
		.DAC_WID_SIZ(DAC_WID_SIZ),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
		.DAC_SS_WAIT(DAC_SS_WAIT),
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
		.TIMER_WID(WF_TIMER_WID),
		.WORD_WID(WF_WORD_WID),
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
		.WORD_AMNT(WF_WORD_AMNT),
		.RAM_WID(WF_RAM_WID),
		.RAM_WORD_WID(WF_RAM_WORD_WID),
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
	) waveform_$2 (
		.clk(clk),
		.arm(wf_arm_$2),
		.halt_on_finish(wf_halt_on_finish_$2),
		.finished(wf_finished_$2),
		.time_to_wait(wf_time_to_wait_$2),
		.refresh_start(wf_refresh_start_$2),
		.start_addr(wf_start_addr_$2),
		.refresh_finished(wf_refresh_finished_$2),
		.ram_dma_addr(wf_ram_dma_addr_$2),
		.ram_word(wf_ram_word_$2),
		.ram_read(wf_ram_read_$2),
		.ram_valid(wf_ram_valid_$2),
		.mosi(mosi_port_$2[1]),
		.sck(sck_port_$2[1]),
		.ss_L(ss_L_port_$2[1])
	)
⟩)

m4_define(m4_adc_switch, ⟨
	spi_master_ss_no_write #(
		.WID($1),
		.WID_LEN(ADC_WID_SIZ),
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
		.SS_WAIT(ADC_CONV_WAIT),
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
		.POLARITY(ADC_POLARITY),
		.PHASE(ADC_PHASE)
	) adc_master_$2 (
		.clk(clk),
		.miso(adc_sdo[$2]),
		.sck_wire(adc_sck[$2]),
		.ss_L(adc_conv_L[$2]),
		.finished(adc_finished_$2),
		.arm(adc_arm_$2),
		.from_slave(from_adc_$2)
	)
⟩)

/*********************************************************/
/*********************** Verilog *************************/
/*********************************************************/

`include "control_loop_cmds.vh"
module base #(
	parameter DAC_PORTS = 2,
`define DAC_PORTS_CONTROL_LOOP (DAC_PORTS + 1)

	parameter DAC_NUM = 8,
	parameter DAC_WID = 24,
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID_SIZ = 5,
	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_CYCLE_HALF_WAIT = 10,
	parameter DAC_CYCLE_HALF_WAIT_SIZ = 4,
	parameter DAC_SS_WAIT = 5,
	parameter DAC_SS_WAIT_SIZ = 3,
	parameter WF_TIMER_WID = 32,
	parameter WF_WORD_WID = 20,
	parameter WF_WORD_AMNT_WID = 11,
	parameter [WF_WORD_AMNT_WID-1:0] WF_WORD_AMNT = 2047,
	parameter WF_RAM_WID = 32,
	parameter WF_RAM_WORD_WID = 16,
	parameter WF_RAM_WORD_INCR = 2,

	parameter ADC_PORTS = 1,
`define ADC_PORTS_CONTROL_LOOP (ADC_PORTS + 1)
	parameter ADC_NUM = 8,
	/* Three types of ADC. For now assume that their electronics
	 * are similar enough, just need different numbers for the width.
	 */
	parameter ADC_TYPE1_WID = 18,
	parameter ADC_TYPE2_WID = 16,
	parameter ADC_TYPE3_WID = 24,
	parameter ADC_WID_SIZ = 5,
	parameter ADC_CYCLE_HALF_WAIT = 5,
	parameter ADC_CYCLE_HALF_WAIT_SIZ = 3,
	parameter ADC_POLARITY = 1,
	parameter ADC_PHASE = 0,
	/* The ADC takes maximum 527 ns to capture a value.
	 * The clock ticks at 10 ns. Change for different clocks!
	 */
	parameter ADC_CONV_WAIT = 53,
	parameter ADC_CONV_WAIT_SIZ = 6,

	parameter CL_CONSTS_WHOLE = 21,
	parameter CL_CONSTS_FRAC = 43,
	parameter CL_CONSTS_SIZ = 7,
	parameter CL_DELAY_WID = 16,
`define CL_CONSTS_WID (CL_CONSTS_WHOLE + CL_CONSTS_FRAC)
`define CL_DATA_WID `CL_CONSTS_WID
	parameter CL_READ_DAC_DELAY = 5,
	parameter CL_CYCLE_COUNT_WID = 18
) (
	input clk,

	output [DAC_NUM-1:0] dac_mosi,
	input  [DAC_NUM-1:0] dac_miso,
	output [DAC_NUM-1:0] dac_sck,
	output [DAC_NUM-1:0] dac_ss_L,

	output [ADC_NUM-1:0] adc_conv,
	input [ADC_NUM-1:0] adc_sdo,
	output [ADC_NUM-1:0] adc_sck,

	m4_dac_wires(`DAC_PORTS_CONTROL_LOOP, 0),
	m4_dac_wires(DAC_PORTS, 1),
	m4_dac_wires(DAC_PORTS, 2),
	m4_dac_wires(DAC_PORTS, 3),
	m4_dac_wires(DAC_PORTS, 4),
	m4_dac_wires(DAC_PORTS, 5),
	m4_dac_wires(DAC_PORTS, 6),
	m4_dac_wires(DAC_PORTS, 7),

	input [`ADC_PORTS_CONTROL_LOOP-1:0] adc_sel_0,

	m4_adc_wires(ADC_TYPE1_WID, 0),
	m4_adc_wires(ADC_TYPE1_WID, 1),
	m4_adc_wires(ADC_TYPE1_WID, 2),
	m4_adc_wires(ADC_TYPE1_WID, 3),
	m4_adc_wires(ADC_TYPE1_WID, 4),
	m4_adc_wires(ADC_TYPE1_WID, 5),
	m4_adc_wires(ADC_TYPE1_WID, 6),
	m4_adc_wires(ADC_TYPE1_WID, 7),

	output cl_in_loop,
	input [`CONTROL_LOOP_CMD_WIDTH-1:0] cl_cmd,
	input [`CL_DATA_WID-1:0] cl_word_in,
	output reg [`CL_DATA_WID-1:0] cl_word_out,
	input cl_start_cmd,
	output reg cl_finish_cmd
);

wire [ADC_NUM-1:0] adc_conv_L;
assign adc_conv = ~adc_conv_L;

m4_dac_switch(`DAC_PORTS_CONTROL_LOOP, 0);
m4_dac_switch(DAC_PORTS, 1);
m4_dac_switch(DAC_PORTS, 2);
m4_dac_switch(DAC_PORTS, 3);
m4_dac_switch(DAC_PORTS, 4);
m4_dac_switch(DAC_PORTS, 5);
m4_dac_switch(DAC_PORTS, 6);
m4_dac_switch(DAC_PORTS, 7);

/* 1st adc is Type 1 (18 bit) */

wire [`ADC_PORTS_CONTROL_LOOP-1:0] adc_conv_L_port_0;
wire [`ADC_PORTS_CONTROL_LOOP-1:0] adc_sdo_port_0;
wire [`ADC_PORTS_CONTROL_LOOP-1:0] adc_sck_port_0;
wire [`ADC_PORTS_CONTROL_LOOP-1:0] adc_mosi_port_0_unassigned;
wire adc_mosi_unassigned;

spi_switch #(
	.PORTS(`ADC_PORTS_CONTROL_LOOP)
) switch_adc_0 (
	.select(adc_sel_0),
	.mosi(adc_mosi_unassigned),
	.miso(adc_sdo[0]),
	.sck(adc_sck[0]),
	.ss_L(adc_conv_L[0]),

	.mosi_ports(adc_mosi_port_0_unassigned),
	.miso_ports(adc_sdo_port_0),
	.sck_ports(adc_sck_port_0),
	.ss_L_ports(adc_conv_L_port_0)
);

spi_master_ss_no_write #(
	.WID(ADC_TYPE1_WID),
	.WID_LEN(ADC_WID_SIZ),
	.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
	.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
	.SS_WAIT(ADC_CONV_WAIT),
	.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
	.POLARITY(ADC_POLARITY),
	.PHASE(ADC_PHASE)
) adc_master_0 (
	.clk(clk),
	.miso(adc_sdo_port_0[0]),
	.sck_wire(adc_sck_port_0[0]),
	.ss_L(adc_conv_L_port_0[0]),
	.finished(adc_finished_0),
	.arm(adc_arm_0),
	.from_slave(from_adc_0)
);

control_loop #(
	.ADC_WID(ADC_TYPE1_WID),
	.ADC_WID_SIZ(ADC_WID_SIZ),
	.ADC_CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
	.ADC_CYCLE_HALF_WAIT_SIZ(ADC_CYCLE_HALF_WAIT_SIZ),
	.ADC_POLARITY(ADC_POLARITY),
	.ADC_PHASE(ADC_PHASE),
	.ADC_CONV_WAIT(ADC_CONV_WAIT),
	.ADC_CONV_WAIT_SIZ(ADC_CONV_WAIT_SIZ),
	.CONSTS_WHOLE(CL_CONSTS_WHOLE),
	.CONSTS_FRAC(CL_CONSTS_FRAC),
	.CONSTS_SIZ(CL_CONSTS_SIZ),
	.DELAY_WID(CL_DELAY_WID),
	.READ_DAC_DELAY(CL_READ_DAC_DELAY),
	.CYCLE_COUNT_WID(CL_CYCLE_COUNT_WID),
	.DAC_WID(DAC_WID),
	.DAC_WID_SIZ(DAC_WID_SIZ),
	.DAC_DATA_WID(DAC_DATA_WID),
	.DAC_POLARITY(DAC_POLARITY),
	.DAC_PHASE(DAC_PHASE),
	.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
	.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
	.DAC_SS_WAIT(DAC_SS_WAIT),
	.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ)
) cl (
	.clk(clk),
	.in_loop(cl_in_loop),
	.dac_mosi(mosi_port_0[2]),
	.dac_miso(miso_port_0[2]),
	.dac_ss_L(ss_L_port_0[2]),
	.dac_sck(sck_port_0[2]),
	.adc_miso(adc_sdo_port_0[1]),
	.adc_conv_L(adc_conv_L_port_0[1]),
	.adc_sck(adc_sck_port_0[1]),
	.cmd(cl_cmd),
	.word_in(cl_word_in),
	.word_out(cl_word_out),
	.start_cmd(cl_start_cmd),
	.finish_cmd(cl_finish_cmd)
);

m4_adc_switch(ADC_TYPE1_WID, 1);
m4_adc_switch(ADC_TYPE1_WID, 2);
m4_adc_switch(ADC_TYPE1_WID, 3);
m4_adc_switch(ADC_TYPE1_WID, 4);
m4_adc_switch(ADC_TYPE1_WID, 5);
m4_adc_switch(ADC_TYPE1_WID, 6);
m4_adc_switch(ADC_TYPE1_WID, 7);

endmodule
`undefineall