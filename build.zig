//! Standalone build for the markdown plugin — the canonical third-party shape.
//! `zig build` produces `markdown.<dylib|dll|so>`. Install with
//! `--prefix <plugins-dir>/markdown`.
const std = @import("std");
const fizzy = @import("fizzy");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = fizzy.plugin.create(b, .{
        .name = "markdown",
        .target = target,
        .optimize = optimize,
    });

    const cmark_gfm = b.dependency("cmark_gfm", .{ .target = target, .optimize = optimize });
    lib.root_module.linkLibrary(cmark_gfm.artifact("cmark-gfm"));
    lib.root_module.linkLibrary(cmark_gfm.artifact("cmark-gfm-extensions"));
    lib.root_module.addIncludePath(cmark_gfm.path("src"));
    lib.root_module.addIncludePath(cmark_gfm.path("extensions"));
    lib.root_module.addIncludePath(b.path("src/md"));

    fizzy.plugin.install(b, lib, .{});
}
