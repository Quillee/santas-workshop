const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "gift_id_service",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add httpz dependency
    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("httpz", httpz.module("httpz"));

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Unit tests for the ID generator
    const id_gen_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/id_generator.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_id_gen_tests = b.addRunArtifact(id_gen_tests);

    // Unit tests for the HTTP server
    const server_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/server.zig" },
        .target = target,
        .optimize = optimize,
    });
    server_tests.root_module.addImport("httpz", httpz.module("httpz"));

    const run_server_tests = b.addRunArtifact(server_tests);

    // Main tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.root_module.addImport("httpz", httpz.module("httpz"));

    const run_main_tests = b.addRunArtifact(main_tests);

    // This creates a build step that runs all tests
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_id_gen_tests.step);
    test_step.dependOn(&run_server_tests.step);
    test_step.dependOn(&run_main_tests.step);

    // Benchmark executable
    const bench = b.addExecutable(.{
        .name = "bench",
        .root_source_file = .{ .path = "src/bench.zig" },
        .target = target,
        .optimize = .ReleaseFast, // Always optimize benchmarks
    });
    
    b.installArtifact(bench);
    
    const bench_cmd = b.addRunArtifact(bench);
    bench_cmd.step.dependOn(b.getInstallStep());
    
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&bench_cmd.step);

    // Format check step
    const fmt = b.addFmt(.{
        .paths = &.{ "src", "build.zig" },
        .check = true,
    });

    const fmt_step = b.step("fmt-check", "Check formatting");
    fmt_step.dependOn(&fmt.step);

    // Format fix step  
    const fmt_fix = b.addFmt(.{
        .paths = &.{ "src", "build.zig" },
        .check = false,
    });

    const fmt_fix_step = b.step("fmt", "Format code");
    fmt_fix_step.dependOn(&fmt_fix.step);
}