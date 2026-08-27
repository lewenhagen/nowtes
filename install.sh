#!/bin/bash
set -e

INSTALL_DIR="$HOME/.local/share/nowtes"
BIN_DIR="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
BINDINGS_LUA="$HOME/.config/hypr/bindings.lua"
APPCLASS="io.nowtes"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}::${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}!${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*"; }

# --- Pre-flight checks ---
echo -e "${BOLD}Installing Nowtes${NC}"
echo ""

if ! command -v hyprctl &>/dev/null; then
    err "Hyprland not found. Nowtes requires Hyprland."
    exit 1
fi
ok "Hyprland detected"

if ! command -v python3 &>/dev/null; then
    err "python3 not found."
    exit 1
fi
ok "Python 3 detected"

# --- Detect terminal ---
TERMINAL=""
for t in foot ghostty alacritty kitty; do
    if command -v "$t" &>/dev/null; then
        TERMINAL="$t"
        break
    fi
done

if [ -z "$TERMINAL" ]; then
    err "No supported terminal found (foot, ghostty, alacritty, kitty)."
    exit 1
fi
ok "Terminal: ${BOLD}$TERMINAL${NC}"

# --- Detect omarchy ---
OMARCHY=false
if [ -d "$HOME/.local/share/omarchy" ]; then
    OMARCHY=true
    ok "Omarchy detected"
fi

# --- Detect Hyprland config system ---
LUA_MODE=false
if [ -f "$HYPR_LUA" ]; then
    LUA_MODE=true
    ok "Hyprland Lua config detected (Omarchy v4+)"
fi

# --- Install files ---
info "Installing files..."
mkdir -p "$INSTALL_DIR" "$BIN_DIR"
cp "$SCRIPT_DIR/nowtes.py" "$INSTALL_DIR/nowtes.py"
chmod +x "$INSTALL_DIR/nowtes.py"
cp "$SCRIPT_DIR/nowtes-toggle" "$BIN_DIR/nowtes-toggle"
chmod +x "$BIN_DIR/nowtes-toggle"
ok "Files installed"

# --- Install Python dependencies ---
info "Checking Python dependencies..."
if python3 -c "import textual" 2>/dev/null; then
    ok "textual already installed"
elif command -v pacman &>/dev/null; then
    info "Installing textual via pacman..."
    sudo pacman -S --noconfirm python-textual || pip install --break-system-packages textual
    ok "textual installed"
elif command -v apt-get &>/dev/null; then
    info "Installing textual via pip..."
    pip install --user textual 2>/dev/null || pip install --break-system-packages textual
    ok "textual installed"
else
    pip install --user textual 2>/dev/null || pip install --break-system-packages textual
    ok "textual installed"
fi

# --- Detect binding conflicts ---
_find_bind_conflict() {
    local mod="$1" key="$2" desc=""

    if $LUA_MODE; then
        local lua_key
        if [ "$mod" = "SUPER" ]; then
            lua_key="SUPER + ${key}"
        else
            lua_key="SUPER + SHIFT + ${key}"
        fi
        local match
        match=$(grep -rh "\"${lua_key}\"" \
            "$HOME/.local/share/omarchy/default/hypr/" \
            "$HOME/.config/hypr/" \
            2>/dev/null | grep -v "[Nn]owtes\|^[[:space:]]*--\|hl\.unbind" | head -1 || true)
        if [ -n "$match" ]; then
            desc=$(echo "$match" | sed -n 's/.*o\.bind([^,]*, *"\([^"]*\)".*/\1/p')
            [ -z "$desc" ] && desc="unknown"
            echo "$desc"
        fi
    else
        local pattern
        if [ "$mod" = "SUPER" ]; then
            pattern="^[[:space:]]*bindd\?[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*${key},"
        else
            pattern="^[[:space:]]*bindd\?[[:space:]]*=[[:space:]]*SUPER SHIFT,[[:space:]]*${key},"
        fi
        local match
        match=$(grep -rh "$pattern" \
            "$HOME/.local/share/omarchy/default/hypr/" \
            "$HOME/.config/hypr/" \
            2>/dev/null | grep -v "nowtes" | head -1 || true)
        if [ -n "$match" ]; then
            desc=$(echo "$match" | sed -n 's/.*bindd = [^,]*, [^,]*, \([^,]*\),.*/\1/p')
            [ -z "$desc" ] && desc="unknown"
            echo "$desc"
        fi
    fi
}

echo ""
CONFLICT_SUPER=$(_find_bind_conflict "SUPER" "N")
CONFLICT_SHIFT=$(_find_bind_conflict "SUPER SHIFT" "N")

HAS_CONFLICTS=false
if [ -n "$CONFLICT_SUPER" ] || [ -n "$CONFLICT_SHIFT" ]; then
    HAS_CONFLICTS=true
fi

info "Keybinding selection:"
echo ""

OPT1_NOTE=""
OPT2_NOTE=""
[ -n "$CONFLICT_SUPER" ] && OPT1_NOTE=" (replaces ${BOLD}${CONFLICT_SUPER}${NC})"
[ -n "$CONFLICT_SHIFT" ] && OPT2_NOTE=" (replaces ${BOLD}${CONFLICT_SHIFT}${NC})"

echo -e "  1) ${BOLD}SUPER + N${NC}${OPT1_NOTE}"
echo -e "  2) ${BOLD}SUPER + SHIFT + N${NC}${OPT2_NOTE}"
echo ""

if [ -n "$CONFLICT_SUPER" ] && [ -z "$CONFLICT_SHIFT" ]; then
    DEFAULT=2
elif [ -z "$CONFLICT_SUPER" ]; then
    DEFAULT=1
else
    DEFAULT=1
fi

read -rp "Choose keybinding [1/2] (default: $DEFAULT): " BIND_CHOICE
BIND_CHOICE="${BIND_CHOICE:-$DEFAULT}"

case "$BIND_CHOICE" in
    1)
        BIND_MOD="SUPER"
        BIND_KEY="N"
        BIND_LUA="SUPER + N"
        NEEDS_UNBIND=$( [ -n "$CONFLICT_SUPER" ] && echo true || echo false )
        ok "Keybinding: SUPER + N"
        ;;
    *)
        BIND_MOD="SUPER SHIFT"
        BIND_KEY="N"
        BIND_LUA="SUPER + SHIFT + N"
        NEEDS_UNBIND=$( [ -n "$CONFLICT_SHIFT" ] && echo true || echo false )
        ok "Keybinding: SUPER + SHIFT + N"
        ;;
