const std = @import("std");
const luaz = @import("luaz");
const c = @import("c");

extern fn external_consumer_smoke() c_int;
extern fn compiler_budget_begin(limit: usize) void;
extern fn compiler_budget_end() usize;
extern fn compiler_backing_fail() void;
extern fn compiler_meter_refused() bool;

fn recover() !void {
    compiler_budget_begin(std.math.maxInt(usize));
    const result = luaz.Compiler.compileBounded("return 42", .{}, 4096);
    const refused = compiler_meter_refused();
    const live = compiler_budget_end();
    defer result.deinit();
    if (result != .ok or refused or live != 0) return error.CompilerDidNotRecover;
}

pub fn main() !void {
    if (external_consumer_smoke() != 0) return error.NativeConsumerFailed;
    var source = [_]u8{' '} ** 8192 ++ "local function answer() return 42 end return answer()".*;
    for ([_]bool{ false, true }) |backing_failure| {
        compiler_budget_begin(if (backing_failure) std.math.maxInt(usize) else 4096);
        if (backing_failure) compiler_backing_fail();
        const result = luaz.Compiler.compileBounded(&source, .{}, 4096);
        const refused = compiler_meter_refused();
        const live = compiler_budget_end();
        defer result.deinit();
        if (result != .allocation_failed or refused == backing_failure or live != 0)
            return error.ExpectedAllocationFailure;
        try recover();

        compiler_budget_begin(if (backing_failure) std.math.maxInt(usize) else 4096);
        if (backing_failure) compiler_backing_fail();
        const convenience = luaz.Compiler.compile(&source, .{});
        const convenience_refused = compiler_meter_refused();
        const convenience_live = compiler_budget_end();
        if (convenience) |blob| {
            blob.deinit();
            return error.ExpectedOutOfMemory;
        } else |err| {
            if (err != error.OutOfMemory) return err;
        }
        if (convenience_refused == backing_failure or convenience_live != 0)
            return error.InvalidAllocationEvidence;
        try recover();
    }

    const baseline = luaz.Compiler.compileBounded("return 42", .{}, 4096);
    defer baseline.deinit();
    if (baseline != .ok) return error.ExpectedBytecode;
    for ([_]usize{ baseline.ok.len, baseline.ok.len - 1 }) |limit| {
        compiler_budget_begin(std.math.maxInt(usize));
        const bounded = luaz.Compiler.compileBounded("return 42", .{}, limit);
        const refused = compiler_meter_refused();
        const live = compiler_budget_end();
        defer bounded.deinit();
        if (refused or live != 0) return error.InvalidOutputLimitEvidence;
        if (limit == baseline.ok.len) {
            if (bounded != .ok) return error.ExpectedInclusiveSuccess;
        } else if (bounded != .output_limit_exceeded) return error.ExpectedOutputLimit;
    }
    compiler_budget_begin(std.math.maxInt(usize));
    var output: [*c]u8 = undefined;
    var size: usize = 1;
    const status = c.luaz_compile_bounded("return 6 *", 10, null, 0, &output, &size);
    const refused = compiler_meter_refused();
    const live = compiler_budget_end();
    if (status != c.LUAZ_COMPILE_OUTPUT_LIMIT_EXCEEDED or output != null or size != 0 or refused or live != 0)
        return error.ExpectedEmptyOutputLimit;
    const syntax = try luaz.Compiler.compile("return 6 *", .{});
    defer syntax.deinit();
    if (syntax != .err) return error.ExpectedCompileError;
    try recover();
}
