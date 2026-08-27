# Nowtes — Claude context

## What this is

A minimal TUI todo/notes app for Hyprland + Omarchy. Built with Python + Textual.
Toggled as a Hyprland special-workspace scratchpad (float overlay, not a full window).

## Files

- `nowtes.py` — the Textual TUI app
- `nowtes-toggle` — bash script that shows/hides the scratchpad via `hyprctl`
- `install.sh` — installer: copies files, installs textual, writes Hyprland config
- Data lives at `~/.local/share/nowtes/todos.json`

## Omarchy / Hyprland config

This project targets Omarchy. Two config systems exist:

**v4.0+ Quattro (current) — Lua config:**
- Entry point: `~/.config/hypr/hyprland.lua`
- Bindings: `~/.config/hypr/bindings.lua` using `o.bind()` / `hl.unbind()`
- Window rules: appended to `hyprland.lua` using `o.window()`
- Default omarchy bindings live in `~/.local/share/omarchy/default/hypr/*.lua`
- `hyprland.conf` still exists but is NOT read by Hyprland in v4 — don't write config there

**Pre-v4 (legacy) — ini config:**
- Entry point: `~/.config/hypr/hyprland.conf`
- Bindings: `bindd = SUPER, N, ...` syntax
- Window rules: `windowrule = float on, match:class nowtes`

`install.sh` detects which system is active by checking for `~/.config/hypr/hyprland.lua`.

## Window rules (v4 Lua)

```lua
o.window("^nowtes$", { float = true, fullscreen = false, size = { 900, 600 }, center = true, workspace = "special:nowtes silent" })
```

The `float = true` + `fullscreen = false` combo prevents it from opening tiled or fullscreen.
`workspace = "special:nowtes silent"` sends it to a named scratchpad on launch.

## Binding (v4 Lua)

```lua
o.bind("SUPER + N", "Nowtes", "/home/klw/.local/bin/nowtes-toggle")
```

Only emit `hl.unbind("SUPER + N")` before the bind if `SUPER + N` is already taken.
`SUPER + SHIFT + N` IS taken by default ("Editor" in `bindings/applications.lua`) — always unbind it if chosen.
`SUPER + N` has NO default binding in Omarchy v4.

## Conflict detection in install.sh

Lua mode: grep `.lua` files for `"SUPER + N"` / `"SUPER + SHIFT + N"` literal strings,
excluding lines that start with `--` (comments) or contain `hl.unbind` or `[Nn]owtes`.

## Cleanup / idempotent reinstall

Removes `-- >>> Nowtes ... -- <<< Nowtes` marker blocks from `hyprland.lua` and `bindings.lua`,
then removes lines matching `/[Nn]owtes/` and stale `hl.unbind("SUPER + N")` / `hl.unbind("SUPER + SHIFT + N")` lines.
Also strips the legacy `# >>> Nowtes` ini block from `hyprland.conf` if present.

## textual app notes

- Uses `Binding` objects for keyboard shortcuts
- Markdown-style links `[name](url)` are parsed and rendered as OSC 8 hyperlinks via `render_note()`
- Alarm/reminder feature plays sound via `paplay`/`pw-play`/`aplay`
- App class name in Hyprland is set by the terminal flag: `--app-id nowtes` (foot) or `--class nowtes` (alacritty/kitty/ghostty)

## README is outdated

The README still documents the pre-v4 ini config approach. It should be updated to show the Lua syntax for Omarchy v4+ users.
