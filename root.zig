//! Fizzy plugin dylib entry — the canonical third-party `root.zig`.
//!
//! Copy this file to your plugin project root (beside `build.zig`). It is the whole entry:
//! `sdk.dylib.exportEntry` emits the required C symbols, wired to your `register` and
//! `manifest`. The host-injected allocator and `*Host` live in the SDK (`sdk.allocator()` /
//! `sdk.host()`), so there is no storage file to write. Implement your plugin in
//! `src/plugin.zig` (including `pub const manifest: sdk.PluginManifest`); you should never
//! need to edit this file.
const sdk = @import("sdk");

comptime {
    sdk.dylib.exportEntry(@import("src/plugin.zig"));
}
