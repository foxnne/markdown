//! Markdown editor plugin: split source/preview for `.md` files.
const std = @import("std");
const markdown = @import("../markdown.zig");
const sdk = markdown.sdk;
const dvui = markdown.dvui;
const State = markdown.State;
const Document = markdown.Document;
const MarkdownEditor = markdown.MarkdownEditor;
const DocHandle = sdk.DocHandle;

pub const manifest = sdk.PluginManifest{
    .id = "markdown",
    .name = "Markdown",
    .version = .{ .major = 0, .minor = 0, .patch = 1 },
};

var plugin: sdk.Plugin = .{
    .state = undefined,
    .vtable = &vtable,
    .id = "markdown",
    .display_name = "Markdown",
};

const vtable: sdk.Plugin.VTable = .{
    .deinit = deinit,
    .fileTypePriority = fileTypePriority,
    .documentStackSize = documentStackSize,
    .documentStackAlign = documentStackAlign,
    .loadDocument = loadDocument,
    .loadDocumentFromBytes = loadDocumentFromBytes,
    .setDocumentGroupingOnBuffer = setDocumentGroupingOnBuffer,
    .documentIdFromBuffer = documentIdFromBuffer,
    .deinitDocumentBuffer = deinitDocumentBuffer,
    .registerOpenDocument = registerOpenDocument,
    .documentPtr = documentPtr,
    .documentByPath = documentByPath,
    .unregisterDocument = unregisterDocument,
    .documentGrouping = documentGrouping,
    .setDocumentGrouping = setDocumentGrouping,
    .documentPath = documentPath,
    .setDocumentPath = setDocumentPath,
    .bindDocumentToPane = bindDocumentToPane,
    .documentHasNativeExtension = documentHasNativeExtension,
    .documentHasRecognizedSaveExtension = documentHasRecognizedSaveExtension,
    .drawDocument = drawDocument,
    .closeDocument = closeDocument,
    .isDirty = isDirty,
    .saveDocument = saveDocument,
    .saveDocumentAsync = saveDocument,
    .documentDefaultSaveAsFilename = documentDefaultSaveAsFilename,
};

comptime {
    sdk.Plugin.assertEditorVTable(vtable);
}

pub fn register(host: *sdk.Host) !void {
    const gpa = host.allocator;

    const st = try gpa.create(State);
    errdefer gpa.destroy(st);
    st.* = .{};
    plugin.state = @ptrCast(st);

    try host.registerPlugin(&plugin);
    try host.registerMenuSection(.{
        .id = "markdown.menu.view.example",
        .parent_menu_id = "shell.menu.view",
        .owner = &plugin,
        .draw = drawViewExampleSection,
    });
}

pub fn pluginPtr() *sdk.Plugin {
    return &plugin;
}

fn deinit(state: *anyopaque) void {
    const st: *State = @ptrCast(@alignCast(state));
    const gpa = sdk.allocator();
    st.deinit(gpa);
    gpa.destroy(st);
}

fn fileTypePriority(_: *anyopaque, ext: []const u8) ?u8 {
    if (std.ascii.eqlIgnoreCase(ext, ".md")) return 50;
    if (std.ascii.eqlIgnoreCase(ext, ".markdown")) return 50;
    return null;
}

fn documentStackSize(_: *anyopaque) usize {
    return @sizeOf(Document);
}
fn documentStackAlign(_: *anyopaque) usize {
    return @alignOf(Document);
}
fn loadDocument(_: *anyopaque, path: []const u8, out_doc: *anyopaque) anyerror!void {
    try sdk.document.loadPathInto(Document, path, docBuf(out_doc));
}
fn loadDocumentFromBytes(_: *anyopaque, path: []const u8, bytes: []const u8, out_doc: *anyopaque) anyerror!void {
    try sdk.document.loadBytesInto(Document, path, bytes, docBuf(out_doc));
}
fn setDocumentGroupingOnBuffer(_: *anyopaque, doc: *anyopaque, grouping: u64) void {
    docBuf(doc).grouping = grouping;
}
fn documentIdFromBuffer(_: *anyopaque, doc: *anyopaque) u64 {
    return docBuf(doc).id;
}
fn deinitDocumentBuffer(_: *anyopaque, doc: *anyopaque) void {
    docBuf(doc).deinit();
}

