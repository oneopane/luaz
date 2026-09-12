const std = @import("std");

extern fn luaz_native_consumer_smoke() c_int;
extern fn luaz_native_consumer_failure_smoke() c_int;

test "native compiler and VM package boundary" {
    try std.testing.expectEqual(@as(c_int, 0), luaz_native_consumer_smoke());
}

test "native compiler error buffer and load failure cleanup" {
    try std.testing.expectEqual(@as(c_int, 0), luaz_native_consumer_failure_smoke());
}
