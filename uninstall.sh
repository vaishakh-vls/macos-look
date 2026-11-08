#!/usr/bin/env bash
# Takes the macOS look off again: every setting look.dconf changes goes back
# to what it was before the first install (or to GNOME's default), and the
# extensions that weren't on before are turned off.
#
#   ./uninstall.sh                  settings and extensions only
#   ./uninstall.sh --remove-files   also deletes the built themes, icons,
#                                   cursors and the Mac Look extension
#
# Log out and back in afterwards.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/macos-look"
EXTENSIONS=(
    mac-look@virallens.com
    blur-my-shell@aunetx
    just-perfection-desktop@just-perfection
    logomenu@aryan_k
    touchpad-gesture-customization@coooolapps.com
    user-theme@gnome-shell-extensions.gcampax.github.com
)

python3 -I - "$HERE/look.dconf" "$STATE/before.dconf" "${EXTENSIONS[@]}" <<'PY'
import ast, os, subprocess, sys

def read(path):
    """{(dir, key): value} from a dconf dump."""
    values, section = {}, None
    if not os.path.exists(path):
        return values
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("["):
                section = "/" + line.strip("[]") + "/"
            elif section and "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                values[(section, key.strip())] = value
    return values

look, before = read(sys.argv[1]), read(sys.argv[2])
for key in look:
    if key in before:
        subprocess.check_call(["dconf", "write", key[0] + key[1], before[key]])
    else:
        subprocess.check_call(["dconf", "reset", key[0] + key[1]])

ours = sys.argv[3:]
was_on = before.get(("/org/gnome/shell/", "enabled-extensions"), "[]")
was_on = ast.literal_eval(was_on.removeprefix("@as "))
out = subprocess.check_output(["gsettings", "get", "org.gnome.shell", "enabled-extensions"], text=True).strip()
enabled = [u for u in ast.literal_eval(out.removeprefix("@as ")) if u not in ours or u in was_on]
subprocess.check_call(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(enabled)])
print(f"Restored {len(look)} settings; extensions on: {len(enabled)}")
PY

if [ "${1:-}" = --remove-files ]; then
    data="${XDG_DATA_HOME:-$HOME/.local/share}"
    rm -rf "$HOME"/.themes/MacTahoe-* "$data"/icons/MacTahoe "$data"/icons/MacTahoe-dark \
        "$data"/icons/MacTahoe-cursors "$data/gnome-shell/extensions/mac-look@virallens.com"
    gtk4="$HOME/.config/gtk-4.0"
    rm -rf "$gtk4"/{gtk-Light.css,gtk-Dark.css,assets,windows-assets}
    for link in gtk.css gtk-dark.css; do
        [ -L "$gtk4/$link" ] && rm "$gtk4/$link"
    done
    echo "Removed the themes, icons, cursors and the Mac Look extension."
fi

echo "Done. Log out and back in."
