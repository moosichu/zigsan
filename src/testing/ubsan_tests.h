#include <stdint.h>

void addition_overflow(void);
void subtraction_overflow(void);
void multiplication_overflow(void);
void negation_overflow(void);
void division_overflow(void);
void division_by_0(void);
void shift_by_negative(void);
void shift_out_of_bounds(void);
void shift_out_of_bounds_2(void);
void array_out_of_bounds(void);
void function_type_mismatch(void);
void builtin_unreachable(void);
void f16_cast_overflow(void);
void f32_cast_overflow(void);
void f64_cast_overflow(void);
void f80_cast_overflow(void);

// C++ only errors
int32_t empty_return(void);
