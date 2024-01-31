# SBCT11 PDP-11/DCT11 Single Board Computer

![SBCT11 being debugged](images/"SBCT11 Debugging.jpg")

The Spare Time Gizmos SBCT11 is a PDP-11 compatible single board computer based on the DEC DCT11 microprocessor.  The DCT11 is a 16 bit microprocessor that executes the standard PDP-11/LSI-11 instruction set and is roughly the speed of a PDP-11/34.  The SBCT11 itself measures 10" by 4.5" and features:

* 16 bit wide data and address busses

* 64Kb (32Kw) of RAM and 64Kb (32Kw) of EPROM

* Memory mapping system that allows both RAM and EPROM to share the T-11 address space.

* Two DC319 KL11 compatible serial ports, one for the console and the other for a secondary device such as a TU58.

* An BDV11/MXV11 compatible 60Hz line time clock.

* An 8255 PPI that can be used as a Centronics printer port or as a high speed parallel interface.

* A DS12887 non-volatile RAM and real time clock.

* A 16 bit ATA/IDE disk interface.

* PDP-11 compatible bus timeout emulation.

* PDP-11 compatible vectored interrupts.

* A 50 pin expansion bus connector for adding additional peripherals.

## Software and Firmware

The SBCT11 can boot and run RT11 from a TU58 attached to the second serial port.  Additionally it should be able to boot and run RT11 from an IDE disk, if I ever find the time to write an RT11 device driver for IDE.  The 32Kw EPROM contains a bootstrap along with a number of other useful functions:

* A power on self test that exercises all the hardware, including interrupts.

* Commands to examine and modify memory, registers and processor state.

* Commands to set breakpoints and single step thru programs.

* Commands to set or show the RTC date and time.

* A PDP-11 code disassembler.

* PDP-11 bus timeout emulation.

* Low level interface routines for both IDE and TU58.

## To Be Done

The SBCT11 hardware works and, as of revision C, is able to boot and run RT11 from TU58.  It's not a completely finished project, however, and some work still remains:

* An IDE driver for RT11 is needed!

* The built in firmware needs to be finished.

* A user manual needs to be written.

* XXDP doesn't boot, for unknown reasons.  It should, and there is actually a DCT11 diagnostic which should run.

