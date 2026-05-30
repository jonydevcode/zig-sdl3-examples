const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zig_sdl3_examples", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const sdl = b.dependency("sdl", .{
        .optimize = optimize,
        .target = target,
    });

    const clear_exe = b.addExecutable(.{
        .name = "clear",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/clear.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zig_sdl3_examples", .module = mod },
            },
        }),
    });
    clear_exe.root_module.addImport("sdl3", sdl.module("sdl3"));

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
            .imports = &.{
                .{ .name = "zig_sdl3_examples", .module = mod },
            },
        }),
    });
    primitives_exe.root_module.addImport("sdl3", sdl.module("sdl3"));

    b.installArtifact(primitives_exe);

    const run_primitives = b.step("run-primitives", "Run the example: primitives");
    const run_primitives_cmd = b.addRunArtifact(primitives_exe);
    run_primitives.dependOn(&run_primitives_cmd.step);
    run_primitives_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_primitives_cmd.addArgs(args);
    }
}
