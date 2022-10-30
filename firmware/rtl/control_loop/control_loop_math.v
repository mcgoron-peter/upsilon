/*************** Precision **************
 * The control loop is designed around these values, but generally
 * does not hardcode them.
 *
 * Since α and P are precalculated outside of the loop, their
 * conversion to numbers the loop understands is done outside of
 * the loop and in the kernel.
 *
 * The 18-bit ADC is twos-compliment, -10.24V to 10.24V,
 * with 78μV per increment.
 * The 20-bit DAC is twos-compliment, -10V to 10V.
 *
 * The `P` constant has a minimum value of 1e-7 with a precision
 * of 1e-9, and a maxmimum value of 1.
 *
 * The `I` constant has a minimum value of 1e-4 with a precision
 * of 1e-6 and a maximum value of 100.
 *
 * Δt is cycles/100MHz. This makes Δt at least 10 ns, with a
 * maximum of 1 ms.
 *
 * [1 : sign][7: whole][40: fractional]
 * This is 127 to -128, with a resolution of 9.095e-13.
 */

/* If this design needs to be faster, you can:
 1) Pipeline the design
 2) Use DSPs

 With symbiflow + yosys there is no way to explicitly instantiate
 a DSP40 module. YOSYS may infer it but that might be unreliable.
 */

module control_loop_math #(
	parameter CONSTS_WHOLE = 8,
	parameter CONSTS_FRAC = 40,
