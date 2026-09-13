const std = @import("std");
const c = @import("c");
const luaz = @import("luaz");

extern fn luaz_native_consumer_smoke() c_int;
extern fn luaz_native_consumer_failure_smoke() c_int;
extern fn luaz_native_consumer_assert_smoke() c_int;

test "native compiler and VM package boundary" {
    try std.testing.expectEqual(@as(c_int, 0), luaz_native_consumer_smoke());
}

test "native compiler error buffer and load failure cleanup" {
    try std.testing.expectEqual(@as(c_int, 0), luaz_native_consumer_failure_smoke());
}

test "public luaz and c modules share the native assert boundary" {
    const handler: luaz.AssertHandler = null;

    // Exercise both documented Zig module surfaces.  The native smoke test
    // below resolves the same exported function through the package artifact.
    luaz.setAssertHandler(handler);
    c.luau_set_assert_handler(handler);

    try std.testing.expectEqual(@as(c_int, 0), luaz_native_consumer_assert_smoke());
}
