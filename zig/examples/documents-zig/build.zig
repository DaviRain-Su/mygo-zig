const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mygo_mod = b.createModule(.{
        .root_source_file = b.path("../../sdk/mygo.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const app_mod = b.createModule(.{
        .root_source_file = b.path("src/app.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = optimize != .debug,
        .imports = &.{
            .{ .name = "mygo", .module = mygo_mod },
        },
    });

    const lib = b.addLibrary(.{
        .name = "documentszig",
        .linkage = .dynamic,
        .root_module = app_mod,
    });

    const install_lib = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = "../resources" } },
    });
    b.getInstallStep().dependOn(&install_lib.step);
}
