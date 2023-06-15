/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
generate_macro(CONTROL_LOOP_NOOP, 0)
generate_macro(CONTROL_LOOP_STATUS, 1)
generate_macro(CONTROL_LOOP_SETPT, 2)
generate_macro(CONTROL_LOOP_P, 3)
generate_macro(CONTROL_LOOP_I, 4)
generate_macro(CONTROL_LOOP_ERR, 5)
generate_macro(CONTROL_LOOP_Z, 6)
generate_macro(CONTROL_LOOP_CYCLES, 7)
generate_macro(CONTROL_LOOP_DELAY, 8)
generate_macro(CONTROL_LOOP_CMD_WIDTH, 8)
generate_macro(CONTROL_LOOP_WRITE_BIT, (1 << (M4_CONTROL_LOOP_CMD_WIDTH-1)))