#!/bin/bash
set -e

INSTALL_DIR="$HOME/.local/share/nowtes"
BIN_DIR="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Nowtes..."

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

cp "$SCRIPT_DIR/nowtes.py" "$INSTALL_DIR/nowtes.py"
chmod +x "$INSTALL_DIR/nowtes.py"

cp "$SCRIPT_DIR/nowtes-toggle" "$BIN_DIR/nowtes-toggle"
chmod +x "$BIN_DIR/nowtes-toggle"

echo "Installing Python dependencies..."
if command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm python-textual
elif command -v pip &>/dev/null; then
    pip install --user textual
else
    echo "Could not install textual automatically. Install it manually:"
    echo "  Arch: sudo pacman -S python-textual"
    echo "  Other: pip install --user textual"
fi

echo ""
echo "Done! Add these lines to your Hyprland config:"
echo ""
echo "  # Window rules (add near your other windowrulev2 lines)"
echo "  windowrulev2 = float, class:^(nowtes)\$"
echo "  windowrulev2 = size 900 600, class:^(nowtes)\$"
echo "  windowrulev2 = center, class:^(nowtes)\$"
echo "  windowrulev2 = workspace special:nowtes, class:^(nowtes)\$"
echo ""
echo "  # Keybinding (add near your other bind lines)"
echo "  bind = SUPER, N, exec, ~/.local/bin/nowtes-toggle"
echo ""
echo "To use a different terminal, set NOWTES_TERMINAL in your environment."
echo "Default is 'foot'. For alacritty or kitty, pass --class instead of --app-id"
echo "and update nowtes-toggle accordingly."
