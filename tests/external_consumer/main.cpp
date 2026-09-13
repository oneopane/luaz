#include "luaz_config.h"
#include "Luau/Compiler.h"
#include "lua.h"
#include "lualib.h"
#include "handler.h"
#include "luaz_compiler.h"
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <new>

// Consumer-owned deterministic allocator: production Luaz does not install it.
static thread_local bool metering;
static thread_local size_t live_bytes;
static thread_local size_t budget;
static thread_local size_t successful_allocations;
static thread_local bool meter_refused;
static thread_local bool fail_backing_allocation;
struct alignas(std::max_align_t) Allocation {
    size_t size;
    bool charged;
};

void* operator new(size_t size)
{
    if (size > std::numeric_limits<size_t>::max() - sizeof(Allocation))
        throw std::bad_alloc();
    if (metering && size > budget - live_bytes)
    {
        meter_refused = true;
        throw std::bad_alloc();
    }
    // This failure is independent of the caller's budget refusal latch.
    if (metering && fail_backing_allocation)
        throw std::bad_alloc();
    auto* allocation = static_cast<Allocation*>(std::malloc(sizeof(Allocation) + size));
    if (!allocation)
        throw std::bad_alloc();
    allocation->size = size;
    allocation->charged = metering;
    if (metering)
    {
        live_bytes += size;
        ++successful_allocations;
    }
    return allocation + 1;
}
void operator delete(void* pointer) noexcept
{
    if (!pointer)
        return;
    auto* allocation = static_cast<Allocation*>(pointer) - 1;
    if (allocation->charged)
        live_bytes -= allocation->size;
    std::free(allocation);
}
void* operator new[](size_t size) { return ::operator new(size); }
void operator delete[](void* pointer) noexcept { ::operator delete(pointer); }
void operator delete(void* pointer, size_t) noexcept { ::operator delete(pointer); }
void operator delete[](void* pointer, size_t) noexcept { ::operator delete(pointer); }

extern "C" void compiler_budget_begin(size_t limit)
{
    if (metering || live_bytes != 0)
        std::abort(); // This fixture deliberately rejects nested invocations.
    budget = limit;
    successful_allocations = 0;
    meter_refused = false;
    fail_backing_allocation = false;
    metering = true;
}
extern "C" void compiler_backing_fail() { fail_backing_allocation = true; }
extern "C" bool compiler_meter_refused() { return meter_refused; }
extern "C" size_t compiler_budget_end()
{
    metering = false;
    return live_bytes;
}

static_assert(LUA_USE_LONGJMP == 1);
static_assert(LUA_VECTOR_SIZE == EXPECTED_VECTOR_SIZE);
static_assert(LUAZ_COMPILE_OK == 0 && LUAZ_COMPILE_ERROR == 1 &&
    LUAZ_COMPILE_OUTPUT_LIMIT_EXCEEDED == 2 && LUAZ_COMPILE_INTERNAL_ERROR == 3 &&
    LUAZ_COMPILE_ALLOCATION_FAILED == 4);

extern "C" int external_consumer_smoke()
{
    char source[8192 + sizeof("local function answer() return 42 end return answer()")];
    std::memset(source, ' ', 8192);
    std::memcpy(source + 8192, "local function answer() return 42 end return answer()",
        sizeof("local function answer() return 42 end return answer()"));
    bool saw_success = false;
    bool saw_partial_allocation_failure = false;
    for (size_t limit = 4096; limit <= 1024 * 1024; limit *= 2)
    {
        compiler_budget_begin(limit);
        char* output = nullptr;
        size_t output_size = 0;
        const auto status = luaz_compile_bounded(source, sizeof(source) - 1, nullptr,
            4096, &output, &output_size);
        const auto remaining = compiler_budget_end();
        if (remaining != 0)
            return 10;
        if (status == LUAZ_COMPILE_ALLOCATION_FAILED)
        {
            if (output || output_size != 0 || !meter_refused)
                return 11;
            if (successful_allocations != 0)
                saw_partial_allocation_failure = true;
        }
        else if (status == LUAZ_COMPILE_OK)
        {
            if (meter_refused)
                return 14;
            saw_success = true;
            std::free(output);
        }
        else
            return 12;
    }
    if (!saw_success || !saw_partial_allocation_failure)
        return 13;
    compiler_budget_begin(std::numeric_limits<size_t>::max());
    compiler_backing_fail();
    char* failed_output = reinterpret_cast<char*>(1);
    size_t failed_size = 1;
    const auto failed_status = luaz_compile_bounded(source, sizeof(source) - 1, nullptr,
        4096, &failed_output, &failed_size);
    const bool refused = compiler_meter_refused();
    if (compiler_budget_end() != 0 || refused || failed_output || failed_size != 0 ||
        failed_status != LUAZ_COMPILE_ALLOCATION_FAILED)
        return 15;
    luau_set_assert_handler(nullptr);
    const auto bytecode = Luau::compile("return 6 * 7");
    lua_State* state = luaL_newstate();
    if (!state)
        return 1;
    int status = luau_load(state, "=external-consumer", bytecode.data(), bytecode.size(), 0);
    if (status == LUA_OK)
        status = lua_pcall(state, 0, 1, 0);
    const bool passed = status == LUA_OK && lua_tonumber(state, -1) == 42;
    lua_close(state);
    return passed ? 0 : 2;
}