esac

# --- Configure Hyprland ---
echo ""
info "Configuring Hyprland..."

if $LUA_MODE; then
    # Clean up any legacy ini-style block from hyprland.conf
    if [ -f "$HYPR_CONF" ] && grep -q "match:class $APPCLASS\|nowtes-toggle" "$HYPR_CONF" 2>/dev/null; then
        info "Removing legacy Nowtes config from hyprland.conf..."
        sed -i "/# >>> Nowtes/,/# <<< Nowtes/d" "$HYPR_CONF"
        sed -i "/match:class ${APPCLASS}/d" "$HYPR_CONF"
        sed -i "/nowtes-toggle/d" "$HYPR_CONF"
        sed -i "/unbind.*# nowtes/d" "$HYPR_CONF"
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$HYPR_CONF"
    fi

    # Remove previous Nowtes Lua blocks from both files (idempotent reinstall)
    for lua_file in "$HYPR_LUA" "$BINDINGS_LUA"; do
        if [ -f "$lua_file" ] && grep -qi "nowtes" "$lua_file"; then
            info "Removing previous Nowtes config from $(basename "$lua_file")..."
            sed -i "/-- >>> Nowtes/,/-- <<< Nowtes/d" "$lua_file"
            sed -i '/[Nn]owtes\|hl\.unbind("SUPER + N")\|hl\.unbind("SUPER + SHIFT + N")/d' "$lua_file"
            sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$lua_file"
        fi
    done

    # Append window rules to hyprland.lua
    {
        echo ""
        echo "-- >>> Nowtes"
        local lua_match="${APPCLASS//./%.}"
        echo "o.window(\"^${lua_match}$\", { float = true, fullscreen = false, size = { 900, 600 }, center = true, workspace = \"special:${APPCLASS} silent\" })"
        echo "-- <<< Nowtes"
    } >> "$HYPR_LUA"
    ok "Window rules added to hyprland.lua"

    # Append binding to bindings.lua
    {
        echo ""
        echo "-- >>> Nowtes"
        $NEEDS_UNBIND && echo "hl.unbind(\"${BIND_LUA}\")"
        echo "o.bind(\"${BIND_LUA}\", \"Nowtes\", \"$BIN_DIR/nowtes-toggle\")"
        echo "-- <<< Nowtes"
    } >> "$BINDINGS_LUA"
    ok "Keybinding added to bindings.lua"

