//! Fizzy plugin dylib entry. Copied from fizzy `src/plugins/root.zig`
//! `sdk.dylib.exportEntry` emits the required C symbols; implement the plugin in
//! `src/plugin.zig`. The host injects the allocator + `*Host` into the SDK itself
//! (`sdk.allocator()` / `sdk.host()`). You should never need to edit this file.
const sdk = @import("sdk");

comptime {
    sdk.dylib.exportEntry(@import("src/plugin.zig"));
}
