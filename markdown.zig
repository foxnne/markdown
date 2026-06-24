//! Markdown plugin root module and intra-plugin import hub.
//!
//! Files under `src/` import this as `../markdown.zig` for shared deps (`sdk`/`dvui`)
//! and sibling types — the conventional `<package>.zig` namespace.
const std = @import("std");

pub const sdk = @import("sdk");
pub const dvui = @import("dvui");

pub const plugin = @import("src/plugin.zig");
pub const State = @import("src/State.zig");
pub const Document = @import("src/Document.zig");
pub const MarkdownEditor = @import("src/MarkdownEditor.zig");
