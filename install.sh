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
if python3 -c "import textual" 2>/dev/null; then
    echo "textual already installed, skipping."
elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm python-textual || \
        pip install --break-system-packages textual
else
    pip install --user textual 2>/dev/null || \
        pip install --break-system-packages textual
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