fn registerOpenDocument(state: *anyopaque, file: *anyopaque) anyerror!*anyopaque {
    const st: *State = @ptrCast(@alignCast(state));
    const doc = docBuf(file);
    try st.docs.put(sdk.allocator(), doc.id, doc.*);
    return st.docs.getPtr(doc.id).?;
}
fn documentPtr(state: *anyopaque, id: u64) ?*anyopaque {
    const st: *State = @ptrCast(@alignCast(state));
    return st.docById(id);
}
fn documentByPath(state: *anyopaque, path: []const u8) ?*anyopaque {
    const st: *State = @ptrCast(@alignCast(state));
    return st.docByPath(path);
}
fn unregisterDocument(state: *anyopaque, id: u64) void {
    const st: *State = @ptrCast(@alignCast(state));
    _ = st.docs.swapRemove(id);
}

fn documentGrouping(_: *anyopaque, handle: DocHandle) u64 {
    return (docFrom(handle) orelse return 0).grouping;
}
fn setDocumentGrouping(_: *anyopaque, handle: DocHandle, grouping: u64) void {
    (docFrom(handle) orelse return).grouping = grouping;
}
fn documentPath(_: *anyopaque, handle: DocHandle) []const u8 {
    return (docFrom(handle) orelse return "").path;
}
fn setDocumentPath(_: *anyopaque, handle: DocHandle, path: []const u8) anyerror!void {
    const doc = docFrom(handle) orelse return error.DocumentNotFound;
    const gpa = sdk.allocator();
    const new_path = try gpa.dupe(u8, path);
    gpa.free(doc.path);
    doc.path = new_path;
}
fn bindDocumentToPane(_: *anyopaque, _: DocHandle, _: dvui.Id, _: *anyopaque, _: bool) void {
    // Text editing needs no pane/canvas binding; the text widget manages its own state.
}
fn documentHasNativeExtension(_: *anyopaque, _: DocHandle) bool {
    return true;
}
fn documentHasRecognizedSaveExtension(_: *anyopaque, _: DocHandle) bool {
    return true;
}

fn drawDocument(_: *anyopaque, handle: DocHandle) anyerror!void {
    const doc = docFrom(handle) orelse return;
    if (try MarkdownEditor.draw(doc, handle.id, sdk.allocator())) {
        doc.dirty = true;
    }
}

fn closeDocument(_: *anyopaque, handle: DocHandle) void {
    (docFrom(handle) orelse return).deinit();
}
fn isDirty(_: *anyopaque, handle: DocHandle) bool {
    return (docFrom(handle) orelse return false).dirty;
}
fn saveDocument(_: *anyopaque, handle: DocHandle) anyerror!void {
    try (docFrom(handle) orelse return).save();
}
fn documentDefaultSaveAsFilename(_: *anyopaque, handle: DocHandle, allocator: std.mem.Allocator) anyerror![]const u8 {
    const doc = docFrom(handle) orelse return error.DocumentNotFound;
    return allocator.dupe(u8, std.fs.path.basename(doc.path));
}

fn drawViewExampleSection(_: ?*anyopaque) !void {
    try sdk.menu.submenu(@src(), "Example", .{ .expand = .horizontal }, struct {
        fn body() !void {
            if (sdk.menu.menuItem(@src(), "Hi!", .{}, .{ .expand = .horizontal }) != null) {
                dvui.log.info("Hi from the markdown plugin!", .{});
            }
        }
    }.body);
}

fn docBuf(buf: *anyopaque) *Document {
    return @ptrCast(@alignCast(buf));
}
fn docFrom(handle: DocHandle) ?*Document {
    const st: *State = @ptrCast(@alignCast(plugin.state));
    return st.docById(handle.id);
}