`define CONSTS_WID (CONSTS_WHOLE + CONSTS_FRAC)
	/* This number is the conversion from ADC voltage units to
	 * a fixed-point number.
	 * A micro-optimization could roll the ADC reading and the multiplier
	 * together.
	 * The LSB of this number is 2**(-CONSTS_FRAC).
	 */
	parameter INT_TO_REAL_WID = 27,
	parameter [INT_TO_REAL_WID-1:0] INT_TO_REAL = 'b101000111001001111101110010,
	/* This number is 1/(clock cycle).
	   The number is interpreted so the least significant bit
	   coincides with the LSB of a constant. */
	parameter SEC_PER_CYCLE_WID = 14,
	parameter [SEC_PER_CYCLE_WID-1:0] SEC_PER_CYCLE = 'b10101011110011,
	parameter DELAY_WID = 16,
	parameter DAC_DATA_WID = 20,
	parameter ADC_WID = 18,
	parameter CYCLE_COUNT_WID = 18
) (
	input clk,
	input arm,
	output finished,

	input [ADC_WID-1:0] setpt,
	input [ADC_WID-1:0] measured,
	input [`CONSTS_WID-1:0] cl_P,
	input [`CONSTS_WID-1:0] cl_I,
	input [`CONSTS_WID-1:0] e_prev,
	input [CYCLE_COUNT_WID-1:0] cycles,
	input [DELAY_WID-1:0] dely,

	output reg [`CONSTS_WID-1:0] e_cur,
	output reg [DAC_DATA_WID-1:0] adjval
);

/**** Stage 1: Convert error to real value, calculate Δt = cycles/100MHz
 *
 *    e_unscaled: ERR_WID.0
 * x INT_TO_REAL: 0.INT_TO_REAL_WID
 *- -----------------------------
 *   e_scaled_unsat: ERR_WID + INT_TO_REAL_WID
 */

`define ERR_WID (ADC_WID + 1)
wire [`ERR_WID-1:0] e_unscaled = setpt - measured;

reg arm_stage_1 = 0;
wire mul_scale_err_fin;

`define E_UNTRUNC_WID (`ERR_WID + INT_TO_REAL_WID)
wire [`E_UNTRUNC_WID-1:0] e_scaled_unsat;
boothmul #(
	.A1_LEN(INT_TO_REAL_WID),
	.A2_LEN(`ERR_WID)
) mul_scale_err (
	.clk(clk),
	.arm(arm_stage_1),
	.a1(INT_TO_REAL),
	.a2(e_unscaled),
	.outn(e_scaled_unsat),
	.fin(mul_scale_err_fin)
);

`define E_WID (`E_UNTRUNC_WID > `CONSTS_WID ? `CONSTS_WID : `E_UNTRUNC_WID)
wire [`E_WID-1:0] e;

`define E_FRAC (`E_WID < `CONSTS_FRAC ? `E_WID : `E_WID - `CONSTS_FRAC)
`define E_WHOLE (`E_WID - `E_FRAC)

/* Don't bother keeping numbers larger than the constant width
 * since the value will always fit in it. */

generate if (`E_UNTRUNC_WID > `CONSTS_WID) begin
	intsat #(
		.IN_LEN(`E_UNTRUNC_WID),
		.LTRUNC(`E_UNTRUNC_WID - `CONSTS_WHOLE)
	) sat_mul_scale_err (
		.inp(e_scaled_unsat),
		.outp(e)
	);
end else begin
	assign e = e_scaled_unsat;
end endgenerate

/*    cycles: CYCLE_COUNT_WID.0
 *    SEC_PER_CYCLE: 0....SEC_PER_CYCLE_WID
 * -x--------------------------------
 *    dt_unsat: CYCLE_COUNT_WID + SEC_PER_CYCLE_WID
 *
 * Optimization note: the total width can be capped to below 1.
 */

`define DT_UNSAT_WID (CYCLE_COUNT_WID + SEC_PER_CYCLE_WID)
wire [`DT_UNSAT_WID-1:0] dt_unsat;
wire mul_dt_fin;
boothmul #(
	.A1_LEN(CYCLE_COUNT_WID),
	.A2_LEN(SEC_PER_CYCLE_WID)
) mul_dt (
	.clk(clk),
	.arm(arm_stage_1),
	.a1(cycles),
	.a2(SEC_PER_CYCLE),
	.outn(dt_unsat),
	.fin(mul_dt_fin)
);

`define DT_WID (`DT_UNSAT_WID > `CONSTS_WID ? `CONSTS_WID : `DT_UNSAT_WID)
wire [`DT_WID-1:0] dt;

`define DT_WHOLE (`DT_WID < `CONSTS_FRAC ? 0 : `CONSTS_FRAC - `DT_WID)
`define DT_FRAC(`DT_WID - `DT_WHOLE)

generate if (`DT_UNSAT_WID > `CONSTS_WID) begin
	intsat #(
		.IN_LEN(`DT_UNSAT_WID),
		.LTRUNC(`DT_UNSAT_WID - `CONSTS_WID)
	) insat_dt (
		.inp(dt_unsat),
		.outp(dt)
	);
end else begin
	assign dt = dt_unsat;
end endgenerate

/**** Stage 2: Calculate P + IΔt
 *     I: CONSTS_WHOLE.CONSTS_FRAC
 *  x  dt: DT_WHOLE.DT_FRAC
 *-- -------------------------------
 *     Idt_unscaled:
 *-- --------------------------------
 *     Idt: CONSTS_WHOLE.CONSTS_FRAC
 *
 * Right-truncate DT_FRAC bits to ensure CONSTS_FRAC
 * Integer-sature the DT_WHOLE bits if it extends far enough
 */

wire stage2_finished;
reg arm_stage2 = 0;
wire [`CONSTS_WID-1:0] idt;

mul_const #(
/* TODO: does this autoinfer CONSTS_WID? */
	.CONSTS_WHOLE(CONSTS_WHOLE),
	.CONSTS_FRAC(CONSTS_FRAC),
	.IN_WHOLE(`DT_WHOLE),
	.IN_FRAC(`DT_FRAC)
) mul_const_idt (
	.clk(clk),
	.inp(dt),
	.const_in(cl_I),
	.arm(arm_stage2),
	.outp(idt),
	.finished(stage2_finished)
);

wire [`CONSTS_WID:0] pidt_untrunc = cl_P + idt;
/* Assuming that the constraints on cl_P, I, and dt hold */
wire [`CONSTS_WID-1:0] pidt = pidt_untrunc[`CONSTS_WID-1:0];

/**** Stage 3: calculate e_t(P + IΔt) and P e_{t-1} ****/

reg arm_stage3 = 0;

wire epidt_finished;
wire pe_finished;

wire [`CONSTS_WID-1:0] epidt;
mul_const #(
	.CONSTS_WHOLE(`CONSTS_WHOLE),
	.CONSTS_FRAC(`CONSTS_FRAC),
	.IN_WHOLE(`E_WHOLE),
	.IN_FRAC(`E_FRAC)
) mul_const_epidt (
	.clk(clk),
	.inp(e),
	.const_in(idt),
	.arm(arm_stage3),
	.outp(epidt),
	.finished(epidt_finished)
);

wire [`CONSTS_WID-1:0] pe;
mul_const #(
	.CONSTS_WHOLE(`CONSTS_WHOLE),
	.CONSTS_FRAC(`CONSTS_FRAC),
	.IN_WHOLE(`E_WHOLE),
	.IN_FRAC(`E_FRAC)
) mul_const_pe (
	.clk(clk),
	.inp(e),
	.const_in(idt),
	.arm(arm_stage3),
	.outp(pe),
	.finished(epidt_finished)
);

/******* State machine ********/
localparam WAIT_ON_ARM = 0;
localparam WAIT_ON_STAGE_1 = 1;
localparam WAIT_ON_STAGE_2 = 2;
localparam WAIT_ON_STAGE_3 = 3;
localparam WAIT_ON_DISARM = 4;

localparam STATE_SIZ = 3;
reg [STATE_SIZ-1:0] state = WAIT_ON_ARM;

always @ (posedge clk) begin
	case (state) begin
	WAIT_ON_ARM: begin
		if (arm) begin
			arm_stage_1 <= 1;
			state <= WAIT_ON_STAGE_1;
		end
	end
	WAIT_ON_STAGE_1: begin
		if (mul_scale_err_fin && mul_dt_fin) begin
			arm_stage_1 <= 0;
			arm_stage_2 <= 1;
			state <= WAIT_ON_STAGE_2;
		end
	end
	WAIT_ON_STAGE_2: begin
		if (stage2_finished) begin
			arm_stage_2 <= 0;
			arm_stage_3 <= 1;
			state <= WAIT_ON_STAGE_3;
		end
	end
	WAIT_ON_STAGE_3: begin
		if (epidt_finished && pe_finished) begin
			arm_stage3 <= 0;
			finished <= 1;
			state <= WAIT_ON_DISARM;
		end
	end
	WAIT_ON_DISARM: begin
		if (!arm) begin
			finished <= 0;
			state <= WAIT_ON_ARM;
		end
	end
end

endmodule
