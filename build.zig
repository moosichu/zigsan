const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the ubsan runtime library!
    const ubsan_rt = b.addStaticLibrary(.{
        .name = "ubsan_rt",
        .root_source_file = .{ .path = "src/rt/ubsan_rt.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Have to link with libC or otherwise getBaseAddress in process.zig
    // panics (during the panic) caused by ubsan.
    ubsan_rt.linkLibC();

    // Have to link libCPP as it depends on ubsan C++ standard library functionality
    // TODO: add option to build without C++ sanitisation runtime!
    ubsan_rt.linkLibCpp();
    ubsan_rt.addCSourceFile("src/rt/ubsan/ubsan_type_hash.cpp", &[_][]const u8{
        "-Wall",
        "-Wextra",
        "-Werror",
    });

    b.installArtifact(ubsan_rt);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    main_tests.linkLibC();
    main_tests.linkLibCpp();
    main_tests.addIncludePath("src");

    main_tests.linkLibrary(ubsan_rt);

    // TODO: Add tests for ubsan minimal and non-recoverable traps and more!
    main_tests.addCSourceFile("src/testing/ubsan_c_tests.c", &[_][]const u8{
        "-fno-sanitize-trap=undefined",
        // "-fno-sanitize-recover=all",
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
