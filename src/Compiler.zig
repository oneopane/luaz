//! Luau compiler interface for compiling Lua source code to bytecode.

const std = @import("std");
const c = @import("c");

const Self = @This();

const Error = @import("Lua.zig").Error;

/// Result of compilation operation containing either bytecode or error message.
pub const Result = union(enum) {
    /// Compiled Luau bytecode.
    ok: []const u8,
    /// Result contains the error message.
    err: []const u8,

    /// Luau uses `malloc` to allocate the returning blob with either bytecode or error message.
    /// Either way, must use `C.free` to let it go.
    pub fn deinit(self: Result) void {
        switch (self) {
            .ok => |bytecode| std.c.free(@constCast(bytecode.ptr)),
            .err => |message| std.c.free(@constCast(message.ptr)),
        }
    }
};

/// Compilation options for controlling Luau compiler behavior.
pub const Opts = struct {
    /// Optimization level.
    ///
    /// - `0` - no optimization
    /// - `1` - baseline optimization level that doesn't prevent debuggability
    /// - `2` - includes optimizations that harm debuggability such as inlining
    opt_level: u8 = 1,

    /// Debug level.
    ///
    /// - `0` - no debugging support
    /// - `1` - line info & function names only; sufficient for backtraces
    /// - `2` - full debug info with local & upvalue names; necessary for debugger
    dbg_level: u8 = 1,

    /// Type information level for native code generation.
    ///
    /// Information includes testable types for function arguments, locals, upvalues and some temporaries.
    ///
    /// - `0` - generate for native modules
    /// - `1` - generate for all modules
    type_info_level: u8 = 0,

    /// Coverage support level.
    ///
    /// - `0` - no code coverage support
    /// - `1` - statement coverage
    /// - `2` - statement and expression coverage (verbose)
    coverage_level: u8 = 0,
};

/// Compiles Lua source code to bytecode using the Luau compiler.
/// Returns either compiled bytecode or an error message.
/// In both cases, memory must be freed using Result.deinit().
pub fn compile(source: []const u8, opts: Opts) !Result {
    return switch (compileBounded(source, opts, std.math.maxInt(usize))) {
        .ok => |blob| .{ .ok = blob },
        .err => |blob| .{ .err = blob },
        .allocation_failed => Error.OutOfMemory,
        // No representable blob exceeds this call's maxInt output ceiling.
        .output_limit_exceeded => Error.OutOfMemory,
        .internal_error => error.CompilerInternalError,
    };
}

/// Explicit native compiler disposition. Owned blobs use the same malloc/free
/// contract as Result; limit, allocation, and internal failures own no blob.
pub const BoundedResult = union(enum) {
    ok: []const u8,
    err: []const u8,
    output_limit_exceeded,
    allocation_failed,
    internal_error,

    pub fn deinit(self: BoundedResult) void {
        switch (self) {
            .ok, .err => |blob| std.c.free(@constCast(blob.ptr)),
            .output_limit_exceeded, .allocation_failed, .internal_error => {},
        }
    }
};

/// Catches native allocation failure before it crosses into Zig. output_limit
/// bounds the returned copy before allocation; compiler working-memory metering
/// remains the consumer's responsibility.
pub fn compileBounded(source: []const u8, opts: Opts, output_limit: usize) BoundedResult {
    const options = c.lua_CompileOptions{
        .optimizationLevel = opts.opt_level,
        .debugLevel = opts.dbg_level,
        .typeInfoLevel = opts.type_info_level,
        .coverageLevel = opts.coverage_level,
    };

    var sz: usize = 0;
    var ptr: [*c]u8 = null;
    const status = c.luaz_compile_bounded(
        source.ptr,
        source.len,
        &options,
        output_limit,
        &ptr,
        &sz,
    );
    return switch (status) {
        c.LUAZ_COMPILE_OK => .{ .ok = ptr[0..sz] },
        c.LUAZ_COMPILE_ERROR => .{ .err = ptr[0..sz] },
        c.LUAZ_COMPILE_OUTPUT_LIMIT_EXCEEDED => .output_limit_exceeded,
        c.LUAZ_COMPILE_ALLOCATION_FAILED => .allocation_failed,
        else => .internal_error,
    };
}

test "bounded compiler returns distinct inclusive output limit" {
    const baseline = compileBounded("return 42", .{}, std.math.maxInt(usize));
    defer baseline.deinit();
    try std.testing.expect(baseline == .ok);
    const exact = compileBounded("return 42", .{}, baseline.ok.len);
    defer exact.deinit();
    try std.testing.expect(exact == .ok);
    const short = compileBounded("return 42", .{}, baseline.ok.len - 1);
    defer short.deinit();
    try std.testing.expect(short == .output_limit_exceeded);
    const syntax = compileBounded("return 6 *", .{}, 4096);
    defer syntax.deinit();
    try std.testing.expect(syntax == .err);
    const bounded_syntax = compileBounded("return 6 *", .{}, 0);
    defer bounded_syntax.deinit();
    try std.testing.expect(bounded_syntax == .output_limit_exceeded);
}

test "compile Luau code" {
    const result = try Self.compile("return 1 + 1", .{ .opt_level = 2 });
    defer result.deinit();

    try std.testing.expect(result == .ok);

    const bytecode = result.ok;
    try std.testing.expect(bytecode.len > 0);
}

test "compile error" {
    const result = try Self.compile("return 1 + '", .{});
    defer result.deinit();

    // Assert that compilation failed
    try std.testing.expect(result == .err);

    const message = result.err;
    const expected_error = ":1: Malformed string; did you forget to finish it?";

    // Check that the error message contains the expected text
    try std.testing.expect(std.mem.indexOf(u8, message, expected_error) != null);
}
