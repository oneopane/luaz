#pragma once
#include <stddef.h>
#include "luacode.h"

#ifdef __cplusplus
extern "C" {
#define LUAZ_NOEXCEPT noexcept
#else
#define LUAZ_NOEXCEPT
#endif

typedef enum Luaz_CompileStatus {
    LUAZ_COMPILE_OK = 0,
    LUAZ_COMPILE_ERROR = 1,
    LUAZ_COMPILE_OUTPUT_LIMIT_EXCEEDED = 2,
    LUAZ_COMPILE_INTERNAL_ERROR = 3,
    LUAZ_COMPILE_ALLOCATION_FAILED = 4
} Luaz_CompileStatus;

// Success and syntax errors own a malloc blob, released with free(). All other
// outcomes set *output=null and *output_size=0. The ceiling is inclusive and
// bounds the returned copy, not compiler working memory (owned by the caller).
// Allocation failure does not identify its cause: a caller-owned meter must
// separately record whether it refused an allocation.
// source, output and output_size must be valid; options may be null.
Luaz_CompileStatus luaz_compile_bounded(const char* source, size_t source_size,
    const lua_CompileOptions* options, size_t output_limit,
    char** output, size_t* output_size) LUAZ_NOEXCEPT;

#ifdef __cplusplus
}
#endif
#undef LUAZ_NOEXCEPT
