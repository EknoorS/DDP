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


	    if (compare >= 0)
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



}

// Calculates res = a * b * r^(-1) mod n.
// a, b, n, n_prime represent operands of size elements
// res has (size+1) elements
// Optimised ASM version
void montMulOpt(uint32_t *a, uint32_t *b, uint32_t *n, uint32_t *n_prime, uint32_t *res, uint32_t size)
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

    	carry = mul_accumulate_asm(
    	    &t[i],
    	    b,
    	    a[i],
    	    size - i
    	);


        sum = (uint64_t)t[size] + carry;
        t[size] = (uint32_t)sum;
        carry = sum >> 32;

        t[size + 1] += (uint32_t)carry;
    }


    for (uint32_t i = 0; i < size; i++)
    {
    m = (uint32_t)(
        (uint64_t)t[0]
        * (uint64_t)n_prime[0]
    );

    carry = mont_reduce_asm(
        t,
        n,
        m,
        size
    );


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


    if (compare >= 0)
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




}






































//
//
//for (uint32_t k = 0; k < size + 2; k++) {
//        t[k] = 0;
//    }
//
//for(int i = 0; i<size ; i++){
//	uint32_t C = 0;
//
//	for(int j = 0; j<size-i ; j++){
//		uint64_t sum =(uint64_t)[i + j] + ((uint64_t)a[i] * (uint64_t)b[j] ) + C;
//
//		t[i + j] = (uint32_t)sum;
//		C = sum >> 32;
//
//	}
//////	a*b
//	uint64_t res64;
//	for (int i = 0; i < size; i++){
//		res64 = (uint64_t) a[i] * (uint64_t) b[i]; // this is 64 bits which should be devided into two array elements
//		res[2*i] = res64;
//		res64 = res64 >> 32;
//		res[2i + 1] = res64;
//	}
//
//	// NOW WE HAVE THE ARRAY RES CONTAINING 2*SIZE ELEMENTS OF EACH 32 BITS
//
//	// ADD Z * N SO WE HAVE ZERO'S AT THE BOTTOM BUT WHAT IS z
//	// we use int to not put a boundry on the possibilities of size (no chopping down should be done)
//	long long r = 2^size; // ask
//
//	// now calculate z = n_prime * t_prime mod r
//	uint32_t z[size];
//	for (int i = 0; i < size; i++){
//		z64 = ((uint64_t) n_prime[i] * (uint64_t) res[i] ); // this is 64 bits which should be devided into two array elements
//		[2*i] = z64;
//		res64 = res64 >> 32;
//		res[2i + 1] = res64;
//	}
