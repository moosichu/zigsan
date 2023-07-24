#include <stdint.h>

void addition_overflow(void)
{
    int32_t max_int32 = INT32_MAX;
    max_int32 += 1;
}

void subtraction_overflow(void)
{
    int32_t min_int32 = INT32_MIN;
    min_int32 -= 1;
}

void multiplication_overflow(void)
{
    int32_t max_int32 = INT32_MAX;
    max_int32 *= 2;
}

void negation_overflow(void)
{
    int32_t min_int32 = INT32_MIN;
    min_int32 = -min_int32;
}

void division_overflow(void)
{
    int32_t min_int32 = INT32_MIN;
    min_int32 /= -1;
}

void division_by_0(void)
{
    int32_t int32 = 1;
    int32 /= 0;
}

void shift_by_negative(void)
{
    int32_t int32 = 1;
    int32 = int32 << -1;
}

void shift_out_of_bounds(void)
{
    int32_t int32 = 1;
    int32 = int32 << 33;
}

void shift_out_of_bounds_2(void)
{
    int32_t int32 = 0b100;
    int32 = int32 << 31;
}

void array_out_of_bounds(void)
{
    int32_t int32[1] = {1};
    int32[2] = 2;
}
