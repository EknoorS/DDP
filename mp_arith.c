/*
 * mp_arith.c
 *
 */

#include <stdint.h>


// calculate the sum first by casting first both numbers to 64 bit then the sum will have its carry
// bit on
void mp_add(uint32_t *a, uint32_t *b, uint32_t *res, uint32_t size)
{
	uint32_t carry = 0;

	// dont use int but define smaller variables
	// size DONT HARDCODEEEEEE
	for(int i = 0; i<size ; i++)
	{
		uint32_t old_carry = carry;

		uint32_t temp = a[i] +b[i];
		carry = (temp < a[i]);// comparison is bad
		//


		res[i] = temp + old_carry ;
		if(res[i]<temp)
			carry = 1;

	}
	 res[32] = carry;

}


// same thing
void mp_sub(uint32_t *a, uint32_t *b, uint32_t *res, uint32_t size)
{
	uint32_t borrow = 0;

	for(int i = 0 ; i<32 ; i++)
	{
		uint32_t old_borrow = borrow;

		uint32_t temp =a[i] - b[i];
		borrow = (a[i]<b[i]);

		res[i] = temp - old_borrow;
		if(res[i]> temp)
			borrow =1;

	}

}



void mod_add(uint32_t *a, uint32_t *b, uint32_t *N, uint32_t *res, uint32_t size)
{


	uint32_t sum[33];

	mp_add(a, b, sum, size);

	// just use 8 bit int instead of int
	int subtract_n = 0;
	if (sum[size] != 0)
	{
		subtract_n = 1;
	}
	else
	{
		// make more efficient by removing the if else embedding

		for (int i = size - 1; i >= 0; i--)
		{
			if (sum[i] > N[i])
			{
				subtract_n = 1;
				break;
			}
			else if (sum[i] < N[i])
			{
				subtract_n = 0;
				break;
			}
			else if (i == 0)
			{
				subtract_n = 1;
			}
		}
	}

	if (subtract_n)
	{
		mp_sub(sum, N, res, size);
	}

	else
	{
		for (int i = 0; i < size; i++)
		{
			res[i] = sum[i];
		}
	}
}






void mod_sub(uint32_t *a, uint32_t *b, uint32_t *N, uint32_t *res, uint32_t size)
{


	int compare = 0;

	for (int i = size - 1; i >= 0; i--)
	{
		if (a[i] > b[i])
		{
			compare = 1;
			break;
		}
		else if (a[i] < b[i])
		{
			compare = -1;
			break;
		}
	}

	if (compare >= 0)
	{
		mp_sub(a, b, res, size);
	}
	else
	{
		uint32_t temp[32];
		mp_sub(b, a, temp, size);
		mp_sub(N, temp, res, size);
	}
}



