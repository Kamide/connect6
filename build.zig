const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Run = Step.Run;

const builtin = @import("builtin");

const name = "connect6";

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dependency = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib_module = raylib_dependency.module("raylib");
    const raylib_artifact = raylib_dependency.artifact("raylib");

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = name, .module = root_module },
            .{ .name = "raylib", .module = raylib_module },
        },
    });

    const run_step = b.step("run", "Run");

    if (target.query.os_tag == .emscripten) {
        const rlz = @import("raylib_zig");
        const emsdk = rlz.emsdk;

        const wasm_library = b.addLibrary(.{
            .name = name,
            .root_module = main_module,
        });

        const emcc_step = try emsdk.emccStep(
            b,
            &.{},
            &.{ raylib_artifact, wasm_library },
            .{
                .optimize = optimize,
                .flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize }),
                .settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize }),
                .shell_file_path = raylib_dependency.builder.dependency("raylib", .{}).path("src/shell.html"),
                .install_dir = .{ .custom = "web" },
                .preload_paths = &.{.{ .src_path = b.path("resources"), .virtual_path = "resources" }},
                .out_file_name = "index.html",
            },
        );

        if (builtin.target.os.tag == .windows) {
            for (emcc_step.dependencies.items) |dependency| {
                const run = dependency.cast(Run) orelse continue;
                run.argv.items[0].lazy_path.lazy_path = try emsdk.path(b, "upstream/emscripten/emcc.bat");
            }
        }
        b.getInstallStep().dependOn(emcc_step);

        const emrun_step = try emsdk.emrunStep(
            b,
            b.graph.path(.install_prefix, "web/index.html"),
            &.{},
        );
        emrun_step.dependOn(emcc_step);

        run_step.dependOn(emrun_step);
    } else {
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = main_module,
        });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        run_cmd.addPassthruArgs();

        run_step.dependOn(&run_cmd.step);

        const root_test = b.addTest(.{ .root_module = root_module });
        const test_root = b.addRunArtifact(root_test);

        const main_test = b.addTest(.{ .root_module = main_module });
        const test_main = b.addRunArtifact(main_test);

        const test_step = b.step("test", "Test");
        test_step.dependOn(&test_root.step);
        test_step.dependOn(&test_main.step);
    }
}
