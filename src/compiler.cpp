#include "compiler.h"
#include "Luau/Compiler.h"
#include <cstdlib>
#include <cstring>
#include <new>
#include <string>

#ifdef LUAZ_TEST_RETURNED_COPY_ALLOCATOR
// External fixture supplies this C++-linkage binding only in injected builds.
void* luaz_test_returned_copy_allocate(size_t size);
#endif

Luaz_CompileStatus luaz_compile_bounded(const char* source, size_t source_size,
    const lua_CompileOptions* options, size_t output_limit,
    char** output, size_t* output_size) noexcept
{
    *output = nullptr;
    *output_size = 0;
    try
    {
        Luau::CompileOptions opts;
        if (options)
        {
            static_assert(sizeof(lua_CompileOptions) == sizeof(Luau::CompileOptions));
            std::memcpy(static_cast<void*>(&opts), options, sizeof(opts));
        }
        const std::string result = Luau::compile(std::string(source, source_size), opts);
        if (result.size() > output_limit)
            return LUAZ_COMPILE_OUTPUT_LIMIT_EXCEEDED;
        if (result.empty())
            return LUAZ_COMPILE_INTERNAL_ERROR;
#ifdef LUAZ_TEST_RETURNED_COPY_ALLOCATOR
        char* copy = static_cast<char*>(luaz_test_returned_copy_allocate(result.size()));
#else
        char* copy = static_cast<char*>(std::malloc(result.size()));
#endif
        if (!copy)
            return LUAZ_COMPILE_ALLOCATION_FAILED;
        std::memcpy(copy, result.data(), result.size());
        *output = copy;
        *output_size = result.size();
        return result[0] == 0 ? LUAZ_COMPILE_ERROR : LUAZ_COMPILE_OK;
    }
    catch (const std::bad_alloc&)
    {
        return LUAZ_COMPILE_ALLOCATION_FAILED;
    }
    catch (...)
    {
        return LUAZ_COMPILE_INTERNAL_ERROR;
    }
}
