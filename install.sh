#!/usr/bin/env bash
# macOS look for Ubuntu 24.04 (GNOME 46): theme, icons, top bar, dock, Control
# Center, lock screen and trackpad gestures. Safe to re-run.
#
# Your current settings for everything it changes are saved on the first run,
# so ./uninstall.sh can put them back. Log out and back in afterwards.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/macos-look"
MAC_LOOK=mac-look@virallens.com

shell_major="$(gnome-shell --version 2>/dev/null | awk '{print $3}' | cut -d. -f1)"
if [ "$shell_major" != 46 ]; then
    echo "This is made for GNOME 46 (Ubuntu 24.04); found GNOME ${shell_major:-none}." >&2
    exit 1
fi

# Build tools, the Inter font, Space-bar previews in Files, and User Themes.
packages=(git curl sassc fonts-inter gnome-sushi gnome-shell-extensions)
missing=()
for pkg in "${packages[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if [ ${#missing[@]} -gt 0 ]; then
    echo "==> Installing ${missing[*]}"
    sudo apt-get install -y "${missing[@]}"
fi

# Settings as they were before the first install, for uninstall.sh.
mkdir -p "$STATE"
[ -f "$STATE/before.dconf" ] || dconf dump / > "$STATE/before.dconf"

echo "==> Theme, icons and cursors"
"$HERE/theme.sh"

echo "==> Mac Look extension"
target="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$MAC_LOOK"
rm -rf "$target"
mkdir -p "$target"
cp -r "$HERE/$MAC_LOOK/." "$target/"

echo "==> Extensions from extensions.gnome.org"
"$HERE/extensions.sh"

echo "==> Settings"
dconf load / < "$HERE/look.dconf"

echo "Done. Log out and back in to see the macOS look."
