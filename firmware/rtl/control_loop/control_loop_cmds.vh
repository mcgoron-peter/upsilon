`define CONTROL_LOOP_NOOP 0
`define CONTROL_LOOP_STATUS 1
`define CONTROL_LOOP_SETPT 2
`define CONTROL_LOOP_P 3
`define CONTROL_LOOP_I 4
`define CONTROL_LOOP_ERR 5
`define CONTROL_LOOP_Z 6
`define CONTROL_LOOP_CYCLES 7
`define CONTROL_LOOP_WRITE_BIT (1 << (CONTROL_LOOP_CMD_WIDTH-1))
`define CONTROL_LOOP_CMD_WIDTH 8
