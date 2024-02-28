"""
##########################################################################
# Portions of this file incorporate code licensed under the
# BSD 2-Clause License.
#
# Copyright (c) 2014-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2013-2014 Sebastien Bourdeauducq <sb@m-labs.hk>

# Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2020 Antmicro <www.antmicro.com>
# Copyright (c) 2022 Victor Suarez Rovere <suarezvictor@gmail.com>
# BSD 2-Clause License
# 
# Copyright (c) Copyright 2012-2022 Enjoy-Digital.
# Copyright (c) Copyright 2012-2022 / LiteX-Hub community.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##########################################################################
# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
"""

# There is nothing fundamental about the Arty A7(35|100)T to this
# design, but another eval board will require some porting.
from migen import *
import litex_boards.platforms.digilent_arty as board_spec
from litex.soc.integration.builder import Builder
from litex.build.generic_platform import IOStandard, Pins, Subsignal
from litex.soc.integration.soc_core import SoCCore
from litex.soc.integration.soc import SoCRegion, SoCBusHandler, SoCIORegion
from litex.soc.cores.clock import S7PLL, S7IDELAYCTRL
from litex.soc.interconnect.csr import AutoCSR, Module, CSRStorage, CSRStatus
from litex.soc.interconnect.wishbone import Interface, SRAM, Decoder

from litedram.phy import s7ddrphy
from litedram.modules import MT41K128M16
from litedram.frontend.dma import LiteDRAMDMAReader
from liteeth.phy.mii import LiteEthPHYMII

from util import *
from swic import *
from extio import *
from region import BasicRegion
import json

"""
Keep this diagram up to date! This is the wiring diagram from the ADC to
the named Verilog pins.

Refer to `A7-constraints.xdc` for pin names.
DAC: SS MOSI MISO SCK
  0:  1    2    3   4 (PMOD A top, right to left)
  1:  1    2    3   4 (PMOD A bottom, right to left)
  2:  1    2    3   4 (PMOD B top, right to left)
  3:  0    1    2   3 (Analog header)
  4:  0    1    2   3 (PMOD C top, right to left)
  5:  4    5    6   8 (Analog header)
  6:  1    2    3   4 (PMOD D top, right to left)
  7:  1    2    3   4 (PMOD D bottom, right to left)


Outer chip header (C=CONV, K=SCK, D=SDO, XX=not connected)
26  27  28  29  30  31  32  33  34  35  36  37  38  39  40  41
C4  K4  D4  C5  K5  D5  XX  XX  C6  K6  D6  C7  K7  D7  XX  XX
C0  K0  D0  C1  K1  D1  XX  XX  C2  K2  D2  C3  K3  D3
0   1   2   3   4   5   6   7   8   9   10  11  12  13

The `io` list maps hardware pins to names used by the SoC
generator. These pins are then connected to Verilog modules.

If there is more than one pin in the Pins string, the resulting
name will be a vector of pins.

TODO: generate declaratively from constraints file.
"""
io = [
#    ("differntial_output_low", 0, Pins("J17 J18 K15 J15 U14 V14 T13 U13 B6 E5 A3"), IOStandard("LVCMOS33")),
    ("dac_ss_L_0", 0, Pins("G13"), IOStandard("LVCMOS33")),
    ("dac_mosi_0", 0, Pins("B11"), IOStandard("LVCMOS33")),
    ("dac_miso_0", 0, Pins("A11"), IOStandard("LVCMOS33")),
    ("dac_sck_0", 0, Pins("D12"), IOStandard("LVCMOS33")),
#    ("dac_ss_L", 0, Pins("G13 D13 E15 F5 U12 D7 D4 E2"), IOStandard("LVCMOS33")),
#    ("dac_mosi", 0, Pins("B11 B18 E16 D8 V12 D5 D3 D2"), IOStandard("LVCMOS33")),
#    ("dac_miso", 0, Pins("A11 A18 D15 C7 V10 B7 F4 H2"), IOStandard("LVCMOS33")),
#    ("dac_sck", 0, Pins("D12 K16 C15 E7 V11 E6 F3 G2"), IOStandard("LVCMOS33")),
    ("adc_conv_0", 0, Pins("V15"), IOStandard("LVCMOS33")),
    ("adc_sck_0", 0, Pins("U16"), IOStandard("LVCMOS33")),
    ("adc_sdo_0", 0, Pins("P14"), IOStandard("LVCMOS33")),
#    ("adc_conv", 0, Pins("V15 T11 N15 U18 U11 R10 R16 U17"), IOStandard("LVCMOS33")),
#    ("adc_sck", 0, Pins("U16 R12 M16 R17 V16 R11 N16 T18"), IOStandard("LVCMOS33")),
#    ("adc_sdo", 0, Pins("P14 T14 V17 P17 M13 R13 N14 R18"), IOStandard("LVCMOS33")),
    ("module_reset", 0, Pins("D9"), IOStandard("LVCMOS33")),
#    ("test_clock", 0, Pins("P18"), IOStandard("LVCMOS33"))
]

