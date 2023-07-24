
#include <typeinfo>
#include <string.h>

// TODO: translate (do this part in zig?)
// #if SANITIZER_MAC && !(defined(__arm64__) && SANITIZER_IOS)
// # define SANITIZER_NON_UNIQUE_TYPEINFO 0
// #else
// # define SANITIZER_NON_UNIQUE_TYPEINFO 1
// #endif
// https://github.com/llvm-mirror/compiler-rt/blob/69445f095c22aac2388f939bedebf224a6efcdaf/lib/sanitizer_common/sanitizer_platform.h

#define SANITIZER_NON_UNIQUE_TYPEINFO 1

extern "C" bool cppCheckTypeInfoEquality(void * typeInfo1Ptr, void * typeInfo2Ptr)
{
    std::type_info const * typeInfo1 = static_cast<std::type_info const *>(typeInfo1Ptr);
    std::type_info const * typeInfo2 = static_cast<std::type_info const *>(typeInfo2Ptr);
    return SANITIZER_NON_UNIQUE_TYPEINFO && typeInfo1->name()[0] != '*' &&
         typeInfo2->name()[0] != '*' &&
         (strcmp(typeInfo1->name(), typeInfo2->name()) != 0);
}
