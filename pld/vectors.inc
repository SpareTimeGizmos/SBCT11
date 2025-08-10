/*++									*/
/* vectors.pld - Spare Time Gizmos DCT11 interrupt vector definitions	*/
/*									*/
/*   Copyright (C) 2021 by Robert Armstrong, Milpitas, California.	*/
/*									*/
/*  This program is free software; you can redistribute it and/or	*/
/* modify it under the terms of the GNU General Public License as	*/
/* published by the Free Software Foundation; either version 2 of the	*/
/* License, or (at your option) any later version.			*/
/*									*/
/*  This program is distributed in the hope that it will be useful, but	*/
/* WITHOUT ANY WARRANTY; without even the implied warranty of		*/
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU	*/
/* General Public License for more details.				*/
/*									*/
/*   You should have received a copy of the GNU General Public License	*/
/* along with this program; if not, write to the Free Software		*/
/* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.	*/
/*                                                                      */
/* DESCRIPTION								*/
/*   These are the CP codes used by the DCT11 for various interrupt	*/
/* vectors.  The same codes are issued on DAL8..11 during IACK cycles.	*/
/*									*/
/* REVISION HISTORY							*/
/* 23-FEB-21	RLA	New file.					*/
/*--									*/

/*   IMPORTANT - If you read the DCT11 datasheet, these values will all	*/
/* appear inverted.  That's because the CPx lines are active low and 	*/
/* the data sheet is showing the actual state of the pin, not the	*/
/* logical signal state.  Since CUPL handles inverting the outputs for	*/
/* us, we want the "correct" polarity here.				*/
$define VECNONE	'B'0000
$define VEC070	'B'0001	/* IDE/ATA disk */
$define VEC064	'B'0010	/* SLU0 transmit */
$define VEC060	'B'0011	/* SLU0 receive */
$define VEC134	'B'0100	/* spare *
$define VEC130	'B'0101	/* PPI */
$define VEC124	'B'0110	/* SLU1 transmit */
$define VEC120	'B'0111	/* SLU1 receive */
$define VEC114	'B'1000
$define VEC110	'B'1001
$define VEC104	'B'1010
$define VEC100	'B'1011	/* LTC */
$define VEC154	'B'1100
$define VEC150	'B'1101
$define VEC144	'B'1110
$define VEC140	'B'1111