# Clock and Reset Generator
# I don't know how this works, I only know that it does.
class _CRG(Module):
    def __init__(self, platform, sys_clk_freq, with_dram, rst_pin):
        self.rst = Signal()
        self.clock_domains.cd_sys      = ClockDomain()
        self.clock_domains.cd_eth      = ClockDomain()
        if with_dram:
            self.clock_domains.cd_sys4x  = ClockDomain()
            self.clock_domains.cd_sys4x_dqs = ClockDomain()
            self.clock_domains.cd_idelay    = ClockDomain()

        # Clk/Rst.
        clk100 = platform.request("clk100")
        rst = ~rst_pin if rst_pin is not None else 0

        # PLL.
        self.submodules.pll = pll = S7PLL(speedgrade=-1)
        self.comb += pll.reset.eq(rst | self.rst)
        pll.register_clkin(clk100, 100e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)
        pll.create_clkout(self.cd_eth, 25e6)
        self.comb += platform.request("eth_ref_clk").eq(self.cd_eth.clk)
        platform.add_false_path_constraints(self.cd_sys.clk, pll.clkin) # Ignore sys_clk to pll.clkin path created by SoC's rst.
        if with_dram:
            pll.create_clkout(self.cd_sys4x,     4*sys_clk_freq)
            pll.create_clkout(self.cd_sys4x_dqs, 4*sys_clk_freq, phase=90)
            pll.create_clkout(self.cd_idelay,   200e6)

        # IdelayCtrl.
        if with_dram:
            self.submodules.idelayctrl = S7IDELAYCTRL(self.cd_idelay)

