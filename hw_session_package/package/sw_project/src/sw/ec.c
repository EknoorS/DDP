#include "ec.h"
#include <string.h>

int ec_scalar_mult(const Field scalar, const Point *base, Point *out) {
    Point acc = {0};
    acc.coord[Y][0] = 1;
    acc.coord[Z][0] = 1;
    // Match the course reference's projective scale by skipping leading zeros.
    int bit = 252;
    while (bit >= 0 && !(scalar[bit / 32] & (1U << (bit % 32)))) --bit;
    for (; bit >= 0; --bit) {
        int rc = ec_add(&acc, &acc, &acc);
        if (rc) return rc;
        if (scalar[bit / 32] & (1U << (bit % 32))) {
            rc = ec_add(&acc, base, &acc);
            if (rc) return rc;
        }
    }
    *out = acc;
    return 0;
}

// Shamir's trick for the public verification scalars. Bit order is (m_i,r_i).
static int joint_scalar_mult(const Field m, const Point *g, const Field r,
                             const Point *p, Point *out) {
    Point acc = {0}, g_plus_p;
    const Point *addend[4] = {NULL, p, g, &g_plus_p};
    acc.coord[Y][0] = 1;
    acc.coord[Z][0] = 1;
    int rc = ec_add(g, p, &g_plus_p);
    if (rc) return rc;
    int bit = 252;
    while (bit >= 0 && !((m[bit / 32] | r[bit / 32]) & (1U << (bit % 32)))) --bit;
    for (; bit >= 0; --bit) {
        unsigned shift = bit % 32;
        unsigned pair = (((m[bit / 32] >> shift) & 1U) << 1)
                      | ((r[bit / 32] >> shift) & 1U);
        rc = ec_add(&acc, &acc, &acc);
        if (rc) return rc;
        if (pair) {
            rc = ec_add(&acc, addend[pair], &acc);
            if (rc) return rc;
        }
    }
    *out = acc;
    return 0;
}

int verify_signature(const Field message, const Field r, const Field s,
                     const Field modulus, const Point *g, const Point *public_key,
                     const Point *k, Point *c, Point *c_prime) {
    Field lhs, rhs;
    int rc = joint_scalar_mult(message, g, r, public_key, c);
    if (rc) return rc;
    rc = ec_scalar_mult(s, k, c_prime);
    if (rc) return rc;
    rc = montgomery_mult(c->coord[X], c_prime->coord[Z], modulus, lhs);
    if (rc) return rc;
    rc = montgomery_mult(c_prime->coord[X], c->coord[Z], modulus, rhs);
    if (rc) return rc;
    return memcmp(lhs, rhs, sizeof(Field)) == 0;
}
