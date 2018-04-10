#include "soc/rtc_cntl_reg.h"
#include "soc/rtc_io_reg.h"
#include "soc/soc_ulp.h"

#include "stack.S"

/* RTC_GPIO_9 maps to GPIO 32 */
.macro GPIO_read
	READ_RTC_REG(RTC_GPIO_IN_REG, RTC_GPIO_IN_NEXT_S + 9, 1)
.endm

/* Set pin high-impedance state (input mode) */
/* high imedance pin has an indeterminate state. it is nether high or low which is also commonly referred as "floating" or "tri-stated". To set it to high or low, it has to be driven by an external source */
.macro GPIO_H
	WRITE_RTC_REG(RTC_GPIO_ENABLE_W1TC_REG, RTC_GPIO_ENABLE_W1TC_S + 9, 1, 1)
.endm

/* Output mode */
.macro GPIO_L
	WRITE_RTC_REG(RTC_GPIO_ENABLE_W1TS_REG, RTC_GPIO_ENABLE_W1TS_S + 9, 1, 1)
.endm

/* These two marco for set bus high and set low when GPIO_L is called, enable W1TS. */
.macro GPIO_high
	WRITE_RTC_REG(RTC_GPIO_OUT_W1TS_REG, RTC_GPIO_OUT_DATA_W1TS_S + 9, 1, 1)
.endm

.macro GPIO_low
	WRITE_RTC_REG(RTC_GPIO_OUT_W1TC_REG, RTC_GPIO_OUT_DATA_W1TC_S + 9, 1, 1)
.endm


	/* Define variables, which go into .bss section (zero-initialized data) */
	.bss
	.global stack
stack:
	.skip 24
	.global stackEnd
stackEnd:
	.long 0

	.global temperatureC
temperatureC:
	.long 0
	
	.global temperatureF
temperatureF:
	.long 0

	.global romID 
romID:	
	.long 0		// Byte 0: 
	.long 0		// Byte 1: 
	.long 0		// Byte 2: 
	.long 0		// Byte 3: 
	.long 0 	// Byte 4: 
	.long 0		// Byte 5: 
	.long 0		// Byte 6: 
	.long 0		// Byte 7: 

	.global romID1
romID1:
	.long 0		// Byte 0: 
	.long 0		// Byte 1: 
	.long 0		// Byte 2: 
	.long 0		// Byte 3: 
	.long 0 	// Byte 4: 
	.long 0		// Byte 5: 
	.long 0		// Byte 6: 
	.long 0		// Byte 7: 

	.global discrepmarker
discrepmarker:
	.long 0

	.global bit_index
bit_index:
	.long 0
	
	.global byte_index
byte_index:
	.long 0

	.global bit_mask
bit_mask:
	.long 0
	
	.global lastDiscrep
lastDiscrep:
	.long 0


	/* Code goes into .text section */
	.text
	.global entry
entry:

/* Register general usage: */
/* R1 is used for scratech register: So, don't use it if you are push/pop/psr/ret */
/* R3 is used as stack pointer: DON'T USE */
/* R0 is sometime used for JUMPR .... */
/* R2 is free to use: Here, R2 is either used as passing para or as a return var. */

	move r3, stackEnd
	
	psr
	jump search_rom

	move r0, 0
copy_8bytes:
	move r1, romID
	add r1, r1, r0
	move r2, romID1
	add r2, r2, r0

	push r0

	ld r0, r1, 0
	st r0, r2, 0
	move r0, 0x00
	st r0, r1, 0

	pop r0

	add r0, r0, 1
	jumpr copy_8bytes, 8, LT

	psr
	jump search_rom

	jump exit_wake

exit:
        // ULP will restart when half
        halt

