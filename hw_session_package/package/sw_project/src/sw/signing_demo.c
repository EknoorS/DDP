// Reproducible classroom fixture. The public key, nonce and digest here are
// test values. The demo always signs the same digest with this fixed nonce.
#include "ec.h"
#include "xil_printf.h"
#include <string.h>

extern Field modulus, R2_N;
static const Field order = {
    0x00000001U, 0x0a118000U, 0xd0000001U, 0x59aa76feU,
    0x5c37b001U, 0x60b44d1eU, 0x9a2ca556U, 0x12ab655eU
};
static const Field r2_order = {
    0x57243d96U, 0x4e71d642U, 0x2927b89dU, 0x995c347aU,
    0xe4d19b47U, 0x81fe2891U, 0x545f6a79U, 0x111fedf2U
};
static const Field test_d = {
    0x01844a46U, 0x12436935U, 0xe9e4980cU, 0xd23d5cf4U,
    0x5d42e1c7U, 0x55c4d092U, 0x611109f4U, 0x00beee33U
};
static const Field test_k = {
    0x110d7cdbU, 0xc180eb24U, 0x9bf99d11U, 0x0c2ce926U,
    0x40b1d86fU, 0x663cb58dU, 0x5ffca799U, 0x00349937U
};
static const Field test_m = {
    0xbdc01332U, 0xf43241c8U, 0x968a54faU, 0x9a2e394dU,
    0x9f83521eU, 0xef0da1e2U, 0x083a428cU, 0x1170763cU
};
static const Field expected_r = {
    0x914122e0U, 0x44f03b60U, 0x2047f45bU, 0xe01f57c3U,
    0x8758e4f7U, 0x4b229988U, 0xff943e59U, 0x0a6ee01eU
};
static const Field expected_s = {
    0xf86f213fU, 0xa32e3752U, 0x3b47b251U, 0x148e4fefU,
    0x742717eaU, 0x9af981f1U, 0x81454e67U, 0x037b22d1U
};

static const Field one = {1};
static const Field zero = {0};
enum { FIELD_WORDS = 12 }; // ceil(377 / 32); the DMA buffer has 32 words.

// R = 2^377 for both moduli. Turn one operand into a Montgomery residue,
// then the second Montgomery call produces an ordinary modular product.
static int product_mod(const Field a, const Field b, const Field m,
                       const Field r2, Field out) {
    Field a_mont;
    int rc = montgomery_mult(a, r2, m, a_mont);
    if (rc) return rc;
    return montgomery_mult(a_mont, b, m, out);
}

// For a prime m and nonzero input, a^(-1) = a^(m-2) mod m.
static int inverse_mod(const Field a, const Field m, const Field r2, Field out) {
    Field power, acc, exponent;
    if (!memcmp(a, zero, sizeof(Field))) return -8;
    memcpy(exponent, m, sizeof(Field));
    // Both course primes have low word 1; subtract 2 with a borrow.
    uint64_t borrow = 2;
    for (unsigned i = 0; borrow && i < FIELD_WORDS; ++i) {
        uint64_t word = exponent[i];
        exponent[i] = (uint32_t)(word - borrow);
        borrow = word < borrow;
    }
    int rc = montgomery_mult(a, r2, m, power);
    if (rc) return rc;
    rc = montgomery_mult(one, r2, m, acc);
    if (rc) return rc;
    for (int bit = 376; bit >= 0; --bit) {
        rc = montgomery_mult(acc, acc, m, acc);
        if (rc) return rc;
        if ((exponent[bit / 32] >> (bit % 32)) & 1U) {
            rc = montgomery_mult(acc, power, m, acc);
            if (rc) return rc;
        }
    }
    return montgomery_mult(acc, one, m, out);
}

// The input is below 2*n. A single subtraction puts it in [0,n).
static void reduce_once(Field value) {
    Field diff = {0};
    uint64_t borrow = 0;
    for (unsigned i = 0; i < FIELD_WORDS; ++i) {
        uint64_t sub = (uint64_t)order[i] + borrow;
        diff[i] = (uint32_t)((uint64_t)value[i] - sub);
        borrow = (uint64_t)value[i] < sub;
    }
    if (!borrow) memcpy(value, diff, sizeof(Field));
}

static void reduce_x_to_order(const Field x, Field r) {
    memset(r, 0, sizeof(Field));
    for (int bit = 376; bit >= 0; --bit) {
        uint32_t carry = (x[bit / 32] >> (bit % 32)) & 1U;
        for (unsigned i = 0; i < FIELD_WORDS; ++i) {
            uint32_t next = r[i] >> 31;
            r[i] = (r[i] << 1) | carry;
            carry = next;
        }
        reduce_once(r);
    }
}

static void add_mod_order(const Field a, const Field b, Field out) {
    uint64_t carry = 0;
    memset(out, 0, sizeof(Field));
    for (unsigned i = 0; i < FIELD_WORDS; ++i) {
        uint64_t sum = (uint64_t)a[i] + b[i] + carry;
        out[i] = (uint32_t)sum;
        carry = sum >> 32;
    }
    reduce_once(out);
}

int run_signing_demo(const Point *g) {
    static Point pub, k_point, c, cp;
    Field z_inv, x, r, dr, sum, k_inv, signature_s, altered;
    xil_printf("DEMO: deriving P=dG and K=kG with the FPGA point engine.\r\n");
    int rc = ec_scalar_mult(test_d, g, &pub);
    if (rc) return rc;
    rc = ec_scalar_mult(test_k, g, &k_point);
    if (rc) return rc;
    rc = inverse_mod(k_point.coord[Z], modulus, R2_N, z_inv);
    if (rc) return rc;
    rc = product_mod(k_point.coord[X], z_inv, modulus, R2_N, x);
    if (rc) return rc;
    reduce_x_to_order(x, r);
    xil_printf("DEMO: computing s with the same multiplier, modulo n.\r\n");
    rc = product_mod(test_d, r, order, r2_order, dr);
    if (rc) return rc;
    add_mod_order(test_m, dr, sum);
    rc = inverse_mod(test_k, order, r2_order, k_inv);
    if (rc) return rc;
    rc = product_mod(k_inv, sum, order, r2_order, signature_s);
    if (rc) return rc;
    // Independent values from the course Python point formulas and integer arithmetic.
    if (memcmp(r, expected_r, sizeof(Field)) ||
        memcmp(signature_s, expected_s, sizeof(Field))) return -9;
    rc = verify_signature(test_m, r, signature_s, modulus, g, &pub, &k_point, &c, &cp);
    if (rc != 1) return rc < 0 ? rc : -10;
    memcpy(altered, test_m, sizeof(Field));
    altered[0] ^= 1U;
    rc = verify_signature(altered, r, signature_s, modulus, g, &pub, &k_point, &c, &cp);
    if (rc != 0) return rc < 0 ? rc : -11;
    xil_printf("DEMO PASS: r and s match Python, signature accepted, changed digest rejected.\r\n");
    return 0;
}
