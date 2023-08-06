#include "ubsan_tests.h"
#include <stdbool.h>
#include <stdint.h>

void additionOverflow(void)
{
    int32_t max_int32 = INT32_MAX;
    max_int32 += 1;
}

void subtractionOverflow(void)
{
    int32_t min_int32 = INT32_MIN;
    min_int32 -= 1;
}

void multiplicationOverflow(void)
{
    int32_t max_int32 = INT32_MAX;
    max_int32 *= 2;
}

void negationOverflow(void)
{
    int32_t min_int32 = INT32_MIN;
    min_int32 = -min_int32;
}

void divisionOverflow(void)
{
    int32_t min_int32 = INT32_MIN;
    min_int32 /= -1;
}

void divisionBy0(void)
{
    int32_t int32 = 1;
    int32 /= 0;
}

void shiftByNegative(void)
{
    int32_t int32 = 1;
    int32 = int32 << -1;
}

void shiftOutOfBounds(void)
{
    int32_t int32 = 1;
    int32 = int32 << 33;
}

void shiftOutOfBounds2(void)
{
    int32_t int32 = 0b100;
    int32 = int32 << 31;
}

void arrayOutOfBounds(void)
{
    int32_t int32[1] = {1};
    int32_t test = int32[1];
}

void builtinUnreachable(void)
{
    __builtin_unreachable();
}

// TODO: test the formatting for all float sizes!
void f16CastOverflow(void)
{
    _Float16 max_f16 = __FLT16_MAX__;
    int16_t int16 = (int16_t) max_f16;
}

void f32CastOverflow(void)
{
    float max_f32 = __FLT_MAX__;
    int32_t int32 = (int32_t) max_f32;
}

void f64CastOverflow(void)
{
    double max_f64 = __FLT_MAX__;
    int64_t int64 = (int64_t) max_f64;
}

void f80CastOverflow(void)
{
    long double max_f80 = __FLT_MAX__;
    int64_t int64 = (int64_t) max_f80;
}

void alignmentAssumption(void)
{
    struct AlignedStruct
    {
        int64_t a;
        int8_t b;
        int8_t c;
    } aligned_struct;
    int64_t int64 = *((int64_t *) &aligned_struct.c);
}

void invalidBool(void)
{
    int8_t bad_bool = 4;
    bool test_bool = *((bool *) &bad_bool);
}

// This is considered an enum under the llvm ubsan rt!
void invalidBoolAliased(void)
{
    typedef bool test_bool_type;
    int8_t bad_bool = 3;
    test_bool_type test_bool = *((test_bool_type *) &bad_bool);
}

void invalidEnum(void)
{
    enum Enum
    {
        a = 0,
        b = 1,
        c = 2,
    };

    int bad_enum = 5;
    enum Enum enum_value = *((enum Enum *) &bad_enum);
}

void notNull(__nonnull void * arg) {}
void nonNull(void)
{
    notNull(0);
}

void dereferenceNull(void)
{
    int32_t int32 = *((int32_t *) (0));
}

void testFunction(int32_t arg) {}
typedef int32_t wrongFunctionType(uint64_t);

void functionTypeMismatch(void)
{
    wrongFunctionType * wrong_test_functionn = &testFunction;
    int32_t my_result = wrong_test_functionn((uint64_t) 0);
}