exit_wake:
        READ_RTC_REG(RTC_CNTL_DIAG0_REG, 19, 1)
        and r0, r0, 1
        jump exit, eq

        // Wake up the SoC and stop ULP program
        wake
        // Stop the wakeup timer so it does not restart ULP
        WRITE_RTC_FIELD(RTC_CNTL_STATE0_REG, RTC_CNTL_ULP_CP_SLP_TIMER_EN, 0)
        halt


////////////////////////////////////////
//////// Routine search_rom ////////////
////////////////////////////////////////

search_rom:

	// init or reset bit_index 1-64 (8 Bytes) after one FULL romID(8 Bytes) search.
	move r0, bit_index
	move r1, 0x01
	st r1, r0, 0

	// init byte_index (8 Bytes)
	move r0, byte_index
	move r1, 0
	st r1, r0, 0			

	psr
	jump rst_pulse

	// Send searchRom Command
	move r2, 0xF0
	psr
	jump send_byte

loop_8bytes:
	// init or reset bit_mask bitpos[7:0] after each Byte increments
	move r0, bit_mask
	move r1, 0
	st r1, r0, 0

	stage_rst			// bit loop reset to zero
	
loop_8bits:
	move r0, 0x0
	psr
	jump read_bit
	move r2, r0
	lsh r2, r2, 1
	
	wait(8)				// wait 1 us
	
	psr
	jump read_bit
	add r0, r2, r0			// R0 => 0 0 or 0 1 or 1 0 or 1 1(no device)
					// not conflicting bits: 0 1 or 1 0 , devices have all 0 or all 1
					// conflicting bits    : 0 0 in r0 , devices have 0 and 1
	jumpr exit_wake, 3, ge
	jumpr not_conflicting_bits, 1, ge

conflicting_bits:
					// If this discrepancy is before the last discrepancy on previous
					// Next call then set value to last value.
	move r0, bit_index
	ld r0, r0, 0
	move r1, lastDiscrep
	ld r1, r1, 0

	sub r0, r1, r0
	jumpr this_descrep_after_Ldescrep, 1 , LT	// is bit_index(present descrep) after lastdescrep?
	
this_discrep_before_Ldescrep:
	move r0, byte_index
	ld r0, r0, 0
	move r1, romID
	ld r1, r1, 0
	add r0, r1, r0			// RomID + offset (byte_index) => RomID[n]
	ld r0, r0, 0			// Get value from RomID
	move r1, bit_mask
	ld r1, r1, 0
	move r2, 0x01
	lsh r2, r2, r1
	and r0, r0, r2			// RomID[n] & bit_mask, isolate the needed bit

	rsh r0, r0, r1			// rsh it back to bitpos 1
	jump if_output_equal_zero
	
this_descrep_after_Ldescrep:
					// bit_index == lastDiscrep ??
	move r0, bit_index
	ld r0, r0, 0
	move r1, lastDiscrep
	ld r1, r1, 0
	sub r0, r0, r1
	jump they_equal, eq
not_equal:
	move r0, 0 			// r0 = bit_index == lastDiscrep??
	jump if_output_equal_zero
they_equal:
	move r0, 1			// r0 = bit_index == lastDiscrep??
	
if_output_equal_zero:			// if zero(R0) was picked then record it
	sub r1, r0, 0
	jump discropmarkerEqualBitIndex, eq
	jump no_rsh

discropmarkerEqualBitIndex:
	move r1, discrepmarker
	move r2, bit_index
	ld r2, r2, 0
	st r2, r1, 0			// discropMarker = bit_index
	jump no_rsh

not_conflicting_bits:
	rsh r0, r0, 1			// shift out the complement bit, leaving first read bit.

