#ifndef EC_H
#define EC_H
#include <stdint.h>
// Defines the memory layout of a field element and a point, plus the function declarations shared by the C files.
typedef uint32_t Field[32];
enum { X, Y, Z, T };
typedef struct { Field coord[4]; } Point;

int accelerator_check(void);
int montgomery_mult(const Field a, const Field b, const Field m, Field out);
int ec_add(const Point *a, const Point *b, Point *out);
int ec_scalar_mult(const Field scalar, const Point *base, Point *out);
// 1 = valid, 0 = invalid, negative = hardware error.
int verify_signature(const Field message, const Field r, const Field s,
                     const Field modulus, const Point *g, const Point *public_key,
                     const Point *k, Point *c, Point *c_prime);
#endif
