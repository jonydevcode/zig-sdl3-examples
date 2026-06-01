const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });
    // Swap the comment of the next two statements if using
    // the system library instead of castholm's port
    // translate_c.linkSystemLibrary("sdl3", .{
    //     .use_pkg_config = .yes,
    // });
    translate_c.addIncludePath(sdl_dep.path("include"));

    const clear_exe = b.addExecutable(.{
        .name = "clear",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/clear.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    clear_exe.root_module.addImport("sdl", translate_c.createModule());
    clear_exe.root_module.linkLibrary(sdl_lib);
    b.installArtifact(clear_exe);
    const run_clear = b.step("run-clear", "Run the example: clear");
    const run_clear_cmd = b.addRunArtifact(clear_exe);
    run_clear.dependOn(&run_clear_cmd.step);
    run_clear_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_clear_cmd.addArgs(args);
    }

    const primitives_exe = b.addExecutable(.{
        .name = "primitives",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/primitives.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    primitives_exe.root_module.addImport("sdl", translate_c.createModule());
    primitives_exe.root_module.linkLibrary(sdl_lib);
    b.installArtifact(primitives_exe);
    const run_primitives = b.step("run-primitives", "Run the example: primitives");
    const run_primitives_cmd = b.addRunArtifact(primitives_exe);
    run_primitives.dependOn(&run_primitives_cmd.step);
    run_primitives_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_primitives_cmd.addArgs(args);
    }

    const snake_exe = b.addExecutable(.{
        .name = "snake",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/snake/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    snake_exe.root_module.addImport("sdl", translate_c.createModule());
    snake_exe.root_module.linkLibrary(sdl_lib);
    b.installArtifact(snake_exe);
    const run_snake = b.step("run-snake", "Run the example: snake");
    const run_snake_cmd = b.addRunArtifact(snake_exe);
    run_snake.dependOn(&run_snake_cmd.step);
    run_snake_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_snake_cmd.addArgs(args);
    }

    const gpu_exe = b.addExecutable(.{
        .name = "gpu",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gpu/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    gpu_exe.root_module.addImport("sdl", translate_c.createModule());
    gpu_exe.root_module.linkLibrary(sdl_lib);
    b.installArtifact(gpu_exe);
    const run_gpu = b.step("run-gpu", "Run the example: gpu");
    const run_gpu_cmd = b.addRunArtifact(gpu_exe);
    run_gpu.dependOn(&run_gpu_cmd.step);
    run_gpu_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_gpu_cmd.addArgs(args);
    }

    const check = b.step("check", "Check if the program compiles");
    check.dependOn(&clear_exe.step);
    check.dependOn(&primitives_exe.step);
    check.dependOn(&snake_exe.step);
    check.dependOn(&gpu_exe.step);
}