no_rsh:
	move r2, r0
	push r2				// save result for sendCommand
	
	move r1, bit_mask
	ld r2, r1, 0

	lsh r0, r0, r2			// move input bit to right position along bit_mask.
	
	add r2, r2, 1			// bit_mask++
	st r2, r1, 0

	move r1, romID
	move r2, byte_index
	ld r2, r2, 0
	add r1, r1, r2			// romID + offset(byte_index)

	ld r2, r1, 0			// load value of romID to r2
	or r0, r0, r2			// OR read bit, value of romID
	st r0, r1, 0			// store result into romID

	move r1, bit_index
	ld r2, r1, 0
	add r2, r2, 1
	st r2, r1, 0			// bit_index++

	pop r2
	psr
	jump send_bit

	stage_inc 1
	jumps loop_8bits, 8, LT

	move r1, byte_index
	ld r0, r1, 0
	add r0, r0, 1
	st r0, r1, 0			// byte_index++ and store

	jumpr loop_8bytes, 8, LT

	move r0, lastDiscrep
	move r1, discrepmarker
	ld r1, r1, 0
	st r1, r0, 0

	ret

////////////////////////////////////////
///////// Routine rst_pulse ////////////
////////////////////////////////////////
rst_pulse:
	/* set OUTPUT_W1TS for output */
	GPIO_L
	/* ULP running at 8mhz, 8mhz  = 1us per 8 cpu cycles, thats 0.125us a cpu cycle.  */
	/* So, 500us delay = 500/0.125 => 4,000 cpu cycles. */
	/* wait 500 microsecond, 1000 ms = 1 millisecon */
	GPIO_low
	wait(4000) /* 500 us */
	
	GPIO_high
	GPIO_H
	wait(240) /* 30us */
	GPIO_read /* r0 holds input result */
	wait(3760) /* 470us */
	ret

////////////////////////////////////////
///////// Routine read_byte ////////////
////////////////////////////////////////
/* R2: (8bits) read_byte stores in R2 on return. */
read_byte:
	/*
	psr
	jump read_bit
	move r2, r0
	wait(120)  15 us 
	move r0, 1
	*/
	move r2, 0
	move r0, 0

read_byte_loop:
	push r0
	psr
	jump read_bit
	move r1, r0
	pop r0

	lsh r1, r1, r0
	or r2, r2, r1

	wait(120) /* 15 us */
	add r0, r0, 1
	jumpr read_byte_loop, 8, LT

	ret

////////////////////////////////////////
///////// Routine read_bit /////////////
////////////////////////////////////////
/* R0: (1bit) stores GPIO input on return. */
/* since R2 is used to store all the bits */
read_bit:
	GPIO_L
	GPIO_low
	wait(16) /* 2 us */
	GPIO_high
	wait(120) /* 15 us */
	GPIO_H
	GPIO_read 
	
	ret


////////////////////////////////////////
///////// Routine send_byte ////////////
////////////////////////////////////////
/* R0 is used to counter, R1 is used by psr, R3 is used by stack */
/* R2: stores the (8bits) beging sent. */
send_byte:
	move r1, r2
	move r0, 0
send_byte_loop:
	rsh r2, r1, r0
	and r2, r2, 0x01
	/* r2 hold the bit to be sent */
	
	push r0
	push r1

	psr
	jump send_bit

	pop r1
	pop r0

	add r0, r0, 1
	jumpr send_byte_loop, 8, LT
	
	wait(800) /* 100us */
	ret


////////////////////////////////////////
///////// Routine send_bit /////////////
////////////////////////////////////////
/* R2: Stores the one bit being sent. */
send_bit:
	GPIO_L
	GPIO_low
	wait(40) /* 5us */
	sub r2, r2, 0
	jump send_bit_low, eq
send_bit_high:
	GPIO_high
	
send_bit_low:
	wait(640) /* 80us */
	GPIO_high

	ret


////////////////////////////////////////
///////// Routine delay_ms /////////////
////////////////////////////////////////
delay_ms:
	/* delay 750 mill sec, wait 0.75 sec, 1000 millisecond = 1 second */
	/* 1ms = 1,000 us */
	move r0, 750
	delay_ms_loop:

	sub r0, r0, 1
	wait(7990) /* 1millsecond = 1000 microsecond */
	jumpr delay_ms_loop, 1, GE
	ret

