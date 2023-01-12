Upsilon Programmers Manual. This document may be distributed under the terms
of the GNU GPL v3.0 (or any later version), or under the [CC BY-SA 4.0][CC].

[CC]: https://creativecommons.org/licenses/by-sa/4.0/legalcode

This document is aimed at maintainers of this software who are not
experienced programmers (in either software or hardware). Its goal is
to contain any pertinent information to the devlopment process of Upsilon.

You do not need to read and digest the entire manual in sequence. Many
things will seem confusing and counterintuitive, and will require some time
to properly understand.

# FPGA Concepts

Upsilon runs on a Field Programmable Gate Array (FPGA). FPGAs are sets
of logic gates and other peripherals that can be changed by a computer.
FPGAs can implement CPUs, digital filters, and control code at a much
higher speed than a computer. The downside is that FPGAs are much more
difficult to program for.

A large part of Upsilon is written in Verilog. Verilog is a Hardware
Description Language (HDL), which is similar to a programming language
(such as C++ or Python).

The difference is, is that Verilog compiles to a *piece of hardware* that
deals with individual bits executing operations in sync with a clock. This
differs from a *piece of software*, which is a set of instructions that a
computer follows. Verilog is usually much less abstract than regular code.

Regular code is tested on the system in which it is run. Hardware,
on the other hand, is very difficult to test on the device that it
is actually running on. Hardware is usually *simulated*. This project
primarily simulates Verilog code using the program Verilator, where the
code that runs the simulation is written in C++.

Instead of strings, integers, and classes, the basic components of all
Verilog code is the wire and the register, which store bits (1 and 0).
Wires connect components together, and registers store data, in a similar
way to variables in software. Unlike usual programming languages, where
code executes one step at a time, most FPGA code runs at the tick of
the system clock in parallel.

To compile Verilog to a format suitable for execution on an FPGA, you
*synthesize* the Verilog into a low-level format that uses the specific
resources of the FPGA you are using, and then you run a *place and route*
program to allocate resources on the FPGA to fit your design. Running
synthesis on its own can help you understand how much resources a module
uses. Place-and-route gives you *timing reports*, which tell you about
major design problems that outstrip the capabilities of the FPGA (or the
programs you are using). You should look up what "timing" on an FPGA is
and learn as much as you can about it, because it is an issue that does
not happen in standard software and can be very difficult to fix when
you run into it.

Once a bitstream is synthesized, it is loaded onto a FPGA through a cable
(for this project, openFPGALoader).

## Recommendations to Learners

[Gisselquist Technology][GT] is the best free online resource for FPGA
programming out there. These articles will help you understand how to
write *good* FPGA code, not just valid code.

[GT]: https://zipcpu.com/

Here are some exercises for you to ease yourself into FPGA programming.

* Write an FPGA program that implements addition without using the `+`
  operator. This program should add each number bit by bit, handling
  carried digits properly. This is called a *full adder*.
* Write an FPGA program that multiplies two signed integers together,
  without using the `*` operator.  The width of these integers should
  not be hard-coded: it should be easy to change. What you write in
  this is something that is actually a part of this project: see
  `boothmul.v`. You do not (and should not!) write it just like Upsilon
  has written it.
* Write an FPGA program that communicates over SPI. For simplicity,
  you only need to write it for a single SPI mode: look up on the internet
  for details. There is an SPI slave device in this repository that you
  can use to simulate an end for the SPI master you write, but you should
  write the SPI slave yourself. For bonus points, connect your SPI master
  to a real SPI device and confirm that your communication works.

For each of these exercises, follow the complete "Design Testing Process"
below. At the very least, write simulations and test your programs on
real hardware.

# Organization

Upsilon uses LiteX and ZephyrOS for it's FPGA code. LiteX generates HDL
and glues it together. It also forms the build system of the hardware
portion of Upsilon. ZephyrOS is the kernel portion, which deals with
communication between the computer that receives scan data and the
hardware that is executing the scan.

LiteX further uses F4PGA to compile the HDL code. F4PGA is primarily
made up of Yosys (synthesis) and nextpnr (place and route).

# Setting up the Toolchain

The toolchain is primarily designed around modern Linux. It may not work
properly on Windows or MacOS. If you have access to a computational
cluster (if you are at FSU physics, ask the Physics department) then
you should set up the toolchain on their servers. You will be able to
compile things on any computer with an internet connection.

TODO

# Design Testing Process

## Simulation

When you write or modify a verilog module, the first thing you should do
is write/run a simulation of that module. A simulation of that module
should at the minimum compare the execution of the module with known
results (called "Ground truth testing"). A simulation should also consider
borderline cases that you might overlook when writing Verilog.

For example, a module that multiplies two signed integers together should
have a simulation that sends the module many pairs of integers, taking
care to ensure that all possible permutations of sign are tested (i.e.
positive times positive, negative times positive, etc.) and also that
special-cases are handled (i.e. largest 32-bit integer multiplied by
largest negative 32-bit integer, multiplication by 0 and 1, etc.).

Writing simulation code is a very boring task, but you *must* do it.
Otherwise there is no way for you to check that

1. Your code does what you want it to do
2. Any changes you make to your code don't break it

If you find a bug that isn't covered by your simulation, make sure you
add that case to the simulation.

## Test Synthesis

**Yosys only accepts a subset of the Verilog that Verilator supports. You
might write a bunch of code that Verilator will happily simulate but that
will fail to go through Yosys.**

Once you have simulated your design, you should use yosys to synthesize it.
This will allow you to understand how much and what resources the module
is taking up. To do this, you can put the follwing in a script file:

    read_verilog module_1.v
    read_verilog module_2.v
    ...
    read_verilog top_module.v
    synth_xilinx -flatten -nosrl -noclkbuf -nodsp -iopad -nowidelut
    write_verilog yosys_synth_output.v

and run `yosys -s scriptfile`. The options to `synth_xilinx` reflect
the current limitations that F4PGA has. The file `xc7.f4pga.tcl` that
F4PGA downloads is the complete synthesis script.

## Test Compilation

# Hacks and Pitfalls

The open source toolchain that Upsilon uses is novel and unstable.

## F4PGA

This is really a Yosys (and really, really, an abc bug). F4PGA defaults
to using the ABC flow, which can break, especially for block RAM. To
fix, edit out `-abc` in the tcl script (find it before you install it...)

## Yosys

Yosys fails to calculate computed parameter values correctly. For instance,

    parameter CTRLVAL = 5;
    localparam VALUE = CTRLVAL + 1;

Yosys will *silently* fail to compile this, setting `VALUE` to be equal
to 0. The solution is to use preprocessor defines:

    parameter CTRLVAL = 5;
    `define VALUE (CTRLVAL + 1)

In Verilog, in order to replace a macro identifier with the value of the
macro, you must put a backtick before the name: i.e.

    `VALUE