class UpsilonSoC(SoCCore):
    def add_ip(self, ip_str, ip_name):
        # The IP of the FPGA and the IP of the TFTP server are stored as
        # "constants" which turn into preprocessor defines.

        # They are IPv4 addresses that are split into octets. So the local
        # ip is LOCALIP1, LOCALIP2, etc.
        for seg_num, ip_byte in enumerate(ip_str.split('.'),start=1):
            self.add_constant(f"{ip_name}{seg_num}", int(ip_byte))

    def add_slave_with_registers(self, name, bus, region, registers):
        """ Add a bus slave, and also add its registers to the subregions
        dictionary. """
        self.bus.add_slave(name, bus, region)
        self.soc_subregions[name] = registers

    def add_blockram(self, name, size, connect_now=True):
        """ Add a blockram module to the system.

        :param connect_now: Connect the block ram directly to the SoC.
           You will probably never need this, since this just adds
           more ram to the main CPU which already has 256 MiB of RAM.
           Only useful for testing to see if the Blockram works by poking
           it directly from the main CPU.
        """
        mod = SRAM(size)
        self.add_module(name, mod)

        if connect_now:
            self.bus.add_slave(name, mod.bus,
                    SoCRegion(origin=None, size=size, cached=True))
        return mod

    def add_preemptive_interface(self, name, size, slave):
        """ Add a preemptive interface with "size" connected to the slave's bus. """
        mod = PreemptiveInterface(size, slave)
        self.add_module(name, mod)
        return mod

    def add_picorv32(self, name, size=0x1000, origin=0x10000):

        # Add PicoRV32 core
        pico = PicoRV32(name, origin, origin+0x10)
        self.add_module(name, pico)

        # Attach the register region to the main CPU.
        self.add_slave_with_registers(name + "_dbg_reg", pico.debug_reg_read.bus,
                SoCRegion(origin=None, size=pico.debug_reg_read.width, cached=False),
                pico.debug_reg_read.public_registers)

        # Add a Block RAM for the PicoRV32 toexecute from.
        ram = self.add_blockram(name + "_ram", size=size, connect_now=False)

        # Control access to the Block RAM from the main CPU.
        ram_iface = self.add_preemptive_interface(name + "ram_iface", 2, ram)

        # Allow access from the PicoRV32 to the Block RAM.
        pico.mmap.add_region("main",
                BasicRegion(origin=origin, size=size, bus=ram_iface.buses[1]))

        # Allow access from the main CPU to the Block RAM.
        self.add_slave_with_registers(name + "_ram", ram_iface.buses[0],
                SoCRegion(origin=None, size=size, cached=True),
                None)

    def picorv32_add_cl(self, name, param_origin=0x100000):
        """ Add a register area containing the control loop parameters to the
            PicoRV32.

            :param param_origin: The origin of the parameters in the PicoRV32's
            address space. """
        pico = self.get_module(name)
        params = pico.add_cl_params(param_origin, name + "_cl.json")
        self.add_slave_with_registers(name + "_cl", params.mainbus,
                SoCRegion(origin=None, size=params.width, cached=False),
                params.public_registers)

    def add_AD5791(self, name, **kwargs):
        args = SPIMaster.AD5791_PARAMS
        args.update(kwargs)
        spi = SPIMaster(**args)
        self.add_module(name, spi)
        return spi

    def add_LT_adc(self, name, **kwargs):
        args = SPIMaster.LT_ADC_PARAMS
        args.update(kwargs)
        args["mosi"] = Signal()

        # SPI Master brings ss_L low when converting and keeps it high
        # when idle. The ADC is the opposite, so invert the signal here.
        conv_high = Signal()
        self.comb += conv_high.eq(~kwargs["ss_L"])

        spi = SPIMaster(**args)
        self.add_module(name, spi)
        return spi

    def __init__(self,
                 variant="a7-100",
                 local_ip="192.168.2.50",
                 remote_ip="192.168.2.100",
                 tftp_port=6969):
        """
        :param variant: Arty A7 variant. Accepts "a7-35" or "a7-100".
        :param local_ip: The IP that the BIOS will use when transmitting.
        :param remote_ip: The IP that the BIOS will use when retreving
          the Linux kernel via TFTP.
        :param tftp_port: Port that the BIOS uses for TFTP.
        """

        sys_clk_freq = int(100e6)
        platform = board_spec.Platform(variant=variant, toolchain="f4pga")
        rst = platform.request("cpu_reset")
        self.submodules.crg = _CRG(platform, sys_clk_freq, True, rst)

        # The SoC won't know the origins until LiteX sorts out all the
        # memory regions, so they go into a dictionary directly instead
        # of through MemoryMap.
        self.soc_subregions = {}

        """
        These source files need to be sorted so that modules
        that rely on another module come later. For instance,
        `control_loop` depends on `control_loop_math`, so
        control_loop_math.v comes before control_loop.v

        If you want to add a new verilog file to the design, look at the
        modules that it refers to and place it the files with those modules.

        Since Yosys doesn't support modern Verilog, only put preprocessed
        (if applicable) files here.
        """
        platform.add_source("rtl/picorv32/picorv32.v")
        platform.add_source("rtl/spi/spi_master_preprocessed.v")
        platform.add_source("rtl/spi/spi_master_ss.v")
        platform.add_source("rtl/spi/spi_master_ss_wb.v")

        # SoCCore does not have sane defaults (no integrated rom)
        SoCCore.__init__(self,
                clk_freq=sys_clk_freq,
                toolchain="symbiflow", 
                platform = platform,
                bus_standard = "wishbone",
                ident = f"Arty-{variant} F4PGA LiteX VexRiscV Zephyr - Upsilon",
                bus_data_width = 32,
                bus_address_width = 32,
                bus_timeout = int(1e6),
                cpu_type = "vexriscv_smp",
                cpu_count = 1,
                cpu_variant="linux",
                integrated_rom_size=0x20000,
                integrated_sram_size = 0x2000,
                csr_data_width=32,
                csr_address_width=14,
                csr_paging=0x800,
                csr_ordering="big",
                timer_uptime = True)
        # This initializes the connection to the physical DRAM interface.
        self.submodules.ddrphy = s7ddrphy.A7DDRPHY(platform.request("ddram"),
            memtype     = "DDR3",
            nphases     = 4,
            sys_clk_freq   = sys_clk_freq)
        # Synchronous dynamic ram. This is what controls all access to RAM.
        # This houses the "crossbar", which negotiates all RAM accesses to different
        # modules, including the verilog interfaces (waveforms etc.)
        self.add_sdram("sdram",
            phy        = self.ddrphy,
            module      = MT41K128M16(sys_clk_freq, "1:4"),
            l2_cache_size = 8192
        )

        # Initialize Ethernet
        self.submodules.ethphy = LiteEthPHYMII(
            clock_pads = platform.request("eth_clocks"),
            pads       = platform.request("eth"))
        self.add_ethernet(phy=self.ethphy, dynamic_ip=True)

        # Initialize network information
        self.add_ip(local_ip, "LOCALIP")
        self.add_ip(remote_ip, "REMOTEIP")
        self.add_constant("TFTP_SERVER_PORT", tftp_port)

        # Add pins
        platform.add_extension(io)

        # Add control loop DACs and ADCs.
        self.add_picorv32("pico0")
        self.picorv32_add_cl("pico0")
        # XXX: I don't have the time to restructure my code to make it
        # elegant, that comes when things work
        # If DACs don't work, comment out from here
        module_reset = platform.request("module_reset")
        self.add_AD5791("dac0",
                rst=module_reset,
                miso=platform.request("dac_miso_0"),
                mosi=platform.request("dac_mosi_0"),
                sck=platform.request("dac_sck_0"),
                ss_L=platform.request("dac_ss_L_0"),
        )

        self.add_preemptive_interface("dac0_PI", 2, self.dac0)
        self.add_slave_with_registers("dac0", self.dac0_PI.buses[0],
                SoCRegion(origin=None, size=self.dac0.width, cached=False),
                self.dac0.public_registers)
        self.pico0.mmap.add_region("dac0",
                    BasicRegion(origin=0x200000, size=self.dac0.width,
                                bus=self.dac0_PI.buses[1],
                                registers=self.dac0.public_registers))

        self.add_LT_adc("adc0",
                rst=module_reset,
                miso=platform.request("adc_sdo_0"),
                sck=platform.request("adc_sck_0"),
                ss_L=platform.request("adc_conv_0"),
                spi_wid=18,
        )
        self.add_preemptive_interface("adc0_PI", 2, self.adc0)
        self.add_slave_with_registers("adc0", self.adc0_PI.buses[0],
                SoCRegion(origin=None, size=self.adc0.width, cached=False),
                self.adc0.public_registers)
        self.pico0.mmap.add_region("adc0",
                    BasicRegion(origin=0x300000, size=self.adc0.width,
                                bus=self.adc0_PI.buses[1],
                                registers=self.adc0.public_registers))
        # To here

    def do_finalize(self):
        with open('soc_subregions.json', 'wt') as f:
            json.dump(self.soc_subregions, f)

def generate_main_cpu_include(csr_file):
    """ Generate Micropython include from a JSON file. """
    with open('mmio.py', 'wt') as out:

        print("from micropython import const", file=out)
        with open(csr_file, 'rt') as f:
            csrs = json.load(f)

        for key in csrs["csr_registers"]:
            if key.startswith("pico0"):
                print(f'{key} = const({csrs["csr_registers"][key]["addr"]})', file=out)

        with open('soc_subregions.json', 'rt') as f:
            subregions = json.load(f)

        for key in subregions:
            if subregions[key] is None:
                print(f'{key} = const({csrs["memories"][key]["base"]})', file=out)
            else:
                print(f'{key}_base = const({csrs["memories"][key]["base"]})', file=out)
                print(f'{key} = {subregions[key].__repr__()}', file=out)

def main():
    from config import config
    soc =UpsilonSoC(**config)
    builder = Builder(soc, csr_json="csr.json", compile_software=True)
    builder.build()

    generate_main_cpu_include("csr.json")

if __name__ == "__main__":
    main()
