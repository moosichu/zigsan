#include "ubsan_tests.h"
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
    int32_t test = int32[1];
}

void builtin_unreachable(void)
{
    __builtin_unreachable();
}

// TODO: test the formatting for all float sizes!
void f16_cast_overflow(void)
{
    _Float16 max_f16 = __FLT16_MAX__;
    int16_t int16 = (int16_t) max_f16;
}

void f32_cast_overflow(void)
{
    float max_f32 = __FLT_MAX__;
    int32_t int32 = (int32_t) max_f32;
}

void f64_cast_overflow(void)
{
    double max_f64 = __FLT_MAX__;
    int64_t int64 = (int64_t) max_f64;
}

void f80_cast_overflow(void)
{
    long double max_f80 = __FLT_MAX__;
    int64_t int64 = (int64_t) max_f80;
}

void test_function(int32_t arg) {}
typedef int32_t wrong_function_type(uint64_t);

void function_type_mismatch(void)
{
    wrong_function_type * wrong_test_functionn = &test_function;
    int32_t my_result = wrong_test_functionn((uint64_t) 0);
}
