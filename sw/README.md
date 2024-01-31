# SBCT11 Firmware

  This is the firmware for the Spare Time Gizmos SBCT11 project.  It is admittedly unfginished, however what you find here is sufficient to boot RT11.

  To rebuild the EPROM images you will need a copy of the MACRO-11 cross assembler by Richard Krehbiel,

	https://github.com/shattered/macro11

You'll also need the obj2rom utility from the tools repository of this, Spare Time Gizmos, github.

  The ROM can also optionally contain a copy of DEC BASIC-11, which can be run standalone without any disk or tape.  To include this you'll need a copy of the BASIC-11 paper tape, DEC-11-UABLB-A-PO.  You can run this paper tape thru the abs2asm program, also found in the tools repository of this github, and then include it in the assembly.
  