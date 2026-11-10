.text
.type reduce_cross_fast, %function

reduce_cross_fast:

    /*
     * r0 = t
     * r1 = n
     * r2 = b_ptr
     * r3 = a_ptr
     *
     * r4 = nprime0
     * r5 = size
     * r6 = count
     */

    push {r4-r11}

    /*
     * m = low32(t[0] * nprime0)
     */

    ldr r12, [r0]
    mul r4, r12, r4


    /*
     * Montgomery reduction
     */

    ldr r12, [r0]
    ldr r8, [r1], #4

    umull r8, r9, r4, r8

    adds r8, r8, r12
    adc  r9, r9, #0

    mov r7, r9


    add r10, r0, #4
    mov r11, r0

    subs r5, r5, #1
    beq reduce_fast_tail


reduce_fast_reduce_loop:

    ldr r12, [r10], #4
    ldr r8, [r1], #4

    umull r8, r9, r4, r8

    adds r8, r8, r12
    adc  r9, r9, #0

    adds r8, r8, r7
    adc  r9, r9, #0

    str r8, [r11], #4

    mov r7, r9

    subs r5, r5, #1
    bne reduce_fast_reduce_loop


reduce_fast_tail:

    ldr r12, [r10]

    adds r8, r12, r7

    mov r9, #0
    adc r9, r9, #0

    str r8, [r11]

    ldr r12, [r10, #4]

    add r12, r12, r9

    str r12, [r10]

    mov r12, #0
    str r12, [r10, #4]


    /*
     * Cross-products
     */

    cmp r6, #0
    beq reduce_fast_done


reduce_fast_cross_loop:

    ldr r8, [r2], #4
    ldr r9, [r3], #-4

    umull r4, r7, r8, r9

    ldr r12, [r11]

    adds r4, r4, r12
    adc  r7, r7, #0

    str r4, [r11]

    ldr r12, [r10]

    adds r12, r12, r7

    str r12, [r10]

    mov r7, #0
    adc r7, r7, #0

    ldr r4, [r10, #4]

    add r4, r4, r7

    str r4, [r10, #4]

    subs r6, r6, #1
    bne reduce_fast_cross_loop


reduce_fast_done:

    pop {r4-r11}
    bx lr
.text
.global reduce_all_asm
.type reduce_all_asm, %function

reduce_all_asm:

    /*
     * C arguments:
     *
     * r0 = t
     * r1 = n
     * r2 = b
     * r3 = a
     *
     * stack:
     * nprime0
     * size
     */

    push {r4-r10, lr}

    /*
     * 8 registers pushed = 32 bytes
     */
    ldr r4, [sp, #32]      @ r4 = nprime0
    ldr r5, [sp, #36]      @ r5 = size

    /*
     * count starts at size-1
     */
    sub r6, r5, #1

    /*
     * Keep permanent pointers
     */
    mov r7, r0             @ r7 = t
    mov r8, r1             @ r8 = n

    add r9, r2, #4         @ r9 = &b[1]

    /*
     * r10 = &a[size-1]
     */
    add r10, r3, r5, LSL #2
    sub r10, r10, #4


reduce_all_fast_loop:

    /*
     * Custom convention for reduce_cross_fast:
     *
     * r0 = t
     * r1 = n
     * r2 = b_ptr
     * r3 = a_ptr
     *
     * r4 = nprime0
     * r5 = size
     * r6 = count
     */

    mov r0, r7
    mov r1, r8
    mov r2, r9
    mov r3, r10

    bl reduce_cross_fast


    /*
     * count == 0 means we just performed
     * the final outer iteration.
     */
    cmp r6, #0
    beq reduce_all_fast_done

    /*
     * Next iteration
     */
    sub r6, r6, #1
    add r9, r9, #4

    b reduce_all_fast_loop


reduce_all_fast_done:

    pop {r4-r10, lr}
    bx lr

.text
.global clear_t_asm
.type clear_t_asm, %function

clear_t_asm:

    /*
     * r0 = t
     * r1 = count
     */

    mov r2, #0

clear_t_loop:

    cmp r1, #0
    beq clear_t_done

    str r2, [r0], #4

    subs r1, r1, #1
    bne clear_t_loop

clear_t_done:

    bx lr

.text
.global final_reduce_asm
.type final_reduce_asm, %function

final_reduce_asm:

    /*
     * r0 = t
     * r1 = n
     * r2 = res
     * r3 = size
     */

    push {r4-r11}
        @ First check the extra word t[size]
    @ If t[size] != 0, then t >= n for sure

    ldr r12, [r0, r3, LSL #2]     @ r12 = t[size]
    cmp r12, #0
    bne final_subtract_setup

    /*
     * ==========================================================
     * PART 1 : compare t and n
     *
     * Start from the most significant word.
     * ==========================================================
     */

    mov r7, r3                  @ r7 = number of words

    /*
     * r4 = &t[size-1]
     */
    add r4, r0, r3, LSL #2
    sub r4, r4, #4

    /*
     * r5 = &n[size-1]
     */
    add r5, r1, r3, LSL #2
    sub r5, r5, #4


final_compare_loop:

    ldr r8, [r4], #-4          @ t[i]
    ldr r9, [r5], #-4          @ n[i]

    cmp r8, r9

    bhi final_subtract_setup    @ t > n
    blo final_copy_setup        @ t < n

    /*
     * equal word -> continue
     */
    subs r7, r7, #1
    bne final_compare_loop


    /*
     * All words equal:
     *
     * t == n
     *
     * We must subtract because condition is t >= n.
     */

    b final_subtract_setup



/*
 * ==========================================================
 * PART 2A : t >= n
 *
 * res = t - n
 * ==========================================================
 */

final_subtract_setup:

    mov r4, r0                  @ t pointer
    mov r5, r1                  @ n pointer
    mov r6, r2                  @ res pointer

    mov r7, r3                  @ count
    mov r8, #0                  @ borrow = 0


final_subtract_loop:

    ldr r9,  [r4], #4           @ t[i]
    ldr r10, [r5], #4           @ n[i]

    /*
     * First:
     * t[i] - n[i]
     */

    subs r11, r9, r10

    /*
     * Save borrow generated by t[i]-n[i]
     *
     * ARM C flag:
     * C = 1 -> no borrow
     * C = 0 -> borrow
     */

    movcc r12, #1
    movcs r12, #0


    /*
     * Then subtract previous borrow
     */

    subs r11, r11, r8

    /*
     * borrow generated by subtraction of previous borrow
     */

    movcc r8, #1
    movcs r8, #0


    /*
     * New borrow =
     *
     * borrow from (t-n)
     * OR
     * borrow from (- previous_borrow)
     */

    orr r8, r8, r12


    /*
     * Store result
     */

    str r11, [r6], #4


    /*
     * next word
     */

    subs r7, r7, #1
    bne final_subtract_loop

    b final_reduce_done



/*
 * ==========================================================
 * PART 2B : t < n
 *
 * Simply copy t -> res
 * ==========================================================
 */

final_copy_setup:

    mov r4, r0                  @ t pointer
    mov r6, r2                  @ res pointer
    mov r7, r3                  @ count


final_copy_loop:

    ldr r8, [r4], #4
    str r8, [r6], #4

    subs r7, r7, #1
    bne final_copy_loop



/*
 * ==========================================================
 * DONE
 * ==========================================================
 */

final_reduce_done:

    pop {r4-r11}
    bx lr

.text
.global mul_phase_asm
.type mul_phase_asm, %function

mul_phase_asm:

    /*
     * r0 = t
     * r1 = a
     * r2 = b
     * r3 = size
     */

    push {r4-r11}

    /*
     * Keep useful values:
     *
     * r4 = i
     * r5 = size
     */
    mov r4, #0
    mov r5, r3


mul_phase_outer:

    /*
     * if i == size -> done
     */
    cmp r4, r5
    beq mul_phase_done


    /*
     * ai = a[i]
     *
     * r6 = ai
     */
    ldr r6, [r1, r4, LSL #2]


    /*
     * carry = 0
     *
     * r7 = carry
     */
    mov r7, #0


    /*
     * source b pointer starts at b[0]
     */
    mov r8, r2


    /*
     * destination pointer starts at &t[i]
     */
    add r9, r0, r4, LSL #2


    /*
     * count = size - i
     *
     * r10 = count
     */
    sub r10, r5, r4


mul_phase_inner:

    /*
     * if count == 0 -> finish this i
     */
    cmp r10, #0
    beq mul_phase_inner_done


    /*
     * load b[j]
     */
    ldr r11, [r8], #4


    /*
     * product = ai * b[j]
     *
     * low  = r11
     * high = r12
     */
    umull r11, r12, r6, r11


    /*
     * load current t[i+j]
     */
    ldr r3, [r9]


    /*
     * + t[i+j]
     */
    adds r11, r11, r3
    adc  r12, r12, #0


    /*
     * + carry
     */
    adds r11, r11, r7
    adc  r12, r12, #0


    /*
     * store low word
     */
    str r11, [r9], #4


    /*
     * new carry = high word
     */
    mov r7, r12


    /*
     * count--
     */
    subs r10, r10, #1
    bne mul_phase_inner


mul_phase_inner_done:

    /*
     * C pseudocode:
     *
     * sum = t[size] + carry;
     *
     * t[size] = low;
     * carry = high;
     *
     * t[size+1] += carry;
     */


    /*
     * address of t[size]
     */
    add r8, r0, r5, LSL #2


    /*
     * load t[size]
     */
    ldr r11, [r8]


    /*
     * t[size] + carry
     */
    adds r11, r11, r7


    /*
     * store low result back
     */
    str r11, [r8]


    /*
     * convert carry flag into 0/1
     */
    mov r12, #0
    adc r12, r12, #0


    /*
     * t[size+1] += overflow
     */
    ldr r11, [r8, #4]

    add r11, r11, r12

    str r11, [r8, #4]


    /*
     * i++
     */
    add r4, r4, #1

    b mul_phase_outer


mul_phase_done:

    pop {r4-r11}

    bx lr

.text
.global reduce_cross_asm
.type reduce_cross_asm, %function

reduce_cross_asm:

    /*
     * Arguments:
     *
     * r0 = t
     * r1 = n
     * r2 = &b[i+1]
     * r3 = &a[size-1]
     *
     * stack:
     * m
     * size
     * count
     */

    push {r4-r11}

    /*
     * 8 registers pushed = 32 bytes
     *
     * [sp,#32] = m
     * [sp,#36] = size
     * [sp,#40] = count
     */

    ldr r4, [sp, #32]     @ r4 = nprime0
    ldr r5, [sp, #36]     @ r5 = size
    ldr r6, [sp, #40]     @ r6 = count


/*
 * m = low32(t[0] * nprime0)
 */

    ldr r12, [r0]         @ r12 = t[0]

    mul r4, r12, r4       @ r4 = m


    /*
     * ==========================================================
     * PART 1 : Montgomery reduction
     * ==========================================================
     */

    ldr r12, [r0]          @ r12 = t[0]

    ldr r8, [r1], #4       @ r8 = n[0]
                            @ r1 -> n[1]

    umull r8, r9, r4, r8   @ r9:r8 = m * n[0]

    adds r8, r8, r12       @ + t[0]
    adc  r9, r9, #0        @ propagate carry

    mov r7, r9              @ r7 = carry


    /*
     * Source pointer = &t[1]
     */
    add r10, r0, #4

    /*
     * Destination pointer = &t[0]
     */
    mov r11, r0


    /*
     * remaining reduction iterations = size - 1
     */
    subs r5, r5, #1
    beq reduce_cross_tail


reduce_cross_reduce_loop:

    ldr r12, [r10], #4     @ r12 = t[j]

    ldr r8, [r1], #4       @ r8 = n[j]

    umull r8, r9, r4, r8   @ r9:r8 = m * n[j]

    adds r8, r8, r12       @ + t[j]
    adc  r9, r9, #0

    adds r8, r8, r7        @ + previous carry
    adc  r9, r9, #0

    str r8, [r11], #4      @ t[j-1] = low

    mov r7, r9              @ carry = high

    subs r5, r5, #1
    bne reduce_cross_reduce_loop


reduce_cross_tail:

    /*
     * r10 -> t[size]
     * r11 -> t[size-1]
     */

    ldr r12, [r10]         @ t[size]

    adds r8, r12, r7       @ t[size] + carry

    mov r9, #0
    adc r9, r9, #0         @ r9 = overflow carry

    str r8, [r11]          @ t[size-1] = low


    /*
     * t[size] = t[size+1] + carry
     */
    ldr r12, [r10, #4]     @ t[size+1]

    add r12, r12, r9

    str r12, [r10]         @ store into t[size]


    /*
     * t[size+1] = 0
     */
    mov r12, #0
    str r12, [r10, #4]


    /*
     * ==========================================================
     * PART 2 : Cross-products
     * ==========================================================
     */

    cmp r6, #0
    beq reduce_cross_done


reduce_cross_cross_loop:

    /*
     * b[j]
     * pointer moves forward
     */
    ldr r8, [r2], #4

    /*
     * a[size-j+i]
     * pointer moves backward
     */
    ldr r9, [r3], #-4

    /*
     * product = b[j] * a[...]
     */
    umull r4, r7, r8, r9


    /*
     * + t[size-1]
     */
    ldr r12, [r11]

    adds r4, r4, r12
    adc  r7, r7, #0

    str r4, [r11]


    /*
     * t[size] += high
     */
    ldr r12, [r10]

    adds r12, r12, r7

    str r12, [r10]


    /*
     * Extract overflow carry:
     * r7 = 0 or 1
     */
    mov r7, #0
    adc r7, r7, #0


    /*
     * t[size+1] += carry
     */
    ldr r4, [r10, #4]

    add r4, r4, r7

    str r4, [r10, #4]


    /*
     * count--
     */
    subs r6, r6, #1
    bne reduce_cross_cross_loop


reduce_cross_done:

    pop {r4-r11}

    bx lr

.text
.global cross_products_asm
.type cross_products_asm, %function

cross_products_asm:

    push {r4-r8}

cross_loop:

    cmp r3, #0
    beq cross_done

    @ --------------------------------------
    @ Load b[j]
    @ then advance b pointer
    @ --------------------------------------
    ldr r4, [r1], #4

    @ --------------------------------------
    @ Load current a word
    @ then move pointer backwards
    @ --------------------------------------
    ldr r5, [r2], #-4

    @ --------------------------------------
    @ product = b[j] * a[...]
    @
    @ r7:r6 = 64-bit product
    @ --------------------------------------
    umull r6, r7, r4, r5


    @ --------------------------------------
    @ Load t[size-1]
    @ --------------------------------------
    ldr r8, [r0]

    @ low += t[size-1]
    adds r6, r6, r8

    @ propagate overflow to high part
    adc r7, r7, #0

    @ t[size-1] = low
    str r6, [r0]


    @ --------------------------------------
    @ Now:
    @ carry = r7
    @
    @ t[size] += carry
    @ --------------------------------------

    ldr r8, [r0, #4]

    adds r8, r8, r7

    str r8, [r0, #4]


    @ --------------------------------------
    @ If that addition overflowed,
    @ add the carry to t[size+1]
    @
    @ ADC with zero extracts the carry flag
    @ --------------------------------------

    mov r7, #0
    adc r7, r7, #0

    ldr r8, [r0, #8]
    add r8, r8, r7
    str r8, [r0, #8]


    @ --------------------------------------
    @ count--
    @ --------------------------------------
    subs r3, r3, #1
    bne cross_loop


cross_done:

    pop {r4-r8}
    bx lr



.text
.global mont_reduce_asm
.type mont_reduce_asm, %function

mont_reduce_asm:

    push {r4-r9}

    /*
     * r0 = t
     * r1 = n
     * r2 = m
     * r3 = size
     */

    /* Load t[0] and n[0] */
    ldr r4, [r0]
    ldr r5, [r1]

    /* m * n[0] */
    umull r6, r7, r2, r5

    /* + t[0] */
    adds r6, r6, r4
    adc  r7, r7, #0

    /* r7 = carry */
    mov r8, r7

    /*
     * Advance n pointer to n[1]
     */
    add r1, r1, #4

    /*
     * Advance t pointer to t[1]
     *
     * We will read t[j]
     * and write result to t[j-1].
     */
    add r4, r0, #4

    /*
     * destination pointer starts at t[0]
     */
    mov r5, r0

    /*
     * We already handled j = 0,
     * so remaining iterations = size - 1
     */
    subs r3, r3, #1

reduce_loop:

    cmp r3, #0
    beq reduce_done

    /*
     * Load t[j]
     */
    ldr r6, [r4], #4

    /*
     * Load n[j]
     */
    ldr r7, [r1], #4

    /*
     * m * n[j]
     *
     * low  -> r9
     * high -> r7
     *
     * Careful: we need a free high register.
     */
    umull r9, r7, r2, r7

    /*
     * Add t[j]
     */
    adds r9, r9, r6
    adc  r7, r7, #0

    /*
     * Add previous carry
     */
    adds r9, r9, r8
    adc  r7, r7, #0

    /*
     * Store low word into t[j-1]
     */
    str r9, [r5], #4

    /*
     * New carry = high word
     */
    mov r8, r7

    subs r3, r3, #1
    bne reduce_loop

reduce_done:

    /*
     * Return final carry in r0
     */
    mov r0, r8

    pop {r4-r9}
    bx lr
.text

.global mul_accumulate_asm
.type mul_accumulate_asm, %function

mul_accumulate_asm:

    push {r4-r8}

    mov r4, #0

loop_mul_acc:

    cmp r3, #0
    beq end_mul_acc

    ldr r5, [r1], #4
    ldr r8, [r0]

    umull r6, r7, r2, r5

    adds r6, r6, r8
    adc  r7, r7, #0

    adds r6, r6, r4
    adc  r7, r7, #0

    str r6, [r0], #4

    mov r4, r7

    subs r3, r3, #1
    bne loop_mul_acc

end_mul_acc:

    mov r0, r4

    pop {r4-r8}
    bx lr
.text

.global add_3
.func add_3, add_3
.type add_3, %function

add_3:
add r0, r0, r1
add r0, r0, r2
bx lr
.endfunc

.text

.global add_10
.func add_10, add_10
.type add_10, %function

add_10:
cmp r1, #0
beq end_add
mov r2, #0
add_loop:
	ldr r3, [r0], #4
	add r2, r2, r3
	subs r1, r1, #1
	bne  add_loop
mov r0, r2
end_add:
bx lr
.endfunc

.text

.global arr_copy
.func arr_copy, arr_copy
.type arr_copy, %function

arr_copy:
cmp r2, #0
beq end_add
copy_loop:
	ldr r3, [r0], #4
	str r3, [r1], #4
	subs r2, r2, #1
	bne  copy_loop
end_copy:
bx lr
.endfunc

.text

.global multiply
.func multiply, multiply
.type multiply, %function

multiply:
	push {r4-r9}
	// If more registers are used in the function make sure to do push them on the stack to preserve them
	ldr r4, [sp, #24]		@m pointer is stored in R4
	ldr r5, [sp, #28]		@n pointer is stored in R5
	add r1, r1, r0, lsl #2
	ldr r6, [r4]
	ldr r7, [r5]
	umull r8, r9, r6, r7
	ldr r6, [r2]
	ldr r7, [r3]
	umull r4, r5, r6, r7
	adds r8, r8, r4
	adc r9, r9, r5
	stmia r1, {r8, r9}
	pop {r4-r9}
	bx lr
.endfunc






@USEFUL FUNCTIONS

@ add Rx, Ry, Rz	//Rx = Ry + Rz  second operand can be constant
@ sub Rx, Ry, Rz	//Rx = Ry - Rz second operand can be constant
@ addc Rx, Ry, Rz	//Rx = Ry + Rz + CARRY   one operand can be constant
@ cmp Rx, Ry		//compares Rx and Ry and if they are equal sets Z flag, otherwise resets Z flag (works by subtracting two values and checks if result is zero)
@ b{cond} <label>		//Jumps to given label in the code if given condition is satisfied
@ umull Rn, Rm, Rx, Ry 	//{Rm, Rn} = Rx * Ry Multiplies unsigned 32bit values in Rx and Ry. Stores the higher 32 bits in Rm, and lower in Rn
@ ldr Rx, [Ry]		//Loads from memory pointed by Ry to register Rx, see addressing modes for post increment, pre decrement
@ str Rx, [Ry]		//Stores to memory pointed by Ry value in register Rx, see addressing modes for post increment, pre decrement
@ pop {}			//Pops values from stack to specified registers in order they are specified
@ push {}			//Push registers to stack in orded they are specified
@ ldmia rx, {set of registers} //Loads to specified set of registers memory values, starting from rx. Increasing addresses
@ stmia rx, {set of registers} //Stores specified set of registers in memory, starting from address pointed by rx. Increasing addresses
