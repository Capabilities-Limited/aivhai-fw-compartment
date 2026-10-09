/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2026 Capabilities Limited
 *
 * This software/hardware was developed in part by Capabilities Limited, lowRISC CIC,
 * Sigil Logic Inc., and Cherified Systems LLC under Advanced Research and Invention
 * Agency (ARIA) Contract MSAI-PR01-P060, "AI Verified Hardware for AI (AIVHAI)".
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#define STR_IMPL(x) #x
#define STR(x) STR_IMPL(x)

#define CSR_MSECCFG     0x747
#define CSR_MIE         0x304
#define MSECCFG_CRE     (1 << 3)

.section .data
.balign 64
.globl tohost
.type tohost, %object
tohost:
    .dword 0
.size tohost, . - tohost

.balign 64
.globl fromhost
.type fromhost, %object
fromhost:
    .dword 0
.size fromhost, . - fromhost

.balign 16
.globl cheri_infinite_cap
.type  cheri_infinite_cap, %object
cheri_infinite_cap:
	.chericap 0x0
.size cheri_infinite_cap, . - cheri_infinite_cap

## An asset to try to attack/reach from _within_ a compartment
.balign 8
.globl write_var
write_var: .long 0xcacacaca
.balign 8
.globl read_var
read_var: .long 0xcbcbcbcb

.section .entry, "ax", %progbits
.globl _start
_start:
	/* Enable the capability instructions */
	csrs CSR_MSECCFG, MSECCFG_CRE

	/* Switch to capability mode */
	ymodeswy

	/* Initialize the ca3 as infinite capability */
	auipc   a3, 0
	yaddrw  a3, a3, zero

	lly     t0, cheri_infinite_cap
	sy      a3, 0(t0)

	j       compartment_setup

# -------------------- Compartmentlaisation-related bits ---------------- #
######################################################################### #
## Compartment exception handling
.balign 4
.globl compartment_trap
compartment_trap:
	wfi
	j compartment_trap
######################################################################### #

######################################################################### #
## Compartment bootstrapping and setup before first entry
.globl compartment_setup
compartment_setup:
###1 Disable interrupts
	csrw  CSR_MIE, zero

###2 Setup mtvec
	lly   t0, compartment_trap
	csrw  mtvec, t0

###3 Setup PCC
	# Load PCC
	lly    t0, cheri_infinite_cap
	ly     t0, 0(t0)

	lly t2, compartment_enter
	lly t1, compartment_end
	sub t1, t1, t2

	yaddrw t0, t0, t2
#if defined(AIVHAI_VULN_BOUNDS)
	ymv    t1, t0
#else
	ybndsw t1, t0, t1
#endif

#if !defined(AIVHAI_VULN_ASR)
	# Strip ASR permission
	li t0, __CHERI_CAP_PERMISSION_ACCESS_SYSTEM_REGISTERS__
	ypermc t1, t1, t0
#endif

	ymv ra, t1

#if !defined(AIVHAI_VULN_REGS_TEMP)
###4 clear all registers
	/* flush the instruction cache */
	fence.i
	li sp, 0
	li gp, 0
	li tp, 0
	li t0, 0
	li t1, 0
	li t2, 0
	li s0, 0
	li s1, 0
	li a0, 0
	li a1, 0
	li a2, 0
	li a3, 0
	li a4, 0
	li a5, 0
	li a6, 0
	li a7, 0
	li s2, 0
	li s3, 0
	li s4, 0
	li s5, 0
	li s6, 0
	li s7, 0
	li s8, 0
	li s9, 0
	li s10, 0
	li s11, 0
	li t3, 0
	li t4, 0
	li t5, 0
	li t6, 0
	csrw mscratch, c0
	csrw mepc, c0
	csrw mtidc, c0
	csrw sepc, c0
	csrw stvec, c0
	csrw sscratch, c0
	csrw stidc, c0
	csrw utidc, c0
#endif

#if !defined(AIVHAI_VULN_DDC)
	csrw ddc, c0
#endif

###5 Jump to a compartment
	########################################################################
	# Jump to the compartment
	# After this point, a compartment is entered, take extra care
  #######################################################################$
	jalr ra

###6 Compartment return without exceptions
compartment_return:
	wfi
	j compartment_return

## Actual compartment content (ELF/bin, code, data, etc)
.section .compartment_bits, "awx", %progbits
.balign 1024*1024
.globl compartment_enter
compartment_enter:
#ifndef FW_COMPARTMENT_PATH
	wfi
	j	compartment_enter
#else
	.incbin STR(FW_COMPARTMENT_PATH)
#endif
.balign 1024*1024
compartment_end:
.size compartment_enter, . -compartment_enter
# -------------------- Compartmentlaisation-related bits ---------------- #
