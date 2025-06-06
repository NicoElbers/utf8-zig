const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .cpu_model = .native } });
    const optimize = b.standardOptimizeOption(.{});

    // Main module
    const utf8_mod = b.addModule("utf8", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Benchmarks
    bench(b, target, optimize, utf8_mod);

    // Examples
    const example_encode_mod = b.createModule(.{
        .root_source_file = b.path("examples/encoding.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_encode_mod.addImport("utf8", utf8_mod);
    const example_encode_exe = b.addExecutable(.{
        .name = "example_encode",
        .root_module = example_encode_mod,
    });
    const run_example_encode = b.addRunArtifact(example_encode_exe);

    const example_decode_mod = b.createModule(.{
        .root_source_file = b.path("examples/decoding.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_decode_mod.addImport("utf8", utf8_mod);
    const example_decode_exe = b.addExecutable(.{
        .name = "example_decode",
        .root_module = example_decode_mod,
    });
    const run_example_decode = b.addRunArtifact(example_decode_exe);

    // Tests
    const tests = b.addTest(.{
        .root_module = utf8_mod,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_example_encode.step);
    test_step.dependOn(&run_example_decode.step);

    const slow_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });
    const run_slow_tests = b.addRunArtifact(slow_tests);

    const slow_test_step = b.step("slow_test", "Run all test, including slow ones");
    slow_test_step.dependOn(&run_slow_tests.step);
    slow_test_step.dependOn(test_step);
}

fn bench(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
    utf8_mod: *std.Build.Module,
) void {
    const bench_step = b.step("bench", "Benchmark application");

    const bench_mod = b.createModule(.{
        .root_source_file = b.path("bench/benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    bench_mod.addImport("utf8", utf8_mod);

    bench_mod.addCSourceFiles(.{
        .root = b.path("bench"),
        .files = &.{
            "hoehrmann.c",
            "wellons_branchless.c",
            "wellons_simple.c",
        },
        .flags = &.{ "-Wall", "-Werror", "-std=c11" },
    });
    const bench_exe = b.addExecutable(.{
        .name = "bench",
        .root_module = bench_mod,
    });
    bench_step.dependOn(&b.addInstallArtifact(bench_exe, .{}).step);
}
