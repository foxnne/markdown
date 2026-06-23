const std = @import("std");
const Io = std.Io;

const dvui = @import("dvui");

const Document = @import("Document.zig");
const md_parse = @import("md/cmark_parse.zig");
const render_ast = @import("md/render_ast.zig");

pub const MarkDownPreviewWidget = @This();

pub const State = struct {
    scroll: dvui.ScrollInfo = .{},
    content_hash: u64 = std.math.maxInt(u64),
    ast_root: ?*anyopaque = null,
    gpa: ?std.mem.Allocator = null,
    rs: render_ast.RenderState = .{},

    pub fn deinit(self: *State) void {
        md_parse.freeCachedRoot(self.ast_root);
        self.ast_root = null;
        if (self.gpa) |gpa| self.rs.deinit(gpa);
    }

    pub fn ensureParsed(self: *State, content: []const u8, gpa: std.mem.Allocator) void {
        self.gpa = gpa;
        var hasher = std.hash.XxHash3.init(0);
        hasher.update(content);
        const h = hasher.final();
        if (self.content_hash == h) return;
        md_parse.freeCachedRoot(self.ast_root);
        self.ast_root = null;
        self.rs.clear(gpa);
        self.content_hash = h;
        if (md_parse.parseMarkdown(content)) |ast| {
            self.ast_root = @ptrCast(ast.root.n);
            _ = ast.extensions;
            _ = render_ast.scanNode(ast.root, &self.rs, gpa);
        }
    }
};

doc: *const Document.DocView = undefined,
state: *State = undefined,
io: Io = undefined,

pub fn init(
    src: std.builtin.SourceLocation,
    doc: *const Document.DocView,
    state: *State,
    io: Io,
    gpa: std.mem.Allocator,
) MarkDownPreviewWidget {
    _ = src;
    // All persistent render-state allocations must use the single host-injected
    // plugin allocator. `dvui.currentWindow().gpa` is a *different* allocator
    // instance (the window is created with the runtime's `main_init.gpa`), so
    // mixing the two frees memory across allocators and trips the debug
    // allocator's bucket assertion on document close.
    state.ensureParsed(doc.text, gpa);
    if (state.ast_root) |rp| {
        const root: md_parse.Node = .{ .n = @ptrCast(@alignCast(rp)) };
        render_ast.preloadImages(root, .{
            .image_base_dir = std.fs.path.dirname(doc.path) orelse ".",
            .io = io,
            .gpa = gpa,
            .rs = &state.rs,
        });
    }
    return .{ .doc = doc, .state = state, .io = io };
}

pub fn deinit(_: MarkDownPreviewWidget) void {}

pub fn processEvents(self: *MarkDownPreviewWidget) void {
    const doc = self.doc;
    const state = self.state;

    // Vertical document scroll only; wide tables scroll horizontally inside GridWidget.
    var scroll = dvui.scrollArea(@src(), .{
        .scroll_info = &state.scroll,
        .horizontal_bar = .hide,
        .vertical_bar = .auto_overlay,
    }, .{
        .expand = .both,
        .margin = dvui.Rect.all(4),
        .corner_radius = dvui.Rect.all(5),
        .border = dvui.Rect.all(1),
        .padding = dvui.Rect.all(6),
        .background = true,
        .color_fill = dvui.themeGet().fill,
        .style = .content,
        .id_extra = doc.id,
    });
    defer scroll.deinit();

    if (state.ast_root) |rp| {
        var v = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .gravity_x = 0,
            .padding = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
            .id_extra = doc.id + 1,
        });
        defer v.deinit();

        const root: md_parse.Node = .{ .n = @ptrCast(@alignCast(rp)) };
        const base_dir = std.fs.path.dirname(doc.path) orelse ".";
        render_ast.renderDocument(root, .{
            .image_base_dir = base_dir,
            .io = self.io,
            .gpa = state.gpa.?,
            .rs = &state.rs,
            .id_base = @intCast(doc.id << 16),
        });
    } else {
        dvui.labelNoFmt(
            @src(),
            "Could not parse markdown.",
            .{},
            .{
                .expand = .both,
                .gravity_x = 0.5,
                .gravity_y = 0.5,
                .color_text = dvui.themeGet().color(.err, .text).opacity(0.85),
                .id_extra = doc.id,
            },
        );
    }
}
