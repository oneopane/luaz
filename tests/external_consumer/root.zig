const luaz = @import("luaz");
const c = @import("c");

extern fn external_consumer_smoke() c_int;
extern fn compiler_budget_begin(limit: usize) void;
extern fn compiler_budget_end() usize;

pub fn main() !void {
    if (external_consumer_smoke() != 0) return error.NativeConsumerFailed;
    var source = [_]u8{' '} ** 8192 ++ "local function answer() return 42 end return answer()".*;
    compiler_budget_begin(4096);
    const result = luaz.Compiler.compileBounded(&source, .{}, 4096);
    const live = compiler_budget_end();
    defer result.deinit();
    if (result != .exhausted or live != 0) return error.ExpectedExhaustion;

    var output: [*c]u8 = undefined;
    var size: usize = 1;
    const status = c.luaz_compile_bounded("return 42", 9, null, 0, &output, &size);
    if (status != c.LUAZ_COMPILE_EXHAUSTED or output != null or size != 0)
        return error.ExpectedEmptyExhaustion;
    const recovered = luaz.Compiler.compileBounded("return 42", .{}, 4096);
    defer recovered.deinit();
    if (recovered != .ok) return error.CompilerDidNotRecover;
}
