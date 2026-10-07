/*
 * montgomery.c
 *
 */

#include "montgomery.h"



// Calculates res = a * b * r^(-1) mod n.
// a, b, n, n_prime represent operands of size elements
// res has (size+1) elements
void montMul(uint32_t *a, uint32_t *b, uint32_t *n, uint32_t *n_prime, uint32_t *res, uint32_t size)
{
//	a*b
	uint64_t res64;
	for (int i = 0; i < size; i++){
		res64 = (uint64_t) a[i] * (uint64_t) b[i]; // this is 64 bits which should be devided into two array elements
		res[2*i] = res64;
		res64 = res64 >> 32;
		res[2i + 1] = res64;
	}

	// NOW WE HAVE THE ARRAY RES CONTAINING 2*SIZE ELEMENTS OF EACH 32 BITS

	// ADD Z * N SO WE HAVE ZERO'S AT THE BOTTOM BUT WHAT IS z
	// we use int to not put a boundry on the possibilities of size (no chopping down should be done)
	long long r = 2^size; // ask

	// now calculate z = n_prime * t_prime mod r
	uint32_t z[size];
	for (int i = 0; i < size; i++){
		z64 = ((uint64_t) n_prime[i] * (uint64_t) res[i] ); // this is 64 bits which should be devided into two array elements
		[2*i] = z64;
		res64 = res64 >> 32;
		res[2i + 1] = res64;
	}


	// we use the long long ahhhh slide with the CIHS thingy to implement this stupids

}

// Calculates res = a * b * r^(-1) mod n.
// a, b, n, n_prime represent operands of size elements
// res has (size+1) elements
// Optimised ASM version
void montMulOpt(uint32_t *a, uint32_t *b, uint32_t *n, uint32_t *n_prime, uint32_t *res, uint32_t size)
{

}
