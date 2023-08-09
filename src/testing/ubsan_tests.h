#include <stdint.h>

void additionOverflow(void);
void subtractionOverflow(void);
void multiplicationOverflow(void);
void negationOverflow(void);
void divisionOverflow(void);
void divisionBy0(void);
void shiftByNegative(void);
void shiftOutOfBounds(void);
void shiftOutOfBounds2(void);
void arrayOutOfBounds(void);
void functionTypeMismatch(void);
void builtinUnreachable(void);
void f16CastOverflow(void);
void f32CastOverflow(void);
void f64CastOverflow(void);
void f80CastOverflow(void);
void alignmentAssumption(void);
void invalidBool(void);
void invalidBoolAliased(void);
void invalidEnum(void);
void signedIntegerTruncation(void);
void unsignedIntegerTruncation(void);
void signChange(void);
void signedIntegerOrSignChange(void);

// C++ only errors
int32_t empty_return(void);
