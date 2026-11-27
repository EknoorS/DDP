#include "ec.h"
#include "xil_cache.h"
#include "xil_io.h"
#include <stdalign.h>
#include <string.h>

enum { COMMAND, INPUT_A, OUTPUT, INPUT_B, MODULUS };
enum { DONE = 1, IDLE = 2, ERROR = 4 };
#define BASE 0x40400000U
#define REG(i) (BASE + 4U*(i))
#define EC_IMAGE 0x45434131U

// Single-threaded bare-metal driver. Each coordinate is one aligned DMA beat.
alignas(128) static Point arg_a, arg_b, answer;
alignas(128) static Field arg_m;

static int wait_status(unsigned mask) {
    for (unsigned i = 0; i < 100000000U; ++i) {
        uint32_t status = Xil_In32(REG(COMMAND));
        if (status & ERROR) return -2;
        if (status & mask) return 0;
    }
    return -1;
}

// The comparison build fixes M=q; reject any call asking it to use another M.
extern Field modulus;
static int variable_modulus;
int accelerator_check(void) {
    if (Xil_In32(REG(INPUT_A)) != EC_IMAGE) return -3;
    uint32_t version = Xil_In32(REG(OUTPUT));
    if (version != 0x53484d30U && version != 0x53484d31U) return -3;
    variable_modulus = version == 0x53484d31U;
    return 0;
}

static int execute(unsigned command, unsigned size) {
    Xil_Out32(REG(COMMAND), 0);
    int rc = wait_status(IDLE);
    if (rc) return rc;
    Xil_DCacheFlushRange((INTPTR)&arg_a, size);
    Xil_DCacheFlushRange((INTPTR)&arg_b, size);
    Xil_DCacheFlushRange((INTPTR)&answer, size);
    if (command == 1) Xil_DCacheFlushRange((INTPTR)arg_m, sizeof(Field));
    Xil_Out32(REG(INPUT_A), (uint32_t)(uintptr_t)&arg_a);
    Xil_Out32(REG(INPUT_B), (uint32_t)(uintptr_t)&arg_b);
    Xil_Out32(REG(OUTPUT),  (uint32_t)(uintptr_t)&answer);
    Xil_Out32(REG(MODULUS), (uint32_t)(uintptr_t)arg_m);
    Xil_Out32(REG(COMMAND), command);
    rc = wait_status(DONE);
    Xil_Out32(REG(COMMAND), 0);
    if (rc) return rc;
    Xil_DCacheInvalidateRange((INTPTR)&answer, size);
    return wait_status(IDLE);
}

int montgomery_mult(const Field a, const Field b, const Field m, Field out) {
    if (!variable_modulus && memcmp(m, modulus, sizeof(Field))) return -7;
    memcpy(arg_a.coord[X], a, sizeof(Field));
    memcpy(arg_b.coord[X], b, sizeof(Field));
    memcpy(arg_m, m, sizeof(Field));
    int rc = execute(1, sizeof(Field));
    if (!rc) memcpy(out, answer.coord[X], sizeof(Field));
    return rc;
}

int ec_add(const Point *a, const Point *b, Point *out) {
    arg_a = *a;
    arg_b = *b;
    int rc = execute(2, sizeof(Point));
    if (!rc) *out = answer;
    return rc;
}
