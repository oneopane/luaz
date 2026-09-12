const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const flags = &.{
        "-std=c++17",
        "-DLUA_API=extern\"C\"",
        "-DLUACODEGEN_API=extern\"C\"",
        "-DLUACODE_API=extern\"C\"",
    };

    // All build steps
    const steps = .{
        .@"test" = b.step("test", "Run unit tests"),
        .docs = b.step("docs", "Install docs"),
        .check_fmt = b.step("check-fmt", "Check formatting"),
        // Luau tools
        .luau_compile = b.step("luau-compile", "Run Luau compiler"),
        .luau_analysis = b.step("luau-analyze", "Run Luau analyze"),
        // Luau libs
        .luau_vm = b.step("luau-vm", "Build Luau VM lib"),
        .luau_codegen = b.step("luau-codegen", "Build Luau codegen lib"),
    };

    const opts = .{
        .cover = b.option(bool, "coverage", "Generate test coverage (requires kcov)") orelse false,
        .codegen = b.option(bool, "codegen", "Build and link Luau CodeGen") orelse true,
        .vector_size = b.option(u8, "vector-size", "Luau vector size (3 or 4, default 4)") orelse 4,
    };

    // Validate vector size
    if (opts.vector_size != 3 and opts.vector_size != 4) {
        std.log.err("Invalid vector size: {}. Must be either 3 or 4", .{opts.vector_size});
        return error.InvalidVectorSize;
    }

    const luau_dep = b.dependency("luau", .{});
    const generated = b.addWriteFiles();
    const config_header = generated.add("luaz_config.h", b.fmt(
        \\#ifndef LUAZ_CONFIG_H
        \\#define LUAZ_CONFIG_H
        \\#define LUA_USE_LONGJMP 1
        \\#define LUA_VECTOR_SIZE {d}
        \\#ifdef __cplusplus
        \\#ifndef LUA_API
        \\#define LUA_API extern "C"
        \\#endif
        \\#ifndef LUACODE_API
        \\#define LUACODE_API extern "C"
        \\#endif
        \\#ifndef LUACODEGEN_API
        \\#define LUACODEGEN_API extern "C"
        \\#endif
        \\#else
        \\#ifndef LUA_API
        \\#define LUA_API
        \\#endif
        \\#ifndef LUACODE_API
        \\#define LUACODE_API
        \\#endif
        \\#ifndef LUACODEGEN_API
        \\#define LUACODEGEN_API
        \\#endif
        \\#endif
        \\#endif
        \\
    , .{opts.vector_size}));

    // Luau VM lib
    const luau_vm = blk: {
        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });

        try addSrcFiles(b, mod, luau_dep, "VM/src", flags);

        mod.addCMacro("LUA_USE_LONGJMP", "1");
        mod.addCMacro("LUA_VECTOR_SIZE", b.fmt("{d}", .{opts.vector_size}));

        mod.addIncludePath(luau_dep.path("VM/include"));
        mod.addIncludePath(luau_dep.path("VM/src"));
        mod.addIncludePath(luau_dep.path("Common/include"));

        const lib = b.addLibrary(.{ .name = "luau_vm", .root_module = mod, .linkage = .static });

        lib.installHeadersDirectory(luau_dep.path("VM/include"), "", .{});

        b.installArtifact(lib);

        steps.luau_vm.dependOn(&lib.step);

        break :blk lib;
    };

    // Luau CodeGen lib
    const luau_codegen = if (opts.codegen) blk: {
        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });

        try addSrcFiles(b, mod, luau_dep, "CodeGen/src", flags);

        mod.addCMacro("LUA_VECTOR_SIZE", b.fmt("{d}", .{opts.vector_size}));
        mod.addIncludePath(luau_dep.path("CodeGen/include"));
        mod.addIncludePath(luau_dep.path("Common/include"));
        mod.addIncludePath(luau_dep.path("VM/src"));

        mod.linkLibrary(luau_vm);

        const lib = b.addLibrary(.{ .name = "luau_codegen", .root_module = mod, .linkage = .static });

        lib.installHeader(luau_dep.path("CodeGen/include/luacodegen.h"), "luacodegen.h");

        b.installArtifact(lib);

        steps.luau_codegen.dependOn(&lib.step);

        break :blk lib;
    } else null;

    // Luau compiler lib
    const luau_compiler = blk: {
        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });

        try addSrcFiles(b, mod, luau_dep, "Compiler/src", flags);
        try addSrcFiles(b, mod, luau_dep, "Ast/src", flags);
        try addSrcFiles(b, mod, luau_dep, "Bytecode/src", flags);
        try addSrcFiles(b, mod, luau_dep, "Common/src", flags);

        mod.addCMacro("LUA_USE_LONGJMP", "1");

        mod.addIncludePath(luau_dep.path("Common/include"));
        mod.addIncludePath(luau_dep.path("Ast/include"));
        mod.addIncludePath(luau_dep.path("Bytecode/include"));
        mod.addIncludePath(luau_dep.path("Compiler/include"));
        mod.addIncludePath(luau_dep.path("Compiler/src"));

        const lib = b.addLibrary(.{ .name = "luau_compiler", .root_module = mod, .linkage = .static });

        lib.installHeader(luau_dep.path("Compiler/include/luacode.h"), "luacode.h");

        b.installArtifact(lib);

        break :blk lib;
    };

    // Luau compiler binary
    {
        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });

        mod.addCSourceFiles(.{
            .root = luau_dep.path("."),
            .files = &.{
                "CLI/src/Compile.cpp",
                "CLI/src/FileUtils.cpp",
                "CLI/src/Flags.cpp",
            },
            .flags = flags,
        });

        addLuauIncludes(luau_dep, mod, opts.codegen);

        mod.linkLibrary(luau_vm);
        if (luau_codegen) |codegen| mod.linkLibrary(codegen);
        mod.linkLibrary(luau_compiler);

        const exe = b.addExecutable(.{ .name = "luau-compile", .root_module = mod });
        const run = b.addRunArtifact(exe);

        if (b.args) |args| {
            run.addArgs(args);
        }

        steps.luau_compile.dependOn(&run.step);
    }

    // Luau analyze binary
    {
        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });

        try addSrcFiles(b, mod, luau_dep, "Analysis/src", flags);
        try addSrcFiles(b, mod, luau_dep, "Config/src", flags);
        try addSrcFiles(b, mod, luau_dep, "Require/src", flags);

        mod.addCSourceFiles(.{
            .root = luau_dep.path("."),
            .files = &.{
                // Analyze CLI
                "CLI/src/Analyze.cpp",
                "CLI/src/AnalyzeRequirer.cpp",
                "CLI/src/FileUtils.cpp",
                "CLI/src/Flags.cpp",
                "CLI/src/VfsNavigator.cpp",
            },
            .flags = flags,
        });

        addLuauIncludes(luau_dep, mod, opts.codegen);

        mod.linkLibrary(luau_vm);
        mod.linkLibrary(luau_compiler);

        const exe = b.addExecutable(.{
            .name = "luau-analyze",
            .root_module = mod,
        });

        const run = b.addRunArtifact(exe);
        if (b.args) |args| {
            run.addArgs(args);
        }

        steps.luau_analysis.dependOn(&run.step);
    }

    // Translated C headers module
    const c_module = blk: {
        const write_files = b.addWriteFiles();

        const header = if (opts.codegen)
            write_files.add("_luau.h",
                \\#include <lua.h>
                \\#include <lualib.h>
                \\#include <luacode.h>
                \\#include <luacodegen.h>
                \\#include <handler.h>
            )
        else
            write_files.add("_luau.h",
                \\#include <lua.h>
                \\#include <lualib.h>
                \\#include <luacode.h>
                \\#include <handler.h>
            );

        const translated = b.addTranslateC(.{
            .root_source_file = header,
            .target = target,
            .optimize = optimize,
        });

        translated.addIncludePath(luau_dep.path("VM/include"));
        translated.addIncludePath(luau_dep.path("Common/include"));
        translated.addIncludePath(luau_dep.path("Bytecode/include"));
        translated.addIncludePath(luau_dep.path("Compiler/include"));
        if (opts.codegen) translated.addIncludePath(luau_dep.path("CodeGen/include"));
        translated.addIncludePath(b.path("src"));
        translated.defineCMacro("LUA_VECTOR_SIZE", b.fmt("{d}", .{opts.vector_size}));

        const mod = b.addModule("c", .{
            .root_source_file = translated.getOutput(),
            .target = target,
            .optimize = optimize,
        });

        mod.linkLibrary(luau_vm);
        if (luau_codegen) |codegen| mod.linkLibrary(codegen);
        mod.linkLibrary(luau_compiler);

        break :blk mod;
    };

    // Main module
    {
        const mod = b.addModule("luaz", .{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        });

        mod.addImport("c", c_module);

        // Add C wrapper
        mod.addCSourceFile(.{ .file = b.path("src/handler.cpp"), .flags = flags });
        mod.addCMacro("LUA_VECTOR_SIZE", b.fmt("{d}", .{opts.vector_size}));
        mod.addIncludePath(luau_dep.path("VM/include"));
        mod.addIncludePath(luau_dep.path("Common/include"));
        mod.addIncludePath(luau_dep.path("Ast/include"));
        mod.addIncludePath(luau_dep.path("Bytecode/include"));
        mod.addIncludePath(luau_dep.path("Compiler/include"));
        mod.addIncludePath(luau_dep.path("VM/src"));
        mod.addIncludePath(b.path("src"));

        mod.linkLibrary(luau_vm);

        if (luau_codegen) |codegen| mod.linkLibrary(codegen);
        mod.linkLibrary(luau_compiler);

        const lib = b.addLibrary(.{
            .name = "luaz",
            .root_module = mod,
            .linkage = .static,
        });

        b.installArtifact(lib);
        lib.installHeadersDirectory(luau_dep.path("Compiler/include"), "", .{});
        lib.installHeadersDirectory(luau_dep.path("Common/include"), "", .{});
        lib.installHeadersDirectory(luau_dep.path("Ast/include"), "", .{});
        lib.installHeadersDirectory(luau_dep.path("VM/src"), "luau/internal", .{});

        // Docs
        const install_docs = b.addInstallDirectory(.{
            .source_dir = lib.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });

        steps.docs.dependOn(&install_docs.step);
        b.getInstallStep().dependOn(&install_docs.step);
    }

    // zig build test
    {
        const test_mod = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });

        test_mod.addImport("luaz", b.modules.get("luaz").?);
        test_mod.addImport("c", c_module);

        const unit_tests = b.addTest(.{ .root_module = test_mod });

        // See https://zig.news/squeek502/code-coverage-for-zig-1dk1
        if (opts.cover) {
            unit_tests.setExecCmd(&[_]?[]const u8{
                "kcov",
                "--clean", // Don't accumulate data from multiple runs
                "--include-path=src/",
                b.pathJoin(&.{ b.install_path, "coverage" }),
                null,
            });
        }

        const run_tests = b.addRunArtifact(unit_tests);
        steps.@"test".dependOn(&run_tests.step);
    }

    // Package-boundary smoke test for native consumers.
    {
        const test_mod = b.createModule(.{
            .root_source_file = b.path("tests/native_consumer/root.zig"),
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });
        test_mod.addCSourceFile(.{
            .file = b.path("tests/native_consumer/native_link.cpp"),
            .flags = flags,
        });
        test_mod.addIncludePath(config_header.dirname());
        test_mod.addIncludePath(luau_dep.path("Common/include"));
        test_mod.addIncludePath(luau_dep.path("Ast/include"));
        test_mod.addIncludePath(luau_dep.path("Compiler/include"));
        test_mod.addIncludePath(luau_dep.path("VM/include"));
        test_mod.linkLibrary(luau_vm);
        test_mod.linkLibrary(luau_compiler);

        const native_tests = b.addTest(.{ .root_module = test_mod });
        const run_native_tests = b.addRunArtifact(native_tests);
        const native_step = b.step("test-native-consumer", "Test the native package boundary");
        native_step.dependOn(&run_native_tests.step);
    }

    // Deterministic facts for consumers that attest the selected native build.
    {
        const triple = try target.result.zigTriple(b.allocator);
        const codegen_text = if (opts.codegen) "true" else "false";
        const facts = b.fmt(
            \\{{
            \\  "schema": "luaz-build-facts-v1",
            \\  "luaz_version": "0.6.0",
            \\  "luau_version": "0.738",
            \\  "luau_commit": "c54f558b4d5748ab0658610b8ce0c432053e41eb",
            \\  "luau_zig_content_hash": "N-V-__8AAPjfGgFG_Ps7mXvCH5VHQbc2TojbrtiKBntwm277",
            \\  "target": "{s}",
            \\  "zig": "{s}",
            \\  "optimize": "{s}",
            \\  "vector_size": {d},
            \\  "longjmp": true,
            \\  "codegen": {s},
            \\  "cxx_standard": "c++17",
            \\  "cxx_library": "libc++",
            \\  "source_selection": "recursive .c/.cpp files sorted lexicographically",
            \\  "vm_sources": "VM/src",
            \\  "compiler_sources": ["Compiler/src", "Ast/src", "Bytecode/src", "Common/src"]
            \\}}
            \\
        , .{ triple, builtin.zig_version_string, @tagName(optimize), opts.vector_size, codegen_text });
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(facts, &digest, .{});
        const fingerprint = std.fmt.bytesToHex(digest, .lower);
        const facts_file = generated.add("build-facts.json", facts);
        const fingerprint_file = generated.add("build-fingerprint.txt", b.fmt("{s}\n", .{fingerprint}));

        const install_facts = b.addInstallFile(facts_file, "share/luaz/build-facts.json");
        const install_fingerprint = b.addInstallFile(fingerprint_file, "share/luaz/build-fingerprint.txt");
        const install_config = b.addInstallFile(config_header, "include/luaz_config.h");
        const profile_step = b.step("profile", "Install deterministic native build facts");
        profile_step.dependOn(&install_facts.step);
        profile_step.dependOn(&install_fingerprint.step);
        profile_step.dependOn(&install_config.step);
        b.getInstallStep().dependOn(&install_config.step);
    }

    // zig build check-fmt
    {
        const run_fmt = b.addFmt(.{ .check = true, .paths = &.{"."} });

        steps.check_fmt.dependOn(&run_fmt.step);
    }

    // Guided tour example
    {
        const mod = b.createModule(.{
            .root_source_file = b.path("examples/guided_tour.zig"),
            .target = target,
            .optimize = optimize,
        });

        mod.addImport("luaz", b.modules.get("luaz").?);

        const guided_tour = b.addExecutable(.{ .name = "guided-tour", .root_module = mod });

        const run_guided_tour = b.addRunArtifact(guided_tour);
        if (b.args) |args| {
            run_guided_tour.addArgs(args);
        }

        const guided_tour_step = b.step("guided-tour", "Run the guided tour example");
        guided_tour_step.dependOn(&run_guided_tour.step);
    }
}

