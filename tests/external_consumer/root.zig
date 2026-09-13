const std = @import("std");
const luaz = @import("luaz");
const c = @import("c");

extern fn external_consumer_smoke() c_int;
extern fn compiler_budget_begin(limit: usize) void;
extern fn compiler_budget_end() usize;
extern fn compiler_backing_fail() void;
extern fn compiler_meter_refused() bool;
extern fn compiler_copy_mode(mode: c_int) void;
extern fn compiler_copy_attempts() usize;
extern fn compiler_copy_live_bytes() usize;
extern fn compiler_concurrent_copy_isolation() bool;

fn copyFailures() !void {
    for ([_]c_int{ 2, 1 }) |mode| {
        compiler_budget_begin(std.math.maxInt(usize));
        compiler_copy_mode(mode);
        var output: [*c]u8 = @ptrFromInt(1);
        var size: usize = 1;
        const status = c.luaz_compile_bounded("return 42", 9, null, 4096, &output, &size);
        const refused = compiler_meter_refused();
        const live = compiler_budget_end();
        defer if (output != null) std.c.free(output);
        const expected = if (mode == 1) c.LUAZ_COMPILE_ALLOCATION_FAILED else c.LUAZ_COMPILE_INTERNAL_ERROR;
        if (status != expected or output != null or size != 0 or refused or live != 0 or
            compiler_copy_attempts() != 1 or compiler_copy_live_bytes() == 0)
            return error.ExpectedReturnedCopyFailure;
        try recover();
        compiler_budget_begin(std.math.maxInt(usize));
        compiler_copy_mode(mode);
        const result = luaz.Compiler.compile("return 42", .{});
        const mapping_refused = compiler_meter_refused();
        const mapping_live = compiler_budget_end();
        if (result) |blob| {
            blob.deinit();
            return error.ExpectedConvenienceFailure;
        } else |err| {
            const expected_error = if (mode == 1) error.OutOfMemory else error.CompilerInternalError;
            if (err != expected_error) return err;
        }
        if (mapping_refused or mapping_live != 0 or compiler_copy_attempts() != 1 or compiler_copy_live_bytes() == 0)
            return error.InvalidCopyFailureEvidence;
        try recover();
    }
}

fn recover() !void {
    compiler_budget_begin(std.math.maxInt(usize));
    const result = luaz.Compiler.compileBounded("return 42", .{}, 4096);
    const refused = compiler_meter_refused();
    const live = compiler_budget_end();
    defer result.deinit();
    if (result != .ok or refused or live != 0) return error.CompilerDidNotRecover;
    if (@import("test_options").copy_injection and compiler_copy_attempts() != 1)
        return error.ExpectedRecoveryCopy;
}

pub fn main() !void {
    if (@import("test_options").copy_injection) {
        try copyFailures();
        if (!compiler_concurrent_copy_isolation()) return error.ConcurrentCopyIsolationFailed;
        try recover();
    }
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
        if (compiler_copy_attempts() != 0) return error.UnexpectedCopyAttempt;
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
        if (limit < baseline.ok.len) compiler_copy_mode(2);
        const bounded = luaz.Compiler.compileBounded("return 42", .{}, limit);
        const refused = compiler_meter_refused();
        const live = compiler_budget_end();
        defer bounded.deinit();
        if (refused or live != 0) return error.InvalidOutputLimitEvidence;
        if (limit == baseline.ok.len) {
            if (bounded != .ok) return error.ExpectedInclusiveSuccess;
            if (@import("test_options").copy_injection and compiler_copy_attempts() != 1)
                return error.ExpectedInclusiveCopy;
        } else {
            if (bounded != .output_limit_exceeded) return error.ExpectedOutputLimit;
            if (compiler_copy_attempts() != 0) return error.UnexpectedCopyAttempt;
        }
    }
    compiler_budget_begin(std.math.maxInt(usize));
    var output: [*c]u8 = undefined;
    var size: usize = 1;
    const status = c.luaz_compile_bounded("return 6 *", 10, null, 0, &output, &size);
    const refused = compiler_meter_refused();
    const live = compiler_budget_end();
    if (status != c.LUAZ_COMPILE_OUTPUT_LIMIT_EXCEEDED or output != null or size != 0 or refused or live != 0)
        return error.ExpectedEmptyOutputLimit;
    compiler_budget_begin(std.math.maxInt(usize));
    const syntax = try luaz.Compiler.compile("return 6 *", .{});
    const syntax_refused = compiler_meter_refused();
    const syntax_live = compiler_budget_end();
    defer syntax.deinit();
    if (syntax != .err or syntax_refused or syntax_live != 0) return error.ExpectedCompileError;
    if (@import("test_options").copy_injection and compiler_copy_attempts() != 1)
        return error.ExpectedDiagnosticCopy;
    try recover();
}
