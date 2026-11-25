#include "common.h"
#include "sw/ec.h"
#include <string.h>

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

static int check_point(const char *name, const Point *p, const Point *expected) {
    for (unsigned i = 0; i < 4; ++i) {
        for (unsigned w = 0; w < 32; ++w) {
            if (p->coord[i][w] != expected->coord[i][w]) {
                xil_printf("%s.%c word %d: got %08x expected %08x\r\n",
                           name, "XYZT"[i], w, p->coord[i][w], expected->coord[i][w]);
                return 0;
            }
        }
    }
    return 1;
}

static int run(void) {
    static Point g, p, k, c, cp, expected_c, expected_cp;
    Field product, altered;
    int rc = accelerator_check();
    if (rc) {
        xil_printf("FPGA ID mismatch: program the new ECA1 bitstream.\r\n");
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
    int c_ok = check_point("C", &c, &expected_c);
    int cp_ok = check_point("C prime", &cp, &expected_cp);
    if (rc != 1 || !c_ok || !cp_ok) return -5;
    xil_printf("PASS: valid signature, C and C prime match.\r\n");
    memcpy(altered, message, sizeof(Field));
    altered[0] ^= 1U;
    rc = verify_signature(altered, K_X_Modn, s, modulus, &g, &p, &k, &c, &cp);
    if (rc < 0) return rc;
    if (rc != 0) return -6;
    xil_printf("PASS: changed message rejected.\r\n");
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