fn addSrcFiles(
    b: *std.Build,
    mod: *std.Build.Module,
    dep: *std.Build.Dependency,
    dir_path: []const u8,
    flags: []const []const u8,
) !void {
    const extensions = [_][]const u8{ ".cpp", ".c" };

    const abs_path = dep.path(dir_path).getPath(b);
    var dir = try b.build_root.handle.openDir(b.graph.io, abs_path, .{ .iterate = true });
    defer dir.close(b.graph.io);

    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    var files: std.ArrayList([]const u8) = .empty;

    while (try walker.next(b.graph.io)) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const include = for (extensions) |e| {
            if (std.mem.eql(u8, ext, e))
                break true;
        } else false;

        if (include and entry.kind == .file) {
            try files.append(b.allocator, b.dupe(entry.path));
        }
    }

    std.mem.sort([]const u8, files.items, {}, struct {
        fn lessThan(_: void, a: []const u8, rhs: []const u8) bool {
            return std.mem.lessThan(u8, a, rhs);
        }
    }.lessThan);

    mod.addCSourceFiles(.{
        .root = dep.path(dir_path),
        .files = files.items,
        .flags = flags,
    });
}

fn addLuauIncludes(dep: *std.Build.Dependency, mod: *std.Build.Module, codegen: bool) void {
    mod.addIncludePath(dep.path("Common/include"));

    mod.addIncludePath(dep.path("VM/include"));
    mod.addIncludePath(dep.path("Runtime/include"));

    mod.addIncludePath(dep.path("Analysis/include"));
    mod.addIncludePath(dep.path("Config/include"));

    mod.addIncludePath(dep.path("EqSat/include"));
    mod.addIncludePath(dep.path("Navigator/include"));

    mod.addIncludePath(dep.path("Ast/include"));
    mod.addIncludePath(dep.path("Compiler/include"));
    mod.addIncludePath(dep.path("Bytecode/include"));
    if (codegen) mod.addIncludePath(dep.path("CodeGen/include"));

    mod.addIncludePath(dep.path("Require/include"));
    mod.addIncludePath(dep.path("Require/Navigator/include"));
    mod.addIncludePath(dep.path("Require/Runtime/include"));

    mod.addIncludePath(dep.path("CLI/include"));
}
