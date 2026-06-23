# Markdown plugin for Fizzy

Split editor/preview for `.md` and `.markdown` files. Installs as a user plugin dylib.

Plugin structure, required files, and implementation contracts are documented in
[fizzy `docs/PLUGINS.md`](https://github.com/fizzyedit/fizzy/blob/main/docs/PLUGINS.md)
(§2 — Anatomy of a plugin).

## This repo

```
markdown/
  build.zig / build.zig.zon
  root.zig              # dylib entry — copied from fizzy `src/plugins/root.zig` (one exportEntry call)
  src/
    plugin.zig          # register(host) + document vtable; owns its State
    State.zig, …        # feature code
```

The host injects the allocator + `*Host` into the SDK, so plugin code reads them via
`sdk.allocator()` / `sdk.host()` — there is no `Globals.zig` to write.

## Build

```bash
cd ~/dev/fizzyedit/markdown
zig build
zig build install --prefix ~/.config/fizzy/plugins/markdown
```

On macOS:

```bash
zig build install --prefix "$HOME/Library/Application Support/fizzy/plugins/markdown"
```

Requires a sibling [fizzy](https://github.com/fizzyedit/fizzy) checkout at `../../fizzy` (PR [#186](https://github.com/fizzyedit/fizzy/pull/186)).

## Dev shortcut

```bash
export FIZZY_PLUGIN_PATH="$PWD/zig-out/plugin.dylib"
```

Then run Fizzy from the matching `fizzy` revision.
