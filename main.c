/******************************************************************
 * This is the main file for the Software Sessions
 *
 */

#include <stdint.h>
#include <inttypes.h>
#include "mp_arith.h"
#include "montgomery.h"
#include "common.h"
// premier en optimisant premier>>> TIMING: 23161 cycles
//>>> TIMING: 23319 cycles

// Uncomment for Session SW1
// extern void warmup();

// Uncomment for Session SW2 onwards
//#include "mp_arith.h"
//#include "montgomery.h"
//#include "asm_func.h"
//void print_result(uint32_t *x, uint32_t size)
//{
//    xil_printf("0x");
//
//    for (int i = size - 1; i >= 0; i--)
//    {
//        xil_printf("%08x", x[i]);
//    }
//
//    xil_printf("\r\n");
//}

int main()
{
    init_platform();
    init_performance_counters(1);



uint32_t a[32]         = { 0x1c00c9b3, 0x8ac5766c, 0x206ae3dc, 0xd303755f, 0x617d9a52, 0x8275157c, 0xec14e161, 0x4b60ec8a, 0xa71257b1, 0x0d1da433, 0x151594e0, 0x6414d0e1, 0xd61c5d3f, 0x76c1739f, 0xcfc419fc, 0xadac93b1, 0x75d83f40, 0x941bbc35, 0x63f3ad88, 0x67096958, 0xee167dce, 0xb214a702, 0x37ba2219, 0x61433758, 0x87a03fa3, 0x66ffa8ec, 0x1e4d57c4, 0x77cc1c3d, 0x3711712e, 0xea0231c7, 0x45db5f54, 0x8dcaccc5 };
uint32_t b[32]         = { 0x16b0bd01, 0x4f201b9a, 0x950fcc24, 0xe1740ef6, 0xa0c29d33, 0x3df63496, 0x1450185f, 0x70e9ab8c, 0x2e416797, 0x5a6bfa78, 0x7efef0ac, 0x91a46871, 0x3c07f91d, 0xf51fdeba, 0xf689ff4a, 0x9b7e4868, 0xdf0bcae3, 0x36a40976, 0x40b6f157, 0x1beaa2a4, 0x4c3246ec, 0xf9589c89, 0xe9cd4544, 0x46ff3df8, 0xbb78ee3f, 0x3347e11d, 0x3eac340d, 0x805bdb55, 0xdc136190, 0x6c9db31a, 0xd23289b7, 0x8a714566 };
uint32_t n[32]         = { 0x14d36953, 0x7a705c32, 0x92953f5e, 0xefb4d097, 0x7031560a, 0x9f4d57c8, 0xa26d24fd, 0xcf887962, 0xdcc31352, 0x5b3963d6, 0xfdb0ccd3, 0x41e0ccc6, 0xbc0f8e35, 0x6a73add1, 0xad63d432, 0xe27fb031, 0x33dfba3a, 0xd578669d, 0x0658746a, 0xae86cff8, 0xa4bbbbe8, 0x467a14d3, 0x4aad47c4, 0x29f578c2, 0xf94bf3ff, 0xa7927e49, 0x4868c905, 0x2e5dad73, 0x21da8b26, 0x7fd421d5, 0x3a5c78f4, 0x9c87abad };
uint32_t n_prime[32]   = { 0x0d233d25, 0x125dc7c4, 0x3b36cfb1, 0xeada6967, 0x3bb0f51f, 0x532b5053, 0x708907cd, 0xb82a0a93, 0x8c465152, 0xcdc93790, 0xfe6062ec, 0x18f1039b, 0x20eee3af, 0xef80e2cf, 0x8f00035d, 0x7e106826, 0x0415d228, 0x176c7123, 0xcac38fe0, 0x8a021d89, 0xbee6f7e6, 0x9c7ae7da, 0xec8f6228, 0x5669f714, 0x10180643, 0xd025ef15, 0xa3f4ef87, 0x2635af18, 0xf3ac76e8, 0xe5122359, 0xeb436c7a, 0x69435de8 };
uint32_t expres[32]       = { 0x668bfc4a, 0x7024afbb, 0x3131ed6d, 0x221dacf7, 0x78abee39, 0x0e43f7d3, 0x132a70e5, 0x231753db, 0xd1020285, 0x60624378, 0x9e5908b1, 0x6bd799da, 0x2c5030e1, 0x971660dc, 0xe6917d20, 0xbf468ffa, 0x6fdc6952, 0xcf4aeda0, 0xff72f700, 0x6984143d, 0x4db2d212, 0xcab82666, 0x59721813, 0x2823f4a2, 0xac1c534c, 0x4046c747, 0x64886ff4, 0x374aabfc, 0xb6fcbb6d, 0xdc85489d, 0x2162197b, 0x0ecf896b };

//uint32_t res[32] = {0};
//montMul(a, b , n, n_prime, res, 32);

uint32_t res_c[32] = {0};
uint32_t res_opt[32] = {0};

//START_TIMING
montMul(a, b, n, n_prime, res_c, 32);
//STOP_TIMING

START_TIMING
montMulOpt(a, b, n, n_prime, res_opt, 32);
STOP_TIMING


void print_result(uint32_t res_c[32])
{
    xil_printf("0x");

    for (int i = 31; i >= 0; i--)
    {
        xil_printf("%08x", res_c[i]);
    }

    xil_printf("\r\n");
}

xil_printf("Result = ");
    print_result(res_c);

int correct =1;
for(int i = 0; i<32 ; i++)
{
	if(res_c[i] != res_opt[i])
	{
		correct = 0;
		break;

	}

}

if(correct)
{
	xil_printf("correct\r\n");
}






else
{
	xil_printf("wrong\r\n");
}
    cleanup_platform();

    return 0;
}
