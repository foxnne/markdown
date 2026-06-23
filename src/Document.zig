const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
const sdk = @import("sdk");
const MarkDownPreviewWidget = @import("MarkDownPreviewWidget.zig");

const is_wasm = builtin.target.cpu.arch == .wasm32;

pub const DocView = struct {
    path: []const u8,
    text: []const u8,
    id: u64,
};

const Document = @This();

id: u64,
path: []u8,
grouping: u64 = 0,
text: std.ArrayList(u8) = .empty,
line_count: usize = 1,
dirty: bool = false,
split_ratio: f32 = 0.5,
preview: MarkDownPreviewWidget.State = .{},

const max_file_bytes: usize = 64 * 1024 * 1024;

pub fn fromBytes(path: []const u8, bytes: []const u8) !Document {
    const gpa = sdk.allocator();
    var text: std.ArrayList(u8) = .empty;
    errdefer text.deinit(gpa);
    try text.appendSlice(gpa, bytes);
    const path_copy = try gpa.dupe(u8, path);
    errdefer gpa.free(path_copy);
    var doc = Document{
        .id = sdk.host().allocDocId(),
        .path = path_copy,
        .text = text,
    };
    doc.refreshLineCount();
    doc.preview.ensureParsed(doc.text.items, gpa);
    return doc;
}

pub fn refreshLineCount(self: *Document) void {
    self.line_count = if (self.text.items.len == 0) 1 else std.mem.count(u8, self.text.items, "\n") + 1;
}

pub fn fromPath(path: []const u8) !Document {
    if (comptime is_wasm) return error.Unsupported;
    const gpa = sdk.allocator();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(dvui.io, path, gpa, .limited(max_file_bytes));
    defer gpa.free(bytes);
    return fromBytes(path, bytes);
}

pub fn deinit(self: *Document) void {
    const gpa = sdk.allocator();
    gpa.free(self.path);
    self.text.deinit(gpa);
    self.preview.deinit();
}

pub fn save(self: *Document) !void {
    if (comptime is_wasm) return error.Unsupported;
    try std.Io.Dir.cwd().writeFile(dvui.io, .{ .sub_path = self.path, .data = self.text.items });
    self.dirty = false;
}

pub fn view(self: *Document) DocView {
    return .{
        .path = self.path,
        .text = self.text.items,
        .id = self.id,
    };
}
