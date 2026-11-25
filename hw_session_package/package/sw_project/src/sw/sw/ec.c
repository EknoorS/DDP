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

int verify_signature(const Field message, const Field r, const Field s,
                     const Field modulus, const Point *g, const Point *public_key,
                     const Point *k, Point *c, Point *c_prime) {
    Point q, l;
    Field lhs, rhs;
    int rc = ec_scalar_mult(message, g, &q);
    if (rc) return rc;
    rc = ec_scalar_mult(r, public_key, &l);
    if (rc) return rc;
    rc = ec_add(&q, &l, c);
    if (rc) return rc;
    rc = ec_scalar_mult(s, k, c_prime);
    if (rc) return rc;
    rc = montgomery_mult(c->coord[X], c_prime->coord[Z], modulus, lhs);
    if (rc) return rc;
    rc = montgomery_mult(c_prime->coord[X], c->coord[Z], modulus, rhs);
    if (rc) return rc;
    return memcmp(lhs, rhs, sizeof(Field)) == 0;
}
