	.TITLE	SBCT11 ROM Monitor
	.SBTTL	Copyright 2021 Spare Time Gizmos
	.IDENT	/V2.047/

; USE BYTE INSTRUCTIONS IN $POST
; ASPI_OUT forced to zero in INTERRUPT.PLD
; REPLACE HOKEY CP LOGIC WITH ORIGINAL IN INTERRUPT.PLD
; CHECK ACKNOWLEDGE.PLD FOR TEMPORARY LOGIC TOO!
;CHANGE SAVMAP/RSTMAP TO USE THE STACK - CLEAN UP $SAVMAP/$RSTMAP
;MAKE SLU1 OPTIONAL!

;++
;
;        ad88888ba   88888888ba     ,ad8888ba,  888888888888  88      88  
;       d8"     "8b  88      "8b   d8"'    `"8b      88     ,d88    ,d88  
;       Y8,          88      ,8P  d8'                88   888888  888888  
;       `Y8aaaaa,    88aaaaaa8P'  88                 88       88      88  
;         `"""""8b,  88""""""8b,  88                 88       88      88  
;               `8b  88      `8b  Y8,                88       88      88  
;       Y8a     a8P  88      a8P   Y8a.    .a8P      88       88      88  
;        "Y88888P"   88888888P"     `"Y8888Y"'       88       88      88  
;
;             COPYRIGHT (C) 2021 BY SPARE TIME GIZMOS, MILPITAS, CA
;
;   This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the Free
; Software Foundation; either version 2 of the License, or (at your option) any
; later version.
;
;   This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc., 59
; Temple Place, Suite 330, Boston, MA  02111-1307  USA
;--


;++
;   This is the ROM monitor for the Spare Time Gizmos SBCT11 single board
; computer, a PDP-11 compatible system based on (what else?) the DEC DCT11 CPU
; chip.  The SBCT11 contains 32Kw (that's 64K bytes) of static RAM and 32Kw of
; EPROM, along with a simple memory mapping scheme that allows all (well, nearly
; all) of both the RAM and the EPROM to be accessed.  Additionally there is a
; DS12887 real time clock and non-volatile RAM chip that can be used for saving
; settings as well as keeping track of the time of day.
;
;   The SBCT11 also contains two DC319 DLART PDP-11 compatible serial ports, one
; for the console terminal and the other one nominally for a TU58.  An IDE/ATA
; compatible disk interface is also implemented, along with an eight bit general
; purpose bidirectional parallel port.  The latter can be used for a printer or
; as a high speed data link to another device or computer.  PDP-11 compatible
; vectored interrupts are implemented for all of these devices.
;
;   This firmware contains a fairly complete power on self test that exercises
; all of the SBCT11 hardware, including interrupts, and bootstraps for both the
; IDE disk and a TU58.  Additionally there are generic I/O routines in the
; unmapped part of the EPROM for both the IDE/ATA disk and the TU58 that can be
; called from a user program or a device driver.  
;
;   The firmware also contains a command line parser that implements a number of
; commands that are useful to developing or debugging programs.  These include
; the ability to examine and modify RAM, registers and processor state; start
; and interrupt user programs; set breakpoints in or single step thru programs;
; disassemble PDP-11 instructions, and catch all unhandled PDP-11 traps and
; interrupts.
;--

;0000000001111111111222222222233333333334444444444555555555566666666667777777777
;1234567890123456789012345678901234567890123456789012345678901234567890123456789

	.ENABL	LC, REG
	.DSABL	GBL, AMA
	.NLIST	TTM, CND, ME
	.LIST	BEX, MEB, TOC, SYM
	.ASECT
	.SBTTL	Revision History

;++
; REVISION HISTORY
;
; 001	-- Start from scratch!
;
; 002	-- Add lots of definitions, both hardware and software.
;
; 003	-- Add basic console input/output.
;
; 004	-- Add multiply and divide, decimal and RAD50 output.
;
; 005	-- Add command scanner lexical functions, RAD50 scan and output.
;
; 006	-- Add memory examine/deposit and register examine/deposit.
;
; 007	-- Add UCSAVE and UCLOAD, GO command, and trap/interrupt handling.
;
; 008	-- Add TRace command.
;
; 009	-- Add breakpoints, BP, BL and BR commands.
;
; 010	-- Add IDE/ATA disk support.
;
; 011	-- Add TU58 tape support.
;
; 012	-- Re-arrange code to better fit.  The unmapped part of ROM is now
;	   essentially full.  Still tons of room in the mapped section though.
;	   Add assembly warnings if the unmapped section overflows.
;
; 013	-- Add disassembler code and tables (stolen from the DCT11-EM firmware).
;
; 014	-- Add examin instruction (EI) using our nifty new disassembler.
;	   Modify TRace (TR) command to use the disassembler too.
;
; 015	-- Add DLART extended diagnostics.  Fix a few hardware bugs!
;
; 016	-- Add LTC diagnostics.  Fix more hardware bugs!
;
; 017	-- Fix PPI mode as 301.  Make startup code clear PPI interrupts.
;	   Add PPI diagnostics.
;
; 018	-- Add IDE/ATA diagnostics. Make sure ATA interrupts are disabled.
;
; 019	-- Fix bug in Continue that doesn't clear the T bit (causes spurious
; 	   breakpoint traps!).  If a breakpoint trap occurs AND the opcode
;	   is actually BPT, decrement the user PC to the original address.
;
; 020	-- In INCHRS recognize a break as equivalent to ^C.
;
; 021	-- Make NAMENW ignore extra characters.  Modify LOOKUP to have separate
;	   name and dispatch tables.  Clean up command tables.
;
; 022	-- Add basic help text and HELp command.
;
; 023	-- Add build date to startup message.
;
; 024	-- Fix the SBCT11 hardware so that DLART interrupts are edge triggered
; 	   (they are in a real DL11, too).  Modify the POST to check for this.
;
; 025	-- End of table test in BPTINS and BPTRMV are reversed!
;
; 026	-- Rewrite UCSAVE and UCLOAD routines.  Break out breakpoint and restart
;	   handling into independent code.  It now works to hit breakpoints and
; 	   continue inside a repeat command.
;
; 027	-- Make BL list the disassembled instruction, not just the octal.
;
; 028	-- Make Continue command check for an odd PC.  Make all of Trace, GO and
; 	   Continue consistent in checking the PC and SP.
;
; 029	-- Add stand along paper tape BASIC and the BASic command to start it.
;
; 030	-- Add bus timeout trap/NXM support.
;
; !!!!!!!!! RT11-SJ 5.03 BOOTS FROM TU58 !!!!!!!!!
;
; 031	-- Separate FLAGS into HFLAGS and SFLAGS (finally ran out of bits!)
;
; 032	-- Add LTC, NXM and CRT commands to control LTC interrupts, bus timeout
;	   emulation, and CRT/hardcopy mode.
;
; 033	-- In UCLOAD turn on LTC interrupts if enabled.
;
; 034	-- ECHo should flush the remainder of the command after printing.
;
; 035	-- Enhance TU58 code to allow for units > 2 and blocks > 512 ...
;
; 036	-- Invent DEVNW to scan device names
;
; 037	-- Add Boot command and implement DDn (TU58) bootstrap.
;	   DI (IDE) bootstrap is still to be added...
;
; 038	-- Add MFPT to the disassembler table (it was forgotten somehow!).
;
; 039	-- Invent FORmat command to zero TU58 images and disk partitions.
;
; 040	-- Changes for the 2B revision PCBs ...
;
; 041	-- Really implement EPROM checksum checking in the POST (finally!)
;	   This works now that the memory mapping problems are fixed.
;
; 042	-- Swap IDE1FX and IDE3FX (layout error in the rev B PCBs!)
;
; 043	-- Debug DS12887A interface.  Invent RDNVRB and WRNVRB ...
;
; 044	-- Create NOW command to set/show RTC.
;
; 045	-- INvent NVRCHK/NVRTST/NVRUPD to checksum RAM part of DS12887A.
;
; 046	-- REPEAT command needs to increment R5 (skip over the ";") ...
;
; 047	-- Invent the MATCH routine to do handle more sophisticated command name
;	   abbreviations.  Invent COMND and COMNDJ to take advantage of that.
;
; 048	-- Add "generic" EXAMINE and DEPOSIT commands ...
;
; 049	-- Add generic SHOW, SET, CLEAR and TEST commands.
;
; 050	-- Rewrite existing code (NOW, NVR, BP, BR, BL, etc) to fit into the
;	   SHOW/SET/CLEAR/TEST paradigm.
;
; 051	-- Add the TEST NVR command ...
;
; 052	-- Cleanup breakpoint and trap code to remove all vestiges of the PPI
;	   NXM TRAP and RAM ENABLE flags.
;
; 053	-- Add SET/SHOW LTC and SET/SHOW NXM.  Also save these settings to NVR.
;
; 054	-- Add SET/SHOW BOOT and save it to NVR ...
;
; SUGGESTIONS
; invent CLRINT to clear all interrupts before starting usr program?
; make sure console TTY xmt flag is set before starting usr program?  No...
; what happens if we trap and the user's stack points to NXM?
; Add a SHOW command 
;	SHOw VERsion
;	SHOw DISk (or SHOw IDE?)
;	SHOw RTC
; Add a more extensive RAM test?
; Make TU and ID routine consistently return an error status in R0
; Make ?DEVICE ERROR report the error status
; Implement CRT/SCOPE mode
;	* DELETE/BACKSPACE handling in INCHWL
;	* Staus messages in FORmat
; Use TSTB to test LTC, MEM and NXMCSR bits
; Change $SAVMAP/$RSTMAP to push and/or pop the MEMCSR
;   -> don't need H.PRAM anymore
;--
BTSVER=50.		; revision number of this code
	.SBTTL	Subroutine Dictionary

; CONSOLE OUTPUT FUNCTIONS
; -----------------------------------------------------------------------------
;CONPUT	- send 8 bit character from R0 to the console with no processing
;OUTCHR	- type character from R0 and handle ^C, ^O, ^S and ^Q
;TFCHAR	- type a character from R0 and handle printing control characters
;T2CHAR	- type two characters from R0
;OUTSTR	- type the ASCIZ string pointed to by R1
;INLMES	- type an inline ASCIZ message
;TCRLF	- type a CRLF
;TDIGIT	- type a decimal or octal digit from R0
;TDECU	- type an unsigned 16 bit decimal value from R1
;TDECW	- type a signed 16 bit decimal value from R1
;TDEC2	- type a two digit decimal value from R1 with leading zero
;TOCTB	- type a 3 digit 8 bit octal value from R1
;TOCTW	- type a 6 digit 16 bit octal value from R1
;TR50CH	- type a single RADIX-50 character from R0
;TR50W	- type three RADIX-50 characters from R1
;TR50W2	- type six RADIX-50 characters (two words) pointed to by R2
;TERASE	- type <BACKSPACE> <SPACE> <BACKSPACE> sequence
;TSPACE	- type a space
;TTIME	- type a time and date pointed to by R3
;TINSTA	- type an address and disassemble the instruction pointed to by R4
;TINSTW	- disassemble the instruction pointed to by R4 (no address)

; CONSOLE INPUT FUNCTIONS
; -----------------------------------------------------------------------------
;INCHWL	- read a command line with prompting and line editing
;INCHRS	- read a single characer with echo, handle ^S, ^Q, ^O and ^C
;CONGET	- read a character from the console w/o any processing

; PARSING FUNCTIONS
; -----------------------------------------------------------------------------
;GETCCH	- return the CURRENT command line character in R0
;GETNCH	- return the NEXT command line character in R0
;SPANW	- return the next non-white space character from the command line
;CHKEOL	- verify that the CURRENT character for end-of-command
;CHKSPA	- verify that the CURRENT character is a white space
;CHKARG	- return Z set if there are NO more arguments to this command
;ISEOL	- return Z set if the current command line character is EOL
;ISDEC	- return C set if R0 contains a decimal digit
;ISOCT	- return C set if R0 contains an octal digit
;ISLET	- return C set if R0 contains a letter A-Z
;ISALNU	- return C set if R0 contains a letter OR a digit
;ISPRNT	- return C set if R0 contains a printing ASCII character
;DECNW	- scan a decimal argument and return it in R1
;OCTNW	- scan an octal argument and return it in R1
;RANGE	- scan an address range (e.g. "aaaaaa-bbbbbb") and return in ADDRHI/LO
;DEVNW	- scan a device specification and return name in R2 and unit in R1
;NAMENW	- scan a 3 character RADIX-50 name and return in R1
;LOOKUP	- search a table of RADIx-50 names (pointer in R2) for match of R1
;COMERR	- report a command line syntax error and issue a new prompt
;ERRMES	- report a command line semantic error and issue a new prompt

; COMMANDS
; -----------------------------------------------------------------------------
;REPEAT
;ECHO
;HELP
;EXAMINE
;DEPOSIT
;EXAMINE REGISTER
;DEPOSIT REGISTER
;EXAMINE INSTRUCTION
;CLEAR MEMORY
;GO
;TRACE (SINGLE STEP)
;COMMAND
;MASTER RESET
;SET BREAKPOINT
;SHOW BREAKPOINT
;REMOVE BREAKPOINT
;SET LTC ON|OFF
;SET NXM ON|OFF
;SET CRT ON|OFF
;SHOW IDE
;BOOT DDn|DIn
;FORMAT DDn|DIn
;*DUMP NVR|DDn|DIn
;SHOW TIME
;SET TIME
;BASIC
	.SBTTL	Generic Definitions


; Bit equates ...
BIT0=	   1
BIT1=	   2
BIT2=	   4
BIT3=	  10
BIT4=	  20
BIT5=	  40
BIT6=	 100
BIT7=	 200
BIT8=	 400
BIT9=	1000
BIT10=	2000
BIT11=	4000
BIT12= 10000
BIT13= 20000
BIT14= 40000
BIT15=100000

; Special ASCII control characters that get used here and there...
CH.NUL=	000		; A null character (for fillers)
CH.CTC=	003		; Control-C (Abort command)
CH.BEL=	007		; Control-G (BELL)
CH.BSP=	010		; Control-H (Backspace)
CH.TAB=	011		; Control-I (TAB)
CH.LFD=	012		; Control-J (Line feed)
CH.CRT=	015		; Control-M (carriage return)
CH.CTO=	017		; Control-O (Suppress output)
CH.XON=	021		; Control-Q (XON)
CH.CTR=	022		; Control-R (Retype command line)
CH.XOF=	023		; Control-S (XOFF)
CH.CTU=	025		; Control-U (Delete command line)
CH.ESC=	033		; Control-[ (Escape)
CH.DEL=	177		; RUBOUT    (Delete)

; DCT11 (and all PDP-11s) program status word bits ...
PS.PRI=	340		; mask for all priority bits
  PS.PR0=000		;  accept all interrupts!
  PS.PR4=200		;  priority level 4
  PS.PR5=240		;  priority level 5
  PS.PR6=300		;  priority level 6
  PS.PR7=340		;  priority level 7
PS.T=	BIT4		; trace trap bit
PS.N=	BIT3		; negative bit
PS.Z=	BIT2		; zero bit
PS.V=	BIT1		; overflow bit
PS.C=	BIT0		; carry bit
PS.CC=	PS.N!PS.Z!PS.V!PS.C
	.SBTTL	SBCT11 Definitions


; SBCT11 memory configuration ...
ROMBS0=	002000		; start of EPROM (when ROMMAP is true)
ROMBS1=	170000		; start of permanently mapped EPROM
ROMTOP= 175777		; last address assigned to EPROM
RAMTOP= 167777		; last address in RAM (when ROMMAP is false)
START1=	172000		; DCT11 primary start/restart address
START2= 173000		;   "   secondary "     "       "
SCRRAM=	176000		; scratch RAM set aside for our use
SCRTOP= 176377		; last location in scratch RAM

; SBCT11 I/O device addresses ...
IDE=	176400		; IDE disk drive base address
SLU1=	176500		;   "      "     "  1 (TU58)     "     "  "
SPARE=	176560		; spare I/O select address
PPI=	177420		; 82C55 peripheral interface
RTC=	177460		; DS12887A real time clock and non-volatile RAM
SWITCH=	177524		; console switch register address (not implemented)
FLAGS=	177540		; SBCT11 flags and status registers
SLU0=	177560		; DC319 serial line 0 (console) base address

; Other monitor options ...
MAXBPT=8.		; maximum number of breakpoints
MAXCMD=80.		; longest possible command line

;   This magic constant is used by the $DLYMS macro to generate programmed
; delays.  An "SOB Rn, ." loop using this constant takes exactly 1ms to finish.
DLYMS=	270.		; 1ms delay with a 4.9152MHz CPU clock/crystal

; SBCT11 POST codes ...
PC.RUN=	16.		; RUN LED
PC.CPU=	15.		; F - CPU failure, no EPROM or gross PPI failure
PC.SCR=	14.		; E - monitor scratch RAM failure
PC.ROM=	13.		; D - EPROM checksum failure
PC.RAM=	12.		; C - main RAM failure
PC.MAP=	11.		; B - memory mapping failure? 
PC.INT=	10.		; A - unexpected interrupt
PC.SL0=	 9.		; 9 - SLU0 test
PC.SL1=	 8.		; 8 - SLU1 test
PC.LTC=	 7.		; 7 - LTC test
PC.PPI=	 6.		; 6 - PPI test
PC.RTC=	 5.		; 5 - NVR test
PC.IDE=	 4.		; 4 - IDE test 
			; 3 - unused
			; 2 - unused
PC.MON=	 1.		; 1 - this  monitor running
PC.USR=	 0.		; 0 - user program running
PC.PST= 37		; mask for all POST and RUN bits
	.SBTTL	SBCT11 Flags and Status Registers

;++
;   The SBCT11 implements four "flag and status" registers.  Each one of these
; registers contains a single flag output bit which is used to control some
; SBCT11 function (RAM/ROM mapping, LTC enable, NXM trap, etc).  Most of these
; registers also contain a single sense bit which can be used to read the state
; of some SBCT11 signal (LTC tick, NXM request, etc).  It is possible to read 
; back each register and obtain the current status of each flag bit and, for
; those that implement it, the associated sense bit.
;
;    The LTC register is compatible with the LTCS (line time clock control and
; status) register implemented by the DEC KPV11, MXV11, or BDV11 modules.  This
; register and flag bit controls the LTC function in the SBCT11.  The other
; three flag registers are unique to the SBCT11.  Two of them control the RAM
; ENABLE flag and the NXM TRAP ENABLE flag, and the third register and flag bit
; combination is currently unused.
;
;	ADDRESS	REGISTER
;	------- ----------------------------------------------
;	177540	MEMCSR (memory control register/RAM ENABLE flag)
;	177542	NXMCSR (NXM trapping control/status register)
;	177544	SPRCSR (unused spare flag and sense)
;	177546	LTCCSR (line time clock control/status register)
;--


;++
; BIT 15  14  13  12  11  10  9   8   7   6   5   4   3   2   1   0
;   +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;   |   |   |   |   |   |   |   |   |   |RAM|   |   |   |   |   |   |
;   +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;			   MEMCSR REGISTER (177540)
;
;   The memory control (MEMCSR) register at address 177540 controls the state
; of the RAM ENABLE signal.  When set, the RAM bit asserts RAM ENABLE and maps
; RAM to most of the address space.  When cleared, the RAM bit deasserts RAM
; ENABLE and maps EPROM to most of the address space.  This register is read/
; write and it is possible to read back the current state of the RAM ENABLE bit.
;
;   The RAM bit and RAM ENABLE are cleared on power up, but NOT BY BCLR (i.e.
; the RESET instruction does NOT change the memory mapping!).
;--
MEMCSR=	FLAGS+0		; memory control register (RAM/ROM mapping)
  MC.RAM= BIT6		;   set to enable RAM mapping mode


;++
; BIT 15  14  13  12  11  10  9   8   7   6   5   4   3   2   1   0
;   +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;   |   |   |   |   |   |   |   |   |NXM|NXE|   |   |   |   |   |   |
;   +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;			  NXMCSR REGISTER (177542)
;
;   The NXMCSR register controls the non-existent memory trap and bus timeout
; emulation feature.  This is unique to the SBCT11.  NXM trapping is enabled by
; writing a 1 to the NXE bit, and disabled by writing a zero to this bit.  If
; the NXE bit is set and the program references a "non-existent" memory address
; (see the MEMORY and IO GALs for a discussion of what that might mean) then the
; NXM flip flop will be set.  The flip flop will cause an immediate trap to the
; restart addres after the completion of the current instruction.  The NXM bit
; in this register reflects the state of the NXM flip flop.
;
;  The NXE bit can be read or written, but the NXM bit is read only.  Once set,
; the program MUST EXPLICITLY CLEAR the NXM bit by writing a 0 to NXE and then
; (if desired) writing it with a 1 again.  Note that the NXM flip flop will
; never set as long as the NXE bit is cleared.  The NXE bit is cleared on power
; up, but NOT BY BCLR (i.e. the PDP11 RESET instruction does NOT disable bus
; timeout emulation!).
;--
NXMCSR=	FLAGS+2		; NXM trap emulation register
  NX.REQ=BIT7		;  set when a non-existent memory reference occurs
  NX.ENA=BIT6		;  set to enable NXM trap via HALT


;++
; BIT 15  14  13  12  11  10  9   8   7   6   5   4   3   2   1   0
;   +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;   |   |   |   |   |   |   |   |   |SNS|FLG|   |   |   |   |   |   |
;   +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;		     SPARE FLAG REGISTER (177544)
;
;   This register contains a spare flag bit and a spare sense bit, both of which
; are currently unused in the SBCT11.  The FLG bit is read/write and will be
; cleared by BCLR, and the SNS input is read only.  Both the SNS input and FLG
; output are available on the bus connector, J6.
;--
SPACSR=	FLAGS+4		; "spare" flag/sense register
  SP.SNS=BIT7		;  spare sense input
  SP.FLG=BIT6		;  spare flag output


;++
; BIT 15  14  13  12  11  10  9   8   7   6   5   4   3   2   1   0
;   +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;   |   |   |   |   |   |   |   |   |LTS|LTE|   |   |   |   |   |   |
;   +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;			LTCCSR REGISTER (177546)
;
;   The LTCCSR register contains two bits - LTE (bit 6) is the line time clock
; interrupt enable flag, and LTS (bit 7) is the current status of the clock flip
; flop.  The interrupt enable bit may be set or cleared by writing a 1 or 0 to
; bit 6 of address 177546. The interrupt enable flag may be read back, along
; with the current state of the LTC flip flop, by reading address 177546.  The
; LTS flag is read only and cannot be written. The other bits in this register
; are undefined and should be ignored.
;
;  Note that reading this register WILL NOT CLEAR the LTS flag.  Also note that
; the LTS bit WILL NOT TOGGLE unless the LTE bit is also set. You can always
; avoid LTC interrupts by raising the processor priority to level 7. The LTE
; bit is cleared at power up and by BCLR.  This implementation is a superset of
; the DEC BDV11 and MXV11 implementation (which implement only the LTE bit, and
; that as write only) and a variation of the KPV11.
LTCCSR=	FLAGS+6		; Line time clock control register
  LT.FLG=BIT7		;  set when the LTC ticks
  LT.ENA=BIT6		;  enable LTC interrupts
	.SBTTL	DC319 DLART Definitions

;++
;   Ths SBCT11 has two DC319 DLART serial ports, SLU0 and SLU1.  The DC319
; implements a standard PDP11 DL11/KL11 compatible serial port and makes porting
; real PDP-11 software easy.  SLU0 is usually reserved for the console terminal,
; and SLU1 may be used to a serial printer, a modem, or a TU58.  Both ports are
; "data leads only" and SLU0 supports either a programmable baud rate or a hard
; wired baud rate set by jumpers on the PCB.  SLU1 supports a programmable baud
; rate only, and this must be initialized before it can be used.
;--

; SBCT11 serial port I/O addresses ...
S0RCSR=	SLU0+0		; SLU0 (console) receiver CSR
S0RBUF=	SLU0+2		;  "     "   "     "   "  buffer
S0XCSR=	SLU0+4		;  "     "   "   transmitter CSR
S0XBUF=	SLU0+6		;  "     "   "     "     "   buffer
S1RCSR=	SLU1+0		; SLU1 (TU58) receiver CSR
S1RBUF=	SLU1+2		;  "     "      "   "  buffer
S1XCSR=	SLU1+4		;  "     "    transmitter CSR
S1XBUF=	SLU1+6		;  "     "      "     "   buffer

; DC319 DLART receiver CSR bits ...
DL.RAC=	BIT11		; receiver active (R/O)
DL.RDN=	BIT7		; receiver done (R/O)
DL.RIE=	BIT6		; receiver interrupt enable (R/W)

; DC319 DLART receiver buffer bits (all are R/O!) ...
DL.RER=	BIT15		; logical OR of all error bits
DL.ROV=	BIT14		; overrun error
DL.RFR=	BIT13		; framing error
DL.RBK=	BIT11		; break detect

; DC319 DLART transmitter CSR bits ...
DL.XRY=	BIT7		; transmitter ready (R/O)
DL.XIE=	BIT6		; transmit interrupt enable (R/W)1
DL.BRS=	BIT3!BIT4!BIT5	; programmable baud rate
  DL0300=	      0	;   300 baud
  DL0600=          BIT3	;   600 baud
  DL1200=     BIT4	;  1200 baud
  DL2400=     BIT4!BIT3	;  2400 baud
  DL4800=BIT5		;  4800 baud
  DL9600=BIT5!     BIT3	;  9600 baud
  DL1920=BIT5!BIT4	; 19200 baud
  DL3840=BIT5!BIT4!BIT3	; 38400 baud
DL.MNT=	BIT2		; maintenance mode (R/W)
DL.PBE=	BIT1		; programmable baud rate enable (R/W)
DL.XBK=	BIT0		; transmit break (R/W)
	.SBTTL	82C55 PPI Definitions

;++
;   The SBCT11 has a single 82C55 PPI ("programmable peripheral interface") chip
; that's used to implement an 8 bit parallel bidirectional I/O port with full
; handshaking, and also for driving the POST and RUN LEDs on the SBCT11 board
; itself.  Because of the way the SBCT11 hardware is wired up the primary use
; for the PPI is to implement a Centronics compatible parallel printer port,
; however it can also be used to implmement a general purpose 8 bit parallel
; bidirectional port with full handshaking and even DCT11 interrupts.  
;
;	PPI	DIR	USAGE
;	-----	---	-----------------------------------
;	PB0-3	OUT	TIL311 POST code display
;	PB4	OUT	RUN LED (1=>ON, 0=>OFF)
;	PB5	OUT	no connection
;	PB6	OUT	PRINTER SELECT IN
;	PB7	OUT	PRINTER INIT
;	PC0	IN	PRINTER PAPER END
;	PC1	IN	PRINTER SELECT
;	PC2	IN	PRINTER ERROR
;	PC3	OUT	DCT11 PPI IRQ
;	PC4	OUT	STBA / PRINTER BUSY
;	PC5	OUT	IBFA / PRINTER AUTO LF
;	PC6	OUT	ACKA / PRINTER ACK
;	PC7	OUT	OBFA / PRINTER STROBE
;	PA0-7	INOUT	PRINTER DATA0-7
;
;   The "standard" PPI configuration is mode 2 (bidirectional, full handshake)
; for port A and mode 0 (simple output) for port B.  The user's software can
; change this, and as there are no buffers between the PPI and the parallel port
; connector, so the way you wire it up to an external device is pretty much
; arbitrary.  
;
;   HOWEVER, if you change the mode of port B to input, or if you mess with the
; lower five bits of port B as an output, then you'll screw up the POST display
; and/or the RUN LED.  That's just cosmetic and doesn't actually interfere with
; the operation of the SBCT11.
;--

; SBCT11 parallel port I/O addresses ...
PPIA=	PPI		; port A address for the 82C55
PPIB=	PPI+2		; PPI port B
PPIC=	PPI+4		; PPI port C
PPICSR=	PPI+6		; PPI control and status register

; PPI mode selection bits ....
PP.MSE=	BIT7		; must be set to enable mode selection
PP.MD2=	BIT6		; select mode 2 (PPIMDA is ignored)
PP.MDA=	BIT5		; select port A mode 1
PP.AIN=	BIT4		; port A is an input
PP.CUI=	BIT3		; port C bits 4-7 are inputs
PP.MDB=	BIT2		; select port B mode 1
PP.BIN=	BIT1		; port B is an input
PP.CLI=	BIT0		; port C bits 0-3 are inputs

; PPI port C bit set/reset controls ...
PP.BIS=	BIT0		; set the selected bit
PP.BIC=	0		; clear "   "   "   "
PP.PC7=	BIT3!BIT2!BIT1	; PC7
PP.PC6=	BIT3!BIT2	; PC6
PP.PC5=	BIT3!     BIT1	; PC5
PP.PC4=	BIT3		; PC4
PP.PC3=	     BIT2!BIT1	; PC3
PP.PC2=	     BIT2	; PC2
PP.PC1=	          BIT1	; PC1
PP.PC0=	             0	; PC0

; "Standard" PPI mode - port A bidirectional, port B output, and PC0-3 input.
PPIMOD=	PP.MSE!PP.MD2!PP.CLI

; Special port C bits in mode 2 ...
PP.OBF=	BIT7		; output buffer full
PP.IE1=	BIT6		; interrupt enable 1 (OBF interrupts)
PP.IBF=	BIT5		; input buffer full
PP.IE2=	BIT4		; interrupt enable 2 (IBF interrupts)
PP.INT=	BIT3		; master interrupt request

; Special mode 2 commands (written to PPICSR) ...
PP.SE1=	PP.BIS!PP.PC6	; set INTE1
PP.CE1=	PP.BIC!PP.PC6	; clear "
PP.SE2=	PP.BIS!PP.PC4	; set INTE2
PP.CE2=	PP.BIC!PP.PC4	; clear "
	.SBTTL	DS12887 Real Time Clock Definitions

;++
;   The SBCT11 has a single DS12887A real time clock and non-volatile RAM chip.
; This is the same chip that was used in the classic PC/AT to save the CMOS
; settings and keep track of the time.  The DS12887 looks something like a
; memory chip to the CPU, with a total of 128 bytes.  The first 10 bytes keep
; track of the time and date; the next four bytes are control and status
; registers, and the remaining 114 bytes are general purpose memory.  The time
; and status bytes are updated automatically by the DS12887 as time passes, and
; the general purpose RAM bytes can be used for whatever we want.  This code
; uses some of the to store settings (e.g. baud rates, boot flags, etc) and the
; remainder are available to the user's programs.
;
;   The SBCT11 maps the DS12887 into the DCT11 I/O space as an address port and
; two data ports, one read/write and write only.  The software should write the
; desired RTC/NVR register address (0..127) to the RTCAS location, and then it
; can read or write the contents of that RTC register by accessing the RTCRD
; or RTCWR locations.  Even though the DS12887 is effectively just a 128 byte
; SRAM chip, it's not mapped into the DCT11 address space as a block of memory
; locations.  It proved to be too hard to do that and still meet the DS12887
; timing requirements.  Besides, nobody needs fast access to the RTC/NVR anyway.
;
;   Note that there was a slight error (don't ask!) in the revision B SBCT11
; PC boards, and the DS12887 is actually connected to DAL1-8.  This means that
; all addresses and data need to be left shifted by one bit.  In the revision C
; PC boards this was fixed and the DS12887 is properly connected to DAL0-7.
; In the revision C boards you can use byte instructions (e.g. MOVB) to access
; the DS12887 address and data registers, but in revision B you cannot.
;
;   The RTC/NVR didn't work at all in the revision A PCBs.
;--

; These PDP11 memory locations are the only access to the DS12887...
RTCRD=	RTC+0		; read data from the DS12887
RTCWR=	RTC+2		; write data to the DS12887
RTCAS=	RTC+6		; load the DS12887 address

; Time and date registers ...
RTC.SC=	0.		; current time - seconds
RTC.AS=	1.		; alarm time   - seconds
RTC.MN=	2.		; current time - minutes
RTC.AM=	3.		; alarm time   - minutes
RTC.HR=	4.		; current time - hours
RTC.AH=	5.		; alarm time   - hours
RTC.DW=	6.		; day of week (Sunday=1)
RTC.DY=	7.		; day of month (1..31)
RTC.MO=	8.		; month (1..12)
RTC.YR=	9.		; year (0..99)

; Control and status registers ...
RTC.A=	10.		; register "A" 
  RT.UIP=BIT7		;  update in progress bit
  RT.DV2=BIT6		;  oscillator control bit
  RT.DV1=BIT5		;    "    "     "  "   "
  RT.DV0=BIT4		;    "    "     "  "   "
  RT.DVM=BIT4!BIT5!BIT6	; mask of all DVx bits
  RT.RSB=017		; square wave output rate selection
RTC.B=	11.		; register "B"
  RT.SET=BIT7		;  inhibit updates while setting clock
  RT.PIE=BIT6		;  periodic interrupt enable
  RT.AIE=BIT5		;  alarm interrupt enable
  RT.UIE=BIT4		;  update interrupt enable
  RT.SQE=BIT3		;  square wave enable
  RT.DM= BIT2		;  (binary) data mode
  RT.24H=BIT1		;  24 hour mode
  RT.DSE=BIT0		;  daylight savings time enable
RTC.C=	12.		; register "C"
  RT.IRQ=BIT7		;  logical OR of PF, AF and UF
  RT.PF= BIT6		;  periodic interrupt request
  RT.AF= BIT5		;  alarm interrupt request
  RT.UF= BIT4		;  update interrupt request
RTC.D=	13.		; register "D"
  RT.VRT=BIT7		;  valid RAM and TIME bit (battery OK)

; The remainder of the DS12887 memory is general purpose RAM ...
RTC.RM=	14.		; first free RAM location
RTC.SZ=	128.		; total RAM size (counting the clock registers!)
	.SBTTL	Non-volatile RAM Storage Map

;++
;   The non-volatile general purpose RAM part of the DS12887A chip is used to
; store various monitor options and settings - e.g. NXM trapping, LTC enable,
; boot device, etc.  The NVR settings are protected by a checksum word, which
; is used to validate the RAM's contents.
;
;   Note that the useful RAM area in the DS12887A is 114 bytes, starting at
; offset RTC.RM and ending at RTC.SZ!
;--

; Useful stuff stored in NVR ...
			; DON'T USE LOCATION RTC.RM!
NV.VER=	RTC.RM+1	; NVR version number
  NVRVER=1		;  ... this is bumped whenever the NVR layout changes
NV.LTC=	NV.VER+1	; 1 ==> LTC enabled, 0 ==> disabled
NV.NXM=	NV.LTC+1	; 1 ==> NXM trapping enabled, 0 ==> disabled
NV.BDV=	NV.NXM+1	; default boot device (ASCII, two bytes!)
NV.BUN=	NV.BDV+2	; boot device unit (16 bits!)
NV.FRE= NV.BUN+2	; next free
NV.CHK= RTC.SZ-2	; NVR checksum


;++
;   The $RDNVR and $WRNVR macros read and write single bytes from or to the NVR.
; Because of a layout error in the revision B PCBs these actually call a
; subroutine to do the job, but in the next revision it should be possible to
; do this directly inline.
;--

; Read a byte from NVR ...
	.MACRO	$RDNVR	ADDR, DATA
	.IF	DIF	ADDR, R2
	MOV	ADDR, R2
	.ENDC
	CALL	RDNVRB
	.IF	DIF	DATA, R1
	MOVB	R1, DATA
	.ENDC
	.ENDM

; Write a byte to NVR ...
	.MACRO	$WRNVR	DATA, ADDR
	.IF	DIF	ADDR, R2
	MOV	ADDR, R2
	.ENDC
	.IF	DIF	DATA, R1
	MOVB	DATA, R1
	.ENDC
	CALL	WRNVRB
	.ENDM

;   This routine "idles" NVR.  In reality the hardware doesn't need us to do
; anything special when we're done using NVR, but there is a potential problem.
; If a user program (or mine, for that matter) goes nuts and accidentally writes
; to the RTCWR address, it will corrupt the last NVR location addressed.  To
; prevent this, everytime we're done using NVR we load the NVR address register
; with a read only address - RTC.D is a good choice.  Then if some errant code
; accidentally writes to the NVR, nothing will happen.
	.MACRO	$NONVR
	MOV	#<RTC.D*2>, @#RTCAS
	.ENDM
	.SBTTL	IDE Definitions

;++
;   The SBCT11 implements a very simple ATA/IDE hardware interface (it doesn't
; really need to be complicated, since the drive does all the work!).  The
; standard ATA interface implements two blocks of eight registers each, and
; the interface has a separate select/enable signal for each one, called CS1FX
; and CS3FX.  The CS1FX register set is the primary one and the CS3FX register
; set is rarely used.
;
;   In principle all ATA registers are 16 bits wide, however in reality only
; the data register uses all 16 bites and all the rest are limited to 8 bits.
; ATA presents a unique problem in that reading some ATA registers will clear
; certain bits once they're read - this presents a problem because the DCT11
; ALWAYS reads a memory location before writing to it.  It's impossible to
; write to a memory location without first reading it, and with ATA that can
; have unexpected side effects.  To work around this the SBCT11 sets aside a
; two distinct address spaces for the ATA register set - the first address
; space being read/write and the second is write only.  The latter explicitly
; inhibits any read operations to defeat the DCT11 "read before write" problem.
;
;   Lastly, note that ATA supports a number of DMA modes and options, NONE of
; which are implemented on the SBCT11.  Programmed I/O is the only data transfer
; mode possible.  Sorry!   Interrupts however are implemented and can be used
; to interrupt the DCT11 when the drive is ready for another command.
;--

; Classic IDE register definitions...
;   Note that, since all registers are theoretically 16 bits, LAL0 isn't used
; and all addresses are even.  ATA doesn't support byte operations, and using
; PDP11 byte instructions to access the ATA address space probably isn't going
; to lead to happy results.  LAL1, 2 and 3 select the specific ATA register.
; LAL4 selects CS1FX (LAL4=1) or CS3FX (LAL4=0), and LAL5 selects the read/write
; space (LAL5=0) or the write only space (LALA5=1).  All told, we use up 64
; bytes (32 words) for the ATA address space...
IDEWRO=	BIT5			; inhibit any read before write
IDE1FX=	BIT4			; select the CS1FX address space
IDE3FX=	0			;   "     "  CS3FX   "  "    "
IDEDAT=	IDE+IDE1FX+<2*0>	; data register (R/W)
IDESCT=	IDE+IDE1FX+<2*2>	; sector count register (R/W)
IDELB0=	IDE+IDE1FX+<2*3>	; LBA byte 0 (or sector number)
IDELB1=	IDE+IDE1FX+<2*4>	; LBA byte 1 (or cylinder low)
IDELB2=	IDE+IDE1FX+<2*5>	; LBA byte 2 (or cylinder high)
IDELB3=	IDE+IDE1FX+<2*6>	; LBA byte 3 (or device/head)
;   Notice that the status register and the command register have the same
; address!  This is the classic case where we have to differentiate between a
; read operation and a write.  The same holds true for the error register and
; the features register ...
IDECMD=	IDE+IDEWRO+IDE1FX+<2*7>	; command register (W/O)
IDESTS=	IDE+IDE1FX+<2*7>	; status register (R/O)
IDEFEA= IDE+IDEWRO+IDE1FX+<2*1>	; features regiter (W/O)
IDEERR=	IDE+IDE1FX+<2*1>	; error register (R/O)
; "Alternate" registers in the CS3FX space ...
IDEAST= IDE+IDE3FX+<2*6>	; alternate status register (R/O)
IDECTL= IDE+IDEWRO+IDE3FX+<2*6>	; device control register

; IDE status register (IDESTS) bits...
ID.BSY=	BIT7		; busy
ID.RDY=	BIT6		; device ready
ID.DF=	BIT5		; device fault
ID.DSC=	BIT4		; device seek complete
ID.DRQ=	BIT3		; data request
ID.COR=	BIT2		; corrected data flag
ID.IDX= BIT1		; index mark
ID.ERR= BIT0		; error detected

; IDE error register (IDEERR) bits ...
ID.BBK= BIT7		; bad block
ID.UNC= BIT6		; uncorrectable data error
ID.MC=  BIT5		; media changed
ID.INF= BIT4		; ID mark not found
ID.MCR=	BIT3		; media change requested
ID.ABT= BIT2		; command aborted
ID.0NF= BIT1		; track 0 not found
ID.ANF= BIT0		; address mark not found

; IDE command codes (or at least the ones we use!)...
ID$EDD=	220		; execute device diagnostic
ID$IDD=	354		; identify device
ID$RDB= 344		; read buffer
ID$RDS=	040		; read sectors with retry
ID$WRB=	350		; write buffer
ID$WRS=	060		; write sectors with retry
;ID$SUP=341		; spin up
;ID$SDN=340		; spin down

; Device Control register (IDECTL) bits ...
ID.RST=	BIT2		; software reset
ID.NIE=	BIT1		; interrupt enable (WHEN 0!!)

; Drive/Head register (IDELB3) bits ...
ID.LBA=	BIT6		; logical block addressing mode
ID.SLV=	BIT4		; select the slave drive

; Magic offsets in the IDENTIFY DEVICE response ...
ID$MOD=	27.*2		; model name/number in ASCII
ID$MDL=	<46.-27.+1>*2	; model name/number length in bytes
ID$LBA=	60.*2		; double word giving total number of sectors

; Other IDE/ATA constants ...
DSKBSZ=512.		; IDE block size (always 512 bytes!)
IDETMO=2.		; drive timeout, in seconds (see WREADY!)
	.SBTTL	TU58 RSP Definitions

;   The SBCT11 supports booting from a TU58 drive connected to the secondary
; serial port, SLU1.  The TU58 speaks a DEC defined protocol known as RSP, or
; "Radial Serial Protocol".  As far as I know it's the ONLY thing to ever use
; this protocol, but if we want to boot from it we have to know how to talk to
; it.
;--

; RSP packet types
;   in the TU58 documentation, these are referred to as "flags"!
TU.DAT=	BIT0		; data packets for read/write
TU.CTL=	BIT1		; control (command) packet
TU.INI=	BIT2		; forces controller initialization
TU.BOO=	BIT3		; sends unit 0/block 0 w/o RSP
TU.CON=	BIT4		; continue with the next data packet

; RSP command opcodes ...
TU$NOP=	 0.		; no operation (returns an END packet)
TU$RD=	 2.		; reads data from the tape
TU$WR=	 3.		; writes data to the tape
TU$POS=	 5.		; positions the tape at a given block
TU$DIA=	 7.		; executes built in self test
TU$END=	64.		; acknowledgement (end) packet type

; RSP command modifiers ...
TU.SAM=	BIT7		; selects special addressing mode
TU.RCK=	BIT0		; decreased sensitivity (read command)
TU.MRS=	BIT3		; switches MRSP mode ON

; RSP end packet error codes ...
;   Note that the error codes are all negative and must be sign extended!
TU$SUC=	  0.		; operation completed without errors
TU$WRT=	  1.		; success, but retries were needed
TU$PST=	 -1.		; self test failed
TU$EOT=	 -2.		; partial operation - end of tape
TU$UNI=	 -8.		; unit number not 0 or 1
TU$NOT=	 -9.		; no cartridge in drive
TU$WLK=	-11.		; tape is write protected
TU$CH=	-17.		; bad data (checksum failure)
TU$SER=	-32.		; block not found (bad tape format?)
TU$JAM=	-33.		; motor stopped (jammed cartridge?)
TU$OPC=	-48.		; bad opcode in command packet
TU$BLK=	-55.		; block number > 511

; Other TU58 related constants
TUMAXB=	512.		; maximum TU58 block number
TUTMO=	20.		; TU58 timeout in 100ms units
TUBAUD=	DL.PBE!DL3840	; default TU58 baud rate
	.SBTTL	RT11 Directory Definitions

; TBA!!!
	.SBTTL	Memory Mapping Macros

;++
;   The SBCT11 has a full 32KW (that's 64K bytes!) of RAM and also a full 32KW
; of ROM/EPROM.  The DCT11 has no MMU and the address space is limited to 16
; bits or 64K bytes.  That means either the RAM or the ROM alone would be enough
; to fill the entire address space, so without some kind of mapping scheme it
; would be impossible to use all of both.
;
;   The SBCT11 has a pretty trivial mapping scheme controlled by a single bit,
; the MC.RAM bit in the MEMCSR.  When set this bit enables the (mostly) RAM
; memory map and when cleared this bit enables the mostly EPROM memory map.  
;
;	ADDRESS RANGE	MC.RAM=1 MC.RAM=0      SIZE
;	--------------	-------- -------- ---------
;	000000..001777	RAM	 RAM	   1K bytes
;	001000..167777	RAM	 EPROM	  59K bytes
;	170000..175777	EPROM	 EPROM	   3K bytes
;	176000..176377	RAM	 RAM	  256 bytes
;	176400..177777	IOPAGE	 IOPAGE   768 bytes
;
;   Notice that the 59K byte block froom 001000 to 167777 is the only part
; that's affected by the MC.RAM bit.  The first 1K bytes are always mapped to
; RAM for vectors and a temporary disk/TU58 buffer.  The section from 170000 to
; 175777 is always mapped to EPROM.  This is used for startup code and for
; subroutines that need to be accessible in either mapping mode.  
;
;   The block of RAM from 176000 to 176377 is reserved specifically for use by
; this monitor as scratch space and, although it's always accessible, user 
; programs shouldn't mess with it.  And lastly, addresses from 176400 and up
; are reserved for I/O devices.  The current SBCT11 I/O map looks like this
;
;	ADDRESS		DEVICE
;	--------------	----------------------------------
;	176400..176477	IDE
;	176500..176507	SLU1 (TU58) secondary serial port
;	176560..176577	SPARE select
;	177400..177417	PPI (82C55) parallel interface
;	177420..177437	DS12887 RTC/NVR chip
;	177540..177547	MEMCSR, NXMCSR, SPACSR and LTCCSR
;	177560..177567	SLU0 (CONSOLE) primary serial port
;
;   SLU0 (console) and SLU1 (TU58) have standard PDP11 I/O addresses.  And the
; LTCCSR is BDV11/KPV11 compatible and has the standard address.
;
;  One last comment - THERE IS NO ADDRESS TRANSLATION HARDWARE in the SBCT11!
; RAM and EPROM are both addressed from 000000 to 177777 and that never changes.
; If the T11 outputs address 012345 then address 012345 is applied to both the
; RAM and EPROM chips.  The only thing that the RAM MAP signal changes is which
; memory chips are selected.
;--

;++
;   The $ROM macro always selects ROM mapping mode and $RAM selects RAM.  The
; $SAVMAP macro saves the current mapping flag in the H.PRAM bit of the HFLAGS
; word, and the $RSTMAP macro restores the saved mapping mode.  These last two
; are handy for unmapped ROM routines that can be called with either mode in
; effect.
;
;   NONE of these should be called from the mapped portion of EPROM.  Calling
; $RAM or $RSTMAP from mapped EPROM would be disastrous, and calling $ROM or
; $SAVMAP would be pointless.
;--

; Select ROM mode by clearing the MC.RAM bit in MEMCSR ...
	.MACRO	$ROM
	CLR	@#MEMCSR
	.ENDM

; Select RAM mode by setting the MC.RAM bit in MEMCSR ...
	.MACRO	$RAM
	MOV	#MC.RAM, @#MEMCSR
	.ENDM

; Save the current memory mapping mode ...
	.MACRO	$SAVMAP	;;?LBL
	MOV	@#MEMCSR, -(SP)
	.ENDM
;;	BIC	#H.PRAM, HFLAGS
;;	BIT	#MC.RAM, @#MEMCSR
;;	BEQ	LBL
;;	BIS	#H.PRAM, HFLAGS
;;LBL:

; Restore the previous mapping mode ...
	.MACRO	$RSTMAP	;;?LBL
	MOV	(SP)+, @#MEMCSR
	.ENDM
;;	CLR	@#MEMCSR
;;	BIT	#H.PRAM, HFLAGS
;;	BEQ	LBL
;;	MOV	#MC.RAM, @#MEMCSR
;;LBL:
	.SBTTL	Other Useful Macros

; Display the specified POST code ...
	.MACRO	$POST	CODE
	BIC	#PC.PST, @#PPIB
	BIS	#<CODE>&PC.PST, @#PPIB
	.ENDM

; Define a PDP11 trap/interrupt vector ...
	.MACRO	$VEC	NAME, ADDR
.=ADDR
NAME:	.BLKW	2
	.ENDM

;   MACRO-11 recognizes "CALL" and "RETURN" as synonyms for "JSR RC," and
; "RTS PC,", but annoyingly it doesn't seem to know PUSH or POP.  This is
; too useful to pass up, so I'll make my own...
	.MACRO	$PUSH	LIST
	.IRP	$$X, <'LIST>
	MOV	$$X, -(SP)
	.ENDR
	.ENDM

;   And here's the complementary version.  BE CAREFUL with the order of the
; arguments - $PUSH and $POP both process the argument list from left to 
; right, so when you call $POP you'll want to reverse the order of $PUSH!
	.MACRO	$POP	LIST
	.IRP	$$X, <'LIST>
	MOV	(SP)+, $$X
	.ENDR
	.ENDM

;   This macro generates programmed delays from 1ms to approximately 1 minute
; (65.535 seconds, actually!).  It depends on the magic constant DLYMS, which
; makes the inner "SOB R0, ." loop take exactly 1ms to complete. Uses R0 and R1.
	.MACRO	$DLYMS	TIME, ?LBL
	MOV	#TIME,  R1
LBL:	MOV	#DLYMS, R0
	SOB	R0, .
	SOB	R1, LBL
	.ENDM

; Print a single character on the console ...
	.MACRO	$TYPE	CH
	MOV	#CH, R0
	CALL	OUTCHR
	.ENDM

; Print out an inline message on the console ...
	.MACRO	$MSG	TEXT
	JSR	R1, INLMES
	.ASCIZ	"'TEXT"
	.EVEN
	.ENDM

; Print an error message (just like $MSG, but also aborts the current command!).
	.MACRO	$ERR	TEXT
	JSR	R1, ERRMES
	.ASCIZ	"'TEXT"
	.EVEN
	.ENDM
	.SBTTL	Low RAM and Vector Declarations

;++
;   These symbols define the contents of low RAM addresses and, on the PDP11,
; these are primarily interrupt or trap vectors and the stack space.  Most of
; these are used by the user's program and this code doesn't mess with them,
; but there are a few that are important to us.
;
;   It probably doesn't need to be pointed out, but you CAN'T initialize these
; vectors here!  This code all goes into EPROM and the only way to initialize
; the RAM contents is to write some code to load it!
;--

; Standard DCT11 vectors ...
	$VEC	IINVEC, 004	; illegal instruction
NXMVEC=IINVEC			; bus timeout uses the same vector!
	$VEC	RINVEC, 010	; reserved instruction
	$VEC	BPTVEC, 014	; BPT and T bit trap
	$VEC	IOTVEC, 020	; IOT instruction trap
	$VEC	PFAVEC, 024	; power fail
	$VEC	EMTVEC, 030	; EMT instruction trap
	$VEC	TRPVEC, 034	; TRAP instruction trap

; SBCT11 specific vectors ...
	$VEC	S0RVEC, 060	; SLU0 (console) receive interrupt
	$VEC	S0XVEC, 064	;   "    "   "   transmit  "    "
	$VEC	IDEVEC, 070	; IDE/ATA disk interrupt
	$VEC	LTCVEC, 100	; line time clock interrupt
	$VEC	S1RVEC, 120	; SLU1 (TU58) receive interrupt
	$VEC	S1XVEC, 124	;   "    "    transmit "    "
	$VEC	PPIVEC, 130	; parallel port interrupt

;   This is the maximum possible interrupt vector on the T11.  Most of these
; are not actually used on the SBCT11 and can only occur in the event of some
; massive hardware glitch, but we'll define them just in case...
MAXVEC=376

;   On reset the DCT11 sets SP to point here (remember that PDP11 stacks grow
; downwards!).  This monitor never uses this space, but we will set SP back to
; this location after booting or when running a user program.
.=MAXVEC
USRSTK:	.BLKW	1

;   This is a temporary buffer used for reading disk and TU58 directories,
; identifying IDE/ATA disks, etc.  It needs to be used with caution since we're
; potentially overwriting some user code, but there's nowhere else to put it.
DSKBUF:	.BLKB	DSKBSZ
.=.
	.SBTTL	Monitor Scratch RAM Declarations

;++
;   There's a 256 byte/128 word block of RAM in the I/O page that's reserved for
; this monitor's scratch space.  This RAM is always mapped, regardless of the
; RAM MAP signal, and the user's program should never touch it.  All of our
; private, important, stuff goes here...
;
;   Like low RAM, you can't initialize ANYTHING here.  DON't even try to use
; .WORD or .BYTE directives here - only .BLKW or .BLKB are allowed.  Anything
; that needs to be initialized must be set by the system startup code.
;
;   One last comment - the POST test E (see SYSINI:) always leaves the scratch
; pad RAM zeroed after a successful test.  The default value for many of the
; flag and other control words is zero, so that's important!
;--
.=SCRRAM
BADSUM:	.BLKW	1

;   The monitor uses a number of global flag bits which are separated into two
; groups - "hardware" flags and "software" flags.  The distinction is pretty
; arbitrary and really only exists because there weren't enough bits in a single
; 16 bit word.  BOTH words are initialized to zero on startup!
HFLAGS:	.BLKW	1	; Hardware flags ...
  H.POST=BIT15		;  POST is in progress
;;H.SLU1=BIT14		;  second DLART serial is installed
  H.RTCC=BIT13		;  DS12887 RTC/NVR is installed
  H.DISK=BIT12		;  IDE/ATA disk drive is present
  H.NXME=BIT11		;  enable bus timeout emulation
  H.LTCE=BIT10		;  enable LTC interrupts
;;  H.CCRT=BIT9		;  console terminal is a CRT (scope!)
;;  H.PRAM=BIT8		;  previous memory map was RAM
SFLAGS:	.BLKW	 1	; Software flags ...
  S.XOFF=BIT15		;  output suspended by Control-S
  S.CTLO=BIT14		;  output suppressed by Control-O
  S.STEP=BIT13		;  single step user program
  S.SSBP=BIT12		;  single stepping after a breakpoint
  S.BPTI=BIT11		;  set when breakpoints are installed
  S.NEGV=BIT10		;  negative flag for decimal I/O
  S.ODDB=BIT9		;  odd byte flag for TU58 I/O routines
  S.NULL=BIT8		;  various commands to detect empty lists/results
  S.MMAT=BIT4		;  "minimum match" flag for MATCH:
  S.NMAT=BIT3		;  "no match" flag for MATCH:

;   WHYBRK contains a code giving the reason the user program stopped and 
; control returned to this monitor (e.g. HALT, break point, various traps, etc).
; There's a table of messages at BRKMSG: that must be in the same order!
WHYBRK:	.BLKW	1	; contains one of the following codes -
  B.HALT= 1.		;  halt instruction or halt switch
  B.UBPT= 2.		;  unexpected breakpoint trap
  B.PFAI= 3.		;  power fail
  B.IINS= 4.		;  illegal instruction trap
  B.RINS= 5.		;  reserved instruction trap
  B.EMT=  6.		;  EMT trap
  B.TRAP= 7.		;  TRAP trap
  B.IOT=  8.		;  IOT trap
  B.UINT= 9.		;  unknown interrupt
  B.UTBI=10.		;  unexpected T bit trap
  B.UNXM=11.		;  unexpected NXM trap

; Temporary storage for the INCHWL routine ...
INPMPT:	.BLKW	1	; command line prompting string
INBUFF:	.BLKW	1	; pointer to the line buffer
INMAXC:	.BLKW	1	; length of the caller's buffer

; Saved user registers - keep these consecutive!
;   BTW, THESE MUST STAY IN ORDER!
USRREG:	.BLKW	6	; R0 .. R5
USRSP:	.BLKW	1	; last user stack pointer
USRPC:	.BLKW	1	; last user program counter
USRPS:	.BLKW	1	; and the last user status bits

; Miscellaneous storage ..
RPTCNT:	.BLKW	1	; number of times to repeat this command
RPTPTR:	.BLKW	1	; command line location to repeat from
ADDRLO:	.BLKW	1	; low address returned by RANGE:
ADDRHI:	.BLKW	1	; high   "        "     "   "
SPSAVE:	.BLKW	1	; UCLOAD/UCSAVE save out SP here
UCSRTN:	.BLKW	1	; return address for UCSAVE
DKSIZE:	.BLKW	1	; size of the attached disk drive, in MB!
TUCKSM:	.BLKW	1	; running TU58 checksum total
OPCODE:	.BLKW	1	; base opcode being disassembled
OPMODE:	.BLKW	1	; addressing mode for this opcode
BTUNIT:	.BLKW	1	; unit number for booting
PASSK:	.BLKW	1	; pass count for test routines
FAILK:	.BLKW	1	; failure count for test routines

; Breakpoint storage...
BPTADR:	.BLKW	MAXBPT	; address assigned to each breakpoint
BPTDAT:	.BLKW	MAXBPT	; original data at the breakpoint
BPTEND=BPTADR+<2*MAXBPT>; end of the breakpoint address table

; WARNING - the following variables are all byte aligned!!!

; Temporary buffer for storing the date and time ...
TIMBUF:	.BLKB	7	; see GETTOD/SETTOD for the format

; Our own command line buffer ...
CMDBUF:	.BLKB	MAXCMD+1; "+1" to allow for the null terminator!

;   Lastly, our own stack starts at the end of our private RAM space and grows
; down.  Hopefully it'll never overlap any of the above variables - the DCT11
; has no stack overflow trap!
MONSTK=SCRTOP+1-2
STKLEN=MONSTK-.+2
	.IF	LT, STKLEN-100
	.ERROR	STKLEN ; MONITOR STACK TOO SMALL
	.ENDC
	.SBTTL	System Initialization and POST, Part 2

;++
;   We get here after the first part system initialization, SYSINI has finished.
; At this point the EPROM, RAM (both user and scratch pad), and the memory map
; hardware have all been tested.  The monitor's scratch RAM has been initialized
; to all zeros and we have a working stack.  The next job is to test the
; remaining hardware, DLARTs, PPI, LTC, RTC/NVR, and the IDE/ATA disk.  Once the
; POST has been completed we'll be ready to start up the command scanner.
;--
.=ROMBS0

;   The copyright notice always appears in plain ASCII near the beginning of
; the EPROM.  We don't want it to be hard to find, after all!
SYSTEM:	.ASCIZ	/SBCT11 ROM MONITOR V/
RIGHTS:	.ASCIZ	/Copyright (C) 2021 by Spare Time Gizmos.  All rights reserved./
SYSDAT:	.include /sysdat.asm/
	.EVEN

;   This part of the POST tests interrupts and runs with interrupts enabled.
; Each test installs its own interrupt handler for the duration of that test,
; and any unexpected interrupts will spin forever in the UCSAVE code because
; the H.POST flag is set.  POST A (10.), below, will occur as soon as we lower
; the priority level if there are any unexpected interrupts active right now.
SYSIN2:	$POST	PC.INT		; unexpected interrupt
	BIS	#H.POST, HFLAGS	; tell UINTRQ that the POST is in progress
	CALL	INIVEC		; initialize all interrupt vectors
	MTPS	#PS.PR0		; accept any and all interrupts

; Test the console (SLU0) DLART ...
	$POST	PC.SL0		; testing SLU0
	MOV	#SLU0, R2	; CSR address for SLU0
	MOV	#S0RVEC, R3	; vector address for SLU0
	CALL	SLUTST		; go test it

; Test the TU58 (SLU1) DLART ...
	$POST	PC.SL1		; testing SLU1
	MOV	#SLU1, R2	; CSR address
	MOV	#S1RVEC, R3	; interrupt vector
	CALL	SLUTST		; and test it!

; Test the line time clock ...
	$POST	PC.LTC		; testing LTC
	CALL	LTCTST		; ...

; Test the 8255 PPI ...
	$POST	PC.PPI		; testing PPI
	CALL	PPITST		; ...

; Test the DS12887 RTC/NVR ...
	$POST	PC.RTC		; testing RTC/NVR
	CALL	RTCTST		; ...

; Test the IDE/ATA disk interface and drive ...
	$POST	PC.IDE		; testing disk drive
	CALL	IDETST		; ...

; All done with the self testing!
	MTPS	#PS.PR7		; disable interrupts now
	BIC	#H.POST, HFLAGS	; and we're no longer doing the POST
	JMP	SYSIN3		; go finish starting up the monitor
	.SBTTL	DLART Serial Line Unit Tests
;++
;   This routine does a simple test on the DLART in loopback mode.  It tests
; the ability to send and receive data; the ability to send and receive breaks
; (essential for the TU58!) and also the ability of both the receiver and the
; transmitter to generate interrupts.  It works on either SLU, and the base
; CSR address as well as the base interrupt vector address are passed in R2 and
; R3.
;
; 	<R2 contains SLU base address (e.g. 176500)>
;	<R3 contains the SLU vector address (e.g. 060)>
;	CALL	DLPOST
;	<return if success; never return if failure!>
;--

;   Enable loopback mode on the DLART and initialize the baud rate.  The console
; normally has a hardwired baud rate and this will be ignored, however SLU1 does
; not and the tests won't pass without this!
SLUTST:	MOV	#DL9600!DL.PBE!DL.MNT, 4(R2)	; set baud and maint clear IE
	CLR	(R2)				; clear receiver IE
	TST	2(R2)		; clear the receiver buffer

;   An annoying feature of the DLART chips is that, even in maintenance mode,
; the transmitter output is still active.  Maintenance/loopback mode only
; affects the receiver input, so anything we transmit in testing will actually
; still go to the console terminal!  Because of that we limit ourselves to
; sending just two characters, "*" (ASCII 52 octal) and "U" (ASCII 125 octal).
; These are alternating bit patterns and will have to do.
	MOV	#52, R0		; load the first test pattern
	CALL	SLUTS1		; and test that
	MOV	#125, R0	; then test the alternate pattern
	CALL	SLUTS1		; ...

;   Restore the original interrupt vectors and disable SLU interrupts. Note that
; we deliberately do it in this order - even if the DONE and IE bits are set in
; the SLU it should not cause a second interrupt, and we want to test that!
	MOV	#UINTRQ,  (R3)	; restore both interrupt vectors
	MOV	#UINTRQ, 4(R3)	;  ... to the default
	MTPS	#PS.PR0		; re-enable interrupts
	BIC	#DL.RIE, (R2)	; disable receiver interrupts
	BIC	#DL.XIE, 4(R2)	; disable additional transmitter interrupts

;   For SLU1 we also test sending and receiving breaks, which are required for
; the TU58.  We'd like to test breaks on the console SLU0 too, but those cause
; a HALT and we've no easy to trap that during the POST.  Well, OK - we could
; do it if we wanted to bad enough, but I'm lazy...
	CMP	R2, #SLU0	; is this the console SLU?
	BEQ	90$		; yes - skip this part

; Try sending a break ...  Note that this test doesn't use interrupts.
	BIS	#DL.XBK, 4(R2)	; set the break enable bit
	MOV	#8., R0		; send 8 null bytes
20$:	MOVB	#0, 6(R2)	; ...
25$:	TSTB	4(R2)		; transmitter ready again?
	BPL	25$		; no - wait
	SOB	R0, 20$		; send all 8

; Now test that the receiver has DONE, ERROR and BREAK all set ...
	TSTB	(R2)		; receiver done should be set
	BPL	.		; spin if not
	TST	2(R2)		; the master error bit should be set
	BPL	.		; spin if not
	BIT	#DL.RBK, 2(R2)	; as well as the break received bit
	BEQ	.		; spin forever if not

; We're done testing - clear the maintenance and break bits annd return ...
90$:	MOVB	#DL9600!DL.PBE, 4(R2)	; clear IE and maintenance, set baud
	CLR	(R2)			; clear IE
	TST	2(R2)		; be sure no junk is left in the buffer
	RETURN			; done testing the DLART


;++
;   This local routine tests send and receiving one character, including testing
; the associated transmitter and receiver interrupts.  If there's a problem, it
; never returns!  The character to transmit is passed in R0, and R2/R3 contain
; the CSR and vector addresses as usual...
;--
SLUTS1:	MOV	#90$,  (R3)	; setup both interrupt vectors to spin
	MOV	#90$, 4(R3)	;  ... forever if they're called
	MTPS	#PS.PR0		; be sure interrupts are enabled
10$:	TSTB	4(R2)		; wait for the transmitter done to be set
	BPL	10$		;  ... this should NOT interrupt yet
	MOVB	R0, 6(R2)	; transmit a byte
	MOV	#20$, 4(R3)	; change the transmitter vector
	BIS	#DL.XIE, 4(R2)	;  ... and interrupt when we're done
	BR	.		; spin here until interrupt
; The transmitter is done ...
20$:	CMP	(SP)+, (SP)+	; tranmitter interrupt occurred - fix the stack
	MOV	#90$, 4(R3)	; and redirect the transmitter vector
; Even though DONE and IE are both still set, this should NOT interrupt again!
	MTPS	#PS.PR0		; enable interrupts
	MOV	#30$, (R3)	; change the receiver vector
	BIS	#DL.RIE, (R2)	; and turn on receiver interrupts
	BR	.		; wait for an interrupt
; The receiver is done ...
30$:	CMP	(SP)+, (SP)+	; fix the stack
	MOV	#90$, (R3)	; point to the dead end vector again
	MTPS	#PS.PR0		; this should NOT interrupt again!
	TSTB	(R2)		; the receiver done flag should be set now
	BPL	.		; spin forever if not
;  Use a CMP here rather than CMPB to ensure that the error bits are all clear!
	CMP	R0, 2(R2)	; did we receive what we sent?
	BNE	.		; nope - failure
	BIC	#DL.RIE, (R2)	; disable receiver interrupts
	BIC	#DL.XIE, 4(R2)	; disable additional transmitter interrupts
	RETURN			; and we're done

; This pseudo-interrupt routine simply loops forever!
90$:	BR	.
	.SBTTL	Line Time Clock Tests

;++
;   This routine tests the 60Hz line time clock on the SBCT11.  The 60Hz signal
; is generated by the console DLART from the baud rate clock and is independent
; of any power line frequencies (so, people in Europe still get 60Hz with the
; SBCT11!).  This test doesn't check the frequency exactly, however it will fail
; if the clock is way out of specification.
;
;   The LTC is controlled by the LTCS register at 177546 which contains only two
; bits - bit 6, LTE, enables the LTC interrupts, and bit 7, LTS, is the status
; of the LTC "tick" flag.  Clearing bit 6 prevents the LTC from ticking and
; disables LTC interrupts.  Bit 7 will be set whenever an LTC interrupt has been
; requested but not yet granted.  LTC interrupts "self clear" - the DCT11 IACK
; cycle for the LTC will automatically clear the LTC IRQ.  The ISR doesn't need
; to do anything to clear the request, and in fact the LTS bit is read only.
;--
LTCTST:	CLR	@#LTCCSR	; be sure the LTC is disabled
	MOV	#90$, @#LTCVEC	; and point the vector to a dead end routine
	MTPS	#PS.PR0		; enable interrupts
	$DLYMS	100.		; wait a while, but nothing should happen
	MOV	#10$, @#LTCVEC	; change to a real vector now
	BIS	#LT.ENA,@#LTCCSR; enable the LTC
	BR	.		; wait for a tick

; Here when the clock ticks - it should not interrupt again for another 16.67ms!
10$:	CMP	(SP)+, (SP)+	; fix the stack after the interrupt
	MOV	#90$, @#LTCVEC	; point to the dead end vector again
	MTPS	#PS.PR0		; and enable interrupts
	$DLYMS	4.		; make sure it doesn't interrupt immediately
	MOV	#20$, @#LTCVEC	; wait for another tick just to be sure
	BR	.		;  ... that it's really ticking

; Here when we're sure the clock is working ...
20$:	CMP	(SP)+, (SP)+	; fix the stack
	CLR	@#LTCCSR	; disable the LTC
	MOV	#UINTRQ,@#LTCVEC; restore the original vector
	MTPS	#PS.PR0		; re-enable interrupts
	RETURN			; and we're done

; This pseudo-interrupt routine simply loops forever!
90$:	BR	.
	.SBTTL	Programmable Parallel Interface (82C55) Tests

;++
;   This routine will test the 82C55 PPI on the SBCT11.  Testing this gizmo is a
; bit tricky because we can't assume there's a loop back connector or anything
; else special on the parallel port.  Worse, we can't write to port A and 
; expect to read back what we just wrote.  Writing port A in mode 2 sets the 
; output latch, but reading it reads the input latch.  They're not the same!
; Port C is a similar problem because all the handshaking bits can't be written
; directly and the remaining three bits are inputs.  Reading port C gets us the
; current flag status, but writing it does nothing.
;
;   Still, we can do a few things.  We can manually control the IBFA and OBFA
; flags with the bit set/reset function of port C, and we can test that writing
; the output port sets the OBFA bit, and that reading the input port clears the
; IBF bit.  And we can test interrupts to see that both IBFA and OBFA can cause
; a DCT11 interrupt with the correct PPI vector.
;--
PPITST:	MOVB	#16, @#PPICSR	; clear OBF
	MOVB	#12, @#PPICSR	; clear IBF
	MOVB	#PP.CE1,@#PPICSR; clear INTE1
	MOVB	#PP.CE2,@#PPICSR; clear INTE2
	MTPS	#PS.PR7		; DISABLE interrupts until we're ready!

; The INTA bit should NOT be set now ...
	BITB	#PP.INT, @#PPIC	; test it
	BNE	.		; fail if it's set

;  Now, set the OBF bit.  Remember that OBF is active low, but the bit in the
; port C register reflects the actual state of the pin, not the logical state
; of OBF.  So, setting OBF means "output buffer empty".  The set the INTE1 bit
; and verify that an interrupt is requested (i.e. INTA is set).  Do a dummy
; write to port A so that the buffer is no longer empty and then verify that
; both OBF and INTA have been cleared.
	MOVB	#17, @#PPICSR	; set OBF
	MOVB	#PP.SE1,@#PPICSR; set INTE1
	BITB	#PP.OBF, @#PPIC	; verify that OBF is set now
	BEQ	.		; fail ...
	BITB	#PP.INT, @#PPIC	; verify that the interrupt request is set
	BEQ	.		; fail ...
	MOVB	#123, @#PPIA	; do a dummy write to port A
	BITB	#PP.OBF, @#PPIC	; and OBF should now be cleared
	BNE	.		; fail ...
	BITB	#PP.INT, @#PPIC	; and the interrupt request should disappear
	BNE	.		; fail ...
	MOVB	#PP.CE1,@#PPICSR; clear INTE1

; Now repeat the same experiment for the IBF bit ...
	MOVB	#13, @#PPICSR	; set IBF
	MOVB	#PP.SE2,@#PPICSR; set INTE2
	BITB	#PP.IBF, @#PPIC	; IBF should be set now
	BEQ	.		; fail ...
	BITB	#PP.INT, @#PPIC	; an interrupt should be requested
	BEQ	.		; fail ...
	TSTB	@#PPIA		; do a dummy read from port A
	BITB	#PP.IBF, @#PPIC	; and IBF should be cleared
	BNE	.		; fail ...
	BITB	#PP.INT, @#PPIC	; and the interrupt request too
	BNE	.		; fail ...
	MOVB	#PP.CE2,@#PPICSR; clear INTE2

; And finally, test the ability of the PPI to generate interrupts...
	MOV	#90$, @#PPIVEC	; point to a dead end ISR
	MTPS	#PS.PR0		; lower CPU priority and enable interrupts
	MOVB	#13, @#PPICSR	; set IBF again - no interrupt should occur!
	NOP			; give it a chance
	MOV	#10$, @#PPIVEC	; set the interrupt vector for real now
	MOVB	#PP.SE2,@#PPICSR; set INTE2 and we should interrupt now
	BR	.		; spin forever waiting for interrupt

; Here if the PPI interrupts ...
10$:	CMP	(SP)+, (SP)+	; fix the stack ...
	MOV	#90$, @#PPIVEC	; point to the dummy ISR again
	TSTB	@#PPIA		; clear IBF
	MTPS	#PS.PR0		; this should NOT interrupt now
	NOP			; ...

; All done - clear everything and return
	MOVB	#16, @#PPICSR	; clear OBF
	MOVB	#PP.CE1,@#PPICSR; clear INTE1
	MOVB	#12, @#PPICSR	; clear IBF
	MOVB	#PP.CE2,@#PPICSR; clear INTE2
	MOV	#UINTRQ,@#PPIVEC; restore the default vector
	RETURN			; and we're done

; This pseudo-interrupt routine simply loops forever!
90$:	BR	.
	.SBTTL	IDE/ATA Disk Tests

;++
;   This routine will attempt to initialize any attached IDE drive and, if it
; is successful, perform a few simple tests to make sure we can transfer data
; and interrupt the DCT11.  As POST tests go, this one ia a little unusual
; because there's no requirement that a drive be connected and it's entirely
; possible there's nothing out there.  That's not an error, and if there's no
; drive we just return silently.  Only if a drive is detected do we try to test
; it, and then if we find a problem we'll lock up here with POST code 4.
;
;  It's also worth pointing out that IDE drives have internal diagnostics that
; can be executed by the appropriate ATA command.  This routine DOES NOT invoke
; those at this time.  It could, but the drive diagnostics can take a while to
; execute and we're not interesting in hanging up the boot process for that.
; Drive diagnostics can always be executed later by an explicit monitor command.
;
;   One last item - the flag H.DISK in HFLAGS is set if a working disk drive is
; attached.
;--
IDETST:	MOV	#99$, @#IDEVEC	; point to a dead end vector
	CALL	IDINIT		; try to initialize the drive
	BCC	90$		; quit now if no drive is found

;   Fill the temporary disk buffer in our RAM with a test pattern ...  Remember
; that the disk buffer lives in a part of RAM that's always mapped!
	MOV	#DSKBUF, R1	; R0 points to the buffer
	MOV	#DSKBSZ/4, R2	; we fill one pair of words each iteration
10$:	MOV	R1, R0		; copy the address
	MOV	R0, (R1)+	;  ... don't use "MOV R1, (R1)+" !
	SWAB	R0		; make a differe pattern
	COM	R0		;  ... for the next word
	MOV	R0, (R1)+	; ...
	SOB	R2, 10$		; keep looping for 512 bytes

;   IDINIT leaves with the master drive selected and interrupts disabled, but
; we'll repeat those settings here just to be sure...
	CLRB	@#IDELB3	; select the master drive
	MOVB	#ID.NIE,@#IDECTL; and disable interrupts

;   Now we execute the ATA WRITE BUFFER command and transfer the data we just
; created.  After that we execute the READ BUFFER command, read back what we
; wrote, and verify that it's correct.  Note that WRITE BUFFER and READ BUFFER
; DON'T write anything on the disk and won't corrupt any data!
	MOVB	#ID$WRB,@#IDECMD; write buffer command
	CALL	WDRQ		; wait for the drive to request data
	BCC	.		; if the drive detected an error, quit!
	MOV	#DSKBUF, R1	; point to the test data
	MOV	#DSKBSZ/2, R2	; count the words transferred
20$:	MOV	(R1)+, @#IDEDAT	; transfer one word
	SOB	R2, 20$		; and do that for 256 words
	CALL	WREADY		; wait for the drive to be ready again
	BCC	.		; spin if something failed

;   Read the data back and verify it, and at the same time test interrupts.  If
; we enable interrupts, then the drive will interrupt when it sets the DRQ bit,
; or right after we issue the READ BUFFER command...
	CLRB	@#IDECTL	; enable interrupts - should not interrupt yet!
	MOV	#30$, @#IDEVEC	; set the interrupt vector
	MOVB	#ID$RDB,@#IDECMD; issue the READ BUFFER command
	BR	.		; and the drive should interrupt now!

; Here when the READ BUFFER command sets DRQ ...
30$:	CMP	(SP)+, (SP)+	; fix the stack ...
	MOVB	@#IDESTS, R0	; reading the status register should clear IRQ
	MOV	#99$, @#IDEVEC	; and any further interrupts are bad!
	BITB	#ID.DRQ, R0	; DRQ should be set after the interrupt
	BEQ	.		; fail
	BITB	#ID.ERR, R0	; and ERR should be cleared
	BNE	.		; ...

; Now verify the contents of the disk buffer ...
	MOV	#DSKBUF, R1	; point to the original data
	MOV	#DSKBSZ/2, R2	; check 256 words
40$:	CMP	@#IDEDAT,(R1)+	; transfer and verify one word
	BNE	.		; fail if they don't match
	SOB	R2, 40$		; and do that for 256 words

; All done testing!
	BIS	#H.DISK, HFLAGS	; set the "disk attached" flag!
	CLRB	@#IDELB3	; be sure the master drive is selected
	MOVB	#ID.NIE,@#IDECTL; and interrupts are disabled
90$:	MOV	#UINTRQ,@#IDEVEC; restore the default interrupt vector
	RETURN			; all done

; This pseudo-interrupt routine simply loops forever!
99$:	BR	.
	.SBTTL	Real Time Clock/Non-Volatile RAM Tests

;++
;   This routine will attempt to test if the DS12887 RTC/NVR chip is installed
; and, if it is, it will test that the battery is OK and that the clock is 
; ticking.  Like the IDE drive, the RTC chip is sort of optional and we don't
; fail (i.e. we don't hang forever) if the DS12887 is not present.  Instead,
; we set or clear the H.RTCC bit in the FLAGS word to remember whether the
; DS12887 is present.
;
;   If the chip IS present, however, then the both the battery OK and the clock
; ticking tests MUST pass.  If either of those fail, the POST will hang with
; code PC.RTC displayed.  
;
;   Note that there are no interrupts associated with the RTC/NVR, so we don't
; need to worry about testing those!
;--
RTCTST:	$RDNVR	#RTC.RM, R3	; first try to read the first NVR location
	$WRNVR	#125, #RTC.RM	; try to write a test value to that location
	$RDNVR	#RTC.RM, R1	; re-read the same location
	CMP	#125, R1	; did it work?
	BNE	10$		; branch if no chip
	$WRNVR	#252, #RTC.RM	; now try to write a different pattern
	$RDNVR	#RTC.RM, R1	; ...
	CMP	#252, R1	; did that work too?
	BNE	10$		; nope ...
	$WRNVR	R3, #RTC.RM	; finally restore the original contents
	$RDNVR	#RTC.RM, R1	; ...
	CMPB	R3, R1		; did that work?
	BEQ	20$		; yes - the DS12887 is alive and well
10$:	RETURN			; no DS12887 

; Here if the DS12887 is present - check the battery status ...
20$:	BIS	#H.RTCC, HFLAGS	; remember that the DS12887 was found
	$RDNVR	#RTC.D, R1	; read register D
	CMP	#RT.VRT, R1	; the battery OK bit should be set
	BNE	.		; nope - DS12887 dead battery ...

; Now see if the clock is ticking ...
	$WRNVR	#RT.DV1, #RTC.A	; be sure the oscillator is enabled
30$:	$RDNVR	#RTC.A, R1	; read status register A again
	BIT	#RT.UIP, R1	; wait for the "update in progress" flag
	BEQ	30$		; ...
35$:	$RDNVR	#RTC.A, R1	; ...
	BIT	#RT.UIP, R1	; now wait for the UIP bit to clear
	BNE	35$		; ...

; All done the RTC/NVR is alive!
	$NONVR			; done using the NVR
	RETURN
	.SBTTL	System Initialization, Part 3

;++
;   This is the final part of system initialization and startup - it initializes
; all the important monitor scratch pad RAM areas - user registers, breakpoint
; tables, etc.  It re-initializes all the vectors to point to dummy handlers in
; the EPROOM, and it initializes the console SLU.  The latter two have already
; been done by the POST, but we'll do them again just to be sure.  After all
; that's done, we print a welcome message and then start the command scanner.
;--

SYSIN3:	CALL	INIVEC		; re-initialize all vectors
	CALL	INIREG		; set user registers to default values
	CALL	BPTCLR		; clear breakpoint table
	CALL	CONINI		; initialize the console SLU

; Type out the system name, version, checksum and copyright notice ...
	CALL	TCRLF		; ...
	CALL	SHOVE1		; ...

; Get the current date and time from the RTC and print that ...
	BIT	#H.RTCC, HFLAGS	; is the DS12887 installed?
	BEQ	20$		; no - skip this
	$MSG	<RTC: >		; ...
	CALL	SHONOW		; type the current date and time
	CALL	NVRTST		; are the NVR contents valid?
	BNE	21$		; no!
	MOV	#COKMSG, R1	; yes - print "CONTENTS OK"
	CALL	OUTSTR		; ...
21$:	CALL	TCRLF
20$:

; Probe for an attached IDE/ATA drive and identify that ..
	BIT	#H.DISK, HFLAGS	; is the IDE disk attached?
	BEQ	10$		; no - skip this
	$MSG	<IDE: >		; ...
	CALL	PROBE		; find any attached IDE/ATA drives
	CALL	TCRLF		; ...
10$:

; Clear all of user RAM ...
	CALL	CLRRAM		; ...
	JMP	SYSIN4		; restore saved settings and autoboot

	.SBTTL	Restore Saved Settings from NVR

;++
;--
SYSIN4:
; And, at last, start reading commands!
	$MSG	<For help type HELP>
	CALL	TCRLF		; ...
	JMP	RESTA		; ...
	.SBTTL	Monitor Main Loop

;++ 
;   This code reads commands from the console and then execute them.  It can be
; entered at RESTA to restart after a Control-C or a fatal error, and at BOOTS
; after completion of a normal command...
;--
RESTA:	$POST	PC.MON		; always display POST 1 here
	MOV	#MONSTK, SP	; reinitialize our stack pointer
	CALL	TCRLF		; be sure the terminal is ready

; Read another command line...
BOOTS:	MOV	#MAXCMD, R0	; length of the command line buffer
	MOV	#CMDBUF, R1	; and a pointer to the buffer
	MOV	#PROMPT, R2	; and the prompting string
	CALL	INCHWL		; read another command line
	MOV	#CMDBUF, R5	; initialize the command parser
	MOV	#0, RPTCNT	; clear the repeat counter

; Execute the next command...
10$:	CALL	SPANW		; skip any white space
	CALL	ISEOL		; is this an empty command line?
	BEQ	20$		; yes - there's no command to lookup
	MOV	#CMDTBL, R4	; table of command names
	MOV	#CMDRTN, R3	; table of command action routines
	CALL	COMNDJ		; lookup and dispatch the command
	
; See if there are more commands on this line...
20$:	CMPB	#';, (R5)+	; are there more commands on this line?
	BEQ	10$		; yes - go execute the next one

; See if this command needs to be repeated...
30$:	TST	RPTCNT		; is the repeat count > 0?
	BEQ	BOOTS		; nope - read another command line
	DEC	RPTCNT		; yes - decrement it for next time
	MOV	RPTPTR, R5	; backup the commnd scanner
	BR	10$		; then repeat the same commands

; This is the standard monitor prompt...
PROMPT:	.ASCIZ	/>>>/
	.SBTTL	REPEAT Command

;++
;   This command causes the remainder of the command line to be repeated. It
; accepts an optional decimal argument which gives the number of repetitions.
; If this argument is omitted, 32767 will be used as a default.
;
;   Note that multiple repeat commands on the same command line will cancel
; each other out and only the last one will have any effect.  And any errors
; or a Control-C while executing any of the commands will terminate the
; repetition prematurely.
;
; USAGE:
;	>>>REPeat [nnnn]; ... more commands here
;--
REPEAT:	CALL	CHKARG		; see if there's any argument
	BEQ	10$		; branch if there is not
	CALL	DECNW		; read a decimal number
	CALL	CHKEOL		; and there should be no more
	BR	20$		; go set up the repeat

; If there's no argument use 32767 as the default ...
10$:	MOV	#32767., R1	; ...

; Set up the repeat count and pointer...
20$:	CMPB	#';, (R5)	; better be more commands on this line
	BNE	21$		;  otherwise we're wasting our time!
	MOV	R1, RPTCNT	; save the count
	BNE	22$		; repeat count can't be zero!
21$:	JMP	COMERR		; and complain if it is
22$:	DEC	RPTCNT		; the first repeat won't be counted
	TSTB	(R5)+		; skip over the ";"
	MOV	R5, RPTPTR	; save the location to repeat from
30$:	RETURN			; and I think we're done
	.SBTTL	ECHO Command

;++
;   The ECho command just echos the remainder of the command line to the
; console, as-is.  It's handy for testing and debugging, but other than that
; it's not good for much.
;
;   BTW, if the remainder of the command contains a ";" or a "!" then that's
; just considered part of the text to echo and doesn't delimit multiple commands
; or a comment.  This command is a special case in that regard.
;
; USAGE:
;	>>>ECho any text here
;--
ECHO:	CALL	SPANW		; skip any white space
	MOV	R5, R1		; and then print the remainder of the line
	CALL	OUTSTR		; ...
	MOV	R1, R5		; update R5 to point to the EOS
	JMP	TCRLF		; finish the line and return
	.SBTTL	HELP Command

;++
; TBA!!!
;--
HELP:	CALL	CHKEOL
	MOV	#HLPTXT, R1
	JMP	OUTSTR
	.SBTTL	Generic EXAMINE Command

;++
;   This routine is the base for all EXAMINE commands.  There are actually
; several variations of these, and the job here is to figure out which one the
; user wants and then branch to the correct code.  Some of the options are -
;
; USAGE:
;	>>>E <octal address>	-> Examine a single memory location
;	>>>E <address range>	-> Examine a range of memory locations
;	>>>E			-> Examine the next block of locations
;	>>>E <register>		-> Examine R0..R5, SP, PC, PS or "REGISTER"
;	>>>E I <address>	-> Disassemble one instruction
;	>>>E I <address range>	-> Disassemble several instructions
;	>>>E I			-> Disassemble the next block of instructions
;--
DOEXAM:	CALL	SPANW		; skip any white space
	CALL	ISEOL		; are there any arguments?
	BNE	10$		; arguments present - keep parsing
	JMP	COMERR		; TBA - examine next block!
10$:	CALL	ISOCT		; is the next character an octal digit?
	BCS	EMEM		; yes - examine memory address or range
	MOV	R5, R3		; save the command pointer so we can back up
	MOV	#INSKEY, R4	; try to match the INSTRUCTIOKN keyword
	CALL	MATCH		; ...
	BNE	20$		; no - try for something else
	JMP	EINST		; yes - EXAMINE INSTRUCTION
20$:	MOV	R3, R5		; backup the parser
	MOV	#REGKEY, R4	; and try to match "REGISTER"
	CALL	MATCH		; ??
	BNE	30$		; no - try for a specific register name
	JMP	ERALL		; yes - EXAMINE [all] REGISTERS
30$:	MOV	R3, R5		; nope - backup one more time
	JMP	EREG1		; and look for a register name

; Keywords for EXAMINE ...
REGKEY:	.ASCIZ	/R*EGISTERS/
INSKEY:	.ASCIZ	/I*NSTRUCTION/
	.EVEN
	.SBTTL	EXAMINE MEMORY Command

;++
;   This routine handles the memory variant of the EXAMINE command.  This dumps
; RAM in both octal words and ASCII.  A single address may be examined or an
; entire range of addresses may be dumped.  For example -
;
; USAGE:
;	>>>E 1234		-> Examine location 1234 only
;	>>>E 71000-72000	-> Dump locations 71000 thru 72000
;
;   Note that this command examines user RAM.  That might seem obvious, but
; remember that the EPROM (including this very routine!) is currently mapped
; into that address space.  We have to use RDRAM to access user RAM.  Currently
; there's no way to examine EPROM, although that might be a nice addition.
;--
EMEM:	CALL	RANGE		; parse the argument(s)
	BCC	EMEM1		; branch if the single address version
	CALL	CHKEOL		; only that argument is allowed
	BIC	#7, ADDRLO	; round ADDRLO down ...
	BIS	#7, ADDRHI	; and round ADDRHI up ...

; First type 8 words of octal data ...
10$:	CALL	ETYPE1		; print "addr/ "
	MOV	#8., R4		; do exactly 8 words
	MOV	ADDRLO, R2	; starting from here
11$:	CALL	ETYPE2		; print one word
	TST	(R2)+		; and bump R2 to the next word
	SOB	R4, 11$		; keep going until we've done 8

; Now type 16 bytes of ASCII data ...
	MOV	#8., R4		; do 8 words again (16 bytes)
	MOV	ADDRLO, R2	; ...
12$:	CALL	ETYPE3		; type two ASCII characters
	TST	(R2)+		; R2 += 2
	SOB	R4, 12$		; keep going until we're done

; THat's one line of the memory dump ...
	CALL	TCRLF		; finish the line
	ADD	#16., ADDRLO	; and bump up ADDRLO
	CMP	ADDRLO, ADDRHI	; are we done yet?
	BLOS	10$		; nope - type another line
	RETURN			; that's it


; Here for the single address version ...
EMEM1:	CALL	CHKEOL		; that'd better be the end
	CALL	ETYPE1		; type "addr/ "
	MOV	ADDRLO, R2	; 
	CALL	ETYPE2		; and type the data
	JMP	TCRLF		; finish the line and we're done


; Here to type out ADDRLO, a slash and a space ...
ETYPE1:	MOV	ADDRLO, R1	; get the current address
	CALL	TOCTW		; type that out
	$TYPE	'/		; then "/"
	JMP	TSPACE		; and space

; Fetch the word pointed to by R2 and type that out in octal ...
ETYPE2:	CALL	RDRAM		; read that location in user RAM
	CALL	TOCTW		; and type that out
	JMP	TSPACE		; followed by a space

; Fetch the word pointed to by R2 and type that as two ASCII characters ...
ETYPE3:	CALL	RDRAM		; read that location
	MOV	R1, R0		; ...
	CALL	ETYPE4		; print the low byte first
	MOV	R1, R0		; get the byte back again
	SWAB	R0		; print the high byte
	CALL	ETYPE4		; ...
	RETURN			; and we're done

; Type the character in R0, or a "." if it's not a printing character ...
ETYPE4:	BIC	#^C177, R0	; only 7 bits please
	CALL	ISPRNT		; is this a printing character?
	BCS	10$		; branch if it's a printing character
	MOV	#'., R0		; not - print "." instead
10$:	JMP	OUTCHR		; print it and return
	.SBTTL	EXAMINE REGISTER Command

;++
;   This routine handles the register form of the EXAMINE command.  It either
; prints the contents of a single register, when the register name is given as
; the argument, or all registers when no argument is given.  For example:
;
;	>>>E R1		- examine user register R1
;	>>>E PC		- examine user register R7 (PC)
;	>>>E R		- print all user registers
;
;   Remeber that the last state of the user's registers were saved in our own
; scratch RAM at location USRREG, et al.
;--
EREG:	CALL	SPANW		; see if a register name was given
	CALL	ISEOL		; anything more?
	BEQ	ERALL		; if none then examine all registers
EREG1:	CALL	NAMENW		; otherwise scan the register name
	CALL	CHKEOL		; and there should be no more after that
	MOV	#REGTAB, R2	; and try to look this one up
	CALL	LOOKUP		; ...
	BCS	EONE		; branch if we found a match
	JMP	COMERR		; unknown register name

; Here to examine a single register ...
EONE:	CALL	TREG		; type just this register
	JMP	TCRLF		; and we're done


; Examine ALL registers ...
;   It's a bit cheap, but this is hard coded for the fact that we have nine
; registers in all - six regular registers, SP, PC and PS ...
ERALL:	CLR	R2		; keep the register index here
	MOV	#3, R4		; and the total number of lines here
10$:	CALL	TREG		; type the register name and value
	CALL	TREG		; ... do three per line
	CALL	TREG		; ...
	CALL	TCRLF		; start a new line
	SOB	R4, 10$		; have we finished them all
	RETURN			; all done


; Type out one register name and its contents ...
;  R2 contains the index into both REGTAB and USRREG!
TREG:	MOV	REGTAB(R2), R1	; get the name
	CALL	TR50W		; type that out
	$TYPE	'/		; a slash
	CALL	TSPACE		; and a space
	MOV	USRREG(R2), R1	; get the register value
	CALL	TOCTW		; and type that in octal
	ADD	#2, R2		; bump the index for next time
	$TYPE	CH.TAB		; space between multiple registers
	RETURN			; ...
	.SBTTL	EXAMINE INSTRUCTION Command

;++
;   And this routine handles the "instruction" (aka disassembler) form of the
; examine command.  Other than the output, this command is identical to the
; regular examine memory command.
;
;	>>>E I 123456		-> disassemble one instruction at 123456
;	>>>E I 71000-72000	-> disassemble the code from 71000 thru 72000
;
; Needless to say, this disassembles instructions from user RAM, not EPROM!
;--
EINST:	CALL	RANGE		; parse the argument(s)
	CALL	CHKEOL		; and only that argument is allowed
	MOV	ADDRLO, R4	; start at the beginning
	BIC	#1, R4		; make sure it's even

;   Note that for the single argument case RANGE will leave ADDRHI set to the
; same value as ADDRLO, so we don't need to worry about that as a special case.
; This is really easy - TINSTA takes care of everything except the CRLF!
10$:	CALL	TINSTA		; disassemble the next instruction
	CALL	TCRLF		; it's the only thing TINSTA doesn't do
	CMP	R4, ADDRHI	; have we reached the end?
	BLOS	10$		; and keep going until we're done
	RETURN			; that's all we need
	.SBTTL	Generic DEPOSIT Command

;++
;   This routine is the base for all DEPOSIT commands.  There are actually two
; variations of this - one that deposits data in memory, and one that deposits
; data in regisers. Note that, unlike EXAMINE, there is no "DEPOSIT INSTRUCTION"
; (i.e. an assembler) version of this command.  It'd be nice to add one...
;
; USAGE:
;	>>>D <address> <data>[,...]	-> deposit words in memory at address
;	>>>D <register> <data>		-> deposit data in a register
;--
DODEPO:	CALL	CHKARG		; there'd better be at least one argument
	BNE	10$		; yes - figure out what they are
	JMP	COMERR		; no - just give up
10$:	CALL	ISOCT		; is this an octal digit?
	BCS	DMEM		; yes - deposit in memory
	JMP	DREG		; no - must be a register name
	.SBTTL	DEPOSIT MEMORY Command

;++
;   This is the version of the DEPOSIT command that alters user RAM. The general
; format is:
;
; USAGE:
;	>>>D 60122 4567	  -> Deposit 4567 into location 060122
;	>>>D 100 1,2,3,4  -> Deposit 1 into location 100, 2 into 102,
;			       3 into 104, and 4 into 106
;
;   Note that deposits are always done in WORDS, never bytes.  If the starting
; address specified is odd, then an error is printed.  
;
;   Also note that it's certainly possible to corrupt locations used by this
; monitor (e.g. scratch RAM at 176000 thru 176377) and crash something!
;--
DMEM:	CALL	OCTNW		; read the address
	BIT	#1, R1		; did he specify an odd address?
	BNE	ODDADR		; yes - that's an error
	MOV	R1, ADDRLO	; save the base address
	CALL	CHKSPA		; we need to see a space here

; Parse one a data word and store in memory ...
10$:	CALL	OCTNW		; scan another octal word
	MOV	ADDRLO, R2	; address to R2
	CALL	WRRAM		; store that in user RAM
	ADD	#2, ADDRLO	; then bump up ADDRLO for next time

; See if there is more data on the line ...
	CALL	SPANW		; get the next non-space character
	CMPB	#',, R0		; is it a comma?
	BNE	20$		; nope - it had better be EOL
	INC	R5		; yes - skip the comma
	BR	10$		; and go parse more words

; Here for the end of the command
20$:	CALL	CHKEOL		; only other legal option is EOL
	RETURN			; and we're done

; Here for an odd address ...
ODDADR:	$ERR	<ODD ADDRESS>
	.SBTTL	DEPOSIT REGISTER Command

;++
;   This is the register modifying version of the DEPOSIT command.  It writes
; one 16 bit value to the saved user context (it doesn't change the current
; registers, of course!).  The argument must be a register name (R0-R5, SP, PC,
; or PS) and an octal value.  For example:
;
;	>>>D R1 177777	- set user register R1 to 177777
;	>>>D SP 1000	- set user stack pointer to 001000
;--
DREG:	CALL	NAMENW		; scan a register name first
	MOV	R1, R3		; save the name for a moment
	CALL	CHKSPA		; make sure there's a space next
	CALL	OCTNW		; and scan an octal value
	MOV	R1, R4		; save the value too
	CALL	CHKEOL		; no more arguments
	MOV	R3, R1		; get the name back
	MOV	#REGTAB, R2	; point to the table of registers
	CALL	LOOKUP		; lookup the register name
	BCS	10$		; branch if we found a match
	JMP	COMERR		; bad register name

;   There are a couple of special hacks here - first, we prevent the user from
; depositing any odd address into either the SP or the PC.  Second, when setting
; the PS we mask out "dangerous" bits like the T bit.
10$:	CMP	R2,#REGTPS-REGTAB; is he modifying the PS?
	BNE	11$		; no - check for the SP or PC
	BIC	#^C<PS.PRI!PS.CC>, R4	; only allow priority and CC to be set
	BR	20$		; go change the PS
11$:	CMP	R2,#REGTSP-REGTAB; is modifying the SP or PC?
	BLO	20$		; no - anything goes
	BIT	#1, R4		; yes - don't allow odd addresses
	BEQ	20$		; ...
	JMP	ODDADR		; give an error and quit if so
; Here to modify one register ...
20$:	MOV	R4, USRREG(R2)	; update the register value
	RETURN			; that's all there is to it
	.SBTTL	GO Command

;++
;   The GO command will start execution of the user's program in RAM.  It clears
; all the regsters, does a BCLR to clear all I/O devices, and then starts the
; user program running.  It accepts a single, optional argument which is the
; starting address - if specified, this value is deposited in the user's PC
; before starting. 
;
;	>>>GO 1000	- start user program at PC=001000
;	>>>GO		- start user program at PC=000000
;--
GOCMD:	CALL	SPANW		; skip any white space
	CALL	ISEOL		; is there an argument?
	BEQ	10$		; branch if none
	CALL	OCTNW		; scan the address
	CALL	CHKEOL		; there should be no more arguments
	CALL	INIREG		; initialize the user registers
	MOV	R1, USRPC	; update the PC with the new value
	BR	GOCMD1

; Here if no argument was specified
10$:	CALL	INIREG		; just initialize the registers
GOCMD1:	CALL	CHKUPC		; make sure the PC is valid
	CALL	CHKUSP		; and the stack as well
	CALL	IOINIT	 	; reset all I/O devices
	BIC	#S.STEP!S.SSBP,SFLAGS; be sure the single step flags are cleared
;   Although UCLOAD starts an arbitrary user program running, it is actually a
; subroutine and will return if the user program encounters a breakpoint.  We
; don't need to do anything special in the event of a breakpoint and we simply
; let control return to the main command loop.  In particular, this means that
; repeat commands involving a GO or CONTINUE will work as expected.
	JMP	UCLOAD		; restore the user context and go


;   This little routine is used by the GO, STEP and CONTINUE commands to sanity
; check the user's stack pointer ...
CHKUSP:	CMP	USRSP, #RAMTOP	; does the SP point to real RAM?
	BHI	10$		; no - bad
	CMP	USRSP, #4	; and is there room for the PS and PC?
	BLO	10$		; no - bad
	BIT	#1, USRSP	; is the stack odd?
	BNE	10$		; also bad
	RETURN			; stack looks good
10$:	$ERR	<BAD USER SP>

; And this routine is about the same, but it checks the program counter ...
CHKUPC:	CMP	USRPC, #RAMTOP	; is the PC in user space?
	BHI	10$		; no - that's bad
	BIT	#1, USRPC	; is the PC odd?
	BNE	10$		; that's also bad
	RETURN			; looks good
10$:	$ERR	<BAD USER PC>
	.SBTTL	Single STEP Command

;++
;   The STEP command traces the execution of one or more user instructions.  It
; uses the PDP11 T-bit trap to single step thru the user's program and prints
; the PC as well as the instruction just executed after each one.  By default
; it traces only one instruction and stops, but it accepts an optional decimal
; argument that specifies the number of instructions to execute.
;
; USAGE:
;	>>>ST		-> single step one instruction and stop
;	>>>ST 10	-> single step ten (decimal!) instructions
;--
TRACE:	CALL	SPANW		; see if an argument is present
	CALL	ISEOL		; ???
	BEQ	10$		; branch if no argument
	CALL	DECNW		; read a decimal count
	CALL	CHKEOL		; and that's the only argument
	BR	11$		; store it
10$:	MOV	#1, R1		; 1 is the default trace count
11$:	$PUSH	R1		; store the step count on the stack
	BNE	20$		; make sure the count is non-zero!
	JMP	COMERR		; a zero count is an error

; Here to execute one instruction ...
20$:	CALL	CHKUSP		; sanity check the user's stack
	CALL	CHKUPC		; ... and the user's PC
	BIS	#S.STEP, SFLAGS	; set the single step flag
	BIC	#S.SSBP, SFLAGS	; ... but clear the "step over breakpoint" flag
	$PUSH	USRPC		; save the user's PC
	CALL	UCLOAD		; execute one instruction
	$POP	R4		; get the user's PC back
	CALL	TINSTA		; type that and disassemble the
	CALL	TCRLF		;  ... instruction just executed
	DEC	(SP)		; decrement the step count
	BNE	20$		; and keep stepping if it's not zero
	TST	(SP)+		; fix the stack
	RETURN			; and we're done
	.SBTTL	CONTINUE Command

;++
;   The CONTINUE command will resume execution of the user's program with the
; previous user context, including all register contents, intact. This is unlike
; the GO command, which will reset the registers and clear all I/O devices. Note
; that CONTINUE will single step over the first instruction before free running.
; This allows CONTINUE to be used immediately after a breakpoint without 
; breaking again immediately.
;
; USAGE:
;	>>>C			-> continue user program
;--
CONT:	CALL	CHKEOL		; no arguments allowed
	CALL	CHKUSP		; sanity check the user's stack
	CALL	CHKUPC		; ... and the user's PC
	BIS	#S.SSBP, SFLAGS	; single step over a breakpoint
	BIC	#S.STEP, SFLAGS	; ... but only once!
;   Remember - if the user program encounters a breakpoint then UCLOAD will
; actually return control.  We don't need to do anything more in that case, so
; we just let control revert to the main command loop - that gives the expected
; results if you use Continue as part of a repeat command ...
	JMP	UCLOAD		; start the user's program
	.SBTTL	RESET Command

;++
;   The RESET command tries to reset as much of the SBCT11 hardware and state
; as possible.  It asserts the BCLR signal to reset most of the hardware and
; clears the saved user program state.  It re-initializes all the interrupt
; vectors but it DOES NOT otherwise clear RAM.  It also does not clear any
; breakpoints that might be set.  There are no arguments..
;
; USAGE:
;	>>>RESET		-> reset the system state
;--
MRESET:	CALL	CHKEOL		; no arguments are allowed
	CALL	IOINIT		; assert BCLR and clear the hardware
	$POST	PC.MON		; POST code 1, RUN LED off
	CALL	INIREG		; initialize saved processor registers
	CALL	INIVEC		; reset all interrupt vectors
	RETURN			; and that's all for now
	.SBTTL	BOOT Command

;++
;   The BOOT command bootstraps the specified device (else could it do?).  The
; argument is a standard device name and unit, "XXu" and the only two device
; names current recognized are "DD" for TU58 and "DI" for IDE disk.  If this
; command succeeds then it never returns - the bootstrap is loaded and started.
; If it fails then some kind of error message, either "DEVICE ERROR" or "NOT
; BOOTABLE" is printed and control returns to the command scanner.
;
; USAGE:
;	>>>B DD		-> boot from TU58 unit 0
;	>>>B DD1	-> boot from TU58 unit 1
;	>>>B DI7:	-> boot IDE unit 7
;--
BOOCMD:	CALL	DEVNW		; read the device name
	CALL	CHKEOL		; and that should be the end of the line
	CMP	#"DD, R2	; does he want to boot TU58?
	BEQ	BOOTDD		; branch if yes
	CMP	#"DI, R2	; or does he want to boot IDE?
	BEQ	BOOTDI		; branch if yes
	BR	BADDEV		; those are the only two options now

; Here to boot from TU58 ... Unit number in R1 ...
BOOTDD:	CALL	TUBOOT		; try to boot from it
;;	JMP	DEVERR

; Here if there's some kind of drive error ...
DEVERR:	$ERR	<DEVICE ERROR>

; Here to boot from IDE ... Unit number in R1 ...
BOOTDI:	JMP	COMERR
;;	JMP	IDBOOT

; Here if the device name (in R2) is unknown ...
BADDEV:	$MSG	<?UNKNOWN DEVICE >
	MOV	R2, R0		; type the device name just to be helpful
	CALL	T2CHAR		; ...
	JMP	RESTA		; ...
	.SBTTL	FORMAT Command

;++
;   The FORmat command will write all zeros to either a TU58 tape or hard disk
; partition.  The name "format" is something of a misnomer since it doesn't
; actually format anything, but it handy for erasing tapes or disks.  It's also
; useful for pre-allocating TU58 images if you're using a TU58 emulator (and
; these days, who isn't?).
;
;   The first argument (required) is a device name, either "DDn" for TU58 tapes,
; or "DIn" for a hard disk partition.  The second, optional, argument is the
; number of 512 byte blocks to write, in decimal.  If omitted then it defaults
; to the full size of the device/partition.
;
; USAGE:
;	>>>FOR DD1		-> format TU58 tape unit 1
;	>>>FOR DI0		-> format hard disk partition 0
;	>>>FOR DD7 20480	-> write 20480 blocks (10Mb) to TU58 unit 7
;
;  There are lots of locals on the stack in this routine!
;
;	4(SP)	- unit number
;	2(SP)	- number of blocks to zero
;	 (SP)	- current block number
;--
FMTCMD:	MOV	#DSKBSZ, R2	; count of bytes to zero
	MOV	#DSKBUF, R1	; address of the disk buffer
	CALL	CLRRAM		; fill the buffer with zeros

; Now parse the rest of the command line ...
	CALL	DEVNW		; get the device name (R2) and unit (R1)
	$PUSH	R1		; save the unit number for later
	$PUSH	#0		; assume the block count is zero
	CALL	CHKARG		; is there another argument?
	BEQ	10$		; branch if not
	CALL	DECNW		; get the block count in R1
	MOV	R1, (SP)	; and replace the zero with that
10$:	CALL	CHKEOL		; that should be the end
;;	CMP	#"DI, R2	; hard disk ?
;;	BR	???		; that's the one
	CMP	#"DD, R2	; TU58?
	BNE	BADDEV		; don't know what it is

; Here to format a TU58 tape ...
20$:	CALL	TUINIT		; initialize the TU58 drive
	BCC	DEVERR		; ?DEVICE ERROR
	TST	(SP)		; is the block count zero?
	BNE	25$		; no 
	MOV	#TUMAXB, (SP)	; use the standard size by default
25$:	$PUSH	#0		; initialize the current block number

; Write the next block to the tape ...
30$:	MOV	4(SP), R1	; get the unit number
	MOV	(SP), R2	; and the current block number
	MOV	#DSKBUF, R3	; address of the disk buffer
	MOV	#DSKBSZ, R4	; number of bytes to write
	CALL	TUWRIT		; ...
	BCC	DEVERR		; ?DEVICE ERROR

; Increment to the next block ...
	BIT	#177, (SP)	; print a message every 128 blocks
	BNE	35$		; not just yet
	$TYPE	CH.CRT		; yes - print the running total
	MOV	(SP), R1	; get the block number
	CALL	TDECU		; type that in decimal
	$MSG	< BLOCKS>	; ...
35$:	INC	(SP)		; increment the current block
	CMP	(SP), 2(SP)	; have we done them all?
	BLO	30$		; nope - go do some more

; Here when we're finished all the blocks ...
	$TYPE	CH.CRT		; print one final message
	MOV	(SP), R1	;  ... with the total number of blocks
	CALL	TDECU		; ...
	$MSG	< BLOCKS>	; ...
	ADD	#6, SP		; fix the stack
	JMP	TCRLF		; finish the line and we're done
	.SBTTL	Generic SHOW Command

;++
;   This is the basis for all SHOW commands - SHOW VERSION, SHOW TIME, SHOW
; BREAKPOINTS, etc.  All it has to do is to call COMNDJ to parse the next
; keyword on the command line; it's not very exciting, I'm afraid.
;--
SHOCMD:	MOV	#SHOTBL, R4	; point to the table of SHOW commands
	MOV	#SHORTN, R3	; and the table of SHOW action routines
	JMP	COMNDJ		; parse it, dispatch, and we're done ...

;   This table is a list of the SHOW command arguments, formatted for the MATCH
; routine.  The table ends with an extra NULL byte, and don't forget the .EVEN!
SHOTBL:	.ASCIZ	/VER*SION/
	.ASCIZ	/BR*EAKPOINTS/
	.ASCIZ	/TIM*E/
	.ASCIZ	/DI*SK/
	.ASCIZ	/BO*OT/
	.ASCIZ	/NVR/
	.ASCIZ	/LTC/
	.ASCIZ	/NXM/
	.BYTE	0
	.EVEN

;   And this is a table of the corresponding SHOW action routines that implement
; the above commands.  Note that this table MUST BE IN THE SAME ORDER AS SHOTBL!
SHORTN:	.WORD	SHOVER		; SHOW VERSION
	.WORD	BPLIST		; SHOW BREAKPOINTS
	.WORD	SHOTIM		; SHOW TIME
	.WORD	SHOIDE		; SHOW DISK
	.WORD	SHOBOO		; SHOW BOOT
	.WORD	SHONVR		; SHOW NVR
	.WORD	SHOLTC		; SHOW LTC
	.WORD	SHONXM		; SHOW NXM
	.SBTTL	Generic SET Command

;++
;   This is the basis for all SET commands - SET TIME, SET BREAKPOINT, SET LTC,
; etc.  All it has to do is to call COMNDJ to parse the next keyword on the
; command line; it's almost identical to the SHOW command ...
;--
SETCMD:	MOV	#SETTBL, R4	; point to the table of SET commands
	MOV	#SETRTN, R3	; and the table of SET action routines
	JMP	COMNDJ		; parse it, dispatch, and we're done ...

; Table of SET command arguments, formatted for the MATCH routine ...
SETTBL:	.ASCIZ	/BR*EAKPOINTS/
	.ASCIZ	/TIM*E/
	.ASCIZ	/BO*OT/
	.ASCIZ	/LTC/
	.ASCIZ	/NXM/
	.BYTE	0
	.EVEN

;   Table of the corresponding SET action routines.  This table must BE IN THE
; SAME ORDER AS THE ONE AT SETTBL!
SETRTN:	.WORD	SETBPT		; SET BREAKPOINT
	.WORD	SETNOW		; SET TIME
	.WORD	SETBOO		; SET BOOT
	.WORD	SETLTC		; SET LTC
	.WORD	SETNXM		; SET NXM
	.SBTTL	Generic CLEAR Command

;++
;   This is the basis for all CLEAR commands - CLEAR BREAKPOINT, CLEAR MEMORY,
; etc.  All it has to do is to call COMNDJ to parse the next keyword on the
; command line; it's almost identical to the SHOW command ...
;--
CLRCMD:	MOV	#CLRTBL, R4	; point to the table of CLEAR commands
	MOV	#CLRRTN, R3	; and the table of CLEAR action routines
	JMP	COMNDJ		; parse it, dispatch, and we're done ...

; Table of CLEAR command arguments, formatted for the MATCH routine ...
CLRTBL:	.ASCIZ	/BR*EAKPOINT/
	.ASCIZ	/MEM*ORY/
	.ASCIZ	/NVR/
	.BYTE	0
	.EVEN

;   Table of the corresponding SET action routines.  This table must BE IN THE
; SAME ORDER AS THE ONE AT SETTBL!
CLRRTN:	.WORD	BREMOV		; CLEAR BREAKPOINT
	.WORD	CLRMEM		; CLEAR MEMORY
	.WORD	CLRNVR		; CLEAER NVR
	.SBTTL	Generic TEST Command

;++
;   This is the basis for all TEST commands - TEST NVR, TEST MEMORY, etc.  It's
; pretty much what you'd expect ...
;--
TSTCMD:	MOV	#TSTTBL, R4	; point to the table of TEST commands
	MOV	#TSTRTN, R3	; and the table of TEST action routines
	JMP	COMNDJ		; parse it, dispatch, and we're done ...

; Table of TEST command arguments, formatted for the MATCH routine ...
TSTTBL:	.ASCIZ	/NVR/
	.ASCIZ	/MEM*ORY/
	.BYTE	0
	.EVEN

;   Table of the corresponding SET action routines.  This table must BE IN THE
; SAME ORDER AS THE ONE AT SETTBL!
TSTRTN:	.WORD	TSTNVR		; TEST MVR
	.WORD	TSTRAM		; TEST MEMORY
	.SBTTL	SET or SHOW TIME Commands

;++
;
;   The SHOW and SET TIME commands will either print the current time and date
; according to the DS12887 RTC chip, or will actually set the RTC clock.  The
; time and date is printed in the format "HH:MM:SS DD-MMM-YYYY WWW" where the
; fields are pretty much what you'd expect. "WWW" is the day of the week, e.g.
; MON, TUE, WED, etc.  The year is always printed as four digits, however the
; DS12887 only supports a two digit year and this code limits the range to
; 2000 .. 2099.  When setting the clock the input is in exactly the same format.
;
; USAGE:
;	>>>SHOW TIME				-> print the time and date
;	>>>SET TIME HH:MM:SS			-> set the time but not the date
;	>>>SET TIME HH:MM:SS DD-MMM-YYYY WWW	-> set both the time and date
;
;   Note that the alternate entry at SHONOW is used by the system startup code
; to print the current date and time.
;--

; Show the current date and time ...
SHOTIM:	CALL	CHKEOL		; no arguments here ...
	BIT	#H.RTCC, HFLAGS	; is the RTC chip installed?
	BEQ	20$		; no - quit now
	CALL	SHONOW		; type out the time
	JMP	TCRLF		; and finish the line

; Here if the RTC is not installed ...
20$:	$ERR	<NOT INSTALLED>


; Here to actually type the time...
SHONOW:	MOV	#TIMBUF, R3	; point to the time buffer
	CALL	GETTOD		; and try to read the clock
	BCC	10$		; branch if error
	JMP	TTIME		; otherwise type it out

; Here if the clock is not set ...
10$:	$MSG	<NOT SET>
	RETURN


; Set the current time from the argument in the form HH:MM:SS ...
SETNOW:	MOV	#TIMBUF, R3	; point to the time buffer
	CALL	GETTOD		; preload it with the current date/time
	CALL	DECNW		; read the hours
	MOVB	R1, (R3)+	; and store that
	CALL	SPANW		; get the next character
	CMPB	#':, R0		; better be a colon
	BEQ	10$		; yes - keep going
99$:	JMP	COMERR		; bad syntax
10$:	INC	R5		; skip over the ":"
	CALL	DECNW		; now read the minutes
	MOVB	R1, (R3)+	; ...
	CALL	SPANW		; ...
	CMPB	#':, R0		; ...
	BNE	99$		; ...
	INC	R5		; skip over the ":"
	CALL	DECNW		; and read the seconds
	MOVB	R1, (R3)+	; ...
	CALL	ISEOL		; is that the end of the line?
	BEQ	20$		; yes - default the date to today
	CALL	CHKSPA		; otherwise we'd better find a space

; Here to parse the date in the form DD-MMM-YYYY ...
	CALL	DECNW		; read the date
	MOVB	R1, (R3)+	; ...
	CALL	SPANW		; then check the separator character
	CMPB	#'-, R0		; it'd had better be a dash
	BNE	99$		; ...
	INC	R5		; skip over the "-"
	CALL	NAMENW		; read the name of the month
	MOV	#MONTAB, R2	; try to find it in the table of month names
	CALL	LOOKUP		; ...
	BCC	99$		; error if no match
	ASR	R2		; convert the word offset to an index
	INC	R2		; and convert zero indexed to one indexed
	MOVB	R2, (R3)+	; save the month index
	CALL	SPANW		; finally we can check the separator character
	CMPB	#'-, R0		; ...
	BNE	99$		; ...
	INC	R5		; skip over the "-"
	CALL	DECNW		; lastly read the year
	CMP	R1, #2000.	; it has to be in the range 2000..2099
	BLO	99$		; ...
	CMP	#2099., R1	; ...
	BLO	99$		; ...
	SUB	#2000., R1	; convert to a 2 digit value
	MOVB	R1, (R3)+	; and store that

; Here to parse the weekday (e.g. MON, TUE, WED, etc) ...
	CALL	CHKSPA		; better be a space first
	CALL	NAMENW		; then read the weekday name
	MOV	#WDYTAB, R2	; try to lookup the day name
	CALL	LOOKUP		; ...
	BCC	99$		; error if there's no match
	ASR	R2		; convert the word offset to an index
	INC	R2		; and then offset so SUNDAY=1
	MOVB	R2, (R3)+	; store that
	CALL	CHKEOL		; and we'd better be at the end!

;   Now go thru the entire TIMBUF again and range check each parameter.  This
; prevents the user from setting the clock to something stupid, like 99:99:99.
; Note that the doesn't detect more subtle errors, for example 31-FEB ...
20$:	MOV	#TIMBUF, R3	; start over again
	CMPB	(R3)+, #24.	; test the hours
	BHIS	99$		; branch if .GT. 24 ...
	CMPB	(R3)+, #60.	; and the minutes ...
	BHIS	99$		; ...
	CMPB	(R3)+, #60.	; and the seconds ...
	BHIS	99$		; ...
	CMPB	(R3)+, #32.	; now the day
	BHIS	99$		; ...
;   We can stop here - there's no need to test the month, year or weekday.  All
; of those we already know to be valid (just look at the code above!) ...

; The time and date are good - set the clock...
	MOV	#TIMBUF, R3	; one more time
	CALL	SETTOD		; set the DS12887 clock
	CALL	SHONOW		; show the current setting just to confirm
	JMP	TCRLF		; finish the line and we're done
	.SBTTL	SHOW DISK Command

;++
;   The SHOW DISK command attempts to print the size and manufacturer's model
; name for any attached IDE/ATA drive.
;
;	>>>SHOW DISK
;
;  Note that the alternate entry point at PROBE is called by the system startup
; code to identify any attached drive.
;--
SHOIDE:	CALL	CHKEOL		; make sure there are no arguments
	CALL	PROBE		; do all the real work
	JMP	TCRLF		; then type the CRLF and we're done


;++
;   This routine does all the work of probing for attached IDE/ATA drives.
; It's called automatically at startup and also at any time by the ID command.
; Essentially it just tries to find an attached drive, initializes it, and then
; sends an ATA IDENTIFY DEVICE command.  The response to the IDENTIFY DEVICE
; comand gives us the drive's capacity and a few other tidbits, such as the
; manufacturer and model name.  
;
;   Notice that this routine has a critical side effect - if it finds a drive
; it will set the H.DISK bit in the flags and also it will leave the drive's
; capacity, in megabytes, in DKSIZE.  Both of these are used elsewhere in this
; code to determine if a drive is attached and how big it is.  Conversely, if
; no drive is found then this routine clears both the H.DISK bit and DKSIZE.
;
;   Another note - our disk I/O routines only support LBA addressing.  C/H/S
; addressing is not supported.  The IDENTIFY DEVICE words we examine to get
; the drive size are implemented ONLY if the drive supports LBA addressing.
; If the drive doesn't support LBA, then these words will be zero and we'll
; just ignore the drive as if it didn't exist.  This is really a non-issue
; since pretty much everything made in the last 20 years supports LBA mode.
;
;   One last time - currently the code only supports one drive, the IDE master.
; If any slave drive is also attached, it will be ignored.
;--
PROBE:	BIC	#H.DISK, HFLAGS	; assume no disk is attached
	CLR	DKSIZE		; ...
	CALL	IDINIT		; initialize the drive
	BCC	90$		; no drive detected
	MOV	#DSKBUF, R2	; ...
	CALL	IDIDEN		; send the IDENTIFY DEVICE command
	BCC	90$		; drive error or no drive

;   Extract the drive size from words 60 and 61 of the buffer.  This is actually
; a count of the total number of sectors.  Sectors are 512 bytes, so dividing
; this value by 2048 gives us the drive size in megabytes.  Dividing by 2048 is
; of course the same as shiftling right by 11 bits.  And remember, if this value
; is zero then the drive doesn't support LBA mode.
;
;   BTW, if you have a very large drive, greater than 65 gigabytes, then the
; result won't fit in DKSIZE.  We don't detect overflows here and you're just
; screwed if that happens.  Who in their right mind would want to put a 65Gb
; drive on a PDP11 anyway ?!?
	MOV	DSKBUF+ID$LBA,R0; get the low word in R0
	SWAB	R0		; correct for the SWAB in IDEIDD
	MOV	DSKBUF+ID$LBA+2,R1; now get the high word
	SWAB	R1		; ...
	.REPT	5		; rotate R0,R1 left five bits
	ROL	R0		; ...
	ROL	R1		; ...
	.ENDR			; ...
	TST	R1		; be sure the size is non-zero
	BEQ	90$		;  this drive doesn't support LBA
	MOV	R1, DKSIZE	; remember the disk size
	BIS	#H.DISK, HFLAGS	; and we have a disk attached

; Type out the drive size and model name ...
	CALL	TDECW	  	; type out the size in megabytes
	$MSG	<MB >
	CLRB	DSKBUF+ID$MOD+ID$MDL-1	; make the model name ASCIZ
	MOV	#DSKBUF+ID$MOD, R1	; point to the model string
	CALL	OUTSTR		; and type that out
	RETURN			; we're done

; Here if no drive is detected ...
90$:	$MSG	<NOT DETECTED>
	RETURN
	.SBTTL	SHOW BREAKPOINTS Command

;++
;   This command will list all the breakpoints which are currently set in
; the user's program.  It has no operands...
;
;	>>>SH BP		-> list all current breakpoints
;--
BPLIST:	CALL	CHKEOL		; there should be no more
	MOV	#BPTADR, R4	; point to the breakpoint table
	BIS	#S.NULL, SFLAGS	; remember that we haven't found any so far

; Loop through the breakpoint table and list all non-zero entries ...
10$:	MOV	(R4)+, R1	; get the address of this breakpoint
	BEQ	20$		; skip zero entries
	$PUSH	R4		; save the table pointer
	MOV	R1, R4		; because the disassembler needs R4
	CALL	TINSTA		; type the breakpoint instruction
	CALL	TCRLF		; ...
	BIC	#S.NULL, SFLAGS	; found at least one non-zero entry
	$POP	R4		; restore the table pointer
20$:	CMP	R4, #BPTEND	; have we finished the list?
	BLO	10$		; nope - keep going

; Here after going through the table...
	BIT	#S.NULL, SFLAGS	; did we find one?
	BNE	30$		; no - say so
	RETURN			; yes - we're all done
30$:	$ERR	<NONE SET>
	.SBTTL	CLEAR BREAKPOINT Command

;++
;   The CLEAR BREAKPOINT command removes a breakpoint at a specific address or,
; if no operand is given, removes all breakpoints.  For example:
;
;	>>>CL BP 17604		-> remove the breakpoint at location 17604
;	>>>CL BP		-> remove all breakpoints
;--
BREMOV:	CALL	SPANW		; get the next character
	CALL	ISEOL		; are there any more arguments?
	BEQ	20$		; no - remove all breakpoints
	CALL	OCTNW		; yes - get the breakpoint address
	CALL	CHKEOL		; and there should be no more after that
	TST	R1		; make sure the address isn't zero
	BNE	10$		; ...
	JMP	COMERR		; don't allow a zero breakpoint address

; Here to remove a single breakpoint; the address is in R1 ...
10$:	CALL	BPTFND		; search for this entry
	BNE	15$		; found it
	CLR	(R4)		; clear the BPTADR entry to remove this one
	RETURN			; and that's all we need to do
15$:	$ERR	<NOT SET>	; no matching breakpoint found

; Here to remove ALL breakpoints ...
20$:	JMP	BPTCLR		; clear the entire table and retirn
	.SBTTL	SET BREAKPOINT Command

;++
;   The Set BREAKPOINT command sets a breakpoint in the user program and it
; requires a single argument giving the address where the breakpoint is to be
; set.  For example:
;
;	>>>SET BP 7604		-> set a breakpoint at location 007604
;
;   The address MUST BE NON-ZERO because it's not possible to set a breakpoint
; at location zero.  Actually the DCT11 wouldn't really care, but we use zero
; to indicate an empty table entry!
;
;   NOTE that this routine only enters the breakpoint into the table - nothing
; actually happens to the user's program until we start it running and the 
; BPTINS routine is called.
;
;   And one more note - breakpoints are executable instructions and as such
; they can only be set on an even address!
;--
SETBPT:	CALL	OCTNW		; go read the address
	CALL	CHKEOL		; and that had better be it
	TST	R1		; make sure the address isn't zero
	BNE	10$		; ...
	JMP	COMERR		; don't allow "BP 0" ...
10$:	BIT	#1, R1		; don't allow odd addresses
	BEQ	11$		; ...
	JMP	ODDADR		; ...

; See if this breakpoint is already in the table..
11$:	CALL	BPTFND		; ...
	BNE	20$		; branch if it's not found
	$ERR	<ALREADY SET>

; Search for a free location in the breakpoint table ...
20$:	MOV	R1, R2		; save the new address for a while
	CLR	R1		; and search for an empty entry
	CALL	BPTFND		; ..
	BEQ	30$		; branch if we found one
	$ERR	<TABLE FULL>

; Insert the breakpoint in the table...
30$:	MOV	R2, (R4)	; store this breakpoint address
	RETURN			; and that's all
	.SBTTL	SHOW VERSION Command

;++
;   The SHOW VERSION command prints the monitor name, version, build date and
; checksum, followed by the Spare Time Gizmos copyright notice.  The alternate
; entry point at SHOVE1 is called by the system startup code...
;
;	>>>SH VE		-> show monitor version
;--
SHOVER:	CALL	CHKEOL		; no argumens allowed
SHOVE1:	MOV	#SYSTEM, R1	; the system name
	CALL	OUTSTR		; ...
	MOV	#BTSVER, R1	; and the version number
	CALL	TDECW		; ... in decimal
	$MSG	<  CHECKSUM >	; type the EPROM checksum
	MOV	CHKSUM, R1	; ...
	CALL	TOCTW		; ... in octal this time
	$MSG	<  BUILD >	; ...
	MOV	#SYSDAT, R1	; type the monitor build date
	CALL	OUTSTR		; ...
	CALL	TCRLF		; finish that line
	MOV	#RIGHTS, R1	; and then type the copyright notice
	CALL	OUTSTR		; ...
	JMP	TCRLF		; ...
	.SBTTL	CLEAR MEMORY Command

;++
;   The CM command zeros user RAM, either a specified range of addresses, or
; all of user RAM.
;
;	>>>CM 1000-1777		; clear RAM from address 1000 to 1777
;	>>>CM			; clear ALL user RAM (from MAXVEC to RAMTOP!)
;
;   Note that clearing is done by words, NOT bytes, so both the starting and
; ending addresses are rounded down to the next even location.
;--
CLRMEM:	CALL	SPANW		; see if an argument was given
	CALL	ISEOL		; ???
	BNE	10$		; branch if there's more there
	JMP	CLRRAM		; no argument - clear everything!

; Here to clear a specific range ...
10$:	CALL	RANGE		; look for a range specification
	CALL	CHKEOL		; and then there should be no more
	MOV	ADDRLO, R1	; get the starting address
	CMP	R1, #MAXVEC	; can't overwrite the vector area!
	BLOS	15$		; bad...
	MOV	ADDRHI, R2	; then get the ending address
	CMP	R1, #RAMTOP	; can't overwrite the I/O area
	BLOS	20$		; this range is OK
15$:	JMP	COMERR		; bad command

; The range looks good ...
20$:	BIC	#1, R1		; make both addresses even
	BIC	#1, R2		; ...
	JMP	CLRRA1		; clear that range and return
	.SBTTL	SET and SHOW LTC Commands

;++
;   The SET LTC ON|OFF command enables or disables line time clock interrupts
; for user programs.  This just determines the initial startup state for the
; program - the user program can change the LTC status at any time by modifying
; the LTCCSR (177546) register.   The SHOW LTC command just reports the current
; LTC setting.
;
;	>>>SET LTC ON		-> enable LTC interrupts
;	>>>SET LTC OFF		-> disable LTC interrupts
;	>>>SHOW LTC		-> show the state of the LTC flag
;
;   NOTE that the LTC setting is saved in NVR and will be restored automatically
; the next time we start up!
;--
SETLTC:	MOV	#OOFTBL, R4	; point to the table of ON/OFF commands
	MOV	#LTCRTN, R3	; and the table of LTC action routines
	JMP	COMNDJ		; parse it, dispatch, and we're done ...

; This table contains the ON and OFF keywords ...
OOFTBL:	.ASCIZ	/ON/
OFFMSG:	.ASCIZ	/OFF/
	.BYTE	0
	.EVEN

; And this is the table of action routines for the LTC ...
LTCRTN:	.WORD	LTCON		; SET LTC ON
	.WORD	LTCOFF		; SET LTC OFF

; Here to turn the LTC on ...
LTCON:	CALL	CHKEOL		; that's the end of the command
	BIS	#H.LTCE, HFLAGS	; turn the LTC on when we start a user program
	MOV	#1, R1		; save a 1 to the LTC flag in NVR 
	JMP	LTCNVR		; ...

; Here to turn the LTC off ...
LTCOFF:	CALL	CHKEOL		; that's the end of the command
	BIC	#H.LTCE, HFLAGS	; disable LTC interrupts
	CLR	R1		; save a 0 to the LTC flag in NVR

; Here to save the current LTC setting in NVR ...
LTCNVR:	MOV	#NV.LTC, R2	; save the LTC setting in this byte
	$WRNVR	R1, R2		; write it to NVR
	JMP	NVRUPD		; update the checksum and we're done


; Here to show the current LTC setting ...
SHOLTC:	CALL	CHKEOL		; that's the end of the command
	$MSG	<LTC is >	; start the message
	BIT	#H.LTCE, HFLAGS	; test the LTC enable bit
				;  ... and fall into SHOOOF ...

; Here to type "ON" or "OFF" ...
SHOOOF:	BEQ	10$		; ON or OFF?
	MOV	#OOFTBL, R1	; ON!
	BR	20$		; ...
10$:	MOV	#OFFMSG, R1	; OFF ...
20$:	CALL	OUTSTR		; type the message
	JMP	TCRLF		; finish the line and we're done
	.SBTTL	SET and SHOW NXM Commands

;++
;   The SET NXM ON|OFF command enables or disables bus timeout (non-existent
; memory) emulation for for user programs.  The SHOW NXM command just reports
; the current NXM emulation setting.
;
;	>>>SET NXM ON		-> enable bus timeout emulation
;	>>>SET NXM OFF		-> disable bus timeout emulation
;	>>>SHOW NXM		-> show the state of bus timeout emulation
;
;   NOTE that the NXM setting is saved in NVR and will be restored automatically
; the next time we start up!
;--
SETNXM:	MOV	#OOFTBL, R4	; point to the table of ON/OFF commands
	MOV	#NXMRTN, R3	; and the table of NXM action routines
	JMP	COMNDJ		; parse it, dispatch, and we're done ...

; This is the table of action routines for the NXM ...
NXMRTN:	.WORD	NXMON		; SET NXM ON
	.WORD	NXMOFF		; SET NXM OFF

; Here to turn bus timeout emulation ON ...
NXMON:	CALL	CHKEOL		; that's the end of the command
	BIS	#H.NXME, HFLAGS	; enable bus time out emulation
	MOV	#1, R1		; save a 1 to the NXM flag in NVR 
	JMP	NXMNVR		; ...

; Here to turn bus timeout emulation OFF ...
NXMOFF:	CALL	CHKEOL		; that's the end of the command
	BIC	#H.NXME, HFLAGS	; disable bus timeout emulation
	CLR	R1		; save a 0 to the NXM flag in NVR

; Here to save the current NXM setting in NVR ...
NXMNVR:	MOV	#NV.NXM, R2	; save the NXM setting in this byte
	$WRNVR	R1, R2		; write it to NVR
	JMP	NVRUPD		; update the checksum and we're done


; Here to show the current NXM setting ...
SHONXM:	CALL	CHKEOL		; that's the end of the command
	$MSG	<NXM is >	; start the message
	BIT	#H.NXME, HFLAGS	; test the NXM enable flag
	JMP	SHOOOF		; type "ON" or "OFF" and we're done
	.SBTTL	SET or SHOW BOOT Command

;++
;   The SET BOOT command parses a default boot device and unit and stores the
; result into NVR. When this monitor starts up, it checks the NVR contents and,
; if a boot device is stored, it will attempt to automatically boot without
; operator intervention.  The SET BOOT NONE command clears any stored boot
; device, and in that case this monitor boots to a command prompt.
;
;  SHOW BOOT just prints the current boot setting, of course...
;
;	>>>SET BOOT DI		-> boot from DI0: on power up
;	>>>SET BOOT DI1234:	-> boot from IDE partition 1234 on power up
;	>>>SET BOOT DD0		-> boot from TU58 unit 0 on power up
;	>>>SET BOOT NONE	-> go to a command prompt on power up
;	>>>SHOW BOOT		-> show the current boot settings
;--
SETBOO:	MOV	R5, R3		; save the command pointer so we can back up
	MOV	#NONKEY, R4	; point to the "NONE" keyword
	CALL	MATCH		; and try to parse that
	BEQ	10$		; yes - SET BOOT NONE ...
	MOV	R3, R5		; nope - backup the parser
	CALL	DEVNW		; we need a device name now
	CMP	#"DD, R2	; does he want to boot TU58?
	BEQ	20$		; yes - that's OK
	CMP	#"DI, R2	; or does he want to boot IDE?
	BEQ	20$		; that's OK too
	JMP	BADDEV		; those are the only two boot devices for now

; Here for SET BOOT NONE ...
10$:	CLR	R2		; clear the device name
	CLR	R1		; and clear the unit number

; Store the device and unit in NVR ...
20$:	CALL	CHKEOL		; that should be the end of the command
	$PUSH	R2		; save the device name for a moment
	MOV	#NV.BUN, R2	; store the boot unit
	CALL	WRNVRW		; ...
	$POP	R1		; then get the device name
	MOV	#NV.BDV, R2	;  ... and store that in NVR too
	CALL	WRNVRW		; ...
	JMP	NVRUPD		; update the checksum and we're done


; Here to show the default boot device ...
SHOBOO:	CALL	CHKEOL		; there are no arguments here
	MOV	#NV.BDV, R2	; get the boot device
	CALL	RDNVRW		;  ... from NVR
	TST	R1		; is it zero ??
	BNE	10$		; no - type a real device and unit
	MOV	#NONKEY, R1	; yes - there's no default boot
	CALL	OUTSTR		;  ... so say "NONE"
	$NONVR			; done with NVR
	JMP	TCRLF		; and done with this line

; Here to print the boot device and unit ...
10$:	MOV	R1, R0		; put the device name in R0
	CALL	T2CHAR		; and type it out
	MOV	#NV.BUN, R2	; then get the unit number
	CALL	RDNVRW		; ...
	CALL	TDECU		; type that out
	$NONVR			; done using NVR
	JMP	TCRLF		; finish the line and we're done


; The keyword for "no boot device" ...
NONKEY:	.ASCIZ	/NONE/
	.EVEN
	.SBTTL	SHOW NVR Command

;++
;   The SHOW NVR command will dump the NVR contents in octal, including the RTC
; registers.  It's handy for debugging but that's about all.
;
;	>>> SHOW NVR		-> dump NVR/RTC contents in octal
;--
SHONVR:	CALL	CHKEOL		; no arguments allowed
	CLR	R2		; keep track of the NVR offset
10$:	MOV	R2, R1		; get the current offset
	CALL	TOCTB		; type it
	$TYPE	'/		; then a separator
	CALL	TSPACE		; and a space

; Type the next NVR byte ...
20$:	$RDNVR	R2, R1		; read a byte from NVR
	CALL	TOCTB		; type that
	CALL	TSPACE		; ...
	INC	R2		; on to the next byte
	BIT	#17, R2		; have we done sixteen?
	BNE	20$		; no - put more on this line
	CALL	TCRLF		; yes - start a new line
	CMP	R2, #RTC.SZ	; have we done them all ?
	BLO	10$		; nope - start another line

;   Now compute the actual NVR checksum and type that out, and then verify that
; against the value actually stored and see if it's good.
	$MSG	<CHECKSUM=>
	CALL	NVRCHK		; compute the actual checksum
	$PUSH	R0		; save the result temporarily
	MOV	R0, R1		; get the low byte
	CALL	TOCTB		; and type that
	CALL 	TSPACE		; ...
	$POP	R1		; then get the checksum back
	SWAB	R1		; and type the bigh byte
	CALL	TOCTB		; ...
	CALL	NVRTST		; does the checksum match the stored value?
	BNE	30$		; no match!
	MOV	#COKMSG, R1	; checksum good - print "CONTENTS OK"
	BR	31$		; ...
30$:	MOV	#CIVMSG, R1	; bad checksum - say "CONTENTS INVALID"
31$:	CALL	OUTSTR		; print the message
	CALL	TCRLF		; and a CRLF
	$NONVR			; we're done using NVR for now
	RETURN			; and return

; NVR checksum good/bad messages ...
COKMSG:	.ASCIZ	/ CONTENTS OK/
CIVMSG:	.ASCIZ	/ CONTENTS INVALID/
	.EVEN
	.SBTTL	CLEAR NVR Command

;++
;   The CLEAR NVR command will fill the DS12887 non-volatile RAM with zeros and
; then write a valid checksum to the end.  The timekeeping registers are NOT
; touched by this routine.  This is handy for initiailizing a new DS12887A chip
; to a known state.
;
;	>>>CLEAR NVR		-> clear NVR to a known state
;--
CLRNVR:	CALL	CHKEOL		; no more arguments

; Fill every NVR location with zeros ...
10$:	MOV	#RTC.RM, R2	; starting offset of general purpose RAM
11$:	$WRNVR	#0, R2		; clear each location
	INC	R2		; on to the next one
	CMP	R2, #RTC.SZ	; have we done them all?
	BLO	11$		; no - keep filling

;   All done - write the current NVR version number and then compute and store
; a valid checksum.  That'll make a valid, but empty, NVR ...
	$WRNVR	#377, #RTC.RM	; this location is always 377
	$WRNVR	#NVRVER, #NV.VER; and the next location is always the version
	JMP	NVRUPD		; update the checksum and return ...
	.SBTTL	TEST NVR Command

;++
;   The TEST NVR command will fill NVR with various patterns, read them back,
; and verify that the RAM part is working.  It doesn't actually test the non-
; volatile part, of course.  The test repeats endlessly until you type ^C or
; restart this monitor.
;
;	>>>TEST NVR		-> test the DS12887A RTC/NVR chip
;
;   Note that this is very careful not to disturb the time registers, however
; any settings or boot options saved in NVR will be lost!
;--
TSTNVR:	CALL	CHKEOL		; no arguments allowed
	CLR	PASSK		; clear the pass counter
	CLR	FAILK		; and clear the failure count too

; Pass 1 - fill every NVR location with its address ...
10$:	MOV	#RTC.RM, R2	; starting offset of general purpose RAM
11$:	$WRNVR	R2, R2		; write each location with its address
	INC	R2		; on to the next one
	CMP	R2, #RTC.SZ	; have we done them all?
	BLO	11$		; no - keep filling

; Pass 2 - verify those addresses ...
20$:	MOV	#RTC.RM, R2	; start at the beginning again
21$:	$RDNVR	R2, R1		; read a byte
	CMPB	R1, R2		; compare it with its addres
	BEQ	22$		; skip if they match
	INC	FAILK		; nope - NVR failure
22$:	INC	R2		; on to the next location
	CMP	R2, #RTC.SZ	; have we done them all?
	BLO	21$		; ...

; Pass 3 - fill every NVR location with its complement ...
30$:	MOV	#RTC.RM, R2	; same old thing
31$:	MOV	R2, R1		; ...
	COM	R1		; but use the complement of the address
	$WRNVR	R1, R2		; ...
	INC	R2		; ...
	CMP	R2, #RTC.SZ	; ...
	BLO	31$		; ...

; Pass 4 - verify those complements ...
40$:	MOV	#RTC.RM, R2	; ...
41$:	$RDNVR	R2, R1		; read a byte from NVR
	BIS	R2, R1		; should be the complement of the address
	CMPB	#377, R1	; ???
	BEQ	42$		; ...
	INC	FAILK		; nope - NVR failure
42$:	INC	R2		; ...
	CMP	R2, #RTC.SZ	; ...
	BLO	41$		; ...

; End of pass ...
	CALL	TSTPAS		; print the pass count
	BR	10$		; and go do it again


;   This routine will print both the pass count and also the failure count.
; Note that calling this implicitly tests for ^C too!
TSTPAS:	$TYPE	CH.CRT		; print carriage return but no LF!
	$MSG	<PASS >		; print the pass count
	CMP	#177777, PASSK	; don't let the pass count roll over!
	BEQ	10$		; just freeze there
	INC	PASSK		; otherwise bump the pass counter
10$:	MOV	PASSK, R1	; type the count
	CALL	TDECU		;  ... unsigned, of course!
	TST	FAILK		; were there any failures?
	BEQ	20$		; no - quit now
	$MSG	< FAILURES >	; yes - type that count too
	MOV	FAILK, R1	; ...
	CALL	TDECU		; ...
20$:	$MSG	< ...>		; ...
	RETURN			; and keep testing


;;NVERR:	$PUSH	<R2, R1>
;;	$MSG	<NVR ERROR LOC=>
;;	MOV	R2, R1
;;	CALL	TOCTB
;;	CALL	TCRLF
;;	$POP	<R1, R2>
;;	RETURN
	.SBTTL	TEST MEMORY Command

;++
;   This routine will perform an exhaustive test on memory using the "Knaizuk
; and Hartmann" algorithm (Proceedings of the IEEE April 1977).  This algorithm
; first fills memory with all ones and then writes a word of zeros to every
; third location.  These values are read back and tested for errors, and then
; the procedure is repeated twice more, changing the positon of the zero words
; each time.  After that, the entire algorithm is repeated three more times,
; this time using a memory fill of zeros and every third word is written with
; ones.  Strange as it may seem, this test can actually detect any combination
; of stuck data and/or stuck address bits.
;
;	>>>TEST MEMORY			-> run exhaustive memory test
;
; Register usage:
;	R2   = memory address
;	R3.1 = filler byte
;	R3.0 = test byte
;	R4.0 = modulo 3 counter (current)
;	R4.1 = iteration number (modulo 3 counter for this pass)
;
;--
TSTRAM:	CALL	CHKEOL		; there should be no more 
	CLR	PASSK		; clear PASSK and ERRORK
	CLR	FAILK		; ...
	RETURN

;;; Here to start another complete pass (six iterations per pass)...
;;10$:	$MSG	<TESTING RAM >	; "TESTING RAM "
;;	MOV	#177400, R3	; load the first test pattern
;;11$:	LDI	2		; initialize the modulo 3 counter
;;	PHI	P4		; ...
;;
;;; Loop 1 - fill memory with the filler byte...
;;RAMT1:	SEX	SP		; point at the stack
;;	IRX			; point to the memory size on the TOS
;;	LDX			; get that
;;	SMI	1		; minus 1
;;	PHI	P2		; and point P2 at the top of memory
;;	DEC	SP		; protect the TOS
;;	LDI	$FF		; and the low byte is always FF
;;	PLO	P2		; ...
;;RAMT1A:	GHI	P3		; get the filler byte
;;	SEX	P2		; and use P2 to address memory
;;	STXD			; and store it
;;	GHI	P2		; check the high address byte
;;	ANI	$80		; have we rolled over from $0000 to $FFFF?
;;	LBZ	RAMT1A		; nope - keep filling
;;	CALL(F_BRKTEST)		; does the user want to stop now?
;;	LBDF	MAIN		; yes - quit now
;;
;;; Loop 2 - fill every third byte with the test byte...
;;RAMT2:	RCLEAR(P2)		; this time start at $0000
;;	GHI	P4		; reset the modulo 3 counter
;;	PLO	P4		; ...
;;RAMT2A:	GLO	P4		; get the modulo 3 counter
;;	LBNZ	RAMT2B		; branch if not the third iteration
;;	GLO	P3		; third byte - get the test byte
;;	STR	P2		; and store it in memory
;;	LDI	3		; then re-initialize the modulo 3 counter
;;	PLO	P4		; ...
;;RAMT2B:	DEC	P4		; decremement the modulo 3 counter
;;	INC	P2		; and increment the address
;;	GHI	P2		; get the high address byte
;;	SEX	SP		; point at the stack
;;	IRX			; point to the memory size on the TOS
;;	XOR			; are they equal?
;;	DEC	SP		; (protect the TOS)
;;	LBNZ	RAMT2A		; nope - keep going
;;	CALL(F_BRKTEST)		; does the user want to stop now?
;;	LBDF	MAIN		; yes - quit now
;;
;;; Loop 3 - nearly the same as Loop2, except this time we test the bytes...
;;RAMT3:	RCLEAR(P2)		; start at $0000
;;	GHI	P4		; reset the modulo 3 counter
;;	PLO	P4		; ...
;;RAMT3A:	GLO	P4		; get the modulo 3 counter
;;	LBNZ	RAMT3B		; branch if not the third iteration
;;	LDI	3		; re-initialize the modulo 3 counter
;;	PLO	P4		; ...
;;	GLO	P3		; and get the test byte
;;	SKP			; ...
;;RAMT3B:	GHI	P3		; not third byte - test against fill byte
;;	SEX	P2		; address memory with P2
;;	XOR			; does this byte match??
;;	LBZ	RAMT3C		; branch if success
;;
;;; Here if a test fails...
;;	OUTSTR(REAMSG)
;;	RCOPY(P1,P2)
;;	CALL(THEX4)
;;	CALL(TCRLF)
;;	CALL(INERRK)
;;
;;; Here if the test passes - on to the next location...
;;RAMT3C:	DEC	P4		; decremement the modulo 3 counter
;;	INC	P2		; and increment the address
;;	GHI	P2		; get the high address byte
;;	SEX	SP		; address the stack
;;	IRX			; point to the memory size on the TOS
;;	XOR			; are they equal??
;;	DEC	SP		; (protect the TOS)
;;	LBNZ	RAMT3A		; nope - keep going
;;	CALL(F_BRKTEST)		; does the user want to stop now?
;;	LBDF	MAIN		; yes - quit now
;;
;;; This pass is completed - move the position of the test byte and repeat...
;;	OUTCHR('.')
;;	GHI	P4		; get the current modulo counter
;;	SMI	1		; decrement it
;;	BL	RAMT4		; branch if we've done three passes
;;	PHI	P4		; nope - try it again
;;	LBR	RAMT1		; and do another pass
;;
;;;   We've done three passes with this test pattern.  Swap the filler and
;;; test bytes and repeat...
;;RAMT4:	GLO	P3		; is the test byte $00??
;;	LBNZ	RAMT5		; nope - we've been here before
;;	RLDI(P3,$00FF)		; yes - use 00 as the fill and FF as the test
;;	LBR	RAMT0A		; reset the modulo counter and test again
;;
;;; One complete test (six passes total) are completed..
;;RAMT5:	CALL(INPASK)		; increment PASSK
;;	CALL(PRTPEK)		; print the pass/error count
;;	CALL(TCRLF)		; finish the line
;;	LBR	RAMT0		; and go start another pass
;;
;;
;;
;;; RAM test messages...
;;RTSMSG:	.TEXT	"Testing RAM \000"
;;REAMSG:	.TEXT	"\r\n?RAM ERROR AT \000"
;;
;;	.EJECT
;;;	.SBTTL	Diagnostic Support Routines
;;
;;; We assume these two items are in order!
;;#if ((ERRORK-PASSK) != 2)
;;	.ECHO	"**** ERROR **** PASSK/ERRORK out of order!"
;;#endif
;;
;;;   This little routine will clear the current diagnostic pass and error
;;; counts (PASSK: and ERRORK:).  It's called at the start of most diagnostics.
;;CLRPEK:	LDI	LOW(PASSK+3)	; PASSK is first, then ERRORK
;;	PLO	DP		; ...
;;	SEX	DP		; ...
;;	LDI	0		; ...
;;	STXD\ STXD		; clear ERRORK
;;	STXD\ STXD		; and clear PASSK
;;	RETURN			; all done
;;
;;; Incrememnt the current diagnostic pass counter...
;;INPASK:	LDI	LOW(PASSK+1)	; point to the LSB first
;;	LSKP			; and fall into INERRK...
;;
;;; Increment the current diagnostic error counter...
;;INERRK:	LDI	LOW(ERRORK+1)	; point to ERRORK this time
;;	PLO	DP		; ...
;;	SEX	DP		; ...
;;	LDX			; get the lest significant byte
;;	ADI	1		; increment it
;;	STXD			; and put it back
;;	LDX			; now get the high byte
;;	ADCI	0		; include the carry (if any)
;;	STR	DP		; put it back
;;	RETURN			; and we're done
;;
;;; Print the current diagnostic pass and error count...
;;PRTPEK:	INLMES(" Pass ")
;;	LDI	LOW(PASSK)	; point DP at the pass counter
;;	PLO	DP		; ...
;;	SEX	DP		; and use DP to address memory
;;	POPR(P1)		; load PASSK into P1
;;	DEC	DP		; point at the low byte again
;;	OUT	LEDS		; display the pass count on the LEDs
;;	CALL(TDEC16)		; print the pass count in decimal
;;	INLMES(" Errors ")	; ...
;;	SEX	DP		; (SCRT changes X!)
;;	POPR(P1)		; and now get ERRORK
;;	LBR	TDEC16		; print that and return
;;
;;; Messages (some) ...
;;RTMSG1:	.TEXT	" bytes - press BREAK to abort\000"
	.SBTTL	Load BASIC-11 from ROM

;++
;--
	.IF	DF BASIC
BASGO:	CALL	CHKEOL
	
; Initialize ...
	CALL	CLRRAM
	CALL	IOINIT
	CALL	INIREG
	CALL	HLTVEC

; load all the segments
	CALL	CHKEOL
	MOV	#BASTAP, R4
	CALL	ROMLDR
	MOV	R1, USRPC

; This is the magic!
	MOV	#50, R2
	CLR	R1
	CALL	WRRAM
	ADD	#2, USRPC	; SKIP THE INITIAL RESET

; and away we go!
	BIC	#S.STEP!S.SSBP, SFLAGS
	JMP	UCLOAD
;	RETURN
	.ENDC

;++
;   Load an absolute image from EPROM. 
;
;	<R4 points to the image in EPROM>
;	CALL	ROMLDR
;	<return with start address in R1>
;--
ROMLDR:	MOV	(R4)+, R3	; get the count of bytes
	BEQ	30$		; branch if this is the end
	MOV	(R4)+, R2	; and the starting address
20$:	MOVB	(R4)+, R1	; get the next byte of data
	CALL	WRRAMB		; and write it to (R2)
	INC	R2		; bump up the address
	SOB	R3, 20$		; and do the whole block

; We've finished this block - start the next one ...
	INC	R4		; be sure the address is even
	BIC	#1, R4		; ...
	BR	ROMLDR		; then keep going

; Here when we reach the end ...
30$:	MOV	(R4)+, R1
	RETURN
	.SBTTL	Breakpoint Utility Functions

;++
;   Search the breakpoint table for one at the address in R1.  If a match is
; found then return with the Z flag set.  In this case R4 points to the matching
; BPTADR table entry, and R3 points to the BPTDAT table entry.  If no match is
; found then return with Z clear and R3/R4 indeterminate.
;
;	<R1 contains the breakpoint address to find>
;	CALL	BPTFND
;	<return with Z set if match; Z cleared if no match>
;	<on match, R3 points to BPTDAT and R4 points to BPTADR>
;
;   NOTE - a cute trick is to call this routine with R1=0.  In that case the
; effect is to find the next free entry in the breakpoint table.  If there are
; no free entries, then Z=0 on return.
;--
BPTFND:	MOV	#BPTDAT, R3	; initialize the search pointers
	MOV	#BPTADR, R4	; ...
10$:	CMP	R1, (R4)	; does this entry match ?
	BEQ	20$		; it's a winner!
	TST	(R3)+		; nope - bump both R3 and R4
	TST	(R4)+		; ...
	CMP	R4, #BPTEND	; have we done them all?
	BLO	10$		; no - keep looking
	CLZ			; yes - return Z cleared
20$:	RETURN			; and we're done


;++
; This routine will zero all the BPTADR entries and clear the breakpoint table.
;--
BPTCLR:	MOV	#BPTADR, R4	; point to the table
10$:	CLR	(R4)+		; clear the next entry
	CMP	R4, #BPTEND	; have we done them all?
	BLO	10$		; not yet
	RETURN			; yep, all done
	.SBTTL	Insert or Remove Breakpoints in Memory

;++
;   This routine will insert breakpoints in the user's program at the locations
; specified in the breakpoint table.  The current contents of each breakpoint
; location are saved in the BPTDAT table, and then are replaced by a BPT
; instruction.  This routine is normally called just before starting the user's
; program!
;
;	CALL	BPTINS
;	<uses all registers!>
;--
BPTINS:	BIT	#S.BPTI, SFLAGS	; are breakpoints already installed?
	BNE	90$		; yes - just quit now
	MOV	#BPTADR, R4	; point R4 at the breakpoint address table
	MOV	#BPTDAT, R3	; and R3 and the breakpoint data table

; Loop through the table and insert the breakpoints...
10$:	MOV	(R4)+, R2	; get the next address
	BEQ	15$		; ignore zero entries
	CALL	RDRAM		; get the current contents of this location
	MOV	R1, (R3)+	; and store in the BPTDAT table
	MOV	#<BPT>, R1	; store a BPT instruction
	CALL	WRRAM		;  ... in the user's program
	BR	19$		; go see if we're finished
15$:	TST	(R3)+		; this entry isn't used - bump R3 too
19$:	CMP	R4, #BPTEND	; have we finished the list?
	BLO	10$		; no - keep going
	BIS	#S.BPTI, SFLAGS	; remember that breakpoints are installed
90$:	RETURN			; yes -- quit now


;++
;   This routine will restore the original contents of all breakpoint locations
; in the user's program from the table at BPTDAT.  It is normally called after
; a trap back to the monitor stops the user's program.  Breakpoints must be
; restored so that the user may examine or change them.
BPTRMV:	BIT	#S.BPTI, SFLAGS	; are breakpoints installed?
	BEQ	90$		; no - just quit now
	MOV	#BPTADR, R4	; point R4 at the breakpoint address table
	MOV	#BPTDAT, R3	; and R3 and the breakpoint data table

; Loop through the breakpoint table and restore all data...
10$:	MOV	(R3)+, R1	; get the next breakpoint data
	MOV	(R4)+, R2	; and get the next breakpoint address
	BEQ	15$		; ignore zero entries
	CALL	WRRAM		; restore the original contents
15$:	CMP	R4, #BPTEND	; have we done them all yet?
	BLO	10$		; no - keep going
	BIC	#S.BPTI, SFLAGS	; remember breakpoints are removed
90$:	RETURN			; yes -- that's it for this time
	.SBTTL	Initialize I/O Devices

;++
;   This routine will assert the BCLR signal and initialize all hardware on the
; SBCT11 board.  We have to be a bit careful about doing this because it may
; screw up the console DLART if that device is busy transmitting right now. 
; We also have to be careful about the 8255 PPI, which will be reset by BCLR.
; This will change PPI port B back to an input and erase the current POST and
; RUN LED settings.  Losing these isn't the end of the world, but we make an
; effort to re-initialize the PPI and preserve the POST and RUN LED state.
;
;	CALL	IOINIt
;	<always return here>
;--
IOINIT:	CALL	CONWAI		; make sure the console is idle first
	$PUSH	@#PPIB		; save the current POST and RUN LED flags
	RESET			; assert BCLR and reset everything
	MOVB	#PPIMOD,@#PPICSR; re-initialize the PPI mode
	$POP	@#PPIB		; restore the POST code and RUN LED state
	JMP	CONINI		; re-initialize the console and we're done
	.SBTTL	Initialize Registers

;++
;   This routine will initialize the saved user registers.  It approximates
; what would happen after a PUP if the user program was running standalone,
; but we take a few liberties.  In particular, the DCT11 doesn't initialize
; any of the registers EXCEPT for SP, PC and PS.
;--
INIREG:	CLR	USRREG+<2*0>	; clear R0 thru R5
	CLR	USRREG+<2*1>	; ...
	CLR	USRREG+<2*2>	; ...
	CLR	USRREG+<2*3>	; ...
	CLR	USRREG+<2*4>	; ...
	CLR	USRREG+<2*5>	; ...
;   On the DCT11, PUP sets the PS to 340 (interrupts masked off), but on all the
; real LSI-11 processors (03, 23+, 73, etc) set the PS to zero.  Turns out that
; this matters to some software, so we'll go with the LSI-11 thinking...
;;	MOV	#PS.PR7, USRPS	; initialize the PS
	CLR	USRPS		; set the PS to zero
	MOV	#USRSTK, USRSP	; initialize the SP
;   The DCT11 and LSI-11s all set the start address according to some jumpers,
; but the only address that's really useful here is zero.  Starting in the ROM
; (e.g. 172000 or 173000) won't get us anything we don't already have!
	CLR	USRPC		; default start address
	RETURN
	.SBTTL	Initialize Vectors

;++
;   This routine will fill ALL the DCT11 vectors with pointers to our own
; "UNEXPECTED INTERRUPT" entry.  It then goes back and fills all the defined
; vectors (e.g. breakpoint, illegal instruction, power fail, etc) with pointers
; to the correct entry point.
;--
INIVEC:	MOV	#4, R2		; start with vector 4
10$:	MOV	#UINTRQ, (R2)+	; set the interrupt vector
	MOV	#PS.PR7, (R2)+	; and the PS
	CMP	R2, #MAXVEC+4	; have we done them all?
	BLO	10$		; no - keep going

;   Now initialize all the defined vectors (or at least the ones that we care
; about).  Note that we don't have to set the PS this time around - that's
; already been set above ...
	MOV	#BPTRQ, @#BPTVEC; breakpoint trap
	MOV	#TRAPRQ,@#TRPVEC; TRAP trap
	MOV	#EMTRQ, @#EMTVEC; EMT trap
	MOV	#IOTRQ, @#IOTVEC; IOT trap
	MOV	#PFRQ,  @#PFAVEC; power fail trap
	MOV	#IINSRQ,@#IINVEC; illegal instruction trap
	MOV	#RINSRQ,@#RINVEC; reserved instruction trap
	RETURN


;++
;   This routine is similar to INIVEC, except that this time all vectors will be
; preloaded with HALT instructions.  In this instance you can deduce with vector
; was taken from the halt address printed by the monitior.  The ONLY vector that
; isn't initialized to halt is the breakpoint/T-bit vector.
;--
HLTVEC:	MOV	#4, R2		; start with vector 4
10$:	MOV	R2, R1		; copy the vector address
	ADD	#2, R1		; and point to the next (PSW) word
	MOV	R1, (R2)+	; store that in the vector
	CLR	(R2)+		; and make the next word a HALT
	CMP	R2, #MAXVEC+4	; have we done them all?
	BLO	10$		; no - keep going
	MOV	#BPTRQ, @#BPTVEC  ; initialize the breakpoint trap
	MOV	#PS.PR7,@#BPTVEC+2; and give it a real PSW
	RETURN			; all done
	.SBTTL	Test and Set NVR Checksum

;++
;   This routine will compute a 16 bit folded checksum of the non-volatile RAM
; part of the DS12887 RTC/NVR chip.  The time registers are not included of
; course (that'd be pretty stupid!), and neither are the last two bytes of NVR.
; The latter are used to store the checksum and are not included in the
; calculation of the checksum.
;
;	CALL	NVRCHK
;	<return checksum in R0>
;--
NVRCHK:	CLR	R0		; accumulate the checksum here
	MOV	#RTC.RM, R2	; start with the first NVR location
10$:	$RDNVR	R2, R1		; read a byte from NVR
	ADD	R1, R0		; add it to the total
	ASL	R0		; rotate the checksum left
	ADC	R0		;  ... with end around carry
	INC	R2		; move on to the next byte
	CMP	R2, #NV.CHK	; have we done them all ?
	BLO	10$		; nope - keep going
	$NONVR			; done using NVR now
	RETURN			; return the checksum in R0


;++
;   This routine will compute the NVR checksum and then compare that to the last
; two bytes stored in NVR.  If they match then the NVR contents are valid and we
; return with the zero flag set.  If they don't match, then we return with zero
; cleared.
;
;	CALL	NVRTST
;	<return with carry set if NVR checksum is valid>
;--
NVRTST:	CALL	NVRCHK		; compute the current NVR checksum
	MOV	#NV.CHK, R2	; read the last two bytes from NVR
	CALL	RDNVRW		; ...
	$NONVR			; done using NVR now
	CMP	R0, R1		; return Z set if they match
	RETURN			; ...


;++
;   This routine will update the checksum stored in NVR.  Whatever's in there
; now becomes the "correct" contents and the checksum will reflect that.
;
;	CALL	NVRUPD
;	<always return here>
;--
NVRUPD:	CALL	NVRCHK		; compute the current NVR checksum
	MOV	#NV.CHK, R2	; store the checksum in the last two bytes
	MOV	R0, R1		; ...
	CALL	WRNVRW		; ..
	$NONVR			; done using NVR
	RETURN			; ...
	.SBTTL	Read and Write NVR Words

;++
;  Just like RDNVRB, except read one word (two consectutive bytes) ...
;
;	<NVR address, 0..126, in R2>
;	CALL	RDNVRW
;	<return NVR word in R1>
;--
RDNVRW:	$RDNVR	R2, R1		; read the first (low order) byte
	$PUSH	R1		; save that for later
	INC	R2		; then read the next byte
	$RDNVR	R2, R1		; ...
	SWAB	R1		; this is the high order byte
	BIS	(SP)+, R1	; OR in the low byte
	RETURN			; and we're done


;++
;  Just like WRNVRB, except write one word (two consectutive bytes) ...
;
;	<NVR address, 0..126, in R2>
;	<word to be written in R1>
;	CALL	WRNVRW
;--
WRNVRW:	$PUSH	R1		; save the word we're writing
	$WRNVR	R1, R2		; and write the low byte first
	INC	R2		; write the next byte
	$POP	R1		; get the original word back
	SWAB	R1		; and write the high byte this time
	$WRNVR	R1, R2		; ...
	RETURN			; ... and return
	.SBTTL	Command Error Processing

;++
;   This routine is called whenever a syntax error is found in the command.  It
; echos the part of the command which has already been scanned inside question
; marks (very much like TOPS-10 used to do!) and then restarts the monitor.
; That's the extent of our error diagnostics!
;
;   Remember - since this routine never actually returns, you don't need to
; CALL here; just JMP here instead!
;--
COMERR:	CALL	ISEOL		; is the current character the end ?
	BEQ	10$		; yes - don't increment R5
	INC	R5		; be sure the bad character gets printed
10$:	CLRB	(R5)		; mark the end of what was actually scanned
	$TYPE	'?		; type the first question mark
	MOV	#CMDBUF, R1	; then echo the part of the command that
	CALL	OUTSTR		;  was actually parsed
	$TYPE	'?		; echo another question mark
	JMP	RESTA		; and then restart the monitor


;++
;   Unlike COMERR (which reports syntax errors in the command line), this ERRMES
; routine is called for semantic errors which have a real associated error
; message string.  It's called via a "JSR R1," and the error message is passed
; inline, as it is with INLMES.  This routine never returns and instead restarts
; the monitor when it's done printing, which resets the stack and implicitly
; removes the extra junk.
;
; CALL:
;	JSR	R1, ERRMES
;	.ASCIZ	/error message/
;	.EVEN
;	<control never returns!!>
;
;   The $ERR macro is handy for generating calls to ERROR.
;--
ERRMES:	$TYPE	'?		; always type a question mark first
	CALL	OUTSTR		; then type the error message text
	JMP	RESTA		; restart the monitor and read another command
	.SBTTL	Basic Command Line Routines

;++
;   These are the basic routines used to scan and parse the command line.
; REMEMBER - all the time we're parsing the command line the pointer to the
; next character is always kept in R5!!
;--

;++
;   Return with Z=1 if the character in R0 is any of the ones that we accept
; as end of command.  That is, any of ";" (used to separate multiple commands
; on the same line), "!" (used to introduce a comment), or NULL (end of string).
;
;	<character to test in R0>
;	CALL	ISEOL
;	<return with Z=1 if EOL>
;--
ISEOL:	MOVB	(R5), R0	; fetch the current character from the line
ISEOL1:	TSTB	R0		; check for EOS first
	BEQ	10$		; yep - return Z=1
	CMPB	#';, R0		; how about a command separator?
	BEQ	20$		; that's it
	CMPB	#'!, R0		; and lastly test for a comment
	BEQ	20$		; ,,,
10$:	RETURN			; return whatever we found
20$:	CLR	R0		; for ";" or "!" pretend it's EOS
	RETURN			; ...

;++
; Return with zero set if R0 contains a space or tab character ...
;
;	<character to test in R0>
;	CALL	ISSPA
;	<return with Z=1 if space or tab>
;--
ISSPA:	CMPB	#' , R0		; test for a space
	BEQ	10$		; return now if so
	CMPB	#CH.TAB, R0	; or is it a tab?
	BNE	10$		; no - return Z cleared
	MOVB	#' , R0		; convert a tab to a space
	SEZ			; (MOVB changes the condition codes!)
10$:	RETURN			; and return
	


;++
;   Get the CURRENT character from the command line, using R5 as the pointer.
; If the character fetched is lower case, then fold it to upper case before
; returning.   Zero is returned for the end of the command line already, but
; if the character is either ";" (used to separate multiple commands on a line)
; or "!" (used to start a comment) then zero is also returned.  This special
; processing for end of command and lower case is the only reason to use this
; routine instead of just "MOVB (R5), ...".
;
;	<be sure R5 points to the command buffer>
;	CALL	 GETCCH
;	<return with the CURRENT character in R0>
;--
GETCCH:	CALL	ISEOL		; get the current character and test for EOL
	BEQ	10$		; quit now if it's the end
	CMPB	R0, #140	; is this a lower case letter
	BLO	10$		; nope - return it as-is
	SUB	#40, R0		; yes - convert to upper case
10$:	RETURN			; and we're done


;++
;   Get the NEXT character from the command line, using R5 as the pointer.  This
; is exactly the same as GETCCH, except that R5 is incremented first.  UNLESS,
; R5 currently points to any end of command character, in which case R5 is not
; incremented and null is returned again.
;
;	<be sure R5 points to the command buffer>
;	CALL	 GETNCH
;	<return with NEXT character in R0>
;--
GETNCH:	CALL	ISEOL		; get the current character and test for EOL
	BEQ	10$		; quit now if it's the end
	INC	R5		; safe to increment the pointer
	BR	GETCCH		; it's the current character we want now
10$:	RETURN			; EOS - return zero


;++
;   This routine will "backup" the command scanner one character.  It's sort of
; the equivalent to ungetch(), except that you can't push back an arbitrary
; character.  This would be as easy as "DEC R5", except that we have to be
; careful around EOL.  If the current character is any of ";", "!", or EOS then
; we don't want to back up because GETCH never advanced in the first place!
;
;	<be sure R5 points to the command buffer>
;	CALL	BACKUP
;--
;;BACKUP:	CALL	ISEOL		; test the current character for EOL
;;	BEQ	10$		; yes - do nothing
;;	DEC	R5		; no - it's safe to back up
;;10$:	RETURN			; and we're done


;++
;   SPANW will skip any white space and then return the next non-blank command
; line character.
;
;	<be sure R5 points to the command buffer>
;	CALL	SPANW
;	<return next non-blank character in R0>
;--
SPANW:	CALL	GETCCH		; start with the current character
10$:	CALL	ISSPA		; is it a space?
	BNE	20$		; nope - we're done
	CALL	GETNCH		; yes - get the next character
	BR	10$		; and keep looking
20$:	RETURN			; otherwise we can quit now


;++
;   CHKEOL will test the CURRENT command character (the one pointed to by R5)
; to see if it's the end of the command.  If it is then we just return without
; doing anything, but if it isn't then we jump to COMERR and abort parsing.
; Any spaces before the EOL will be ignored.
;
;   Note that the name is something of a misnomer - it really tests for end
; of command (";", "!" or null) and not just end of line.
;
;	<be sure R5 points to the command buffer>
;	CALL	CHKEOL
;	<return here only if we're at the end of the command>
;--
CHKEOL:	CALL	SPANW		; skip any white space first
	CALL	ISEOL		; is the current character EOL?
	BNE	10$		; branch if not
	RETURN			; it is - return silently
10$:	JMP	COMERR		; no EOL - report a syntax error


;++
;   This routine will verify that the current character is a white space.  If it
; isn't then it jumps to COMERR and aborts the current command.  Note that the
; end of line/command is NOT considered a space!
;
;	<be sure R5 points to the command buffer>
;	CALL	CHKSPA
;	<return here only if the current character is a space>
;--
CHKSPA:	CALL	GETCCH		; get the current character
	CALL	ISSPA		; is it a space??
	BNE	10$		; nope - report a syntax error
	RETURN			; yes - aall is well
10$:	JMP	COMERR		; no EOL - report a syntax error


;++
;   This routine will return with Z set if there are NO more arguments for this
; command, and Z cleared if there are.  No error messages are generated in 
; either case!
;
;	<be sure R5 points to the command buffer>
;	CALL	CHKARG
;	<return Z cleared if there are more arguments>
;--
CHKARG:	CALL	SPANW		; first skip any white space
	BR	ISEOL1		; then check for EOL
	.SBTTL	Simple Lexical Functions

;++
; Return with carry set if R0 contains a decimal digit, 0..9 ...
;--
ISDEC:	CMPB	R0, #'9+1	; carry = 0 if R0 is above 9
	BHIS	10$		; return with carry clear
	CMPB	#'0-1, R0	; carry = 1 if R0 is above 0
10$:	RETURN


;++
; Return with carry set if R0 contains an octal digit, 0..7 ...
;--
ISOCT:	CMPB	R0, #'7+1	; carry = 0 if R0 is above 7
	BHIS	10$		; return with carry clear
	CMPB	#'0-1, R0	; carry = 1 if R0 is above 0
10$:	RETURN


;++
; Return with carry set if R0 contains a letter A..Z ...
;--
ISLET:	CMPB	R0, #'Z+1	; carry = 0 if R0 is above Z
	BHIS	10$		; return with carry clear
	CMPB	#'A-1, R0	; carry = 1 if R0 is above A
10$:	RETURN


;++
; Return with carry set if R0 contains a letter OR a digit ...
;--
ISALNU:	CALL	ISLET		; is it a letter?
	BCS	10$		; yes - return
	BR	ISDEC		; no - test for a digit and return
10$:	RETURN			; ...


;++
; Return with carry set if R0 contains a printing ASCII character ...
;--
ISPRNT:	CMPB	R0, #177	; carry = 0 if R0 is DEL
	BHIS	10$		; return with carry clear
	CMPB	#37, R0		; carry = 1 if R0 is space or above
10$:	RETURN
	.SBTTL	Scan an Address Range

;++
;   Several commands, E (examine memory), BM (block move memory), CM (clear
; memory), FM (fill memory), etc accept a range of addresses as an argument.
; The range is specified as two octal numbers separate by a "-".  For example;
;
;	0-777		-> addresses 000000 thru 000777
;	1000 - 1020	-> addresses 001000 thry 001020
;
;   A range may also consist of a single address along, for example
;
;	1234		-> just address 001234
;
; in this case the starting and ending addresses of the range are the same.
;
;   This routine will scan an address range specification like this and
; returns the result in the memory locations ADDRLO and ADDRHI.  On return
; the carry flag indicates which form was specified; if two addresses were
; given then carry=1 and if only one address appeared then carry=0.
;
;	<be sure R5 points to the command buffer>
;	CALL	RANGE
;	<return with ADDRHI/ADDRLO and C flag>
;--
RANGE:	CALL	OCTNW		; at least one number is always required
	MOV	R1, ADDRLO	; and that becomes ADDRLO
	CALL	SPANW		; get the next character
	CMPB	#'-, R0		; is it the dash?
	BNE	10$		; nope - must be the single address form
	INC	R5		; skip over the "-"
	CALL	OCTNW		; and read the second number
	MOV	R1, ADDRHI	; that's ADDRHI
	CMP	ADDRHI, ADDRLO	; ADDRHI must be .GE. ADDRLO!
	BLO	20$		; nope - print an error and abort
	SEC			; indicate that we found two addresses
	RETURN			; and we're done

; Here for the single address version
10$:	MOV	ADDRLO, ADDRHI	; make both addresses be the same
	CLC			; and return with carry cleared
	RETURN			; ...

; Here if the range is out of order ...
20$:	$ERR  <WRONG ORDER>
	.SBTTL	Scan Decimal Numbers

;++
;   This routine will read a decimal number from the command line and return 
; the value in R1.  The result is treated as a signed value and a leading "-"
; is recognized (but not a "+" sign!).  The result is also limited to 16 bits
; and overflows are not detected so long strings of digits can give unexpected
; results.
;
;	<be sure R5 points to the command buffer>
;	CALL	DECNW
;	<return with value in R1>
;
;   At least one decimal digit is required on the command line; if it isn't
; found, then COMERR will be called.
;--
DECNW:	$PUSH	R2		; save R2 for MUL ...
	CLR	R1		; clear the result accumulator
	BIC	#S.NEGV, SFLAGS	; and clear the negative value flag
	CALL	SPANW		; get the next non-blank character
	CMPB	#'-, R0		; is it a leading sign?
	BNE	10$		; nope
	BIS	#S.NEGV, SFLAGS	; yes; remember that for later
	CALL	GETNCH		; and then get the next character
10$:	CALL	ISDEC		; is this a decimal digit?
	BCS	20$		; branch if it is
	JMP	COMERR		; at least one digit is required!
20$:	$PUSH	R0		; save the digit for a while
	MOV	#10., R2	; multiply R1 by 10
	CALL	MUL16		; ...
	$POP	R0		; then get the digit back
	SUB	#'0, R0		; convert ASCII to binary
	ADD	R0, R1		; and add it to the total
	CALL	GETNCH		; then go get the next character
	CALL	ISDEC		; is it another digit?
	BCS	20$		; yep - keep going
	BIT	#S.NEGV, SFLAGS	; all done - do we need to negate the result?
	BEQ	30$		; no
	NEG	R1		; yes
30$:	$POP	R2		; restore R2
	RETURN			; and that's it
	.SBTTL	Scan Octal Numbers

;++
;   This routine will read an octal number from the command line and return
; the value in R1.  The value is limited to 16 bits and overflows are not
; detected.
;
;	<be sure R5 points to the command buffer>
;	CALL	OCTNW
;	<return with value in R1>
;
;   At least one octal digit is required on the command line; if it isn't
; found, then COMERR will be called.
;--
OCTNW:	CLR	R1		; clear the result accumulator
	CALL	SPANW		; get the next non-blank character
	CALL	ISOCT		; is this an octal digit?
	BCS	10$		; branch if it is
	JMP	COMERR		; at least one digit is required!
10$:	ASL	R1		; shift the accumulator left one digit
	ASL	R1		; ...
	ASL	R1		; ...
	SUB	#'0, R0		; convert ASCII to binary
	ADD	R0, R1		; and add it to the total
	CALL	GETNCH		; then go get the next character
	CALL	ISOCT		; is it another digit?
	BCS	10$		; yep - keep going
	RETURN			; no - we're done
	.SBTTL	Scan Device Names

;++
;   This routine will scan a device name of the form "XXn:", where "XX" is a two
; letter mnemonic (e.g. "DD" or "DI") and n is a decimal number.  The number is
; optional and defaults to zero if not specified.  The ":" is also optional and
; is ignored if it's present.
;
;   Note that the unit number is NOT limited to a single digit and any 16 bit
; decimal number is accepted, so "DU32769" is perfectly acceptable.  This is
; useful for IDE devices where the unit number maps to a partition number.
;
;	<R5 points to the command buffer>
;	CALL	DEVNW
;	<return device name in R2 and unit in R1>
;
;   The unit number and ":" are optional, but if we can't find at least two
; letters on the command line then COMERR will be called.  Note that the device
; name is returned as two ASCII characters packed into R2 - e.g. "DI" or "DD".
; No validation of the name is done - that's up to the caller.
;--
DEVNW:	CALL	SPANW		; skip any white space
	CLR	R2		; build the name here
	CLR	R1		; and the unit here
10$:	SWAB	R2		; shift the name right
	CALL	GETCCH		; get a character
	CALL	ISLET		; is it a letter?
	BCS	15$		; yes
	JMP	COMERR		; two letters are required
15$:	SWAB	R0		; characters go high byte, low byte
	BIS	R0, R2		; save this letter
	CALL	GETNCH		; advance to the next character
	BIT	#377, R2	; have we done two letters?
	BEQ	10$		; no - do the second one
	CALL	GETCCH		; get the next character
	CALL	ISDEC		; is it a decimal digit??
	BCC	20$		; no - check for a ":"
	CALL	DECNW		; yes - scan a decimal number
	CALL	GETCCH		; get the break character
20$:	CMP	#':, R0		; is this a ":"
	BNE	25$		; no - ignore it
	CALL	GETNCH		; yes skip it
25$:	RETURN			; and we're done
	.SBTTL	Scan RADIX50 Names

;++
;   This routine will scan an alphanumeric name and return the first three
; letters (or less, if the name scanned is shorter) in RADIX-50.  It will scan
; any number of alphanumeric characters, but only the first three are stored.
; It's used to scan command or register name for the monitor.  Although RADIX50
; also allows ".", "$", and maybe (depending on which source you want to
; believe) "%" in names, this code only recognizes letters and digits.
;
;	<be sure R5 points to the command buffer>
;	CALL	NAMENW
;	<return with RADIX50 name in R1>
;
;   On return the command pointer, R5, will be left pointing to the next
; character AFTER the name (i.e. the first non-alphanumeric character we found).
;--
NAMENW:	$PUSH	R2		; save a couple of working registers
	CLR	R1		; accumulate the name here
	CALL	SPANW		; skip any white space
	CALL	NAMNXT		; get the first character
	CALL	NAMNXT		; and the second
	CALL	NAMNXT		; and a third
	BCC	99$		; quit if no more
; Skip over any remaining alphanumeric characters ...
	$PUSH	R1		; save the first three letters
10$:	CALL	NAMNXT		; try to get another character
	BCC	90$		; quit when we run out
	BR	10$		; otherwise keep ignoring them
90$:	$POP	R1		; restore the first three letters
99$:	$POP	R2		; restore R2
	RETURN			; and we' all done


;   This local routine is used by NAMENW to get the next character.  It first
; multiplies R1 by 50 (regardless of what's next on the command line) and then
; pulls the next character from the command.  If this is a letter or digit then
; it adds the RADIX50 value of that to R1.  If it isn't alphanumeric, then we
; backup up the command pointer and don't add anything to R1.
NAMNXT:	MOV	#50, R2		; multiply R1 by 50
	CALL	MUL16		; ...
	CALL	GETCCH		; get the current character
	CALL	ISDEC		; is it a digit?
	BCS	11$		; branch if so
	CALL	ISLET		; what about a letter?
	BCS	10$		; branch if so
	RETURN			; otherwise just ignore it
10$:	SUB	#56, R0		; convert letters to RADIX50
11$:	SUB	#22, R0		; convert digits to RAD50
	ADD	R0, R1		; accumulate the result in R1
	CALL	GETNCH		; and advance to the next character
	SEC			; be sure to return with carry set
	RETURN			; all done
	.SBTTL	Lookup RADIX-50 Names

;++
;   This routine searches a table of RADIX-50 names for the first one that
; matches the value passed in R1.  Yes, names are limited to three characters
; (16 bits in RADIX-50), and the end of the table should be marked by a zero
; word.  If a match is found, this routine returns with the index of the match
; in R2 and with the carry bit set.  If no match is found, then it returns with
; carry cleared.
;
; TABLE FORMAT:
;	.RAD50	/SY1/
;	.RAD50	/SY2/
;	...
;	.WORD	0
;
; Note that the RAD50 names are limited to one word or three characters!
;
;	<R1 contains the RAD50 name we're searching for>
;	<R2 points to the command table>
;	CALL	LOOKUP
;	<return with offset of matching entry in R2 and carry set>
;
;   Note that the value returned in R2 is a BYTE OFFSET RELATIVE TO THE ORIGINAL
; TABLE ADDRESS.  It is NOT an absolute address!  This is handy for using as an
; index into a second table.
;--
LOOKUP:	$PUSH	R2		; save the original address
10$:	TST	(R2)		; end of the table?
	BEQ	30$		; yes - we're done
	CMP	R1, (R2)	; no - does this name match?
	BEQ	20$		; yes - return
	TST	(R2)+		; increment the table pointer
	BR	10$		; and keep looking
20$:	SUB	(SP)+, R2	; match found; compute the offset
	SEC			; and return with carry set
	RETURN			; ...
30$:	CLC			; no match found 
	TST	(SP)+		; fix the stack
	RETURN			; and quit
	.SBTTL	Match an Abbreviated Name

;++
;   This routine is called with R5 pointing to the usual command line and with
; R4 pointing to an alphanumeric ASCIZ string.  This routine will attempt to
; match up letters or numbers from the command line with the contents of the
; string and, if find the end of the string at the same time it finds a
; delimiter on the command line, it returns with zero set to indicate a match.
;
;   The tricky bit is that the ASCIZ name may contain a "*" character - this
; is skipped over for the purpose of matching BUT once the asterisk has been
; found then all additional characters are optional.  So if we find a delimiter
; on the command line AFTER the "*" but before the end of the name, we still
; return zero set for a match.
;
;   An example is worth a thousand words here - suppose the ASCIZ string we
; receive (pointed to by R4) is "BA*SIC".  The command lines "BA", "BAS",
; "BASI" and "BASIC" would all match, however "BASEBALL" would not!
;
;   When we return R4 will always point to the next BYTE after the end of the
; string (no, we DO NOT align it!) and R5 always points to the first delimiter
; after the next word on the command line.  These conditions are both true
; regardless of whether the match was successful or not.
;
;	<R4 points to the name in ASCIZ>
;	<R5 points to the command buffer>
;	CALL	MATCH
;	<return with zero set if match; uses R4, R5, R0>
;--
MATCH:	CALL	SPANW		; ignore any spaces in the command line
	BIC	#S.NMAT!S.MMAT, SFLAGS ; clear no match and minimum match flags

;   Loop and compare characters from the name string and the command line.  Note
; that this loop continues until BOTH strings end - an ASCII null byte in the
; name, and a delimiter in the command line - are found.
10$:	CMPB	#'*, (R4)	; did we find a "*" in the command name?
	BNE	11$		; no - keep going
	BIS	#S.MMAT, SFLAGS	; yes - remember that we have a minimum match
	INC	R4		; and skip over the "*"
11$:	CALL	GETCCH		; get the current command character
	CALL	ISALNU		; is it alphanumeric?
	BCC	30$		; branch if no
	TSTB	(R4)		; have we reached the end of the name?
	BEQ	20$		; branch if yes
	CMPB	R0, (R4)+	; does the name match the command ?
	BEQ	12$		; yes
	BIS	#S.NMAT, SFLAGS	; no - set the "no match" flag
12$:	CALL	GETNCH		; and on to the next character
	BR	10$		; keep checking

;   We've reached the end of the name string.  At this point we already know
; that the next character on the command line ISN'T a delimiter, so this can't
; be match. Scan the command line until we do find a delimiter, and then return.
20$:	INC	R4		; skip over the end of the name
21$:	CALL	GETCCH		; get the current character
	CALL	ISALNU		; is it alphanumeric?
	BCC	29$		; branch if not
	CALL	GETNCH		; yes - skip over it
	BR	21$		; and keep scanning
29$:	CLZ			; return failure
	RETURN			; ...

;   We've found a delimiter on the command line.  Keep advancing R4 until we
; find the end of the name string too.  
30$:	TSTB	(R4)+		; have we also reached the end of the name?
	BEQ	40$		; yes - it's an exact match!
31$:	TSTB	(R4)+		; advance R4 to the end of the name
	BNE	31$		; ...
;   If the NMAT flag is set then we found at least one character that didn't
; match.  In that case the result is always failure.  If NMAT isn't set, then
; the result depends on whether we found enough matching characters.
	BIT	#S.NMAT, SFLAGS	; did we find a non-matching character?
	BNE	29$		; yes - failure
	BIT	#S.MMAT, SFLAGS	; did we find enough matches?
	BEQ	29$		; no - still failure
39$:	SEZ			; yes - success!
	RETURN			; and we're done

;   Here if the two elements are exactly the same length.  That doesn't mean
; that they match - they could be entirely different commands than happen to
; have the same number of letters.  The NMAT flag will tell us...
40$:	BIT	#S.NMAT, SFLAGS	; did we find any different characters?
	BNE	29$		; yes - no match
	BR	39$		; no - it really is an exact match
	.SBTTL	Search Command Table for a Match

;++
;   This routine will search a table of command names, formatted for MATCH, for
; (what else??) a match.  If it finds one it returns the index of the matching
; name - e.g. if the table contains 4 names and the third on matches, we return
; 2 (it's zero based!).  If a match is found we also return with carry set, and
; if no match exists we return with carry cleared.
;
;	<R4 points to the command table>
;	<R5 points to the command buffer>
;	CALL	COMND
;	<return with carry set and the associated index in R4>
;--
COMND:	$PUSH	#0		; count the command names here
	$PUSH	R5		; save the command pointer so we can back up
10$:	CALL	MATCH		; see if this name matches
	BEQ	20$		; yes!
	TSTB	(R4)		; have we reached the end of the table?
	BEQ	30$		; yes - no match exists
	MOV	(SP), R5	; backup the command line pointer
	INC	2(SP)		; increment the name count
	BR	10$		; and keep looking

; Here when we're done, one way or another ...
20$:	SEC			; indicate success
	BR	31$		; fix the stack and return
30$:	CLC			; return failure
31$:	$POP	R4		; remove R5 from the stack
	$POP	R4		; put the count in R4
	RETURN			; and we're done!


;++
;   This routine will use COMND to search a table of commands for a match and,
; if it finds one, it will dispatch to the corresponding address in a second
; table.  If no match is found, then the COMERR routine is called instead.
;
;	<R3 points to the command dispatch table>
;	<R4 points to the command name table>
;	<R5 points to the command buffer>
;	CALL	COMNDJ
;	<return>
;
;   Note that if we don't find a match we call COMERR, which restarts the
; command scanner and never returns.  If we do find a match we'll jump to the
; corresponding routine and what happens then depends on that routine...
;--
COMNDJ:	CALL	COMND		; first try to find a match
	BCS	10$		; branch if we were successful
	JMP	COMERR		; no match!
10$:	ASL	R4		; convert byte index to word
	ADD	R4, R3		; index into the dispatch table
	MOV	(R3), R3	; then get the address of the routine
	JMP	@R3		; go to it...
	.SBTTL	Type RADIX-50 Strings

;++
;   Type three RADIX-50 characters packed into R1.  Note that this always
; types three characters, including any trailing spaces...
;
;	<three RADIX-50 characters packed into R1>
;	CALL	TR50W
;	<return here - R0 destroyed>
;--
TR50W:	$PUSH	R2		; save R2 for working space
	MOV	#50, R2		; and divisor in R2
	CALL	DIV16		; divide
	MOV	R0, -(SP)	; stack the remainder for a moment
	CALL	DIV16		; divide again
	MOV	R0, -(SP)	; and save this remainder too
	MOV	R1, R0		; the last quotient is the first letter
	CALL	TR50CH		; type that
	MOV	(SP)+, R0	; get the middle character
	BEQ	10$		; trim trailing spaces
	CALL	TR50CH		; type it
10$:	MOV	(SP)+, R0	; and finally the last character
	BEQ	20$		; trim trailing spaces
	CALL	TR50CH		; ...
20$:	$POP	R2		; restore R2 and R1
	RETURN			; and we're done


;++
;   TR50W2 types the six character RADIX-50 word pointed to by R2.  It always
; types exactly two words and no special terminator is needed.
;
;	<R2 points to two RADIX-50 words>
;	CALL	TR50W2
;	<return here - R0 and R1 destroyed>
;--
TR50W2:	MOV	(R2), R1	; get the first word
	CALL	TR50W		; type that
	MOV	2(R2), R1	; and then the next
	BNE	TR50W		; type it only if it's not blank
	RETURN			; trim trailing spaces


;++
;   TR50CH types the single RADIX-50 character contained in R0.  This uses a
; translation table to convert from RADIX-50 to ASCII.  I've seen people do
; this with a bunch of compare and branch instructions, but I'm not convinced
; that actually takes less code space (and it's certainly uglier!) ...
;
;	<one RADIX-50 character in R0>
;	CALL	TR50CH
;	<return here with the ASCII eqivalent in R0>
;--
TR50CH:	CMP	R0, #50		; make sure the value is in range
	BLT	10$		; it is - continue
	CLR	R0		; nope - print a space instead
10$:	MOVB	R50ASC(R0), R0	; translate to ASCII
	JMP	OUTCHR		; and type it


; RADIX-50 to ASCII lookup table ...
R50ASC:	.ASCII	/ ABCDEFGHIJKLMNOPQRSTUVWXYZ$.%0123456789/
	.SBTTL	Type Time and Date

;++
;   This routine will type a time and date.  The value to type is passed in a
; seven byte buffer using the same format as the GETTOD and SETTOD routines -
;
;	BUFFER/	hours		- based on a 24 hour clock
;		minutes		- 0..59
;		seconds		- 0..59
;		day		- 1..31
;		month		- 1..12 (1 == JANUARY!)
;		year		- 0..99 
;		day of week	- 1..7 (1 == SUNDAY!)
;
; CALL
;	<R3 points to the buffer>
;	CALL	TTIME
;	<return>
;--
TTIME:	$PUSH	R3		; save the original buffer pointer
	MOVB	(R3)+, R1	; get the hours
	CALL	TDEC2		; ...
	$TYPE	':		; ...
	MOVB	(R3)+, R1	; and the minutes
	CALL	TDEC2		; ...
	$TYPE	':		; ...
	MOVB	(R3)+, R1	; and the seconds
	CALL	TDEC2		; ...
	CALL	TSPACE		; leave a little space
	MOVB	(R3)+, R1	; now the day (of the month)
	CALL	TDEC2		; ...
	$TYPE	'-		; ...
	MOVB	(R3)+, R1	; get the month, 1..12
	ADD	R1, R1 		; convert to a word index
	MOV	MONTAB-2(R1),R1	; get the RADIX-50 month name
	CALL	TR50W		; and type that out
	$TYPE	'-		; ...

;   There's a little cheating here - we always assume that the year in our RTC
; is post Y2K.  Since the SBCT11 was designed in 2021, that seems fair...
	MOVB	(R3)+, R1	; ...
	ADD	#2000., R1	; ...
	CALL	TDECU		; and type that in decimal
	CALL	TSPACE		; leave another space

; Lastly, type the weekday (e.g. MON, TUE, WED, etc) ...
	MOVB	(R3)+, R1	; ...
	ADD	R1, R1		; convert to a word index
	MOV	WDYTAB-2(R1),R1	; get the RADIX-50 weekday name
	CALL	TR50W		; ...
	$POP	R3		; restore the original buffer pointer
	RETURN			; and we're done
	.SBTTL	Read a Line from the Console with Editing

;++
;   This routine will read a single line from the console terminal and store the
; resulting text in a buffer specified by the caller.  The caller may optionally
; specify a prompting string to be printed before we start reading input.  While
; reading, this routine will recognize and handle the following line editing
; characters and functions -
;
;	Control-R --> Retype the current line, including corrections
;	Control-U --> Erase the current line and start over again
;	DELETE	  --> Erase the last character (echos the last character typed)
;	BACKSPACE --> Erase the last character on a CRT
;	RETURN	  --> Terminates the current command
;	LINE FEED -->	 "	  "	"	"
;	ESCAPE	  -->	 "	  "	"	"
;
;   Additionally, the INCHRS routine that we call to get console input will
; recognize the Control-C character.  That will abort any input and jump to
; the monitor's restart routine.
;
;	<R0 contains the maximum line length in bytes>
;	<R1 points to the caller's line buffer>
;	<R2 points to the prompting string, or zero if none>
;	CALL	INCHWL
;	<R0 contains the line terminator - CH.CRT, CH.LFD, or CH.ESC>
;	<R1 contains the actual line length in bytes>
;	<R2 is destroyed>
;
;   One last note - this routine will always null terminate the string returned.
; The maximum length passed in R0 is the line length, NOT the buffer length,
; and doesn't count this null.  In other words, the actual buffer needs to be
; ONE BYTE LONGER than the value passed in R0.
;--

; Register usage while in this routine -
;	R0 -> last character read
;	R1 -> character count
;	R2 -> points to the line buffer
INCHWL:	MOV	R2, INPMPT	; save the caller's original parameters
	MOV	R1, INBUFF	; ...
	MOV	R0, INMAXC	; ...
10$:	MOV	INPMPT, R1	; now type the prompt string
	CALL	OUTSTR		; ...
	MOV	INBUFF, R2	; point to the next charactere here
	CLR	R1		; keep count of the characters read here

; Read and process the next character ...
20$:	CALL	INCHRS		; try to read a character
	BIC #S.CTLO!S.XOFF,SFLAGS; ignore ^O, ^S and ^Q here
	TST	R0		; did we read anything?
	BEQ	20$		; nope - keep waiting
	CMPB	R0, #40		; is this a printing character?
	BLO	40$		; no - check control characters
	CMPB	#CH.DEL, R0	; is this a DELETE?
	BEQ	65$		; yes - treat it like backspace

; Here to process a normal character...
30$:	CMP	R1, INMAXC	; is the buffer full?
	BLO	35$		; no - go store this character
31$:	$TYPE	CH.BEL		; yes - echo a bell instead
	BR	20$		; and ingore this character
35$:	MOVB	R0, (R2)+	; store this character
	INC	R1		; increment the length
	CALL	TFCHAR		; echo whatever we read
	BR	20$		; then keep reading 

; Here to handle a control-R command...
40$:	CMPB	#CH.CTR, R0	; is this really a control-R ??
	BNE	50$		; nope - try something else
	CALL	TFCHAR		; yes - echo ^R
	CLRB	(R2)		; then make sure the buffer is null terminated
	$PUSH	R1		; save the count for a moment
	CALL	TCRLF		; start a new line
	MOV	INPMPT, R1	; first reprint the prompt
	CALL	OUTSTR		; ...
	MOV	INBUFF, R1	; and then reprint the current line
	CALL	OUTSTR		; ...
	$POP	R1		; restore R1
	BR	20$		; finally continue reading

; Here to handle a Control-U character...
50$:	CMPB	#CH.CTU, R0	; is this really a Control-U character ??
	BNE	60$		; nope - keep trying
	CALL	TFCHAR		; echo ^U
	CALL	TCRLF		; start on a new line
	BR	10$		; and go start all over again

; Here to handle a BACKSPACE character...
60$:	CMPB	#CH.BSP, R0	; is that what this is ??
	BNE	70$		; ???
65$:	TST	R1		; get the length of this command
	BEQ	31$		; if it's empty just echo a bell
	CALL	TERASE		; erase the last character
	DEC	R1		; decrement the character count
	DEC	R2		; and decrement the buffer pointer
	BR	20$		; then keep reading

; Here to check for line terminators...
70$:	CMPB	#CH.CRT, R0	; is this a return ??
	BEQ	81$		; yes -- this line is done
	CMPB	#CH.LFD, R0	; no -- Is it a line feed then ?
	BEQ	81$		; yes -- That's just as good
	CMPB	#CH.ESC, R0	; no -- How about an escape ?
	BNE	31$		; no -- ignore all other control characters

; Here to finish a command...
80$:	CALL	TFCHAR		; echo the terminator
81$:	$PUSH	R0		; save the terminator character
	CALL	TCRLF		; always echo CRLF regardless of the input
	$POP	R0		; restore the terminator
	CLRB	(R2)		; make sure the buffer is null terminated
	RETURN			; that's all there is to it
	.SBTTL	Console Terminal Input

;++
;   INCHRS will try to read a character from the console terminal. It always
; trims the character to 7 bit ASCII and never  blocks in no input is available.
; It also checks for various special control characters and handles them
; immediately -
;
;	Control-C -> echos ^C and jumps to RESTA
;	Control-O -> echos ^O and toggles the S.CTLO flag
;	Control-S -> doesn't echo and sets the S.XOFF flag
;	Control-Q -> doesn't echo and clears the S.XOFF flag
;
;   Any other character is returned as-is and WITHOUT ECHO.  If no input is
; available at the time this routine is called, NUL (ASCII 000) is returned.
;
;	CALL	INCHRS
;	<return with character in R0, or NULL if none available>
;--
INCHRS:	CALL	CONGET		; try to read a character from the terminal
	BCC	41$		; return zero if no character is ready
	BIT	#DL.RBK, R0	; did we receive a break?
	BNE	5$		; yes - treat it as a control C
	BIC	#^C177, R0	; ignore the parity bit here
	BEQ	41$		; just ignore nulls
; Check for a Control-C character -- restart the monitor...
	CMPB	#CH.CTC, R0	; is this really a control-C ??
	BNE	10$		; nope - proceed
5$:	BIC	#S.CTLO, SFLAGS	; yes -- clear the control-O
	BIC	#S.XOFF, SFLAGS	;  and XOFF flags
	MOV	#CH.CTC, R0	; (for the break detect case!)
	CALL	TFCHAR		; echo ^C
	CALL	TCRLF		; and newline
	JMP	RESTA		; then restart the monitor
; Check for a Control-O character - discard output ...
;   Note that Control-O acts as a toggle, however there's a bit of subtlety
; about when we change the flag bit in relation to echo.  This ensures that
; the "^O" always gets printed in either case!
10$:	CMPB	#CH.CTO, R0	; compare to a control-O character
	BNE	20$		; no -- keep checking
	BIC	#S.XOFF, SFLAGS	; Control-O always clears the XOFF flag
	BIT	#S.CTLO, SFLAGS	; test the current state
	BEQ	15$		; if it isn't set then go set it
	BIC	#S.CTLO, SFLAGS	; it's currently set - clear the flag
	CALL	TFCHAR		; echo ^O
	BR	41$		; return zero and we're done
15$:	CALL	TFCHAR		; flag is not set - echo first
	BIS	#S.CTLO, SFLAGS	; and then set the flag
	BR	41$		; return zero and we're done
; Check for a Control-S (XOFF) character...
20$:	CMPB	#CH.XOF, R0	; is this a Control-S ??
	BNE	30$		; no - check for Control-Q instead
	BIS	#S.XOFF, SFLAGS	; set the XOFF flag
	BR	41$		; and return nothing
; Check for a Control-Q (XON)  character...
30$:	CMPB	#CH.XON, R0	; is this a Control-Q ??
	BNE	40$		; no -- just give up
	BIC	#S.XOFF, SFLAGS	; clear the XOFF flag
;;	BR	41$		; and return nothing
; Here if this character is nothing special...
41$:	CLR	R0		; return null for any special character
40$:	RETURN			; return the character in R0
	.SBTTL	PDP-11 Disassembler

;++
;   This is a fairly capable PDP-11 disassembler.  It knows the mnemonics for
; all the opcodes (or at least all that are known by the DCT11) and it knows
; how to decode all the operand formats.  Register names and addressing modes
; (autoincrement, autodecrement, indexed, deferred, etc) are printed out as
; you'd expect.  Operands are printed in octal, however relative addressing
; modes (PC relative addressing modes, immediate, absolute, and conditional
; branch instructions, etc) are computed relative to the instruction address
; and the actual target address is printed.  Undefined or illegal opcodes are
; simply printed as 16 bit octal words.
;
;   The address of the instruction to be disassembled is passed in R4.  The
; TINSTA entry point first prints the address, a "/" and a tab, and then
; disassembles the instruction.  The TINSTW entry point just disassembles the
; instruction without any address.  In either case, R4 will point to the first
; word of the NEXT instruction on return.
;
;	<R4 points to the instruction to be disassembled>
;	CALL	TINSTW or TINSTA
;	<return with R4 updated; uses (and destroys) R0-R3>
;
; Needless to say, instructions are disassebled from user RAM, NOT from ROM!
;--

; Type the address first ...
TINSTA:	MOV	R4, R1		; get the instruction address
	CALL	TOCTW		; type in octal
	$TYPE	'/		; then type a slash and a tab
	$TYPE	CH.TAB		; ...

; Fetch the instruction pointed to by R4 ...
TINSTW:	MOV	R4, R2		; get the address of the instruction
	CALL	RDRAM		; and get the opcode from user RAM
	TST	(R4)+		; bump R4 past the opcode
	MOV	R1, OPCODE	; save the opcode for future reference

; Start decode the instruction in 
	MOV	OPCODE, R0	; get the current opcode
	ASL	R0		; isolate just bits 6 through 11
	ASL	R0		; ...
	SWAB	R0		; ...
	BIC	#^C77, R0	; ...
	MOV	R0, OPMODE	; store them for later decoding
	$PUSH	OPCODE		; save the original opcode
	TST	OPCODE		; is this possibly a byte mode instruction?
	BPL	50$		; branch if it can't be a byte instruction
	BIC	#BIT15, OPCODE	; try to lookup the opcode w/o the byte mode bit
	CALL	OPSRCH		; ...
	TSTB	OPTYPE(R3)	; then see if this opcode allows a byte mode
	BPL	50$		; nope - not a byte mode

; Here for a byte mode (ADDB, MOVB, ASLB, RORB, etc) instruction...
	$POP	OPCODE		; restore the original opcode
	MOV	R3, R1		; copy the opcode index
	ASL	R1		; and make index to the name (two RAD50 words!)
	ADD	#OPNAME, R1	; point to the opcode name
	MOV	(R1), R1	; and get just the first three letters!
	CALL	TR50W		; type that
	$TYPE	'B		; then type "B"
	BR	60$		; and finish decoding the rest

; Here for a "word" (i.e. NOT a byte mode) instruction ...
50$:	$POP	OPCODE		; restore the original opcode
	CALL	OPSRCH		; ... just in case we didn't before
	MOV	R3, R2		; copy the opcode index
	ASL	R2		; point to the opcode name
	ADD	#OPNAME, R2	; ...
	TST	(R2)		; is the name blank?
	BEQ	61$		; yes - skip it and the tab
	CALL	TR50W2		; no - type it
	BIT	#17, OPTYPE(R3)	; is the operand type CCC ?
	BEQ	61$		; yes - skip the tab
60$:	$TYPE	CH.TAB		; type a tab before the operand
61$:	MOV	OPTYPE(R3), R1	; get the operand type code
	ASL	R1		; convert to a word index
	BIC	#^C36, R1	; ...
	JMP	@TOPTBL(R1)	; type the operands and return


;   This little routine searchs the OPBASE table for an entry that matches the
; value in OPCODE.  The OPBASE table is sorted in order by ascending binary
; opcode values, and we start searching from the end and work backwards towards
; the beginning.  As soon as we find a table entry that is LESS than the OPCODE,
; we quit.  Note that there's no error return - something will always match!
; The resulting index is returied in R3 ...
OPSRCH:	MOV	#OPBLEN, R3		; load the table length
10$:	CMP	OPCODE, OPBASE(R3)	; compare opcode to base value
	BHIS	20$			; branch if match
	TST	-(R3)			; nope - bump the index
	BR	10$			; ... and keep looking
20$:	RETURN				; found it!


;   This table gives the address of a routine that knows how to type the
; operand(s) for this instruction.  The index into this table comes from the
; OPTYPE table and the order of the entries here MUST CORRESPOND to the
; definitions of the OP.xxx symbols!
TOPTBL: .WORD	TOPCCC		;OP.CCC - condition code (CVZN)
	.WORD	TOPINV		;OP.INV - invalid (type in octal)
	.WORD	TOPNON		;OP.NON - no operands
	.WORD	TOPTRP		;OP.TRP - EMT and TRAP
	.WORD	TOPDSP		;OP.DSP - 8-bit displacement (branch!)
	.WORD	TOPRDD		;OP.RDD - R,DD
	.WORD	TOPONE		;OP.ONE - SS or DD
	.WORD	TOPTWO		;OP.TWO - SS,DD
	.WORD	TOPREG		;OP.REG - R
	.WORD	TOPSOB		;OP.SOB - 6-bit negative displacement (SOB!)


; Here if the instruction has no operand - that's easy!
TOPNON: RETURN


;   Here for instructions that take only a register name as the first operand
; but then allow a full six bit mode and register for the second operand.  I
; believe the only two examples of this are JSR and XOR ...
TOPRDD:	CALL	TOPRNM		; 1st operand is already in OPMODE
	BR	TSRDS1		; type a comma and then the second operand

;   Here for an instruction that takes a full six bit mode and register for the
; first (source) operand AND ALSO for the second (destination) operand ...
TOPTWO:	CALL	TOPSIX		; 1st operand is already in OPMODE
TSRDS1:	$TYPE	<',>		; then type a comma
				; ... and fall into TOPONE ...

;   Here for an instruction that takes a full six bit mode and register for the
; destination operand.  The source operand, if any, might be anything and is
; assumed to have already been handled before we get here!
TOPONE:	MOVB	OPCODE, OPMODE	; get the original opcode back again
	BICB	#^C77, OPMODE	; and then isolate the destination only
				; fall into TOPSIX and we're done ...

;   This routine types a "full" PDP11 SS or DD operand.  It handles all possible
; addressing modes, including the PC ones (immediate, relative and absolute).
; The operand should be passed in OPMODE and R4 points to the next word AFTER
; the original opcode.  If the addressing mode requries fetching any additional
; words, then R4 will be incremented accordingly.
TOPSIX:	MOVB	OPMODE, R2	; get the addressing mode for the operand
	BIT	#10, R2		; deferred?
	BEQ	10$		; no
	$TYPE	'@		; yes - type "@"
10$:	CMPB	R2, #20		; mode 0 or 1?
	BLO	TOPRNM		; yes, just type the register name
	CMPB	R2, #60		; mode 6 or 7?
	BHIS	20$		; yes, indexed
	CMPB	R2, #27		; immediate?
	BEQ	30$		; branch if yes
	CMPB	R2, #37		; or absolute?
	BEQ	30$		; yes
	CMPB	R2, #40		; autodecrement?
	BLO	40$		; nope
	$TYPE	'-		; yes - type "-"
40$:	CALL	TOPIDX		; type the register name in parenthesis
	CMPB	R2, #40		; autoincrement?
	BHIS	99$		; nope, we're done
	$TYPE	'+		; yes - type "+"
99$:	RETURN			; and that's all

; Here for immediate or absolute (the "@" has already been typed!) ...
30$:	$TYPE	'#		; type the "#"
35$:	MOV	R4, R2		; get the RAM address to read
	CALL	RDRAM		; and get the operand from user RAM
	TST	(R4)+		; bump R4 over the operand
	JMP	TOCTW		; type the operand and return

; Here for some form of indexed addressing ...
20$:	CMPB	R2, #67		; is it PC relative?
	BEQ	50$		; yes
	CMPB	R2, #77		; or relative deferred?
	BEQ	50$		; yes
	CALL	35$		; no - type the next location
	BR	TOPIDX		; and type the register name in parenthesis

; Here for PC relative or relative deferred (the "@" is already typed!) ...
50$:	MOV	R4, R2		; read the operand from user RAM
	CALL	RDRAM		; ...
	TST	(R4)+		; bump R4 over the operand
	ADD	R4, R1		; compute the target address
	JMP	TOCTW		; type that and return


;   Here for the EMT and TRAP instructions. The argument is a single 8 bit value
; without sign extension...
TOPTRP:	MOV	OPCODE, R1	; get the lower 8 bits without sign extension
	BIC	#^C377, R1	; ...
	JMP	TOCTW		; type it in octal and we're done


;   Here for the SOB instruction.  This one is unique for two reasons - #1 it
; takes a single register as the first argument and, #2 it uses a six bit
; displacement (regular branch instructions use 8) BUT this one is assumed to be
; a backward branch. 
TOPSOB:	CALL	TOPRNM		; first type the register name
	$TYPE	<',>		; and the usual separator
	MOV	OPCODE, R1	; get the lower 6 bits
	BIC	#^C77, R1	; ...
	ASL	R1		; make it a byte displacement
	NEG	R1		; and it's always a backwards branch
	BR	TBRDS1		; type the target address and we're done

;   Here to figure out the target address for all the branch type instructions.
; Get the lower 8 bits of the opcode; sign extend it and add it to the address
; of the instruction to compute the destination.  Note that by the time we get
; here R4, which holds the address of the instruction, has already been
; incremented by 2 just as the PC would have been!
TOPDSP:	MOVB	OPCODE, R1	; get the lower 8 bits with sign extension
	ASL	R1		; covert word displacement to bytes
TBRDS1:	ADD	R4, R1		; and add in the instruction location
	JMP	TOCTW		; type that in octal and we're done


; Here if the opcode takes only a single register as the argument ...
;   (I believe RTS is the only instruction that qualifies here!)
TOPREG:	MOV	OPCODE, R0	; get the opcode back
	BR	TOPRN1		; and type the 3 LSBs as a register name

; Type the register from OPMODE as an index register - i.e. (Rn) ...
TOPIDX:	$TYPE	'(		; type the left paren
	CALL	TOPRNM		; type the register name
	MOV	#'), R0		; and type the right param
	JMP	OUTCHR		; ...

; Type the register name (R0-R6, SP, or PC) from OPMODE ...
TOPRNM:	MOVB	OPMODE, R0	; get bits 0 through 2
TOPRN1:	BIC	#^C7, R0	; ...
	ASL	R0		; convert to a REGTAB index
	MOV	REGTAB(R0), R1	; and get the register name
	JMP	TR50W		; type that and we're done


;   Type the argument for the CLx or SEx opcodes.  This is one or more of the
; letters C, V, Z, or N.  It might not be obvious (it wasn't to me!) but it's
; possible to combine one or more of these flags in either the SEx or CLx 
; instructions.
TOPCCC:	MOV	OPCODE, R1	; get the opcode back again
	ASR	R1		; is the C bit set?
	BCC	10$		; no
	$TYPE	'C		; yes - type that one
10$:	ASR	R1		; and repeat for the V bit ...
	BCC	20$		; ...
	$TYPE	'V		; ...
20$:	ASR	R1		; and the Z bit ...
	BCC	30$		; ...
	$TYPE	'Z		; ...
30$:	ASR	R1		; and the N bit ...
	BCC	40$		; ...
	$TYPE	'N		; ...
40$:	RETURN			; ...


;   Here for opcodes which aren't valid DCT11 instructions.  Just type the
; 16 bit value in octal and give up ...
TOPINV:	MOV	OPCODE, R1	; get the original opcode back again
	JMP	TOCTW		; type in octal and quit
	.SBTTL	Disassembler Tables

;++
;   These tables are used by the disassembler code to decode PDP11 instructions.
; There's a table of the binary value for each opcode; a table of the opcode
; names, and a table of flags used to decode the instruction's operand(s).
; The $CODES macro is a master list of all the opcodes, and this is expanded
; several times to generate all of those tables.
;--


; Operand types for the $OP macro ...
;   Note that the values of these types (all except OP.BYT) MUST AGREE WITH the
; dispatch table at TOPTBL!
OP.CCC=	0.		; 0 - CVZN
OP.INV=	1.		; 1 - invalid opcode (type as an octal number)
OP.NON=	2.		; 2 - no operands
OP.TRP=	3.		; 3 - EMT and TRAP
OP.DSP=	4.		; 4 - 8-bit displacement for branch
OP.RDD=	5.		; 5 - R,DD
OP.ONE=	6.		; 6 - SS or DD
OP.TWO=	7		; 7 - SS,DD
OP.REG=	8.		; 8 - R only
OP.SOB=	9.		; 9 - 6-bit negative displacement (SOB!)
OP.BYT= BIT7		; opcode has both byte and word modes (ADD/ADDB, etc)


; Master list of all PDP11 opcodes ...
;   WARNING!  The OPSRCH routine assumes that this table is sorted in ascending
; order by the opcode (OPBASE) value!
	.MACRO	$CODES
	$OP	<HALT  >,000000,OP.NON
	$OP	<WAIT  >,000001,OP.NON
	$OP	<RTI   >,000002,OP.NON
	$OP	<BPT   >,000003,OP.NON
	$OP	<IOT   >,000004,OP.NON
	$OP	<RESET >,000005,OP.NON
	$OP	<RTT   >,000006,OP.NON
	$OP	<MFPT  >,000007,OP.NON
	$OP	<JMP   >,000100,OP.ONE
	$OP	<RTS   >,000200,OP.REG
	$OP	<      >,000210,OP.INV
	$OP	<NOP   >,000240,OP.NON
	$OP	<CL    >,000241,OP.CCC
	$OP	<CCC   >,000257,OP.NON
	$OP	<      >,000260,OP.INV
	$OP	<SE    >,000261,OP.CCC
	$OP	<SCC   >,000277,OP.NON
	$OP	<SWAB  >,000300,OP.ONE
	$OP	<BR    >,000400,OP.DSP
	$OP	<BNE   >,001000,OP.DSP
	$OP	<BEQ   >,001400,OP.DSP
	$OP	<BGE   >,002000,OP.DSP
	$OP	<BLT   >,002400,OP.DSP
	$OP	<BGT   >,003000,OP.DSP
	$OP	<BLE   >,003400,OP.DSP
	$OP	<JSR   >,004000,OP.RDD
	$OP	<CLR   >,005000,OP.ONE!OP.BYT
	$OP	<COM   >,005100,OP.ONE!OP.BYT
	$OP	<INC   >,005200,OP.ONE!OP.BYT
	$OP	<DEC   >,005300,OP.ONE!OP.BYT
	$OP	<NEG   >,005400,OP.ONE!OP.BYT
	$OP	<ADC   >,005500,OP.ONE!OP.BYT
	$OP	<SBC   >,005600,OP.ONE!OP.BYT
	$OP	<TST   >,005700,OP.ONE!OP.BYT
	$OP	<ROR   >,006000,OP.ONE!OP.BYT
	$OP	<ROL   >,006100,OP.ONE!OP.BYT
	$OP	<ASR   >,006200,OP.ONE!OP.BYT
	$OP	<ASL   >,006300,OP.ONE!OP.BYT
	$OP	<      >,006400,OP.INV
	$OP	<SXT   >,006700,OP.ONE
	$OP	<      >,007000,OP.INV
	$OP	<MOV   >,010000,OP.TWO!OP.BYT
	$OP	<CMP   >,020000,OP.TWO!OP.BYT
	$OP	<BIT   >,030000,OP.TWO!OP.BYT
	$OP	<BIC   >,040000,OP.TWO!OP.BYT
	$OP	<BIS   >,050000,OP.TWO!OP.BYT
	$OP	<ADD   >,060000,OP.TWO
	$OP	<      >,070000,OP.INV
	$OP	<XOR   >,074000,OP.RDD
	$OP	<      >,075000,OP.INV
	$OP	<SOB   >,077000,OP.SOB
	$OP	<BPL   >,100000,OP.DSP
	$OP	<BMI   >,100400,OP.DSP
	$OP	<BHI   >,101000,OP.DSP
	$OP	<BLOS  >,101400,OP.DSP
	$OP	<BVC   >,102000,OP.DSP
	$OP	<BVS   >,102400,OP.DSP
	$OP	<BCC   >,103000,OP.DSP
	$OP	<BHIS  >,103000,OP.DSP
	$OP	<BCS   >,103400,OP.DSP
	$OP	<BLO   >,103400,OP.DSP
	$OP	<EMT   >,104000,OP.TRP
	$OP	<TRAP  >,104400,OP.TRP
	$OP	<      >,105000,OP.INV
	$OP	<MTPS  >,106400,OP.ONE
	$OP	<      >,106500,OP.INV
	$OP	<MFPS  >,106700,OP.ONE
	$OP	<      >,107000,OP.INV
	$OP	<SUB   >,160000,OP.TWO
	$OP	<      >,170000,OP.INV
	.ENDM


; OPNAME is a table of the opcode names, in RADIX-50 ...
	.MACRO	$OP	NAME,VALUE,FLAGS
	.RAD50	/NAME/
	.ENDM
OPNAME:	$CODES


;   OPBASE is a table of the opcode base values (i.e. the bit pattern of this
; instruction without any operands!)...
	.MACRO	$OP	NAME,VALUE,FLAGS
	.WORD	VALUE
	.ENDM
OPBASE:	$CODES
OPBLEN=.-OPBASE-2


; And OPTYPE is a table of the opcode types and flags ...
	.MACRO	$OP	NAME,VALUE,FLAGS
	.WORD	FLAGS
	.ENDM
OPTYPE:	$CODES
	.SBTTL	Commands, Registers and Names Tables

;++
;   The $COMMANDS macro defines (what else?) the commands for this monitor.
; Each command definition consists of a 1, 2 or 3 character RADIX-50 name and
; the address of a routine to process that command.  The order is unimportant
; since the name table is searched with a simple linear search.
;--
	.MACRO	$COMMANDS
	$CMD	REP*EAT, REPEAT		; REPeat - repeat a command line
	$CMD	EC*HO, ECHO		; ECho - echo command line text

	$CMD	E*XAMINE, DOEXAM	; Examine  - generic examing command
	$CMD	ER, EREG		; ER - examine register
	$CMD	EI, EINST		; EI - examine instruction (disassemble)

	$CMD	D*EPOSIT, DODEPO	; Deposit  - generic deposit command
	$CMD	DR, DREG		; DR - deposit in register

	$CMD	GO, GOCMD	; GO - start user program running
	$CMD	ST*EP, TRACE	; TR - trace user instructions
	$CMD	C*ONTINUE, CONT	; C  - continue user program (past breakpoint)
	$CMD	RESET, MRESET	; MR - master reset

	$CMD	SH*OW, SHOCMD
	$CMD	SE*T, SETCMD
	$CMD	CL*EAR, CLRCMD
	$CMD	TE*ST, TSTCMD

	$CMD	HE*LP, HELP	; HELp - show help text
;;	$CMD	TU, TUTEST
	$CMD	B*OOT, BOOCMD
	.IF	DF BASIC
	$CMD	BAS*IC, BASGO
	.ENDC
	$CMD	FOR*MAT, FMTCMD	; FORmat - "format" a disk or tape device
	.ENDM

; Generate a table of RADIX-50 command names for LOOKUP ...
	.MACRO	$CMD	NAME, ADDR
	.ASCIZ	/NAME/
	.ENDM
CMDTBL:	$COMMANDS
	.BYTE	0		; end of table!
	.EVEN

; Generate a table of command routine addresses ...
	.MACRO	$CMD	NAME, ADDR
	.WORD	ADDR
	.ENDM
CMDRTN:	$COMMANDS

	.MACRO	$CMD	NAME, ADDR
	.ASCIZ	/NAME/
	.EVEN
	.WORD	ADDR
	.ENDM


; This is a table of register names for the ER and DR commands ...
;   Note that the order of these names MUST CORRESPOND to the actual registers
; stored at USRREG:, however the order is pretty obvious!
REGTAB:	.RAD50	/R0/
	.RAD50	/R1/
	.RAD50	/R2/
	.RAD50	/R3/
	.RAD50	/R4/
	.RAD50	/R5/
REGTSP:	.RAD50	/SP/
REGTPC:	.RAD50	/PC/
REGTPS:	.RAD50	/PS/
	.WORD	0


; This is a table of ON/OFF keywords for various commands ...
OOTAB:	.RAD50	/OFF/		; keep the names in this order!
	.RAD50	/ON/
	.WORD	0

; Table of month abbreviations (JANuary=1) ...
MONTAB:	.RAD50	/JAN/
	.RAD50	/FEB/
	.RAD50	/MAR/
	.RAD50	/APR/
	.RAD50	/MAY/
	.RAD50	/JUN/
	.RAD50	/JUL/
	.RAD50	/AUG/
	.RAD50	/SEP/
	.RAD50	/OCT/
	.RAD50	/NOV/
	.RAD50	/DEC/
	.WORD	0

; Table of weekday abbreviations (SUNday=1) ...
WDYTAB:	.RAD50	/SUN/
	.RAD50	/MON/
	.RAD50	/TUE/
	.RAD50	/WED/
	.RAD50	/THU/
	.RAD50	/FRI/
	.RAD50	/SAT/
	.WORD	0
	.SBTTL	Break and Trap Messages

;++
;   This routine is eventually called by trap, interrupt and breakpoint vectors.
; The reason for the break is found in WHYBRK, and this routine prints the
; correct message and then restarts the command scanner.  Note that all these
; conditions are considered "errors" and the saved monitor context is ignored.
; This will abort any command(s) in progress, including repeat or trace.
;
;	<set up WHYBRK with the reason code>
;	JMP	BRKMSG
;	<never returns!>
;--
BRKMSG:	$TYPE	'?		; ...
	MOV	WHYBRK, R1	; get the reason we restarted
	ASL	R1		; convert index to word address
	MOV	MSGTBL(R1), R1	; get the correct message
	CALL	OUTSTR		; and type that
	$MSG	< AT >		; then print the last user PC
	MOV	USRPC, R1	; ...
	CALL	TOCTW		; ...
	CALL	TCRLF		; ...
	JMP	RESTA		; and go restart the monitor

; ASCII messages for the various trap/interrupt types ...
MSGTBL:	.WORD	UBKMSG		; 0 -> unknown restart reason
	.WORD	HLTMSG		; 1 -> HALT instruction or switch
	.WORD	BPTMSG		; 2 -> breakpoint trap
	.WORD	PFTMSG		; 3 -> power fail trap
	.WORD	IITMSG		; 4 -> illegal instruction trap
	.WORD	RITMSG		; 5 -> reserved instruction trap
	.WORD	EMTMSG		; 6 -> EMT trap
	.WORD	TRPMSG		; 7 -> TRAP trap
	.WORD	IOTMSG		; 8 -> IOT trap
	.WORD	UINMSG		; 9 -> unknown/unexpected interrupt
	.WORD	UTBMSG		;10 -> unexpected T-bit trap
	.WORD	UNXMSG		;11 -> unexpected NXM trap

; And here's the actual text for the above table ...
UBKMSG:	.ASCIZ	/UNKNOWN RESTART/
UINMSG:	.ASCIZ	/UNKNOWN INTERRUPT/
BPTMSG:	.ASCIZ	/UNEXPECTED BREAKPOINT/
UTBMSG:	.ASCIZ	/UNEXPECTED T-BIT TRAP/
UNXMSG:	.ASCIZ	/UNEXPECTED NXM TRAP/
IITMSG:	.ASCIZ	/ILLEGAL INSTRUCTION/
RITMSG:	.ASCIZ	/RESERVED INSTRUCTION/
PFTMSG:	.ASCIZ	/POWER FAIL/
EMTMSG:	.ASCIZ	/EMT/
TRPMSG:	.ASCIZ	/TRAP/
IOTMSG:	.ASCIZ	/IOT/
HLTMSG:	.ASCIZ	/HALT/
	.EVEN
	.SBTTL	Help Text

;++
;   This is the entire help "file" for this monitor, in plain ASCII text.
; Why plain ASCII?  Why not?  There's lots of EPROM space!
;--
HLPTXT:
	.ASCII	/EXAMINE AND DEPOSIT COMMANDS/<15><12>
	.ASCII	/E  aaaaaa[-bbbbbb]		-> Examine memory in octal and ASCII/<15><12>
	.ASCII	/EI aaaaaa[-bbbbbb]		-> Disassemble instructions from memory/<15><12>
	.ASCII	/ER [rr]				-> Examine register/<15><12>
	.ASCII	/D  aaaaaa bbbbbb[,cccccc, ...]	-> Deposit data in memory/<15><12>
	.ASCII	/DR rr yyyyyy			-> Deposit data in a register/<15><12>
	.ASCII	<15><12>

	.ASCII	/BREAKPOINT COMMANDS/<15><12>
	.ASCII	/BP aaaaaa			-> Set breakpoint/<15><12>
	.ASCII	/BR [aaaaaaa]			-> Remove breakpoint/<15><12>
	.ASCII	/BL				-> List breakpoints/<15><12>
	.ASCII	<15><12>

	.ASCII	/PROGRAM CONTROL COMMANDS/<15><12>
	.ASCII	/ST [aaaaaa]			-> Start user program/<15><12>
	.ASCII	/C				-> Continue user program/<15><12>
	.ASCII	/TR [nnnn]			-> Trace one or more instruction(s)/<15><12>
	.ASCII	/MR				-> Master reset/<15><12>
	.ASCII	<15><12>

	.ASCII	/DISK AND TAPE COMMANDS/<15><12>
	.ASCII	/B [dd]				-> Boot IDE or TU58/<15><12>
	.ASCII	<15><12>

	.ASCII	/MISCELLANEOUS COMMANDS/<15><12>
	.ASCII	/VE				-> Show firmware version/<15><12>
	.ASCII	/aa; bb; cc; dd ...		-> Combine multiple commands/<15><12>
	.ASCII	/RP [nnnn]; A; B; C; ...		-> Repeat commands A, B, C/<15><12>
	.ASCII	/!any text...			-> Comment text/<15><12>
	.ASCII	<15><12>

	.ASCII	/SPECIAL CHARACTERS/<15><12>
	.ASCII	/Control-S (XOFF)		-> Suspend terminal output/<15><12>
	.ASCII	/Control-Q (XON)			-> Resume terminal output/<15><12>
	.ASCII	/Control-O			-> Suppress terminal output/<15><12>
	.ASCII	/Control-C			-> Abort current operation/<15><12>
	.ASCII	/Control-H (Backspace)		-> Delete the last character entered/<15><12>
	.ASCII	/RUBOUT (Delete)			-> Delete the last character entered/<15><12>
	.ASCII	/Control-R			-> Retype the current line/<15><12>
	.ASCII	/Control-U			-> Erase current line/<15><12>
	.ASCII	<15><12>

	.BYTE	0
	.EVEN
	.SBTTL	BASIC-11

	.IF	DF BASIC
BASTAP:	.include \basic11.dat\
	.ENDC
	.SBTTL	ROM Checksum and Entry Vectors

;++
;   The part of EPROM starting at 170000 is permanently mapped in to the address
; space regardless of the RAM map setting.  The OBJ2HEX program puts a 16 bit
; checksum in location 170000.  This value is calculated so that the sum of all
; words in the EPROM, including the checksum word, will be zero.  The EPROM
; checksum test (see below) uses this to verify the EPROM integrity.
;
;   The second word, 170002, contains the version of this EPROM.  This code
; never uses that, but it's there for user programs that might wish to check
; the EPROM revision level.
;
;   The pairs of words after that contain entry vectors for various subroutines
; in this permanently mapped segment that might be of general use - get a byte
; from the console terminal, print a character, IDE disk I/O, etc. These vectors
; are never used directly by this code, although the routines they point to are
; used all the time.  The vectors are there for the convenience of any user
; programs that might want to use these ROM subroutines as programming short
; cuts.
.=ROMBS1

CHKSUM:	.WORD	0		; OBJ2HEX puts the EPROM checksum here
	.WORD	BTSVER		; and the version number of this code

; General purpose vectors appear here ...
	JMP	@#SYSINI	; 1 - cold start
	JMP	@#MUL16		; 3 - 16x16 unsigned multiply
	JMP	@#DIV16		; 4 - 16x16 unsigned divide
	JMP	@#CONINI	; 5 - initialize the console
	JMP	@#CONPUT	; 6 - console output primitive
	JMP	@#CONGET	; 7 - console input primitive
	JMP	@#OUTCHR	; 8 - output one character to console
	JMP	@#OUTSTR	; 9 - output an ASCIZ string to console
	JMP	@#TDECW		;12 - type a decimal value
	JMP	@#TOCTW		;13 - type an octal value
	JMP	@#IDIDEN	;14 - identify IDE drive
	JMP	@#IDINIT	;15 - initialize IDE drive
	JMP	@#IDREAD	;16 - read IDE disk
	JMP	@#IDWRIT	;17 - write IDE disk
;	JMP	@#IDBOOT	;18 - boot IDE disk
	JMP	@#TUINIT	;19 - initialize TU58
	JMP	@#TUREAD	;20 - read TU58
	JMP	@#TUWRIT	;21 - write TU58
	JMP	@#TUBOOT	;22 - boot TU58
	JMP	@#GETTOD	;23 - get time of day
	JMP	@#SETTOD	;24 - set time of day
; ADD TFCHAR and maybe INLMES?
	.SBTTL	System Initialization and POST, Part 1

;++
;   This is part 1 of the system initialization and self test.  The basic steps
; to be accomplished are -
;
;   * Initialize the PPI and display POST code E
;   * Checksum and verify the monitor EPROMs
;   * Do a simple test of monitor scratch RAM from 176000 to 176377
;   * Test main RAM from 000000 to 167777
;   * And lastly, jump to the secondary startup and POST code
;
;   All of this needs to be in the unmapped part of the EPROM, above 170000.
; You might wonder why that's true since it consumes valuable unmapped space -
; the primary reason is that testing the main RAM requires us to unmap the
; mapped EPROM, and so this code has to be here.  Speaking of which, notice
; that there is no explicit test for the ROM mapping hardware.  If the EPROM
; checksum and the main RAM test both pass, then the  mapping hardware must be
; working.
;--

;   Note that PUP clears the RAM ENABLE bit in the MEMCSR and also the NXM TRAP
; ENABLE bit in the NXMCSR, but BCLR DOES NOT CLEAR EITHER ONE!  This means that
; a RESET instruction won't screw up the memory mapping.  BCLR (and PUP also)
; does, however, clear the LTC ENABLE bit in the LTCCSR and the spare flag bit
; in the spare CSR.
; 
;   BCLR and PUP both reset the PPI, which initializes all ports to input mode.
; This leaves the RUN LED and POST code signals floating, which temporarily
; turns the RUN LED on and displays F on the TIL311.  One of the first things
; we do is to initialize the correct PPI mode, turn the RUN LED off, and then
; display POST code E.
SYSINI:	MTPS	#PS.PR7		; disable all interrupts
	CLR	@#MEMCSR	; be sure ROM is mapped everywhere
	CLR	@#NXMCSR	; be sure NXM traps are disabled
	CLR	@#LTCCSR	; be sure LTC interrupts are disabled
	MOVB	#PPIMOD,@#PPICSR; initialize the PPI mode

;   Next is a super simple test of the monitor's scratch RAM area from 176000
; to 176377.  If this fails we'll just spin in place leaving POST code E on the
; display.  If it passes, then all the monitor scratch RAM is cleared to zeros.
	$POST	PC.SCR		; scratch pad RAM failure
	MOV	#SCRRAM, R0	; point to scratch RAM
	MOV	#125252, R1	; test pattern to use
10$:	MOV	R1, (R0)+	; store the test pattern in RAM
	COM	R1  		; and flip the bits for next time
	CMP	R0, #MONSTK+2	; have we reached the end?
	BNE	10$		; nope - keep going
	MOV	#SCRRAM, R0	; reinitalize the pointer
20$:	CMP	R1, (R0)	; does memory match?
	BNE	.		; nope - spin here forever
	CLR	(R0)+		; yes - leave RAM zeroed
	COM	R1  		; and flip the pattern for next time
	CMP	R0, #MONSTK+2	; have we done it all?
	BNE	20$		; keep going until we have

;   Now that we know the scratchpad RAM works we can checksum all of the monitor
; EPROMs and verify that they are OK.  Remember that ROM MAP mode is still
; enabled, so the EPROMs are mapped from 002000 thru 175777. Or at least they
; should be - the checksum implicitly tests that mapping too.
;
;   But first change the POST code to D and if the checksum fails, just spin
; here forever with that code displayed...
	$ROM			; just in case ...
	$POST	PC.ROM		; EPROM checksum failure
	MOV	#ROMBS0, R0	; point R0 to the start of EPROM
	CLR	R1		; and keep a running total here
30$:	ADD	(R0)+, R1	; add another word to the checksum
	CMP	R0, #ROMTOP+1	; have we done the entire EPROM?
	BNE	30$		; nope - keep adding
;;;	TST	R1		; was the result zero??
;;;	BNE	.		; nope - EPROM checksum failure!
	MOV	R1, BADSUM

;   Change the POST code to C, disable the ROM mapping mode, and do a simple
; test of main RAM.  This test simply writes each location with its address and
; then reads them back and isn't very sophisticated, but it at least proves that
; there's some read/write memory out there.  Speaking of which this also tests
; the other state of the ROM map mode (i.e RAM mode!).
	$POST	PC.RAM		; main RAM failure
	$RAM			; enable RAM from 002000 to 167777
	CLR	R0		; keep a pointer here
;   WARNING - on the DCT11 at least, "MOV R0, (R0)+" stores the INCREMENTED
; address in the destination, so don't try to get clever here!!
40$:	MOV	R0, (R0)	; write each location with its address
	TST	(R0)+		; and then increment the address
	CMP	R0, #RAMTOP+1	; have we done them all?
	BNE	40$		; nope - keep going
	CLR	R0		; now go back and test everything
50$:	CMP	R0, (R0)	; is the RAM correct?
	BNE	.		; spin forever if there's a failure
	CLR	(R0)+		; leave main RAM cleared
	CMP	R0, #RAMTOP+1	; and see if we're done
	BNE	50$		; not yet

;   Ok, if we get here then we know that the CPU works; the EPROM works; the RAM
; works, and the RAM mapping flag works.  Turn the ROM mapping back on; set up
; the monitor stack pointer (so we can call subroutines!); change the POST code,
; and then jump to part 2 of the system initialization and POST...
	$POST	PC.MAP		; memory mapping failure
	$ROM			; map all of EPROM again
	MOV	#MONSTK, SP	; initialize our stack pointer
	JMP	@#SYSIN2	; and continue with part 2
	.SBTTL	Restore User Context

;++
;   This routine will switch to the "user" context.  It first saves all the
; current, monitor, registers on the monitor's stack and saves the monitor's
; stack pointer.  The monitor's stack is in the special scratch pad RAM at
; 176000 and is (hopefully!) immune from any changes by the user program.
;
;   Then we restore the user's registers, the user's stack pointer and PSW.
; If either of the single step flags are set, then we'll set the T-bit in the
; user's PSW, but if neither is then we'll always clear the user's T-bit.  If
; we're not single stepping then the breakpoints will be installed in the user's
; program.  After that the user RAM is mapped; the POST code is changed to zero,
; and we're off!
;
;   You might think that this routine never returns, but that's not actually
; true.  Eventually (probably!) the user program will trap or halt or otherwise
; do something to return control to this monitor.  When that happens, assuming
; that the UCSAVE routine is called, then the user's registers will be saved and
; this monitor's context, including all monitor registers, will be restored.
; That includes the monitor's stack and the return address of the routine that
; called this one!  This behavior is actually critical for some functions, like
; single step and continue.
;
;	CALL	UCLOAD
;	<return to user's context>
;
;   One last note - this doesn't do any sanity checking on the user's context.
; It doesn't check for things like an odd SP or PC, or even that the user stack
; points to valid RAM.  The latter is critical because switching to the user
; context depends on at least a couple of words of valid stack RAM, and if the
; SP is bogus then we'll fail miserably.  It's up to the caller to check these
; things before calling here.
;--
UCLOAD:	CALL	CONWAI		; make sure the console is done printing
	$PUSH<R0,R1,R2,R3,R4,R5>; save all the monitor's registers
	MOV	SP, SPSAVE	; and then save the monitor stack pointer
	CLR	WHYBRK		; clear the "why break" code for UCSAVE

; Set up breakpoints and/or T-bit traps ...
	BIC	#PS.T, USRPS	; clear the user T-bit by default
	MOV	#BPTRQ,@#BPTVEC	; always connect the breakpoint/T-bit trap
	MOV	#PS.PR7,@#BPTVEC+2;  ... to our code
	BIT	#S.STEP!S.SSBP,SFLAGS; are we single stepping ?
	BEQ	10$		; no
	BIS	#PS.T, USRPS	; yes - set the user T-bit after all
	BR	15$		; and finish restoring the context

; Here if we're NOT single stepping ...
10$:	CALL	BPTINS		; install any and all breakpoints
15$:	$RAM			; map user RAM everywhere
	$POST	PC.USR+PC.RUN	; show that the user program is running

; Restore the user's registers ...
	MOV	USRREG+<2*0>,R0	; ...
	MOV	USRREG+<2*1>,R1	; ...
	MOV	USRREG+<2*2>,R2	; ...
	MOV	USRREG+<2*3>,R3	; ...
	MOV	USRREG+<2*4>,R4	; ...
	MOV	USRREG+<2*5>,R5	; ...
	MOV	USRSP, SP	; lastly restore the user's stack

; Push the user's last PC and PS ...
	MOV	USRPS, -(SP)	; stack the user's PS
	MOV	USRPC, -(SP)	; and then stack the user's PC

; If the LTC is enabled, then turn on the LTC interrupts ...
	CLR	@#LTCCSR	; turn the LTC off by default
	BIT	#H.LTCE, HFLAGS	; is the LTC enabled ?
	BEQ	20$		; no - skip it
	MOV	#LT.ENA,@#LTCCSR; yes - enable 60Hz interrupts

;   If we want bus timeout emulation, then enable NXM traps.  Note that this
; has to be pretty much the LAST thing we do, because accessing scratch pad
; RAM (e.g. to push the user PS or PC) will cause a NXM trap!  Once NXM traps
; are enabled, all we can safely access is the monitor ROM...
20$:	CLR	@#NXMCSR	; disable NXM trapping by default
	BIT	#H.NXME, HFLAGS	; but do we want it turned on?
	BEQ	99$		; no - don't enable it
	MOV	#NX.ENA,@#NXMCSR; yes - set the NXM trap enable bit

; Away we go - hope for the best!
99$:	RTT			;...
	.SBTTL	Save User Context

;++
;   This routine is called by the handler routines for any of the traps or
; interrupts that re-enter this monitor.  It saves all the user's registers,
; in scratch pad RAM at USRREG, USRPC, USRSP and USRPS.  Then we restore the
; monitor's original stack, restore the monitor's previous registers (as were
; saved by UCLOAD) and return.
;
;   Note that "return" is a little bit tricky here because this routine was
; originally called while the user's stack was still active.  We remove that
; return address from the user's stack and transfer it to the monitor stack
; so that, when this routine returns, it's actually returning to the same
; place that originally called us even though a completely different stack is
; in use.
;
;	<user context in effect>
;	CALL	UCSAVE		; we're calling on the user's stack!
;	<return here with monitor context in effect>
;
;   One warning - restoring the monitor's context depends on the UCLOAD routine
; having been called previously to actually save that context.  In the event of
; various errors, hardware problems or unexpected interrupts, it's possible to
; get here without that being true.  We have to verify that the saved monitor
; stack is indeed valid before we try to pop things off of it, and if it isn't
; then we set up a new stack in its place.
;--
UCSAVE:	MOV	R0,USRREG+<2*0>	; save the user's registers ...
	MOV	R1,USRREG+<2*1>	; ...
	MOV	R2,USRREG+<2*2>	; ...
	MOV	R3,USRREG+<2*3>	; ...
	MOV	R4,USRREG+<2*4>	; ...
	MOV	R5,USRREG+<2*5>	; ...
	MOV	(SP)+, UCSRTN	; get our return address off the user's stack
	MOV	(SP)+, USRPC	; and pop the user's PC and PS
	MOV	(SP)+, USRPS	;  ... from the user's stack
;;	BIC	#PS.T, USRPS	; always clear the T bit
	MOV	SP, USRSP	; lastly, save the user's SP

; Restore the monitor's stack, but first make sure it's valid!
	MOV	SPSAVE, SP	; restore the saved stack pointer
	CMP	SP, #CMDBUF	; does it look valid?
	BLOS	10$		; no!
	CMP	SP, #MONSTK	; check the other end
	BLOS	20$		; it's valid

; The saved stack is not valid - dummy one up ...
10$:	MOV	#MONSTK, SP	; set a valid stack pointer
	$PUSH	#RESTA		; save a return address
	$PUSH<#0,#0,#0,#0,#0,#0>; and "save" R0 thru R5

; Restore the monitor registers and return to whoever called UCSAVE ...
;   This leaves the original address, of who ever called UCLOAD, on the stack!
20$:	$POP <R5,R4,R3,R2,R1,R0>; restore our registers
	JMP	@UCSRTN		; ...
	.SBTTL	Breakpoint and T-bit Traps

;++
;   The breakpoint/T-bit trap vector is initialized to point to this routine.
; The first job is to figure out which happened - a breakpoint or a trace trap -
; the PDP11 uses the same vector for both.  If it turns out that we're here
; because of an actual BPT breakpoint instruction, then we need to figure out
; whether it's one of ours or just a random BPT that happens to be in the
; user's program.
;
;   Remember that calling UCSAVE will restore the original monitor's context
; (the one in effect at the time USERGO was called), including the monitor's
; stack and all registers.  Most of the registers we don't care about, but
; we do want to preserve R5.  That's the command line pointer and we'll need
; that later if this breakpoint occurs during a REPEAT command...
;
;   Note that the very first thing we want to do is to re-initialize the PPI,
; just in case the user's program has messed it up.  We then turn off the RUN
; LED and set the POST code to 1 again.  Next we turn off NXM trapping because
; otherwise UCSAVE will trap when it tries to access the scratchpad RAM!  BUT,
; we want to leave the RAM map enable set because UCSAVE needs to access the
; user's stack, and that'll never work if we enable ROM now!
;--
BPTRQ:	CLR	@#NXMCSR		; disable NXM trapping
	MOVB	#PPIMOD,@#PPICSR	; restore the PPI mode
	MOVB	#PC.MON, @#PPIB		; POST=1, RUN LED OFF
	CALL	UCSAVE			; swap back to monitor context
	$ROM				; NOW it's safe to map the ROM

;   If the S.SSBP flag is set, then we're trying to continue past a breakpoint
; (one of our breakpoints!).  When we get here we've already stepped over the
; original breakpoint, so now we clear the single step flags and jump back to 
; UCLOAD again.  That will re-install all the breakpoint instructions and
; free run until we hit one again.
	BIT	#S.SSBP, SFLAGS	; stepping over a breakpoint?
	BEQ	10$		; no - must be something else
	BIC	#S.SSBP!S.STEP,SFLAGS; yes - clear the single step flags
	JMP	UCLOAD		; and continue execution

;   If the single step flag, S.STEP, is set then we're executing a single step
; command.  We just return now, with all the original context intact, and the
; single step command will take care of things.
10$:	BIT	#S.STEP, SFLAGS	; are we single stepping?
	BEQ	20$		; no ..
	RETURN			; yes - return to what ever we were doing

;   See if the T-bit was set in the user's PSW.  If it was, then we didn't put
; it there so just print an "unexpected T-bit trap" message and start the
; monitor command scanner...
20$:	BIT	#PS.T, USRPS	; was this a T-bit trap?
	BEQ	30$		; no ...
	MOV	#B.UTBI, WHYBRK	; remember what happened
	JMP	ATRAP2		; and then handle like any other trap

;   It's not a T-bit trap, so it must be a breakpoint (BPT) instruction.  The
; next question is, "was it one of ours?"...
30$:	BIT	#S.BPTI, SFLAGS	; were our breakpoints even installed?
	BEQ	35$		; nope - can't be one of ours
	MOV	USRPC, R1	; get the address of the breakpoint
	TST	-(R1)		; and back up the PC to the BPT instruction
	CALL	BPTFND		; see if it's in our breakpoint table
	BEQ	40$		; branch if yes
35$:	MOV	#B.UBPT, WHYBRK	; unexpected breakpoint trap
	JMP	ATRAP2		; and then handle like any other trap

;   If we get here, then we hit a real breakpoint trap AND it's also one of
; ours.  Remove the breakpoints from the user program (we KNOW that they're
; installed!), print an appropriate message, and then return.  Nore that
; returning from here will actually return back to the GO or Continue command
; that started the user program in the first place.
40$:	MOV	R1, USRPC	; update the user's PC
	CALL	BPTRMV		; remove the breakpoints
	CALL	CONINI		; be sure the console is ready
	CALL	TCRLF		; ...
	$MSG	<%BREAKPOINT AT >
	MOV	USRPC, R1	; get the user's PC back again
	CALL 	TOCTW		; type that
	CALL	TCRLF		; finish the line
	JMP	TCRLF		; and leave an extra blank one
	.SBTTL	Miscellaneous Interrupt and Trap Vectors

;++
;   These are the entry points for all the possible reasons why we could be
; entering the monitor - HALT, break point, T-bit, power fail, various traps,
; and more.  The trick is to set up a code in WHYBRK which lets us remember
; how we got here, and then proceed with saving the user's context.  Once the
; user context has been saved, the PPI initialized and the ROM mapped, we can
; jump to BRKMSG which will print the appropriate message and then restart the
; command scanner ...
;
;   Each of these entry point saves the reason code on the stack and then jumps
; to common generic trap handling code.  Remember that the user's stack is still
; in effect here and we're adding an extra word to his stack space.  That's not
; the best, but there's no easy way around it.  You might be tempted to just
; move the reason code directly to WHYBRK (after all, PDP11s do have a "move
; immediate to memory" instruction) but if NXM traps are enabled then we can't
; access the scratch pad RAM (nor WHYBRK!) without causing a trap.  We have to
; clear the NXMCSR before we can access any monitor RAM...
;--
IOTRQ:	$PUSH	#B.IOT		; IOT trap
	BR	ATRAP1		; ...
TRAPRQ:	$PUSH	#B.TRAP		; TRAP trap
	BR	ATRAP1		; ...
EMTRQ:	$PUSH	#B.EMT		; EMT trap
	BR	ATRAP1		; ...
RINSRQ:	$PUSH	#B.RINS		; reserved instruction trap
	BR	ATRAP1		; ...
IINSRQ:	$PUSH	#B.IINS		; illegal instruction trap
	BR	ATRAP1		; ...
PFRQ:	$PUSH	#B.PFAI		; power fail trap
	BR	ATRAP1		; ...

;++
;   All unused device interrupt vectors are initialized by the POST to point
; here.  This has a special significance during the POST because any unexpected
; interrupt then is Bad News.  The H.POST bit in the flags tells us that we're
; currently executing the POST - if this is set, then just spin here forever.
; Don't bother saving registers and, above all, don't change the POST code
; displayed.  Whatever is on the display now is the number of the failing test.
;
;   It's also possible to get here if the user's code leaves an interrupt vector
; uninitialized and then that interrupt happens to occur.  That's OK, but we
; need to be a little careful about NXM traps - if they're enabled, then we
; can't access scratchpad RAM (including FLAGS!) without causing a trap unless
; we disable NXM traps first.
;--
UINTRQ:	CLR	@#NXMCSR	; disable NXM trapping
	BIT	#H.POST, HFLAGS	; is the POST running right now ?
	BNE	.		; yes - ANY trap here is bad!
	$PUSH	#B.UINT		; no - handle it like any other trap
;;	BR	ATRAP1		; ...


;++
;   This is the common code for all traps and interrupts, except for HALT and
; BPT/T-bit traps.  We need to initialize the PPI, just in case the user's
; program has messed it up, turn the RUN LED off and display POST code 1.  We
; also clear the NXM trap enable, BUT we need to leave the RAM enable bit set.
; That's because UCSAVE needs to access the user's stack, so we can't switch to
; ROM mapping just yet.
;--
ATRAP1:	CLR	@#NXMCSR	; disable NXM trapping
	MOVB	#PPIMOD,@#PPICSR	; initialize the PPI mode
	MOVB	#PC.MON, @#PPIB	; POST=1, RUN LED off
	$POP	WHYBRK		; pop off the reason we stopped
	CALL	UCSAVE		; save the user registers ...
	$ROM			; and NOW it's safe to map EPROM
ATRAP2:	BIT	#S.BPTI, SFLAGS	; are breakpoints installed?
	BEQ	10$		; no ...
	CALL	BPTRMV		; yes - remove them from the user's program
10$:	CALL	CONINI		; be sure the console SLU is OK
	CALL	TCRLF		; be sure we're at the left margin
	JMP	BRKMSG		; and go type an appropriate message
	.SBTTL	Read and Write User RAM

;++
;   The majority of the monitor code lives in the mapped part of ROM and it has
; a problem when it wants to access the user's RAM.  Namely, it can't!  The
; only way to access user RAM from 001000 thru 167777 is to unmap the ROM and
; of course that would crash the very code that's trying to access RAM!  The
; solution is to put two tiny routines, RDRAM and WRRAM, into the unmapped part
; of ROM.  These routines simply unmap the ROM, read or write the required
; location in RAM, map ROM again, and return.  Whenever the monitor code needs
; to access user RAM, it does so by calling one of these.  Not very efficient,
; but for the most part we don't care about speed.
;--


;++
; Read and return one word from user RAM ...
;
;	<user RAM address in R2>
;	CALL	RDRAM
;	<return user RAM data in R1>
;--
RDRAM:	$RAM			; unmap ROM, map RAM
	MOV	(R2), R1	; read the word
	$ROM			; and map the ROM again
	RETURN			; that's all we need!


;++
; Write one word of user RAM ...
;
;	<user RAM address in R2>
;	<data to be writtin in R1>
;	CALL	WRRAM
;--
WRRAM:	$RAM			; unmap ROM, map RAM
	MOV	R1, (R2)	; store the word
	$ROM			; back to the ROM
	RETURN			; ...


;++
; This is just like WRRAM, but for a single byte!
;
;	<user RAM address in R2>
;	<data to be writtin in R1>
;	CALL	WRRAMB
;--
WRRAMB:	$RAM			; same old thing 
	MOVB	R1, (R2)	; but for a single byte this time
	$ROM			; ...
	RETURN			; ...


;++
;   These two routines zero RAM.  CLRRAM zeros all RAM, from MAXVEC thru RAMTOP.
; The alternate entry point, at CLRRA1, zeros RAM from (R1) up to (R2).  There
; is no bounds checking for the latter, so be careful not to zero the monitor's
; scratch pad page!
;
;	CALL	CLRRAM		; clear all user RAM
; -or-
;	<R1 contains starting address and R2 the ending address>
;	CALL	CLRRA1		; zero from (R1) to (R2)
;--
CLRRAM:	MOV	#MAXVEC+2, R1	; starting address
	MOV	#RAMTOP, R2	; ending address
CLRRA1:	$RAM			; map RAM
10$:	CLR	(R1)+		; clear another word
	CMP	R1, R2		; are we done?
	BLOS	10$		; nope, not yet
	$ROM			; back to the monitor
	RETURN			; and return
	.SBTTL	IDE Disk Primary Bootstrap

;++
;   This routine will read block zero from IDE disk unit zero into page
; zero of field zero of main memory.  The next step in the usual boot sequence
; would be to start the secondary bootstrap, but that's up to the caller...
;--
;;IDBOOT:	STA			; point the buffer to page 0
;;	DCA	BUFPTR		; ...
;;	TAD	[CDF 0]		; of field zero
;;	DCA	@[BUFCDF+1]	; ...
;;	DCA	BUFPNL		; of main memory
;;	CDF	0		; PARMAP lives in field 0
;;	TAD	@[PARMAP]	; get partition number of unit 0
;;	CDF	1
;;	DCA	DKPART		; ...
;;	DCA	DKRBN		; block zero
;;	TAD	[-128.]		; we only need the first 1/2 of the block
;;	JMP	@[IDREAD]	; ...
	.SBTTL	TU58 Tape Primary Bootstrap

;++
; R1 contains the unit number!
;--
TUBOOT:	MOV	R1, BTUNIT	; save the unit number
	CALL	TUINIT		; initialize the TU58 drive
	BCC	10$		; branch if timeout
	MOV	BTUNIT, R1	; get the unit number back
	CLR	R2		; read block 0 
	CLR	R3		; into RAM at location 0
	MOV	#512., R4	; read the whole block
	CALL	TUREAD		; ...
	BCS	CHK240		; if we were successful, try to boot
10$:	RETURN			; ...

; CHK240
CHK240:	CMP	#240, @#0	; is this a bootable volume?
	BNE	30$		; no!
	CALL	INIREG		; intialize the user registers
	MOV	#SLU1,  USRREG+<1*2>	; CSR in R1
	MOV	BTUNIT, USRREG+<0*2>	; and unit number in R0
	CLR	USRPC		; start at address zero
	MOV	#10000, USRSP	; and with the stack at 10000
	MOV	#PS.PR7, USRPS	; start with interrupts disabled
	JMP	GOCMD1		; start the user program running!

; Here if the unit isn't bootable ...
30$:	$MSG	<?NOT BOOTABLE>	; ...
	CALL	TCRLF		; ...
	CALL	INIVEC		; restore the interrupt vectors!
	JMP	RESTA		; and print another prompt
	.SBTTL	Startup and Restart Vectors

;++
;--

FREE1=START1-.
	.IF	LT, FREE1
	.ERROR	FREE1 ; CODE OVERWRITES STARTUP VECTOR #1
	.ENDC

.=START1
	JMP	@#SYSINI	; cold start vector
;;	JMP	@#HALTRQ	; halt (instruction or switch!)

;++
;   We get here for a DCT11 halt/restart.  There are four reasons why this can
; this can happen on the SBCT11 -
;
;	* somebody executed a HALT instruction
;	* somebody flipped the RUN/HALT switch
;	* the console terminal sent a break
;	* the program referenced a non-existent memory location
;
;   The first three are all basically the same for our purposes - we want to
; save the user's context, print a "?HALTED AT ..." message, and then go start
; the command scanner.
;
;   The third one, however, is a bit tricky.  If bus timeout emulation has been
; enabled, then we want to simulate a bus timeout trap (i.e. a trap to 4) and
; then continue execution of the user's program.  We can tell if a NXM trap has
; occired by checking the corresponding status bit in the PPI port C register.
; If this bit is not set, then the halt/restart must be due to one of the other
; reasons, and we treat it as such.
;
;   If a NXM trap did occur, then we need to clear the trap request by clearing
; and then resetting the NXM TRAP enable PPI output.  After that we just have to
; fetch the contents of the user's locations 4 and 6, put them on the stack, and
; do an RTT.  That'll activate his bus timeout handler.
;--
HALTRQ:	BIT	#NX.REQ,@#NXMCSR; is this a NXM trap?
	BNE	10$		; yes - deal with that specially

; Here for an ordinary halt of some kind or another ...
	$PUSH	#B.HALT		; remember why we stopped
	JMP	ATRAP1		; and handle like any other trap

;   Here for a NXM trap - see if it's "real" or if the user just screwed up the
; PPI and caused a spurious trap.  The situation here is similar to that at
; ATRAP1: or BPTRQ: in that we can't access the FLAGS variable in scratchpad RAM
; unless we're sure NXM traps are disabled.  The solution is the same - we just
; clear the NXM trap enable and hope for the best.  If the PPI really is screwed
; up then this might now work.
10$:	CLR	@#NXMCSR	; clear the NXM enable bit
	BIT	#H.NXME, HFLAGS	; are we emulating bus timeouts ?
	BNE	20$		; yes - go fake a timeout trap
	$PUSH	#B.UNXM		; no - unexpected NXM trap
	JMP	ATRAP1		; and otherwise pretend it's a HALT

; And finally, here for a real bus timeout emulation!
20$:	CLR	@#NXMCSR	; clear the trap enable flag
	MOV	#NX.ENA,@#NXMCSR; and reset it to clear the trap F-F
	$PUSH	@#NXMVEC+2	; stack the user's timeout trap PS
	$PUSH	@#NXMVEC	;  ... and vector
	RTI			; then call his timeout trap routine
	.SBTTL	Wait for IDE Drive

;++
;   This routine tests for the DRIVE READY bit set in the status register and
; at the same time for the DRIVE BUSY bit to be clear.  READY set means that
; the drive has power and is spinning, and BUSY clear means that it isn't
; currently executing a command.  The combination of these two conditions means
; that the drive is ready to accept another command.
;
;   If there is no drive connected, or if the drive fails for some reason, then
; there is the danger that this routine will hang forever.  To avoid that it
; also implements a simple timeout and if the drive doesn't become ready within
; a certain period of time it will return with the carry cleared.  The magic
; constant loaded into R1, 51000, is calculated such that it requires exactly
; one second for the "SOB R1" loop to expire.  The constant IDETMO specifies
; number of iterations of that loop, giving the actual timeout in seconds.
;
;   It's tempting to make the timeout a pretty short number, say 1 or 2 seconds,
; and that works fine for solid state media like CF cards.  If you ever plan to
; use a real hard drive, however, remember that they have to spin up before they
; go ready and that can take 10, 15 or 20 seconds or more.
;
;	CALL	WREADY
;	<return with C=1 if all is well>
;--
WREADY:	$PUSH	<R1,R0>		; save R1 and R0
	$PUSH	#IDETMO		; and then stack the outer timeout loop counter
11$:	MOV	#189.*DLYMS, R1	; magic constant for one second each iteration
10$:	MOVB	@#IDESTS, R0	; read the status register
	BIT	#ID.BSY, R0	; is the busy bit cleared ?
	BNE	20$		; no - keep waiting
	BIT	#ID.RDY, R0	; and is the ready bit set?
	BEQ	20$		; no - more waiting
	SEC			; success!  Return C=1
15$:	$POP	R1		; remove the timeout from the stack
	$POP	<R0,R1>		; restore R0 and R1
	RETURN			; and we're done

; Here if the drive is not ready yet ...
20$:	SOB	R1, 10$		; count down the one second timeout
	DEC	(SP)		; and decrement the outer one when that runs out
	BNE	11$		; keep going
	CLC			; timed out!  return C=0
	BR	15$		; clean up the stack and we're done


;++
;   This routine will wait for the DRQ bit to set in the drive status register.
; This bit true when the drive is ready to load or unload its sector buffer,
; and normally the next thing to do would be to transfer 512 bytes of data.
; to ether RDIBUF or WRIBUF.  Normally this routine will return with carry set
; if all is well, however if the drive sets its error bit then the carry will
; be cleared on return.
;
;   WARNING - unlike WREADY, this routine does not have a timeout!
;
;	CALL	WDRQ
;	<return with C=1 if all is well>
;--
WDRQ:	MOVB	@#IDESTS, R0	; read the drive status register
	BIT	#ID.BSY, R0	; is the drive still busy ?
	BNE	WDRQ		; yes - keep waiting
	BIT	#ID.ERR, R0	; is the error bit set?
	BNE	10$	 	; yes - return carry cleared
	BIT	#ID.DRQ, R0	; and is DRQ set?
	BEQ	WDRQ		; no - more waiting
	SEC			; yes!  Return with carry set
	RETURN			; ...
10$:	CLC			; in case of error return with
	RETURN			;  ... carry cleared
	.SBTTL	Initialize IDE Drive

;++
;   This routine will determine if any ATA/IDE drive is actually connected and,
; if it is, then it will initialize the drive.  If the drive is present and all
; is well, then we'll return with the carry flag set.  If there is no drive
; attached, or if the hardware is broken, then we'll time out after IDETMO
; seconds of waiting for the drive to signal a ready status.  In that case we
; return with carry clear.
;
;	CALL	IDINIT
;	<return with C=1 if drive present and ready>
;--
IDINIT:

;   Waiting for a timeout is kind of tedious when there's no drive attached,
; so let's do some simple checks first.  The sector count and LBA0, 1 and 2
; registers can all be read or written at will and nothing will happen (provided
; we don't try to initiate a drive operation!).  Let's just test these four
; registers to see if they even exist...
	CLRB	@#IDELB3	; be sure the master drive is selected
	MOVB	#125, @#IDESCT	; write the sector count register
	MOVB	#252, @#IDELB0	; LBA address part 0
	MOVB	#360, @#IDELB1	; LBA address part 1
	MOVB	#017, @#IDELB2	; LBA address part 2
	CMPB	#125, @#IDESCT	; now try to read them back
	BNE	10$		; branch if no drive
	CMPB	#252, @#IDELB0	; ...
	BNE	10$		; branch if no drive
	CMPB	#360, @#IDELB1	; ...
	BNE	10$		; branch if no drive
	CMPB	#017, @#IDELB2	; ...
	BEQ	20$		; branch if all tests passed
10$:	CLC			; otherwise report no drive
	RETURN			; ...

;   Alright! Looks like there's really something out there.  Set the software
; reset bit in the drive control register and wait for the drive to go ready.
; Notice that we also want to SET the IEN bit to DISABLE interrupts!  Yes, the
; sense is backwards.
;
;   Note that the sRST bit doesn't self clear - you have to write it with a 1,
; wait a moment, and then write a 0.  If you don't clear it the drive will stay
; in the reset state forever!  I couldn't find a spec on exactly how long the
; sRST bit needs to stay set, so I just threw in a few NOPs for a delay.  It
; seems to work well enough...
20$:	MOVB	#ID.RST,@#IDECTL; set the software reset bit
	.REPT	4
	NOP			; wait some indeterminate amount of time
	.ENDR
	MOVB	#ID.NIE,@#IDECTL; and then clear it
;  In some cases it seems to be necessary to disable interrupts once again.  My
; theory is that the reset deselects the master drive, so select again and write
; the "NO INTERRUPTS" bit once more.
	CLRB	@#IDELB3	; re-select the master drive again
	MOVB	#ID.NIE,@#IDECTL; and DISABLE interrupts
	JMP	WREADY		; wait for ready and return that status
	.SBTTL	Identify IDE Drive

;++
;   This routine will execute the ATA IDENTIFY DEVICE command and store the
; the result in the caller's buffer.  The drive's response to IDENTIFY DEVICE
; will always be 512 bytes full of device specific data - model number,
; manufacturer, serial number, drive geometry, maximum size, access time, and
; tons of other cool stuff.  Like all the disk I/O routines, this routine will
; return carry=1 for success and carry cleared in the case of an error.
;
;	<R2 points to a 512 byte buffer>
;	CALL	IDIDEN
;	<return with C=1 if success>
;--
IDIDEN:	CALL	WREADY		; (just in case the drive is busy now)
	BCC	90$		; give up now if there are any errors
	MOV	#ID$IDD,@#IDECMD; send the ATA identify device command
	CALL	WDRQ		; wait for the drive to transfer data
	BCC	90$		; branch if error

;   You might like to use IDERDD here, however the drive data is returned in
; words and unfortunately it does so in big endian order.  We need to swap
; bytes on every word read to make sense out of the response.  Rather than
; burden all read operations with this overhead, we just have our own special
; transfer loop here.
	$SAVMAP			; save the current mapping mode
	$RAM			; buffers are always in RAM!
	MOV	#DSKBSZ/2, R0	; set up the word count
10$:	MOV	@#IDEDAT, (R2)	; read the next word
	SWAB	(R2)+		; and byte swap it
	SOB	R0, 10$		; loop for all 256 of them
	$RSTMAP			; restore the previous mapping mode

; All done!
	SEC			; return C=1 for success
90$:	RETURN			; or with C=0 on error
	.SBTTL	Read IDE Disk Sectors

;++
;   This routine will read a single sector from the attached IDE drive. The 
; full 28 bit disk addressing is supported (although I don't know why you'd
; want to connect such a huge drive to a PDP11!) and it always transfers
; exactly one 512 byte sector.  If all is well we return with the carry flag
; set, and if there's an error we return with carry clear.
;
;	<low order LBA in R0; high order LBA in R1>
;	<pointer to 512 byte buffer in R2>
;	CALL	IDREAD
;	<return C=1 if success>
;--
IDREAD:
;   See if there really is a hard disk attached.  If not, then immediately
; take the error return with the carry cleared ...
	BIT	#H.DISK, HFLAGS	; see if a drive is atatached
	BNE	10$		; yes - proceed
90$:	CLC			; no - give the error return now
	RETURN			; ...

; Read the requested sector ...
10$:	CALL	WREADY		; wait for the drive to become ready
	BCC	90$		; quit if there's an error
	CALL	SETLBA		; set up the sector count and LBA registers
	MOVB	#ID$RDS,@#IDECMD; read sector with retry command
	CALL	WDRQ		; now wait for the drive to finish
	BCC	90$		; quit if there was an error

;   Transfer 512 bytes of data from the IDE/ATA device to the caller's buffer.
; Remember tha that the ATA data register is 16 bits wide, and this routine
; copies entire WORDS from the drive, not bytes.  The implication is that pairs
; of bytes are read in the PDP11 little endian order.  That's of no consequence
; as long as you're writing the drive on the SBCT11 too, however if you try to
; move the drive to another system you might have to worry about the ordering.
	$SAVMAP			; save the current mapping mode
	$RAM			; buffers are always in RAM
	MOV	#DSKBSZ/2, R0	; count words here
20$:	MOV	@#IDEDAT, (R2)+	; transfer one word
	SOB	R0, 20$		; do that for 256 words
	$RSTMAP			; restore the previous mapping mode

; Success!
	SEC			; return with carry set
	RETURN			; and we're done


;++
;   This routine will set up the drive's sector count and LBA registers for
; either a read or write call.  It assumes that the desired disk LBA is passed
; in R0/R1, just as it is to IDREAD or IDWRIT.
;--
SETLBA:	MOVB	#1, @#IDESCT	; always set the sector count to 1
	MOVB	R0, @#IDELB0	; set bits 0..7 of the LBA
	SWAB	R0		; then bits 8..15
	MOVB	R0, @#IDELB1	; ...
	MOVB	R1, @#IDELB2	; now buts 16..23
	SWAB	R1		; get bits 24..27
	BIC	^C17, R1	; eliminate any garbage
	BIS	#ID.LBA, R1	; set the LBA mode bit
	MOVB	R1, @#IDELB3	; and set that
	RETURN			; ready to go!
	.SBTTL	Read and Write NVR/RTC Bytes

;++
;   These routines will read or write a single byte from or to the DS12887A
; NVR/RTC chip.  This chip is basically 128 bytes of battery backed up SRAM,
; and the first 14 bytes implement a clock/calendar that keeps track of the
; time of day, even when the power is off. 
;
;   Remember, to access the DS12887 we first write the address of the register
; we want to the RTCAS location, and then we can read or write the contents
; of that register by accessing the RTCRD or RTCWR locations.  This would be
; trivial except that the SBCT11 revision B PC boards have a layout error that
; requires us to shift one bit to the right or left and do some masking.
;--

;++
; Read and return a byte from NVR/RTC ...
;
;	<NVR address, 0..127, in R2>
;	CALL	RDNVRB
;	<return NVR byte in R1>
;--
RDNVRB:	$PUSH	R2		; save the originel address
	ASL	R2		; shift the address left one bit
	BIC	#^C376, R2	; clear out any extra bits
	MOV	R2, @#RTCAS	; load the DS12887 address register
	MOV	@#RTCRD, R1	; read a byte from the DS12887A
	ASR	R1		; right justify it
	BIC	#^C377, R1	; and clear any extra bits
	$POP	R2		; restore the address
	RETURN			; and we're done


;++
; Write one byte to NVR/RTC ...
;
;	<NVR address, 0..127, in R2>
;	<byte to be written in R1>
;	CALL	WRNVRB
;--
WRNVRB:	$PUSH	<R2,R1>		; save the original address and data
	ASL	R2		; gotta shift the address left for the B PCB
	BIC	#^C376, R2	; clear out any extra bits
	MOV	R2, @#RTCAS	; load the DS12887 address register
	ASL	R1		; left justify the data too
	MOV	R1, @#RTCWR	; store these bits in the NVR
	$POP	<R1,R2>		; restore the original register contents
	RETURN			; and we're done
	.SBTTL	Secondary Startup Vectors

;++
;--
FREE2=START2-.

	.IF	LT, FREE2
	.ERROR	FREE2 ; CODE OVERWRITES STARTUP VECTOR #2
	.ENDC

.=START2
	JMP	@#SYSINI	; cold start vector
	JMP	@#HALTRQ	; halt (instruction or switch!)
	.SBTTL	Write IDE Disk Sectors

;++
;   This routine will write a single sector to the attached IDE drive.  Except
; for the direction of data transfer, it's the same as IDREAD including all
; parameters and error returns.  The full 28 bit disk addressing is supported
; and it always transfers exactly one 512 byte sector. If all is well we return
; with the carry flag set, and if there's an error we return with carry clear.
;
;	<low order LBA in R0; high order LBA in R1>
;	<pointer to 512 byte buffer in R2>
;	CALL	IDWRIT
;	<return C=1 if success>
;--
IDWRIT:
;   See if there really is a hard disk attached.  If not, then immediately
; take the error return with the carry cleared ...
	BIT	#H.DISK, HFLAGS	; see if a drive is atatached
	BNE	10$		; yes - proceed
90$:	CLC			; no - give the error return now
	RETURN			; ...

; Tell the drive to expect a write operation ...
10$:	CALL	WREADY		; wait for the drive to become ready
	BCC	90$		; error - give up now
	CALL	SETLBA		; set up the disk address
	MOVB	#ID$WRS,@#IDECMD; write sector with retry command
	CALL	WDRQ		; wait for the drive to request data
	BCC	90$		; did the drive detect an error instead?

;   Transfer 512 bytes of data from a buffer in RAM to the IDE/ATA device.
; Like IDREAD, it writes entire words in PDP11 little endian byte order.
	$SAVMAP			; save the current mapping mode
	$RAM			; buffers are always in RAM
	MOV	#DSKBSZ/2, R0	; count the words transferred
20$:	MOV	(R2)+, @#IDEDAT	; transfer one word
	SOB	R0, 20$		; and do that for 256 words
	$RSTMAP			; restore the original mapping mode

;   There's a subtle difference in the order of operations between reading and
; writing.  In the case of writing, we send the WRITE SECTOR command to the
; drive, transfer our data to the sector buffer, and only then does the
; drive actually go out and access the disk.  This means we have to wait
; one more time for the drive to actually finish writing, because only then
; can we know whether it actually worked or not!
	JMP	WREADY		; wait for the drive to finish writing
	.SBTTL	Read TU58 Tape Records

;++
;   This routine will read one or more data records from the TU58 drive.  On
; call the registers (see below) specify the unit and block number, the address
; of a buffer in RAM, and the number of bytes to read.  A real TU58 drive only
; has units 0 or 1 and tapes only contain 512 blocks, but everybody is using
; TU58 emulators these days.  Those often allow for extra units or oversize tape
; images, so we don't range check either argument.  If any error occurs we
; return with carry clear and an error code from the TU58 in R0.  If the data
; is read successfully then carry will be set on return.
;
;	<R1 contains the unit number>
;	<R2 contains the block number>
;	<R3 points to the caller's buffer>
;	<R4 contains the count of bytes to read>
;	CALL	TUREAD
;	<return with C=1 if successful>
;
;   BTW, you should be sure to call TUINIT before calling this routine!
;--
TUREAD:	$SAVMAP			; save the current memory mapping mode
	$RAM			; assume the caller's buffer is in RAM
	MOV	#TU$RD, R0	; opcode we want to send
	CALL	TUXCMD		; and transmit a control/command packet

; Try to read a data packet header from the TU58 ...
10$:	CALL	TUCLSM		; clear the checksum accumulator
	CALL	TUGETC		; read the next byte
	BCC	30$		; branch if timeout
	CMPB	#TU.DAT, R0	; is this a DATA packet?
	BNE	40$		; no - check for an END packet
	CALL	TUGETC		; get the length byte
	BCC	30$		; timeout
	BIC	#^C377,R0	; clear any UART flags
	MOV	R0, R5		; keep the packet data count here

; Read the bytes in the data packet ...
20$:	CALL	TUGETC		; get another data byte
	BCC	30$		; timeout
	TST	R4		; is the caller's buffer full?
	BEQ	25$		; yes -  don't store this byte
	MOVB	R0,(R3)+	; store it in the caller's buffer
25$:	DEC	R4		; decrement the buffer size
	SOB	R5, 20$		; and always read the entire data block

; Verify the data record checksum ...
	CALL	TURXSM		; receive and verify the checksum
	BCS	10$		; checksum good - read another record
30$:	$RSTMAP			; restore the original mapping mode
	CLC			; checksum (or some other) error
	RETURN			; ...

; Here to check for an END packet ...
40$:	$RSTMAP			; restore the original mapping mode
	JMP	TUREN1		; and read an END packet
	.SBTTL	Write TU58 Tape Data Records

;++
;   This routine will write one or more data records to the TU58 drive.  Except
; for the direction of data transfer the parameter setup is identical to TUREAD.
; If any error occurs we return with carry clear and an error code from the TU58
; in R0.  If the data is read successfully then carry will be set on return.
;
;	<R1 contains the unit number>
;	<R2 contains the block number>
;	<R3 points to the caller's buffer>
;	<R4 contains the count of bytes to write>
;	CALL	TUWRIT
;	<return with C=1 if all is well>
;
;   BTW, you should be sure to call TUINIT before calling this routine!
;--
TUWRIT:	$SAVMAP			; save the current memory mapping mode
	$RAM			; assume the caller's buffer is in RAM
	MOV	#TU$WR, R0	; opcode we want to send
	CALL	TUXCMD		; and transmit a control/command packet

; Try to read a data packet header from the TU58 ...
10$:	CALL	TUGETC		; read the next byte
	BCC	40$		; branch if timeout
	CMPB	#TU.CON, R0	; expect the TU58 to send a CONTINUE
	BNE	40$		; no - that's an error

; Send a data packet to the TU58 ...
	CALL	TUCLSM		; clear the checksum accumulator
	MOVB	#TU.DAT, R0	; send the data packet flag
	CALL	TUPUTC		; ...
	MOV	#128., R5	; assume we'll send 128 bytes
	CMP	R5, R4		; but if fewer bytes remain in 
	BLOS	15$		;  ... the caller's buffer
	MOV	R4, R5		; use that count instead
15$:	SUB	R5, R4		; update the remaining byte count
	MOV	R5, R0		; send the packet byte count
	CALL	TUPUTC		; ...

; Send the bytes in the data packet ...
20$:	MOVB	(R3)+, R0	; get the next data byte
	CALL	TUPUTC		; and send that
	SOB	R5, 20$		; and always read the entire data block

; Transmit the data record checksum ...
	CALL	TUTXSM		; transmit the checksum
	TST	R4		; are there more bytes to send?
	BNE	10$		; yes - go do that
	$RSTMAP			; no - restore the original memory map
	JMP	TUREND		; and the TU58 had better send an END

; Here if there's any error ...
40$:	$RSTMAP			; restore the original mapping mode
	CLC			; return failure
	RETURN			; ...
	.SBTTL	Send TU58 Command Packet

;++
;   This routine will send a command packet (i.e. one where the flag byte is
; TU.CTL, 002) to the drive.  The opcode is passed in R0; the unit and block
; number come from R1, and the length is from R3.  The latter two are exactly
; the same as the calling sequence for TUREAD and TUWRIT routines. The modifier,
; switches and sequence number fields of the command packet will always be zero.
; Since this operation only involves sending data, it can never fail nor timeout
; so there is no returned status.
;
;	<R0 contains the TU58 opcode (e.g.TU$RD, TU$WR, etc)>
;	<R1 contains the unit number>
;	<R2 contains the block number>
;	<R4 contains the byte count>
;	CALL	TUXCMD
;--
TUXCMD:	$PUSH	R0		; save the opcode for a minute
	CALL	TUCLSM		; clear the checksum accumulator
	MOV	#TU.CTL, R0	; this is a "control" packet
	CALL	TUPUTC		; ...
	MOV	#10., R0	; message byte count (always 10)
	CALL	TUPUTC		; ...
	$POP	R0		; get the opcode back
	CALL	TUPUTC		; ... and send that
	CLR	R0		; modifier (not used)
	CALL	TUPUTC		; ...
	MOV	R1, R0		; send the unit number
10$:	CALL	TUPUTC		; ...
	CLR	R0		; ...
	CALL	TUPUTC		; send the switch byte
	CALL	TUPUTW		; and the sequence number
	MOV	R4, R0		; send the byte count
	CALL	TUPUTC		;  ... low byte first
	MOV	R4, R0		; now send the high byte of the count
	SWAB	R0		; ...
	CALL	TUPUTC		; ...
	MOV	R2, R0		; finally send the block number, low byte first
	CALL	TUPUTC		; ...
	MOV	R2, R0		; now the high byte
	SWAB	R0		; ...
	CALL	TUPUTC		; ...
	JMP	TUTXSM		; and lastly send the checksum
	.SBTTL	Receive TU58 END Packet

;++
;   This routine will attempt to receive a control/command packet with the
; opcode END (otherwise known simply as an END packet!).  The TU58 sends one
; of these so signal the end of a data transfer.  Note that the only useful
; information in the END packet is the success code stored in byte 3 - the
; rest of the packet is pro forma and mostly useless.
;
;   If this routine successfully reads an END packet then it will return with
; carry set and the success code in R0.  Note that success codes are typically
; negative numbers and are sign extended to a full 16 bits.  If the next
; packet isn't an END packet, or if there's some error in the end packet, or
; if there's a timeout, then this routine returns with carry cleared. 
;
;	CALL	TUREND
;	<if success return with C=1 and success code in R0>
;
;   Note that there's an alternate entry point at TUREN1 - this assumes that
; the first byte of the packet, whatever it might be, has already been read
; and is in R0.
;--
TUREND:	CALL	TUCLSM		; clear the checksum
	CALL	TUGETC		; and read the next character
	BCC	TUREN2		; branch if timeout
TUREN1:	CMPB	#TU.CTL, R0	; is this a command/control packet?
	BNE	TUREN2		; nope - bad
	CALL	TUGETC		; read the length byte
	BCC	TUREN2		; timeout
	CMPB	#10., R0	; the length is always 10
	BNE	TUREN2		; bad packet
	CALL	TUGETC		; read the opcode
	BCC	TUREN2		; ...
	CMPB	#TU$END, R0	; is this an END packet?
	BNE	TUREN2		; nothing else is allowed here
	CALL	TUGETC		; get the success code
	BCC	TUREN2		; ...
	MOV	R0, R1		; save that for later

; Read a bunch of unused bytes ...
	CALL	TUGETW		; read the unit/not used bytes
	BCC	TUREN2		;  ...
	CALL	TUGETW		; sequence number
	BCC	TUREN2		;  ...
	CALL	TUGETW		; actual byte count
	BCC	TUREN2		;  ...
	CALL	TUGETW		; summary status
	BCC	TUREN2		;  ...

; Verify the checksum and we're done!
	CALL	TURXSM		; read and verify the checksum
	BCC	TUREN2		; branch if bad checksum
	MOVB	R1, R0		; sign extend the success code
	BMI	TUREN2		; failure if negative
	SEC			; and indicate success
	RETURN			; ...

; Here for any error condition ...
TUREN2:	CLC			; return with carry cleared
	RETURN			; ...
	.SBTTL	Initialize TU58 Tape

;++
;   This routine will initialize any TU58 drive attached to the secondary serial
; port SLU1.  If it's successful and the drive responds then it returns with the
; carry set, and if there are any errors or if there's no response from the
; drive then the carry will be cleared.
;
;	CALL	TUINIT
;	<return with C=1 if the drive is ready>
;--
TUINIT:	MOV	#8., R1		; retrun 8 times before giving up
10$:	MOV	#TUBAUD,@#S1XCSR; set the baud rate

; Send a BREAK to the TU58 ...
	BIS	#DL.XBK,@#S1XCSR; force a spacing condition
	MOV	#8., R2		; transmit eight null bytes
15$:	CLR	R0		; ...
	CALL	TUPUT		; ...
	SOB	R2, 15$		; ...
16$:	TSTB	@#S1XCSR	; is the last byte still transmitting?
	BPL	16$		; wait for it to finish
	BIC	#DL.XBK,@#S1XCSR; clear the break condition
	TSTB	@#S1RBUF	; and discard any junk received

;   Send not one but two INIT packets.  Note that the INIT packets are just a
; single byte.  There's no checksum, nothing, else.
	MOV	#TU.INI, R0	; send two <INIT> flag bytes
	CALL	TUPUT		; ...
	CALL	TUPUT		; ...

;   If our friend the TU58 is alive and well, it should send a CONTINUE packet
; as the response.  If we get that now, then great.  If we timeout, then there's
; a problem...
	CALL	TUGET		; read a response
	CMPB	R0, #TU.CON	; is this a CONTINUE?
	BEQ	20$		; yes - success!
	SOB	R1, 10$		; no - go try again
30$:	CLC			; total failure!
	RETURN			; ...

; Here if we succeed at talking to the drive ...
20$:	SEC			; return C=1
	RETURN			; and we're done for now
	.SBTTL	TU58 Input Primitives

;++
;   This routine reads (or at least it tries to) one character from the TU58
; serial port.  If it's successful then it returns the character in R0 and
; the carry set.  If it times out and nothing is read, then it returns the
; carry cleared.
;
;   IMPORTANT - this version does NOT alter the current checksum.  Use TUGETC
; to get a character AND update the checksum calculation.
;
;	CALL	TUGET
;	<if no timeout return character in R0 and with carry set>
;
;   Note that the magic constant for the "SOB R0, ..." loop is calculated such
; that it takes exactly 100ms to expire.  The TUTMO constant specifies the
; number of iterations for that loop...
;--
TUGET:	$PUSH	#TUTMO		; this is the outer timeout loop counter
10$:	MOV	#34.*DLYMS, R0	; and this is the magic constant for 100ms
15$:	TSTB	@#S1RCSR	; have we received anything?
	BPL	20$		; nope - check for timeout
	MOV	@#S1RBUF, R0	; get the byte PLUS any error flags
	BMI	25$		; branch if any error bits are set
	TST	(SP)+		; remove the timeout from the stack
	SEC			; success!
	RETURN			; and we're done
; Here to check for a timeout ...
20$:	SOB	R0, 15$		; count down the inner 100ms timeout
	DEC	(SP)		; decrement the outer counter
	BNE	10$		; not done yet
25$:	TST	(SP)+		; fix the stack
30$:	CLC			; timeout!
	RETURN			; ...


;++
;   This routine calls TUGET and, assuming that's successful, adds the character
; to the current TU58 packet checksum.  
;
;	CALL	TUGET
;	<if no timeout return character in R0 and with carry set>
;
;   Note that the calling sequence for this is exactly the same as TUGET, with
; the side effect of updating the checksum.
;--
TUGETC:	CALL	TUGET		; first get something
	BCC	10$		; and quit now if we failed
	CALL	TUADSM		; update the checksum
	SEC			; return C=1 and data in R0
10$:	RETURN			; and we're done


;++
;   This routine will receive a word from the TU58 by calling TUGETC twice.
; Note that the Tu58 always sends the low order byte first!
;
;	CALL	TUGETW
;	<if no timeout return word in R0 and carry set>
;--
TUGETW:	CALL	TUGETC		; get the first byte
	BCC	15$		; branch if error
	$PUSH	R0		; save the byte for a minute
	CALL	TUGETC		; and get the next one
	BCC	10$		; branch if error
	SWAB	R0		; the second byte is the high byte
	BIS	(SP)+, R0	; put the two bytes together
	SEC			; and return success
	RETURN			; ...
; Here if either read times out ...
10$:	TST	(SP)+		; fix the stack
15$:	CLC			; and return failure
	RETURN			; ...
	.SBTTL	TU58 Output Primitives

;++
;   This routine writes a byte to the TU58 serial port.  It's the complement to
; TUGET but this one's simpler because there's no timeout here.  Like TUGET,
; this DOES NOT update the Tu58 checksum.  Call TUPUTC instead if you want that.
;
;	<character to transmit in R0>
;	CALL	TUPUT
;--
TUPUT:	TSTB	@#S1XCSR	; is the transmitter ready?
	BPL	TUPUT		; no - wait for it
	MOVB	R0, @#S1XBUF	; yes, send this byte now
	RETURN			; ....


;++
; This routine calls TUPUTC and also updates the running TU58 checksum.
;
;	<character to transmit in R0>
;	CALL	TUPUTC
;
;   Note that the calling sequence for this is exactly the same as TUPUT, with
; the side effect of updating the checksum.
;--
TUPUTC:	CALL	TUADSM		; update the checksum
	BR	TUPUT		; and then transmit the character


;++
; This routine transmits a 16 it word from R0, low byte first.
;
;	<word to transmit in R0>
;	CALL	TUPUTW
;--
TUPUTW:	$PUSH	R0		; save the word for a moment
	CALL	TUPUTC		; transmit the low byte first
	$POP	R0		; then get the original word back
	SWAB	R0		; and transmit the high byte last
	BR	TUPUTC		; ...
	.SBTTL	TU58 Checksum Utilities

;++
;   Add the byte in R0 to the running TU58 checksum in TUCKSM.  This is trickier
; than it should be because the TU58 keeps a 16 bit checksum and actually
; checksums PAIRs of bytes rather than individual ones.  Worse, it also uses
; end around carry so carries out of 16 bits are added to the checksum LSB.
;
;	<byte to checksum in R0>
;	CALL	TUADSM
;	<return with R0 unchanged and checksum updated>
;--
TUADSM:	BIC	#^C377, R0	; clear any flags from the UART
	BIT	#S.ODDB, SFLAGS	; is this an odd byte?
	BEQ	10$		; no - add to the checksum LSB
; Here for an odd byte - add to the checksum MSB ...
	SWAB	R0		; put the byte on the left
	ADD	R0, TUCKSM	; update the checksum
	ADC	TUCKSM		; with end around carry
	SWAB	R0		; restore the original character
	BIC	#S.ODDB, SFLAGS	; do the low byte next time around
	RETURN			; all done
; Here for an even byte - add to the checksum LSB ...
10$:	ADD	R0, TUCKSM	; update the low byte of the checksum
	ADC	TUCKSM		; ...
	BIS	#S.ODDB, SFLAGS	; do the high byte next time around
	RETURN			; that's it


;++
; Clear the TU58 checksum accumulator ...
;--
TUCLSM:	CLR	TUCKSM		; zero the accumulator
	BIC	#S.ODDB, SFLAGS	; and clear the odd byte flag
	RETURN			; that's all we need


;++
; Transmit the curreent TU58 checksum (presumably as part of a packet) ...
;--
TUTXSM:	MOV	TUCKSM, R0	; send the low byte first
	CALL	TUPUT		; NOT TUPUTC!
	MOV	TUCKSM, R0	; now sent the high byte
	SWAB	R0		; ...
	JMP	TUPUT		; ...


;++
;   This routine will receive two bytes from the TU58 and compare them to the
; current checksum.  If they match then it returns with the carry set, and if
; they don't match then it returns with the carry clear.  Note that we can't
; use TUGETW or TUGETC here because that would alter the current checksum!
;
;	CALL	TURXSM
;	<return C=1 if checksum matches>
;--
TURXSM:	CALL	TUGET		; receive a byte
	BCC	10$		; branch if timeout
	CMPB	R0, TUCKSM	; check the low byte first
	BNE	10$		; doesn't match!
	CALL	TUGET		; now get the high byte
	BCC	10$		; branch if timeout
	CMPB	R0, TUCKSM+1	; now cmpare the high byte
	BNE	10$		; again, branch if they don't match
	SEC			; return success
	RETURN			;
; Here if the checksum doesn't match ...
10$:	CLC			; be sure the carry is clear
	RETURN			; to signal failure
	.SBTTL	Read Time of Day Clock

;++
;   This routine will read the DS12887 RTC and return the current date and time
; packed into a seven byte buffer provided by the caller.  On return the seven
; bytes in the caller's buffer will be -
;
;	BUFFER/	hours		- based on a 24 hour clock
;		minutes		- 0..59
;		seconds		- 0..59
;		day		- 1..31
;		month		- 1..12 (1 == JANUARY!)
;		year		- 0..99 
;		day of week	- 1..7 (1 == SUNDAY!)
;
;   Note that all values are returned in pure binary, not BCD.  And the year is
; simply a two digit value from 0 thru 99 - it's up to you to figure out how you
; want to handle Y2K.
;
;   If all is well, the carry flag will be set on return.  If the DS12887 is not
; installed or if the time has not been set, then carry will be cleared and the
; results are indeterminate.
;
;	<R3 points to the buffer>
;	CALL	GETTOD
;	<return with carry set if all is well; uses R1 and R2>
;--
GETTOD:	BIT	#H.RTCC, HFLAGS	; is the DS12887 even installed?
	BNE	GETTO1		; yes - keep going
NORTC:	CLC			; no clock - return carry cleared
	RETURN			; and give up

;   First, make sure that 1) the clock is running and that 2) the 24 hour and
; binary mode bits are set.  If this code has previously set the date/time then
; these conditions will both be true.  Note that you can't really change these
; bits while the clock is running (it will cause anomalies in the count if you
; do) - you have to first set the mode bits and then set the time, and that's
; why we don't just change them here.
GETTO1:	$RDNVR	#RTC.A, R1	; first read register A
	BIC	#^C<RT.DVM>, R1	; we're only interested in the oscillator bits
	CMP	#RT.DV1, R1	; is the oscillator running?
	BNE	NORTC		; no - give up
	MOV	#RTC.B, R2	; next read register B
	BIT	#RT.24H, R1	; make sure the 24 hour bit is set
	BNE	NORTC		; ...
	BIT	#RT.DM, R1	; and the binary mode bit
	BNE	NORTC		; ..

;   Looks like the clock is running. Now we have to be careful about _when_ we
; read the clock.  Remember, the RTC hardware potentially changes the seconds,
; minutes, hours, day, month and year registers any time the clock ticks (i.e.
; at 23:59:59 on the last day of the year, all these bytes will change on the
; next tick!).  If the clock just happens to tick while we're in the middle of
; reading it, then the date/time we assemble can be off by a minute, an hour,
; or even a year if we're unlucky!  You might think this is unlikely to happen,
; and I admit that it is, but once upon a time I was personally involved in
; fixing a bug in an embedded system caused by just this situation!  It DOES
; happen...  Fortunately for us, the DS1287 designers thought of this and they
; provided us with a bit, UIP, to signal that an update coming soon.  As long
; as UIP=0 we're guaranteed at least 244us before an update occurs.
20$:	$RDNVR	#RTC.A, R1	; UIP is in register A
        BIT	#RT.UIP, R1	; wait for UIP to be clear
	BNE	20$		; ...

; Ok, we're safe...  Read the clock...
	$PUSH	R3		; save the original buffer pointer
	$RDNVR	#RTC.HR, (R3)+	; the hours
	$RDNVR	#RTC.MN, (R3)+	; and minutes
	$RDNVR	#RTC.SC, (R3)+	; lastly the seconds
	$RDNVR	#RTC.DY, (R3)+	; then the day
	$RDNVR	#RTC.MO, (R3)+	; and the month
	$RDNVR	#RTC.YR, (R3)+	; and the year
	$RDNVR	#RTC.DW, (R3)+	; and lastly the day of the week

; All done!
	$NONVR			; done using the RTC for now
	$POP	R3		; restore the buffer pointer
	SEC			; return carry set for success
	RETURN			; ...
	.SBTTL	Set Time of Day Clock

;++
;   This routine will set the DS12887 time of day clock.  The caller is expected
; to pass the address of a seven byte buffer containing the current hours, 
; minutes, seconds, day, month, year, and day of week.  These bytes are in the
; same order and have the same format as the GETTOD routine, so refer to that
; for more information.
;
;   It returns with carry set if all is well, and carry cleared if the clock
; chip is not installed.
;
;	<R3 points to the buffer>
;	CALL	SETTOD
;	<return with carry set if all is well; uses R1 and R2>
;--
SETTOD:	BIT	#H.RTCC, HFLAGS	; is the DS12887 even installed?
	BEQ	NORTC		; yes - keep going

;   The RTC ships from the factory with the clock turned off, which extends the
; shelf life of the lithium cell.  Before setting the clock, let's turn on the
; oscillator so that it will actually keep time!  If the oscillator is already
; on, this will do no harm...
10$:	$WRNVR	#RT.DV1, #RTC.A	; set the DV1 bit in register A
				;  ... to turn on the oscillator

;   Now set the SET bit, which inhibits the clock from counting.  This prevents
; it from accidentally rolling over while we're in the middle of updating the
; registers!  At the same time, select 24 hour mode, binary (not BCD) mode, and
; enable daylight savings time.  The latter choice is debatable since the chip
; only knows the DST rules for the USA, and not even all parts of the USA
; observe DST to start with.  Still, it works for most customers!
	$WRNVR	#RT.SET!RT.DM!RT.24H, #RTC.B	; set SET, DM, and 24hr

;   Now load the clock registers.  Note that there is no error checking on the
; values - if the caller gives bogus values then the count could be anything!
	$PUSH	R3		; save the original buffer pointer
	$WRNVR	(R3)+, #RTC.HR	; set the hours
	$WRNVR	(R3)+, #RTC.MN	; set the minutes
	$WRNVR	(R3)+, #RTC.SC	; set the seconds
	$WRNVR	(R3)+, #RTC.DY	; set the day
	$WRNVR	(R3)+, #RTC.MO	; set the month
	$WRNVR	(R3)+, #RTC.YR	; set the year
	$WRNVR	(R3)+, #RTC.DW	; set the weekday

; Clear the SET bit to allow the clock to run, and we're done!
	$WRNVR	#RT.DM!RT.24H!RT.DSE, #RTC.B	; set DM, 24HR and DSE
	$NONVR			; done using the NVR for now
	$POP	R3		; restore the original buffer pointer
	SEC			; return success	
	RETURN			; and we're done
	.SBTTL	Type Octal and Decimal Numbers

;++
;   Type the value in R1 as a six digit octal number.  Notice that there's a
; tiny trick here - the digits are typed left to right and the first digit is
; always only a single bit.  All the subsequent digits are three digits
;
;	<R1 contains the value to type>
;	CALL	TOCTW
;	<uses R0 and R1>
;--
TOCTW:	$PUSH	R2		; preserve R2
	MOV	#6, R2		; count of digits to be printed
	CLR	R0		; make sure there are no extra bits around
TOCT1:	ROL	R1		; copy a bit from R1 to R0
	ROL	R0		; ...
	CALL	TDIGIT		; type that digit
	CLR	R0		; do three bits every time after the first
	ROL	R1		; ...
	ROL	R0		; ...
	ROL	R1		; ...
	ROL	R0		; ...
	SOB	R2, TOCT1		; and do all six digits
	$POP	R2		; restore R2
	RETURN			; and we're done!


;++
;   Type the low byte of R1 as three digit octal number.  This tries to share
; some code with TOCTW, but it's not clear that it's worth the trouble!
;
;	<R1 contains the byte to type>
;	CALL	TOCTB
;	<uses R0 and R1>
;--
TOCTB:	$PUSH	R2		; preserve R2
	MOV	#3, R2		; count of digits to be printed
	SWAB	R1		; put the byte we want on the left
	CLR	R0		; make sure there are no extra bits around
	ROL	R1		; this time we need to do TWO bits the
	ROL	R0		;  ... first time around
	BR	TOCT1		; and join the common code


;++
;   Type a 16 bit, SIGNED, decimal number from R1.  Note that only a "-" sign
; is typed when the number is negative - no "+" is ever printed.
;
;   The TDECU entry is identical, except that it types an UNSIGNED value ...
;
;	<R1 contains the value to type>
;	CALL	TDECW/U
;	<uses R0, R1 and R2>
;
;   Sadly, the T11 doesn't have the DIV instruction, so we'll have to do this
; the hard way!
;--
TDECW:	TST	R1		; is the value negative?
	BGE	TDECU		; branch if not
	$TYPE	'-		; we know what to say
	NEG	R1		; and then print the absolute value
TDECU:	MOV	#10., R2	; divide by 10
	CALL	DIV16		; ...
	$PUSH	R0		; save the remainder for a minute
	TST	R1		; and are there any digits left?
	BEQ	20$		; nope - start printing them
	CALL	TDECU		; yes - print those now
20$:	$POP	R0		; get our digit back
	JMP	TDIGIT		; print it and return 


;++
;   Type an unsigned decimal number with at least two digits, printing a
; leading zero if necessary.  This is used for printing the date and time,
; where you want a leading zero (e.g. 21:00:00, not 21:0:0!)...
;
;	<R1 contains the value to type>
;	CALL	TDEC2
;	<uses R0, R1 and R2>
;--
TDEC2:	CMP	#10., R1	; do we need a leading zero?
	BLOS	TDECU		; no - just type it as-is
	$TYPE	'0		; yes - type a leading zero
	BR	TDECU		; then finish up
	.SBTTL	Type ASCII Strings

;++
;   OUTSTR prints an ASCIZ (ASCII, null temrinated) string on the console.  The
; address of the string is passed in R1, and it prints characters until a null
; is found.  On return R1 points to the end of the string (that's important for
; INLMES!).
;
;	<R1 contains the address of an ASCIZ string>
;	CALL	OUTSTR
;	<return with R1 pointing to the EOS>
;
;  NOTE - a subtle but critical behavior of this routine is that if the string
; pointer is null, then it returns w/o doing anything.  Some of the other code
; depends on this!
;--
OUTSTR:	TST	R1		; is there really a string?
	BEQ	20$		; nope - just quit now
10$:	MOVB	(R1)+, R0	; fetch the next byte
	BEQ	20$		; branch if EOS
	CALL	OUTCHR		; nope - print this one
	BR	10$		; and keep going
20$:	RETURN			; here for the end of the string


;++
;   INLMES will type an ASCIZ message "in line".  For example -
;
;	JSR	R1, INLMES
;	.ASCIZ	/test message/
;	.EVEN
;	... control returns here ...
;
;   Given the way the JSR instruction works, this is pretty simple.  The only
; tricky bit comes when the string has an odd number of characters.
;
;   BTW, the $MSG macro is handy for generating calls to INLMES!
;--
INLMES:	CALL	OUTSTR		; first print the string
	BIT	#1, R1		; is the result odd?
	BEQ	10$		; return if not
	INC	R1		; otherwise skip over the odd byte
10$:	RTS	R1		; and return
	.SBTTL	Type Various Special Characters

;++
; Type a space character ...
;--
TSPACE:	MOV	#' , R0		; type a space
	BR	OUTCHR		; ...

;++
; Convert the value in R0 to a decimal digit and type it...
;--
TDIGIT:	ADD	#'0, R0		; convert to ASCII
	BR	OUTCHR		; and type that

;++
; Type a carriage return/line feed ...
;--
TCRLF:	MOV	#CH.CRT, R0	; carriage return first
	CALL	OUTCHR		; ...
	MOV	#CH.LFD, R0	; then a line feed
	BR	OUTCHR		; ...

;++
; Type a backspace, space, and another backspace to erase the last character.
;--
TERASE:	MOV	#CH.BSP, R0	; backup the cursor
	CALL	OUTCHR	 	; ...
	MOV	#' , R0		; erase the last character
	CALL	OUTCHR		; ...
	MOV	#CH.BSP, R0	; and then backup again
	BR	OUTCHR	 	; ...

;++
; Type 2 characters from R0 - low byte then high byte ...
;--
T2CHAR:	$PUSH	R0		; save the high byte
	CALL	TFCHAR		; type the low byte first
	$POP	R0		; restore the character
	SWAB	R0		; and type the high byte last
	JMP	TFCHAR		; ...
	.SBTTL	Console Terminal Output

;++
;   TFCHAR will type a potentially "funny" character on the console.  If the
; character is a normal printing character then it's printed as-is.  If the
; character happens to be a DELETE or NULL (ASCII codes 000 or 177), then it's
; ignored.  If the character is any of TAB (011), BELL (007), carriage return
; (015), or line feed (012) then it will be sent to the console as-is.  The
; escape character (033) is printed as a "$".  Any other control character will
; be converted to the familiar ^x representation.  And regardless of what is
; actually printed, the original character is always returned in R0 unchanged.
;
;	<character to type in R0>
;	CALL	TFCHAR
;	<return with R0 unchanged>
;--
TFCHAR:	$PUSH	R0		; save the original character
	BIC	#^C177, R0	; then trim it to 8 bits
	BEQ	91$		; if it's a null, just return now
	CMPB	#CH.DEL, R0	; or is it a delete?
	BEQ	91$		; yes - ignore that too
	CMPB	#CH.TAB, R0	; is it a tab?
	BEQ	90$	 	; yes - type it as-is and return
	CMPB	#CH.CRT, R0	; same for carriage return?
	BEQ	90$	 	; ...
	CMPB	#CH.LFD, R0	; and line feed ?
	BEQ	90$	 	; ...
;;	CMPB	#CH.BEL, R0	; and bell?
;;	BEQ	90$	 	; ...
;;	CMPB	#CH.BSP, R0	; and backspace?
;;	BEQ	90$		; ...
	CMPB	#CH.ESC, R0	; what about escape?
	BNE	20$	 	; nope
	MOV	#'$, R0		; yes - for escape
	BR	90$  		;  ... print "$" instead
20$:	CMPB	R0, #40		; is it a printing character?
	BHIS	90$		; yes - print it as-is
	MOV	#'^, R0		; it's a control character
	CALL	OUTCHR		;  ... so print it as ^x
	MOV	(SP), R0	; get the original value back
	ADD	#'@, R0		; convert it to a letter and print
90$:	CALL	OUTCHR		; print it as-is
91$:	$POP	R0		; restore the original character
	RETURN			; and we're done


;++
;   OUTCHR will send an ASCII character to the console terminal.  It first polls
; the console for input to see if ^C, ^O, ^S or ^Q has been typed; any other
; input will be ignored.  If the S.CTLO (Control-O) flag is set then we'll just
; return immediately without typing anything.  If the S.XOFF (Control-S) flag
; is set, then we'll spin here (polling input the whole time) waiting for a
; Control-Q.  If none of those conditions are true then we'll type the original
; character and return.
;
;	<character to type in R0>
;	CALL	OUTCHR
;	<return with R0 unchanged>
;--
OUTCHR:	$PUSH	R0		; save the character for a while
10$:	CALL	INCHRS		; poll the operator for input
	BIT	#S.CTLO, SFLAGS	; test the Control-O flag bit
	BNE	30$		;  ... set - just throw this character away
	BIT	#S.XOFF, SFLAGS	; now test the XOFF flag
	BNE	10$		; if it's set then wait for XON
20$:	MOV	(SP), R0	; get the character back
	BIC	#^C177, R0	; always trim it to only 8 bits
	CALL	CONPUT		; and type it
30$:	$POP	R0		; always return with R0 unchanged
	RETURN			; and we're done
	.SBTTL	Console Terminal Primitives

;++
;   This routine will initialize the console serial port.  It clears both
; interrupt enable bits, clears the receiver buffer and, if the programmable
; baud rate is enabled, initializes the baud rate.
;
;   At the moment this is all hardwired and not super useful, but at some
; point we might want to allow the console baud rate to be set in software and
; stored in NVR, and then there might be a little more to do.
;--
CONINI:	TST	@#S0RBUF		; discard anything in the buffer
	CLR	@#S0XBUF		; ...
	MOV	#DL9600!DL.PBE, #S0XCSR	; set the baud rate if enabled
	CLR	@#S0RCSR		; and clear the receiver IE
;   If someone has just asserted the INIT input (a RESET instruction would do
; it!) then the DLART needs a moment to recover.  It's not clear exactly how
; long, but the following little loop seems to be enough.
	CLR	R0			; ...
	SOB	R0, .			; ...
	RETURN				; that's all


;++
;   CONGET tries to read a character from the console terminal.  It never waits
; if no character is available, and it never echos any characters read.  It
; always returns all 8 bits and is safe for reading binary data (e.g. paper
; tape images).
;
;	CALL	CONGET
;	<return with character in R0 and carry set, or carry clear if no data>
;--
CONGET:	CLC			; assume nothing there
	TSTB	@#S0RCSR	; but is there any input waiting?
	BPL	10$		; nope
	MOV	@#S0RBUF, R0	; get the character including flags
	SEC		  	; and return with carry set
10$:	RETURN			; ...


;++
;   CONWAI waits for the console transmitter to be idle before returning.  This
; is used to be sure the DLART is finished sending the last character before
; asserting BCLR or starting a user program.
;
;	CALL	CONWAI
;	<return here when console transmitter is idle>
;--
CONWAI:	TSTB	@#S0XCSR	; is it idle now?
	BPL	CONWAI		; no - wait for it
	RETURN			; that's all there is to it


;++
;   CONPUT will send an 8 bit character to the console terminal with no special
; processing of any kind.  It's binary safe (say, for punching paper tapes) and
; doesn't check either the XOFF nor the Control-O flags.  If the console DLART
; is currently busy sending then it will wait for the transmitter to finish.
;
;	<character to send in R0>
;	CALL	CONPUT
;	<return with R0 unchanged>
;--
CONPUT:	CALL	CONWAI		; wait for the transmitter to be idle
	MOVB	R0, @#S0XBUF	; and print the next character
	RETURN			; we're done ...
	.SBTTL	Multiply and Divide

;++
;   Sadly, the T11 has no hardware MUL nor DIV instruction so here are two
; simple substitutes.  All of them operate on 16 bit UNSIGNED values.
;
;   DIV16 does an unsigned division of R1/R2.  The quotient is returned in R1
; and the remainder in R0.  R2 is destroyed.  The behavior when R2 is zero is
; undefined (currently it'll return 177777 as the quotient and the original
; dividend as the remainder!).  As long as it doesn't hang up for divide by
; zero, I figure anything goes ...
;
;   MUL16 computes an unsigned 16 bit product of R1*R2.  The product is returned
; in R1, and both R2 and R0 are destroyed.  Overflow beyond 16 bits is not
; detected and any overflow bits are lost.
;
;   These are the classic long division and multiplication algorithms, just like
; you learned in grade school.  They're not especially efficient, but they're
; simple and they work.
;--

; 16x16 unsigned multiply of R1 * R2 -> R1.  R0 destroyed ...
MUL16:	CLR	R0		; accumulate the product here
10$:	CLC			; be sure the carry is cleared
	ROR	R2		; and then shift the multiplier right
	BCC	20$		; skip the add if the multipler LSB was zero
	ADD	R1, R0		; add the multiplicand to the result
20$:	CLC			; shift the multiplicand left for next time
	ROL	R1		; ...
	TST	R2		; we can quit when the multiplier is zero
	BNE	10$		; nope - keep going
	MOV	R0, R1		; transfer the result to R1
	RETURN			; and we're done


; 16x16 unsigned divide of R1 / R2 -> R1, remainder in R0 ...
DIV16:	MOV	#17., -(SP)	; keep a loop counter on the stack
	CLR	R0		; clear the remainder
	CLC			; ... and the first quotient bit
30$:	ROL	R1		; shift dividend MSB -> C, C -> quotient LSB
	DEC	(SP)		; decrement the loop counter
	BEQ	50$		; we're done when it reaches zero
	ROL	R0		; shift dividend MSB into remainder
	SUB	R2, R0		; and try to subtract
	BLT	40$		; if it doesn't fit, then restore
	SEC			; it fits - shift a 1 into the quotient
	BR	30$		; and keep dividing
40$:	ADD	R2, R0		; divisor didn't fit - restore remainder
	CLC			; and shift a 0 into the quotient
	BR	30$		; and keep dividing
50$:	TST	(SP)+		; fix the stack
60$:	RETURN			; and we're done
	.SBTTL	End of SBCT11 ROM Monitor

FREE3=ROMTOP-.+1
	.IF	LT, FREE3
	.ERROR	FREE3 ; CODE EXCEEDS UNMAPPED ROM SPACE
	.ENDC

	.END	START1
