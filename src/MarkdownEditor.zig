//! Split markdown editor: monospace source on the left, rendered preview on the right.
const std = @import("std");
const dvui = @import("dvui");
const Document = @import("Document.zig");
const MarkDownPreviewWidget = @import("MarkDownPreviewWidget.zig");
const TextEntryWidget = @import("widgets/TextEntryWidget.zig");

const editor_pad_y: f32 = 8;
const editor_pad_right: f32 = 8;
const text_color = dvui.Color{ .r = 0xdd, .g = 0xdc, .b = 0xd3, .a = 255 };

const chromeless = dvui.Options{
    .background = false,
    .margin = dvui.Rect{},
    .padding = null,
    .border = dvui.Rect{},
    .corner_radius = dvui.Rect{},
    .ninepatch_fill = &dvui.Ninepatch.none,
    .ninepatch_hover = &dvui.Ninepatch.none,
    .ninepatch_press = &dvui.Ninepatch.none,
};

const max_text_bytes: usize = 64 * 1024 * 1024;

pub fn draw(doc: *Document, id_extra: u64, gpa: std.mem.Allocator) !bool {
    const font = dvui.Font.theme(.mono);

    var paned = dvui.paned(@src(), .{
        .direction = .horizontal,
        // Keep both panes side-by-side. A non-zero `collapsed_size` larger than the
        // canvas width would force the paned into collapsed (single-pane carousel)
        // mode on the first frame, translating each full-width pane off opposite
        // edges instead of splitting the available width.
        .collapsed_size = 0,
        .handle_size = 4,
        .split_ratio = &doc.split_ratio,
    }, .{
        .expand = .both,
        .id_extra = @intCast(id_extra),
    });
    defer paned.deinit();

    var changed = false;

    if (paned.showFirst()) {
        // Match the code plugin: TextEntryWidget owns scrolling inside the pane viewport.
        var row = dvui.box(@src(), .{ .dir = .horizontal }, chromeless.override(.{
            .expand = .both,
            .font = font,
            .id_extra = @intCast(id_extra + 10),
        }));
        defer row.deinit();

        var te: TextEntryWidget = undefined;
        te.init(@src(), .{
            .multiline = true,
            .break_lines = false,
            .cache_layout = true,
            .scroll_horizontal = true,
            .focus_border = false,
            .text = .{ .array_list = .{ .backing = &doc.text, .allocator = gpa, .limit = max_text_bytes } },
            .tree_sitter = null,
        }, chromeless.override(.{
            .expand = .both,
            .font = font,
            .padding = .{
                .x = 8,
                .y = editor_pad_y,
                .w = editor_pad_right,
                .h = editor_pad_y,
            },
            .color_text = text_color,
            .id_extra = @intCast(id_extra + 1),
        }));
        defer te.deinit();
        te.processEvents();
        te.draw();
        if (te.text_changed) {
            doc.refreshLineCount();
            doc.preview.ensureParsed(doc.text.items, gpa);
            changed = true;
        }
    }

    if (paned.showSecond()) {
        var preview = MarkDownPreviewWidget.init(@src(), &doc.view(), &doc.preview, dvui.io, gpa);
        preview.processEvents();
    }

    return changed;
}
