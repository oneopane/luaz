#include "luaz_config.h"
#include "Luau/Compiler.h"
#include "lua.h"
#include "luacode.h"
#include "lualib.h"
#include "handler.h"

#include <cstdlib>
#include <cstring>
#include <string>

extern "C" int luaz_native_consumer_smoke()
{
    const std::string bytecode = Luau::compile("return 6 * 7");
    lua_State* state = luaL_newstate();
    if (!state)
        return 1;

    const int load_status = luau_load(state, "=native-consumer", bytecode.data(), bytecode.size(), 0);
    if (load_status != LUA_OK)
    {
        lua_close(state);
        return 2;
    }

    const int call_status = lua_pcall(state, 0, 1, 0);
    if (call_status != LUA_OK)
    {
        lua_close(state);
        return 3;
    }

    const double result = lua_tonumber(state, -1);
    lua_close(state);
    return result == 42.0 ? 0 : 4;
}

extern "C" int luaz_native_consumer_failure_smoke()
{
    const char* invalid_source = "return 6 *";
    lua_CompileOptions options{};
    size_t bytecode_size = 0;
    char* bytecode = luau_compile(invalid_source, std::strlen(invalid_source), &options, &bytecode_size);
    if (!bytecode || bytecode_size == 0)
        return 1;

    const bool encoded_error = bytecode[0] == 0;
    lua_State* state = luaL_newstate();
    if (!state)
    {
        std::free(bytecode);
        return 2;
    }

    const int load_status = luau_load(state, "=invalid", bytecode, bytecode_size, 0);
    lua_close(state);
    std::free(bytecode);
    return encoded_error && load_status != LUA_OK ? 0 : 3;
}

static int native_consumer_assert_handler(const char*, const char*, int, const char*)
{
    return 1;
}

extern "C" int luaz_native_consumer_assert_smoke()
{
    luau_set_assert_handler(native_consumer_assert_handler);
    luau_set_assert_handler(nullptr);
    return 0;
}
