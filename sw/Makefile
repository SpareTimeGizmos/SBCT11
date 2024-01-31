#++
# Makefile - Makefile for the Spare Time Gizmos' SBCT11 EPROM
#
# Copyright (C) 2006 by Spare Time Gizmos.  All rights reserved.
#
# This firmware is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA
#
#DESCRIPTION:
#   This Makefile will build the Spare Time Gizmos SBCT11 EPROM image from
# the PALX source file.  The result is three (yes, three!) files, low.hex,
# high.hex, and boots11.hex.  low.hex and high.hex are the 16 bit versions
# for the low byte and high byte 32K EPROMs, respectively.  boots11.hex is the
# single 64K EPROM version for eight bit systems.
#
#TARGETS:
#  make all	- rebuild low.hex, high.hex, boots11.hex
#  make clean	- clean up all generated files _except_ the .hex files
#
# REVISION HISTORY:
# dd-mmm-yy	who     description
# 31-Jan-24	RLA	New file.
#--

# Tool paths and options - you can change these as necessary...
MACRO=/usr/local/bin/macro11
MACOPTS=-RT11
OBJ2ROM=/usr/local/bin/tools/obj2rom
ROMOPTS=-o000000 -c170000 
DATE=/usr/bin/date
DTFORMAT="	.ASCIZ	\\%H:%M %d-%^b-%Y\\"
ECHO=/usr/bin/echo
RM=/usr/bin/rm

# The default target builds everything...
all:	low.hex high.hex boots11.hex

boots11.obj:	boots11.asm
	@$(ECHO) -e "\nAssembling SBCT11 Bootstrap ..."
	@$(RM) -f sysdat.asm
	@$(DATE) -r boots11.asm +$(DTFORMAT) >sysdat.asm
	$(MACRO) $(MACOPTS) $< -l $(@:.obj=.lst) -o $@

low.hex high.hex boots11.hex &:	boots11.obj
	@$(ECHO) -e "\nBuilding EPROM images ..."
	$(OBJ2ROM) -s32768 $(ROMOPTS) $< low.hex high.hex
	$(OBJ2ROM) -8 -s65536 $(ROMOPTS) $< boots11.hex


# The "clean" target does what you'd expect...
clean:
	$(RM) -f boots11.lst boots11.obj sysdat.asm
	$(RM) -f *.*\~ \#*.*\#
