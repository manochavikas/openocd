/***************************************************************************
 *   Copyright (C) 2010 by Spencer Oliver                                  *
 *   spen@spen-soft.co.uk                                                  *
 *                                                                         *
 *   Copyright (C) 2011 Øyvind Harboe                                      *
 *   oyvind.harboe@zylin.com                                               *
 *                                                                         *
 *   Copyright (C) 2015 Uwe Bonnes                                         *
 *   bon@elektron.ikp.physik.tu-darmstadt.de                               *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.                                        *
 ***************************************************************************/

	.text
	.syntax unified
	.cpu cortex-m0
	.thumb
	.thumb_func

/* To assemble:
 * arm-none-eabi-gcc -c stm32l4x.S
 *
 * To disassemble:
 * arm-none-eabi-objdump -o stm32l4x.o
 *
 * To generate binary file:
 * arm-none-eabi-objcopy -O binary stm32l4x.o stm32l4_flash_write_code.bin
 *
 * To generate include file:
 * xxd -i stm32l4_flash_write_code.bin
 */

/*
 * Params :
 * r0 = workarea start, status (out)
 * r1 = workarea end
 * r2 = target address
 * r3 = count (64bit words)
 * r4 = flash base
 *
 * Clobbered:
 * r5   - rp
 * r6/7 - temp (64-bit)
 * r8   - wp, tmp
 */

#define STM32_FLASH_CR_OFFSET	0x14	/* offset of CR register in FLASH struct */
#define STM32_FLASH_SR_OFFSET	0x10	/* offset of SR register in FLASH struct */

wait_fifo:
	ldr 	r7, [r0, #0]	/* read wp */
	cmp 	r7, #0		/* abort if wp == 0 */
	beq 	exit
	ldr 	r5, [r0, #4]	/* read rp */
	subs	r6, r7, r5	/* number of bytes available for read in r6*/
	cmp 	r6, #8		/* wait until 8 bytes are available */
	bcc 	wait_fifo

	movs	r6, #0x1
	str	r6, [r4, #STM32_FLASH_CR_OFFSET]

	ldr 	r6, [r5]	/* read one word from src, increment ptr */
	ldr 	r7, [r5, #4]	/* read one word from src, increment ptr */
	str 	r6, [r2]	/* write one word to dst, increment ptr */
	str 	r7, [r2, #4]	/* write one word to dst, increment ptr */
	adds	r5, #8
	adds	r2, #8
	dsb
busy:
	ldr 	r6, [r4, #STM32_FLASH_SR_OFFSET]
	movs	r7, #16
	lsrs	r6, r7
	movs 	r7, #0x1	/* BSY (bit16) == 1 => operation in progress */
	tst	r6,r7
	bne 	busy		/* wait more... */
	movs	r7, #0xfa	/* PGSERR | PGPERR | PGAERR | WRPERR | PROGERR*/
	tst	r6,r7
	bne	error		/* fail... */

	cmp 	r5, r1		/* wrap rp at end of buffer */
	bcc	no_wrap
	mov	r5, r0
	adds	r5, #8	/* skip loader args */
no_wrap:
	str 	r5, [r0, #4]	/* store rp */
	subs	r3, r3, #1	/* decrement dword count */
	cmp	r3, #0
	beq	exit	/* loop if not done */
	b	wait_fifo
error:
	movs	r1, #0
	str	r1, [r0, #4]	/* set rp = 0 on error */
exit:
	mov	r0, r6		/* return status in r0 */
	bkpt	#0x00

STM32_PROG: .word 0x1 	/* PG */
