#include "common.h"
#include "xil_cache.h"
#include <stdint.h>
#include <string.h>
#include <stdalign.h>

// Generated in testvector.c
extern uint32_t modulus[32],
                message[32],
                K_X[32], K_Y[32], K_Z[32], K_T[32],
                s[32],
                Public_X[32], Public_Y[32], Public_Z[32], Public_T[32],
                G_X[32], G_Y[32], G_Z[32], G_T[32],
                K_X_Modn[32],
                C_X[32], C_Y[32], C_Z[32], C_T[32],
                C_Prime_X[32], C_Prime_Y[32], C_Prime_Z[32], C_Prime_T[32],
                R_N[32], R2_N[32];

// Indexes of the 32-bit control/status registers
#define COMMAND   0
#define RXADDR_A  1
#define TXADDR    2
#define RXADDR_B  3
#define RXADDR_M  4
#define STATUS    0

#define DONE_BIT   (1U << 0)
#define IDLE_BIT   (1U << 1)
#define ERROR_BIT  (1U << 2)
#define TIMEOUT    100000000U

// CSR register 0 is written as COMMAND and read as STATUS.
static volatile uint32_t * const HWreg = (volatile uint32_t *)0x40400000U;

// Each DMA transaction is 1024 bits (128 bytes), not 377 bytes.
// Keep these buffers 128-byte aligned and in ARM-accessible memory.
alignas(128) static uint32_t idata_A[32];
alignas(128) static uint32_t idata_B[32];
alignas(128) static uint32_t idata_M[32];
alignas(128) static uint32_t odata[32];

// Expected MontMul(G_X, G_Y, modulus), with R = 2^377.
// Words are little-endian: index 0 contains the lowest 32 bits.
static const uint32_t expected_first[32] = {
    0x532108c3, 0x70ffda4c, 0x8b69cdc0, 0x6fed770e,
    0x6abad9e6, 0x7335d478, 0x5bbbe33e, 0x223dd204,
    0xf006021f, 0xace232a7, 0xc1827996, 0x000dd56f
};

void print_array_contents(const uint32_t *src) {
    int i;
    // Print the 12 words that contain the 377-bit number.
    for (i = 11; i >= 0; i -= 4) {
        xil_printf("%08x %08x %08x %08x\r\n",
                   (unsigned)src[i], (unsigned)src[i-1],
                   (unsigned)src[i-2], (unsigned)src[i-3]);
    }
}

// Return 0 on success, -1 on timeout, -2 on DMA error.
static int wait_for_status(uint32_t bit) {
    uint32_t i;
    for (i = 0; i < TIMEOUT; i++) {
        uint32_t status = HWreg[STATUS];
        if (status & ERROR_BIT)
            return -2;
        if (status & bit)
            return 0;
    }
    return -1;
}

// Compute A * B * (2^377)^(-1) modulo M in FPGA hardware.
// All four arguments point to arrays of 32 uint32_t words.
int montgomery_mult(const uint32_t A[32],
                    const uint32_t B[32],
                    const uint32_t M[32],
                    uint32_t result[32]) {
    int rc;

    // A new operation is accepted only after the old one is IDLE.
    HWreg[COMMAND] = 0;
    rc = wait_for_status(IDLE_BIT);
    if (rc != 0)
        return rc;

    memcpy(idata_A, A, sizeof(idata_A));
    memcpy(idata_B, B, sizeof(idata_B));
    memcpy(idata_M, M, sizeof(idata_M));
    memset(odata, 0, sizeof(odata));

    // Flush cached CPU writes before the non-coherent DMA reads DDR.
    Xil_DCacheFlushRange((INTPTR)idata_A, sizeof(idata_A));
    Xil_DCacheFlushRange((INTPTR)idata_B, sizeof(idata_B));
    Xil_DCacheFlushRange((INTPTR)idata_M, sizeof(idata_M));
    Xil_DCacheFlushRange((INTPTR)odata, sizeof(odata));

    // These register values are ADDRESSES, not the 377-bit operands.
    HWreg[RXADDR_A] = (uint32_t)(uintptr_t)idata_A;
    HWreg[RXADDR_B] = (uint32_t)(uintptr_t)idata_B;
    HWreg[RXADDR_M] = (uint32_t)(uintptr_t)idata_M;
    HWreg[TXADDR]   = (uint32_t)(uintptr_t)odata;

    HWreg[COMMAND] = 1;
    rc = wait_for_status(DONE_BIT);
    HWreg[COMMAND] = 0;  // Allow FSM to leave STATE_DONE.
    if (rc != 0)
        return rc;

    // DMA has written the result: discard any stale cached copy.
    Xil_DCacheInvalidateRange((INTPTR)odata, sizeof(odata));
    memcpy(result, odata, sizeof(odata));

    // Wait until the accelerator can accept another operation.
    return wait_for_status(IDLE_BIT);
}

int main(void) {
    uint32_t result[32];
    int rc;

    init_platform();
    init_performance_counters(0);
    xil_printf("\r\nRUN2 - Begin Montgomery FPGA test\r\n");

    // Test 1: compare with the expected value from the 2026 testvector.
    xil_printf("\r\nTest 1: MontMul(G_X, G_Y, modulus)\r\n");
START_TIMING
    rc = montgomery_mult(G_X, G_Y, modulus, result);
STOP_TIMING

    if (rc != 0) {
        xil_printf("Test 1 ERROR: %d, status = %08x\r\n",
                   rc, (unsigned)HWreg[STATUS]);
        cleanup_platform();
        return 1;
    }

    xil_printf("Expected:\r\n");
    print_array_contents(expected_first);
    xil_printf("Received:\r\n");
    print_array_contents(result);

    if (memcmp(result, expected_first, sizeof(result)) != 0) {
        xil_printf("TEST 1 FAILED\r\n");
        cleanup_platform();
        return 1;
    }
    xil_printf("TEST 1 PASSED\r\n");

    // Test 2: R_N = 2^377 mod modulus, so MontMul(G_X, R_N, modulus) = G_X.
    // This also checks that a second command works without resetting the FPGA.
    xil_printf("\r\nTest 2: MontMul(G_X, R_N, modulus)\r\n");
    rc = montgomery_mult(G_X, R_N, modulus, result);
    if (rc != 0) {
        xil_printf("Test 2 ERROR: %d, status = %08x\r\n",
                   rc, (unsigned)HWreg[STATUS]);
        cleanup_platform();
        return 1;
    }

    xil_printf("Expected G_X:\r\n");
    print_array_contents(G_X);
    xil_printf("Received:\r\n");
    print_array_contents(result);

    if (memcmp(result, G_X, sizeof(result)) != 0) {
        xil_printf("TEST 2 FAILED\r\n");
        cleanup_platform();
        return 1;
    }
    xil_printf("TEST 2 PASSED\r\n");
    xil_printf("\r\nBoth FPGA tests passed!\r\n");

    cleanup_platform();
    return 0;
}
