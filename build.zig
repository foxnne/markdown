const std = @import("std");
const fizzy = @import("fizzy");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = fizzy.plugin.create(b, .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("root.zig"),
    });

    const cmark_gfm = b.dependency("cmark_gfm", .{ .target = target, .optimize = optimize });
    lib.root_module.linkLibrary(cmark_gfm.artifact("cmark-gfm"));
    lib.root_module.linkLibrary(cmark_gfm.artifact("cmark-gfm-extensions"));
    lib.root_module.addIncludePath(cmark_gfm.path("src"));
    lib.root_module.addIncludePath(cmark_gfm.path("extensions"));
    lib.root_module.addIncludePath(b.path("src/md"));

    // Installs `<prefix>/plugin.dylib` (the name the host loader scans for). Install with
    // `--prefix <plugins-dir>/markdown`. No shell `cp`/`mkdir` — works on every host.
    fizzy.plugin.install(b, lib, .{});
}
