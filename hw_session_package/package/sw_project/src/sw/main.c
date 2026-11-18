#include "common.h"
#include <stdalign.h>
  
// These variables are defined in the testvector.c
// that is created by the testvector generator python script
extern uint32_t modulus[32],
                message[32],
                K_X[32],
                K_Y[32],
                K_Z[32],
				K_T[32],
				s[32],
                Public_X[32],
                Public_Y[32],
                Public_Z[32],
				Public_T[32],
				G_X[32],
                G_Y[32],
                G_Z[32],
				G_T[32],
                K_X_Modn[32],
				C_X[32],
				C_Y[32],
				C_Z[32],
				C_T[32],
				C_Prime_X[32],
				C_Prime_Y[32],
				C_Prime_Z[32],
				C_Prime_T[32],
				R_N[32],
				R2_N[32];

#define ISFLAGSET(REG,BIT) ( (REG & (1<<BIT)) ? 1 : 0 )

void print_array_contents(uint32_t* src) {
  int i;
  for (i=32-4; i>=20; i-=4)
    xil_printf("%08x %08x %08x %08x\n\r",
      src[i+3], src[i+2], src[i+1], src[i]);
}

int main() {

  init_platform();
  init_performance_counters(0);

  xil_printf("Begin\n\r");

  // Register file shared with FPGA
  volatile uint32_t* HWreg = (volatile uint32_t*)0x40400000;

	#define COMMAND  0
	#define RXADDR_A 1
	#define TXADDR   2
	#define RXADDR_B 3
	#define RXADDR_M 4
	#define STATUS   0

  // Aligned input and output memory shared with FPGA
  alignas(128) uint32_t idata_A[32];
  alignas(128) uint32_t idata_B[32];
  alignas(128) uint32_t idata_M[32];

  alignas(128) uint32_t odata[32];

  // Initialize odata to all zero's
  memset(odata,0,128);

  // for now we populate it using random tings -> yet to be done offially for A, B and M
  for (int i = 0; i < 32; i++) {
      idata_A[i] = G_X[i];
      idata_B[i] = G_Y[i];
      idata_M[i] = modulus[i];

      odata[i] = 0;
  }

  // Write to input regs (SW to HW)

  HWreg[RXADDR_A] = (uint32_t)idata_A;
  HWreg[RXADDR_B] = (uint32_t)idata_B;
  HWreg[RXADDR_M] = (uint32_t)idata_M;
  HWreg[TXADDR] = (uint32_t)odata;  // store address odata in reg2



  // Read from output regs (HW to SW)
  printf("STATUS %08X\r\n", (unsigned int)HWreg[STATUS]);
  printf("RXADDR %08X\r\n", (unsigned int)HWreg[1]);
  printf("TXADDR %08X\r\n", (unsigned int)HWreg[2]);
  printf("REG[3] %08X\r\n", (unsigned int)HWreg[3]);
  printf("REG[4] %08X\r\n", (unsigned int)HWreg[4]);

START_TIMING
  HWreg[COMMAND] = 0x01;
  // Wait until FPGA is done
  while((HWreg[STATUS] & 0x01) == 0);
STOP_TIMING
  
  HWreg[COMMAND] = 0x00;

  printf("STATUS 0 %08X | Done %d | Idle %d | Error %d \r\n", (unsigned int)HWreg[STATUS], ISFLAGSET(HWreg[STATUS],0), ISFLAGSET(HWreg[STATUS],1), ISFLAGSET(HWreg[STATUS],2));
  printf("STATUS 1 %08X\r\n", (unsigned int)HWreg[1]);
  printf("STATUS 2 %08X\r\n", (unsigned int)HWreg[2]);
  printf("STATUS 3 %08X\r\n", (unsigned int)HWreg[3]);
  printf("STATUS 4 %08X\r\n", (unsigned int)HWreg[4]);
  printf("STATUS 5 %08X\r\n", (unsigned int)HWreg[5]);
  printf("STATUS 6 %08X\r\n", (unsigned int)HWreg[6]);
  printf("STATUS 7 %08X\r\n", (unsigned int)HWreg[7]);

  printf("\r\nI_Data:\r\n"); print_array_contents(idata);
  printf("\r\nO_Data:\r\n"); print_array_contents(odata);


  cleanup_platform();

  return 0;
}


//Register	FPGA signal	New purpose
//HWreg[0]	rin0	Command/start
//HWreg[1]	rin1	Address of A
//HWreg[2]	rin2	Address of output
//HWreg[3]	rin3	Address of B
//HWreg[4]	rin4	Address of M