else
    # Legacy ini config path
    if [ ! -f "$HYPR_CONF" ]; then
        err "Hyprland config not found at $HYPR_CONF"
        echo "Add these lines manually to your Hyprland config:"
        echo ""
        echo "  windowrule = float on, match:class $APPCLASS"
        echo "  windowrule = size 900 600, match:class $APPCLASS"
        echo "  windowrule = center 1, match:class $APPCLASS"
        echo "  windowrule = workspace special:$APPCLASS silent, match:class $APPCLASS"
        $NEEDS_UNBIND && echo "  unbind = $BIND_MOD, N"
        echo "  bindd = $BIND_MOD, $BIND_KEY, Nowtes, exec, $BIN_DIR/nowtes-toggle"
        exit 0
    fi

    # Remove any previous nowtes config block (idempotent reinstall)
    if grep -q "match:class $APPCLASS\|nowtes-toggle" "$HYPR_CONF"; then
        info "Removing previous Nowtes config..."
        sed -i "/# >>> Nowtes/,/# <<< Nowtes/d" "$HYPR_CONF" 2>/dev/null || true
        sed -i "/match:class ${APPCLASS}/d" "$HYPR_CONF"
        sed -i "/nowtes-toggle/d" "$HYPR_CONF"
        sed -i "/unbind.*# nowtes/d" "$HYPR_CONF"
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$HYPR_CONF"
    fi

    # Append new config block
    {
        echo ""
        echo "# >>> Nowtes"
        echo "windowrule = float on, match:class $APPCLASS"
        echo "windowrule = size 900 600, match:class $APPCLASS"
        echo "windowrule = center 1, match:class $APPCLASS"
        echo "windowrule = workspace special:$APPCLASS silent, match:class $APPCLASS"
        $NEEDS_UNBIND && echo "unbind = $BIND_MOD, N  # nowtes"
        echo "bindd = $BIND_MOD, $BIND_KEY, Nowtes, exec, $BIN_DIR/nowtes-toggle"
        echo "# <<< Nowtes"
    } >> "$HYPR_CONF"
fi

ok "Hyprland config updated"

# --- Reload Hyprland ---
if hyprctl reload &>/dev/null; then
    ok "Hyprland reloaded"
else
    warn "Could not reload Hyprland — reload manually with: hyprctl reload"
fi

# --- Done ---
echo ""
echo -e "${GREEN}${BOLD}Nowtes installed!${NC}"
BIND_DISPLAY="SUPER + $BIND_KEY"
[ "$BIND_MOD" = "SUPER SHIFT" ] && BIND_DISPLAY="SUPER + SHIFT + $BIND_KEY"
echo -e "Press ${BOLD}$BIND_DISPLAY${NC} to toggle."
echo ""
echo "Data is stored in $INSTALL_DIR/todos.json"
echo "To use a different terminal, set NOWTES_TERMINAL in your environment."
