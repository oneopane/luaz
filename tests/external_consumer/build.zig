const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const codegen = b.option(bool, "codegen", "Enable CodeGen") orelse false;
    const vector_size = b.option(u8, "vector-size", "Vector size") orelse 4;
    const dependency = b.dependency("luaz", .{
        .target = target,
        .optimize = optimize,
        .codegen = codegen,
        .@"vector-size" = vector_size,
    });
    const mod = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    mod.addImport("luaz", dependency.module("luaz"));
    mod.addImport("c", dependency.module("c"));
    mod.addIncludePath(dependency.artifact("luaz").getEmittedIncludeTree());
    mod.addIncludePath(dependency.artifact("luau_vm").getEmittedIncludeTree());
    mod.addIncludePath(dependency.artifact("luaz_support").getEmittedIncludeTree());
    mod.addCSourceFile(.{ .file = b.path("main.cpp"), .flags = &.{"-std=c++17"} });
    mod.addCMacro("EXPECTED_VECTOR_SIZE", b.fmt("{d}", .{vector_size}));
    mod.linkLibrary(dependency.artifact("luaz"));
    const exe = b.addExecutable(.{ .name = "external-luaz-consumer", .root_module = mod });
    const run = b.addRunArtifact(exe);
    b.step("test", "Compile and execute the external package consumer").dependOn(&run.step);
}
