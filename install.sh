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
echo "  # Window rules (add near your other windowrule lines)"
echo "  windowrule = float on, match:class nowtes"
echo "  windowrule = size 900 600, match:class nowtes"
echo "  windowrule = center, match:class nowtes"
echo "  windowrule = workspace special:nowtes silent, match:class nowtes"
echo ""
echo "  # Keybinding (add near your other bind lines)"
echo "  bindd = SUPER, N, Nowtes, exec, ~/.local/bin/nowtes-toggle"
echo ""
echo "To use a different terminal, set NOWTES_TERMINAL in your environment."
echo "Default is 'foot'. Supported: foot, alacritty, kitty, ghostty."
echo "The --app-id/--class flag is chosen automatically."
