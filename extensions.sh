#!/usr/bin/env bash
# Installs the GNOME extensions behind the macOS look, from
# extensions.gnome.org (every version there is reviewed by GNOME), in the build
# for this GNOME version, and turns them on. They start at the next login.
#
# Chosen to stay light: none runs anything in the background or uses the
# network, and blur is "static" (worked out once, not redrawn as windows move).
set -euo pipefail

# The focused app's name next to the logo, the lock screen layout and more
# come from Mac Look, in this folder; install.sh copies it, this turns it on.
MAC_LOOK=mac-look@virallens.com
EXTENSIONS=(
    blur-my-shell@aunetx                           # frosted top bar, dock, overview and lock screen
    just-perfection-desktop@just-perfection        # clock at the right, notifications top-right, no Activities pill
    logomenu@aryan_k                               # the logo menu: About, Settings, Force Quit, Sleep, Restart, Lock...
    touchpad-gesture-customization@coooolapps.com  # macOS trackpad gestures
    rounded-window-corners@fxgn                    # rounded corners on apps that draw square ones (Chrome, Electron)
    compiz-alike-magic-lamp-effect@hermes83.github.com  # the genie effect when a window minimises
)
# Ships with Ubuntu (apt package gnome-shell-extensions); lets GNOME Shell use the theme.
USER_THEME=user-theme@gnome-shell-extensions.gcampax.github.com

shell_major="$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for uuid in "${EXTENSIONS[@]}"; do
    echo "Installing $uuid"
    curl -fsSL --max-time 120 -o "$work/$uuid.zip" \
        "https://extensions.gnome.org/download-extension/$uuid.shell-extension.zip?shell_version=$shell_major"
    gnome-extensions install --force "$work/$uuid.zip"
done

# Turn them on; GNOME Shell loads newly installed extensions only at login.
python3 - "$USER_THEME" "$MAC_LOOK" "${EXTENSIONS[@]}" <<'PY'
import ast, subprocess, sys
def get(key):
    out = subprocess.check_output(["gsettings", "get", "org.gnome.shell", key], text=True).strip()
    return ast.literal_eval(out.removeprefix("@as "))
enabled, disabled = get("enabled-extensions"), get("disabled-extensions")
enabled += [u for u in sys.argv[1:] if u not in enabled]
disabled = [u for u in disabled if u not in sys.argv[1:]]
subprocess.check_call(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(enabled)])
subprocess.check_call(["gsettings", "set", "org.gnome.shell", "disabled-extensions", str(disabled)])
PY

echo "Done. Log out and back in to start them."
