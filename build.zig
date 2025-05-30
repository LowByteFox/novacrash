const std = @import("std");
const rl = @import("raylib_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.addModule("novacrash", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("example/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("novacrash", lib_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "novacrash",
        .root_module = lib_mod,
    });

    const exe = b.addExecutable(.{
        .name = "novacrash",
        .root_module = exe_mod,
    });
    exe.linkLibC();
    lib.linkLibC();

    const custom_frontend = b.option(bool, "custom_frontend", "Enable custom frontend, user will have to implement hooks") orelse false;

    if (!custom_frontend) {
        const raylib_dep = b.lazyDependency("raylib_zig", .{
            .target = target,
            .optimize = optimize,
        }).?;
        const raylib = raylib_dep.module("raylib");
        const raygui = raylib_dep.module("raygui");
        const raylib_artifact = raylib_dep.artifact("raylib");

        exe.linkLibrary(raylib_artifact);
        exe.root_module.addImport("raylib", raylib);
        exe.root_module.addImport("raygui", raygui);

        lib.linkLibrary(raylib_artifact);
        lib.root_module.addImport("raylib", raylib);
        lib.root_module.addImport("raygui", raygui);
    }

    const options = b.addOptions();
    options.addOption(bool, "custom_frontend", custom_frontend);

    lib.root_module.addOptions("config", options);

    b.installArtifact(lib);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
