const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main module
    const slow_tests = b.option(bool, "slow_tests", "Run slow tests (ReleaseSafe reccomended)") orelse false;

    const options = b.addOptions();
    options.addOption(bool, "slow_tests", slow_tests);

    const utf8_mod = b.addModule("utf8", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    utf8_mod.addOptions("build", options);

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
}
