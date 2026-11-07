const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const repo_root = b.path("../../..");

    const os_tag = target.result.os.tag;
    const cpu_arch = target.result.cpu.arch;
    const goos: []const u8 = switch (os_tag) {
        .macos => "darwin",
        .linux => "linux",
        .windows => "windows",
        else => @panic("unsupported OS target for MyGo"),
    };
    const goarch: []const u8 = switch (cpu_arch) {
        .aarch64 => "arm64",
        .x86_64 => "amd64",
        else => @panic("unsupported CPU architecture for MyGo"),
    };

    const archive_name = if (os_tag == .windows) "mygo.lib" else "libmygo.a";
    const go_build = b.addSystemCommand(&.{
        "go",
        "build",
        "-trimpath",
        "-tags",
        "mygo_ffi,mygo_ffi_ui,mygo_noinspector",
        "-ldflags",
        "-s -w -X github.com/egoist/mygo.production=1",
        "-buildmode=c-archive",
        "-o",
    });
    const raw_archive = go_build.addOutputFileArg(archive_name);
    go_build.addArg("./zig");
    go_build.setCwd(repo_root);
    go_build.has_side_effects = true;
    go_build.setEnvironmentVariable("CGO_ENABLED", "1");
    go_build.setEnvironmentVariable("GOOS", goos);
    go_build.setEnvironmentVariable("GOARCH", goarch);
    if (!target.query.isNative()) {
        const zig_triple = switch (os_tag) {
            .linux => if (cpu_arch == .aarch64) "aarch64-linux-gnu" else "x86_64-linux-gnu",
            .windows => if (cpu_arch == .aarch64) "aarch64-windows-gnu" else "x86_64-windows-gnu",
            .macos => if (cpu_arch == .aarch64) "aarch64-macos" else "x86_64-macos",
            else => unreachable,
        };
        go_build.setEnvironmentVariable("CC", b.fmt("{s} cc -target {s}", .{ b.graph.zig_exe, zig_triple }));
    }

    const lib_mygo = if (os_tag == .windows and !target.query.isNative()) blk: {
        const repack = b.addSystemCommand(&.{
            "sh",
            "-c",
            "src=\"$(pwd)/$2\"; dst=\"$(pwd)/$3\"; tmp=$(mktemp -d) && cd \"$tmp\" && \"$1\" ar x \"$src\" && rm -f __.SYMDEF* && \"$1\" ar rcs \"$dst\" *.o && rm -rf \"$tmp\"",
            "repack",
            b.graph.zig_exe,
        });
        repack.addFileArg(raw_archive);
        break :blk repack.addOutputFileArg("mygo.lib");
    } else raw_archive;

    const mygo_mod = b.createModule(.{
        .root_source_file = b.path("../../sdk/mygo.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "mygo", .module = mygo_mod },
        },
    });
    root_mod.addObjectFile(lib_mygo);

    if (os_tag == .macos) {
        root_mod.linkFramework("CoreFoundation", .{});
        root_mod.linkFramework("Security", .{});
        root_mod.linkSystemLibrary("resolv", .{});
    } else if (os_tag == .linux) {
        root_mod.linkSystemLibrary("pthread", .{});
        root_mod.linkSystemLibrary("dl", .{});
    } else if (os_tag == .windows) {
        root_mod.linkSystemLibrary("ws2_32", .{});
        root_mod.linkSystemLibrary("ntdll", .{});
        root_mod.linkSystemLibrary("userenv", .{});
        root_mod.linkSystemLibrary("crypt32", .{});
        root_mod.linkSystemLibrary("winmm", .{});
    }

    const exe = b.addExecutable(.{
        .name = "counter-native-zig",
        .root_module = root_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the Zig GPU Native UI counter");
    run_step.dependOn(&run_cmd.step);
}
