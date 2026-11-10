/*
 * montgomery.c
 *
 */
#include "mp_arith.h"
#include "montgomery.h"
#include "asm_func.h"



// Calculates res = a * b * r^(-1) mod n.
// a, b, n, n_prime represent operands of size elements
// res has (size+1) elements
void montMul(uint32_t *a, uint32_t *b, uint32_t *n, uint32_t *n_prime, uint32_t *res, uint32_t size)
{


	    uint32_t t[size + 2];
	    uint64_t sum;
	    uint64_t carry;
	    uint32_t m;


	    for (uint32_t i = 0; i < size + 2; i++)
	    {
	        t[i] = 0;
	    }

	    for (uint32_t i = 0; i < size; i++)
	    {
//debut premier
	        carry = 0;


	        for (uint32_t j = 0; j < size - i; j++)
	        {

	            sum =(uint64_t)t[i + j]+ (uint64_t)a[i] * (uint64_t)b[j] + carry;

	            t[i + j] = (uint32_t)sum;
	            carry = sum >> 32;
	        }
// fin premier

	        sum = (uint64_t)t[size] + carry;
	        t[size] = (uint32_t)sum;
	        carry = sum >> 32;

	        t[size + 1] += (uint32_t)carry;
	    }




	    for (uint32_t i = 0; i < size; i++)
	    {

	        m = (uint32_t)((uint64_t)t[0] * (uint64_t)n_prime[0] );

	        sum =(uint64_t)t[0] + (uint64_t)m * (uint64_t)n[0];
	        carry = sum >> 32;



	        for (uint32_t j = 1; j < size; j++)
	        {

	            sum =(uint64_t)t[j] + (uint64_t)m * (uint64_t)n[j] + carry;

	            carry = sum >> 32;

	            t[j - 1] = (uint32_t)sum;
	        }



	        sum = (uint64_t)t[size] + carry;
	        t[size - 1] = (uint32_t)sum;
	        carry = sum >> 32;


	        t[size] = t[size + 1] + (uint32_t)carry;

	        t[size + 1] = 0;


	        for (uint32_t j = i + 1; j < size; j++)
	        {


	            sum = (uint64_t)t[size - 1] + (uint64_t)b[j]  * (uint64_t)a[size - j + i];

	            t[size - 1] = (uint32_t)sum;
	            carry = sum >> 32;

	            sum =
	                (uint64_t)t[size]
	                + carry;

	            t[size] = (uint32_t)sum;
	            carry = sum >> 32;

	            t[size + 1] += (uint32_t)carry;
	        }
	    }

	    ////////////////
	    int compare = 0;

	    for (int i = (int)size - 1; i >= 0; i--)
	    {
	        if (t[i] > n[i])
	        {
	            compare = 1;
	            break;
	        }

	        if (t[i] < n[i])
	        {
	            compare = -1;
	            break;
	        }
	    }

	    /*
	     * If t[size] != 0, t has an extra word,
	     * so t is definitely >= n.
	     *
	     * Otherwise use the comparison of the lower size words.
	     */
	    if (t[size] != 0 || compare >= 0)
	    {
	        mp_sub(t, n, res, size);
	    }
	    else
	    {
	        for (uint32_t i = 0; i < size; i++)
	        {
	            res[i] = t[i];
	        }
	    }
//////////

}
//
// Calculates res = a * b * r^(-1) mod n.
// a, b, n, n_prime represent operands of size elements
// res has (size+1) elements
// Optimised ASM version
void montMulOpt(uint32_t *a, uint32_t *b, uint32_t *n, uint32_t *n_prime, uint32_t *res, uint32_t size)
{

uint32_t t[size + 2];



clear_t_asm(
	t,
	size + 2
);

mul_phase_asm(
	t,
	a,
	b,
	size
);


reduce_all_asm(
	t,
	n,
	b,
	a,
	n_prime[0],
	size
);

final_reduce_asm(t, n, res, size);



}





























