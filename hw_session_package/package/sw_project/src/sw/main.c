#include "common.h"
#include "ec.h"
#include <string.h>

#ifndef RUN_SIGNING_DEMO
#define RUN_SIGNING_DEMO 0
#endif
// Set this symbol to 1 in the Vitis debugger to use the same ELF and bitstream.
volatile unsigned demo_enabled = RUN_SIGNING_DEMO;
int run_signing_demo(const Point *g);

extern Field modulus, message, K_X_Modn, s, R_N;
extern Field G_X, G_Y, G_Z, G_T, Public_X, Public_Y, Public_Z, Public_T;
extern Field K_X, K_Y, K_Z, K_T, C_X, C_Y, C_Z, C_T;
extern Field C_Prime_X, C_Prime_Y, C_Prime_Z, C_Prime_T;

static void load_point(Point *p, const Field x, const Field y,
                       const Field z, const Field t) {
    memcpy(p->coord[X], x, sizeof(Field));
    memcpy(p->coord[Y], y, sizeof(Field));
    memcpy(p->coord[Z], z, sizeof(Field));
    memcpy(p->coord[T], t, sizeof(Field));
}

// Different addition orders can return the same point with a different scale.
static int same_point(const Point *a, const Point *b) {
    static const Field zero = {0};
    Field left, right;
    if (!memcmp(a->coord[Z], zero, sizeof(Field)) ||
        !memcmp(b->coord[Z], zero, sizeof(Field))) return 0;
    for (unsigned axis = X; axis <= Y; ++axis) {
        int rc = montgomery_mult(a->coord[axis], b->coord[Z], modulus, left);
        if (rc) return rc;
        rc = montgomery_mult(b->coord[axis], a->coord[Z], modulus, right);
        if (rc) return rc;
        if (memcmp(left, right, sizeof(Field))) return 0;
    }
    return 1;
}

static int run(void) {
    static Point g, p, k, c, cp, expected_c, expected_cp;
    Field product, altered;
    int rc = accelerator_check();
    if (rc) {
        xil_printf("FPGA ID mismatch: program the Shamir / merged-shift build.\r\n");
        return rc;
    }
    rc = montgomery_mult(G_X, R_N, modulus, product);
    if (rc) return rc;
    if (memcmp(product, G_X, sizeof(Field))) return -4;
    xil_printf("ECA1: Montgomery smoke test passed. Starting verification.\r\n");
    load_point(&g, G_X, G_Y, G_Z, G_T);
    load_point(&p, Public_X, Public_Y, Public_Z, Public_T);
    load_point(&k, K_X, K_Y, K_Z, K_T);
    load_point(&expected_c, C_X, C_Y, C_Z, C_T);
    load_point(&expected_cp, C_Prime_X, C_Prime_Y, C_Prime_Z, C_Prime_T);
    START_TIMING
    rc = verify_signature(message, K_X_Modn, s, modulus, &g, &p, &k, &c, &cp);
    STOP_TIMING
    if (rc < 0) return rc;
    if (rc != 1) return -5;
    rc = same_point(&c, &expected_c);
    if (rc != 1) return rc < 0 ? rc : -5;
    // sK still follows the original scalar loop, so its exact coordinates agree.
    if (memcmp(&cp, &expected_cp, sizeof(Point))) return -5;
    xil_printf("PASS: signature and both reference points match.\r\n");
    memcpy(altered, message, sizeof(Field));
    altered[0] ^= 1U;
    rc = verify_signature(altered, K_X_Modn, s, modulus, &g, &p, &k, &c, &cp);
    if (rc < 0) return rc;
    if (rc != 0) return -6;
    xil_printf("PASS: changed message rejected.\r\n");
    if (demo_enabled) return run_signing_demo(&g);
    return 0;
}

int main(void) {
    init_platform();
    init_performance_counters(1);
    int rc = run();
    if (rc) xil_printf("FAIL (%d)\r\n", rc);
    cleanup_platform();
    return rc != 0;
}
