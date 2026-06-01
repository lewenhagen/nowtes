# Nowtes

A minimal todo/notes TUI for [Hyprland](https://hyprland.org/) and [omarchy](https://omarchy.org/). Toggle it with `SUPER+N`.

```
 Nowtes                                         14:23:01 
┌─────────────────────────────────────────────────────┐
│  ○  2026-06-01 09:15  Buy groceries                 │
│  ○  2026-06-01 11:42  Review pull requests          │
│  ✓  2026-06-01 12:10  Write unit tests              │  ← green
└─────────────────────────────────────────────────────┘
  New todo… Enter to save, Esc to cancel

  n:New  d:Delete  Space:Toggle done  q:Quit
```

## Requirements

- Python 3.8+
- [textual](https://github.com/Textualize/textual) (`pip install textual`)
- `foot` terminal (or any terminal — see [Custom terminal](#custom-terminal))
- Hyprland

## Install

```bash
git clone https://github.com/yourname/nowtes
cd nowtes
bash install.sh
```

Then add to your Hyprland config (see below).

## Hyprland setup

Add these lines to your Hyprland config. In omarchy this is typically
`~/.config/hypr/hyprland.conf` or a file sourced from it.

```ini
# Window rules
windowrulev2 = float, class:^(nowtes)$
windowrulev2 = size 900 600, class:^(nowtes)$
windowrulev2 = center, class:^(nowtes)$
windowrulev2 = workspace special:nowtes, class:^(nowtes)$

# Keybinding
bind = SUPER, N, exec, ~/.local/bin/nowtes-toggle
```

Reload Hyprland (`SUPER+SHIFT+R` or `hyprctl reload`) and press `SUPER+N`.

## Keybindings

| Key     | Action              |
|---------|---------------------|
| `n`     | New todo            |
| `d`     | Delete selected     |
| `Space` | Toggle done/undone  |
| `q`     | Quit                |
| `Esc`   | Cancel input        |
| `↑/↓`   | Navigate list       |

## Custom terminal

The toggle script uses `foot` by default. Override with the `NOWTES_TERMINAL`
environment variable in your shell profile:

```bash
export NOWTES_TERMINAL=alacritty
```

> **Note:** `alacritty` and `kitty` use `--class` instead of `--app-id`.
> Edit `~/.local/bin/nowtes-toggle` and change `--app-id` to `--class` if needed.

## Data

Todos are stored in `~/.local/share/nowtes/todos.json`.
