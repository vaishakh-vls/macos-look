#!/usr/bin/env bash
# Installs the MacTahoe (macOS Tahoe style) look for GNOME 46 / Ubuntu 24.04:
#   ~/.themes/MacTahoe-Dark-solid    apps (GTK 3 and 4), with opaque sidebars
#   ~/.themes/MacTahoe-Dark          GNOME Shell: top bar, dock, menus, lock screen
#   ~/.config/gtk-4.0                the same app theme for libadwaita apps (Files, Settings)
#   ~/.local/share/icons             MacTahoe icons and cursors
# (and the Light versions, unused unless you switch to light mode).
#
# It downloads the two upstream projects at commits that were reviewed, then
# only compiles their stylesheets with sassc and copies files. None of
# upstream's own scripts run. Safe to re-run.
set -euo pipefail

GTK_REPO=https://github.com/vinceliuice/MacTahoe-gtk-theme.git
GTK_COMMIT=1e45e19f510edb8cde18fa84d6cd5319f60b086b
ICON_REPO=https://github.com/vinceliuice/MacTahoe-icon-theme.git
ICON_COMMIT=839848b9a8a38a92a6936e30c4abe35cc6f2546d

THEMES="$HOME/.themes"
ICONS="$HOME/.local/share/icons"
GTK4_CONFIG="$HOME/.config/gtk-4.0"
SASSC="sassc -t expanded"

shell_major="$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)"
if [ "$shell_major" != 46 ]; then
    echo "This builds the theme for GNOME 46 (Ubuntu 24.04); this is GNOME $shell_major." >&2
    echo "On newer GNOME, use the theme's own installer instead: $GTK_REPO" >&2
    exit 1
fi
command -v sassc >/dev/null || { echo "Needs sassc (sudo apt install sassc)." >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fetch() {  # fetch <repo> <commit> <dir>: just that commit, no history
    git init -q "$3"
    git -C "$3" fetch -q --depth=1 "$1" "$2"
    git -C "$3" checkout -q FETCH_HEAD
}
echo "Downloading MacTahoe theme and icons"
fetch "$GTK_REPO" "$GTK_COMMIT" "$work/gtk"
fetch "$ICON_REPO" "$ICON_COMMIT" "$work/icons"

SRC="$work/gtk/src"

# The stylesheets import these "-temp" files. Their defaults already target
# GNOME 46 and GTK 4.14; "solid" only turns off the see-through backgrounds.
configure() {  # configure normal|solid
    cp -f "$SRC/sass/_gtk-base.scss" "$SRC/sass/_gtk-base-temp.scss"
    cp -f "$SRC/sass/_theme-options.scss" "$SRC/sass/_theme-options-temp.scss"
    cp -f "$SRC/main/gnome-shell/_shell-base.scss" "$SRC/main/gnome-shell/_shell-base-temp.scss"
    if [ "$1" = solid ]; then
        sed -i "/\$trans/s/true/false/" "$SRC/sass/_gtk-base-temp.scss"
    fi
}

# GTK 4.14 can't read the space-separated "RGB(0 0 0/15%)" form and drops the
# whole window shadow, so those are written as rgba().
fix_colors() {
    perl -pi -e 's{RGB\((\d+) (\d+) (\d+)/(\d+)%\)}{sprintf("rgba(%d, %d, %d, %.2f)", $1, $2, $3, $4 / 100)}ge' "$@"
}

for opacity in normal solid; do
    configure "$opacity"
    suffix=""
    [ "$opacity" = solid ] && suffix="-solid"
    for color in Dark Light; do
        name="MacTahoe-$color$suffix"
        target="$THEMES/$name"
        rm -rf "$target"
        mkdir -p "$target"
        icon_theme=MacTahoe
        [ "$color" = Dark ] && icon_theme=MacTahoe-dark
        cat > "$target/index.theme" <<EOF
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=$name
Comment=A MacOS Tahoe like Gtk+ theme based on Elegant Design
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=$name
MetacityTheme=$name
IconTheme=$icon_theme
CursorTheme=MacTahoe-cursors
ButtonLayout=close,minimize,maximize:menu
EOF

        shell="$target/gnome-shell"
        mkdir -p "$shell/assets"
        cp -r "$SRC/assets/gnome-shell/icons" "$shell"
        cp "$SRC/main/gnome-shell/pad-osd.css" "$shell"
        $SASSC "$SRC/main/gnome-shell/gnome-shell-$color.scss" "$shell/gnome-shell.css"
        cp -r "$SRC/assets/gnome-shell/common-assets/"* "$shell/assets"
        cp -r "$SRC/assets/gnome-shell/assets-$color/"* "$shell/assets"
        cp -r "$SRC/assets/gnome-shell/theme/"* "$shell/assets"
        cp "$SRC/assets/gnome-shell/activities/activities-apple.svg" "$shell/assets/activities.svg"
        cp "$SRC/assets/gnome-shell/activities/activities-apple.svg" "$shell/assets/activities-white.svg"
        mv -f "$shell/assets/"{no-events,process-working,no-notifications}.svg "$shell/"

        for gtk in gtk-3.0 gtk-4.0; do
            mkdir -p "$target/$gtk"
            cp "$SRC/assets/gtk/thumbnails/thumbnail-$color.png" "$target/$gtk/thumbnail.png"
            cp -r "$SRC/assets/gtk/common-assets/assets" "$target/$gtk"
            cp -r "$SRC/assets/gtk/scalable" "$target/$gtk/assets"
            cp -r "$SRC/assets/gtk/windows-assets/titlebutton" "$target/$gtk/windows-assets"
            $SASSC "$SRC/main/$gtk/gtk-$color.scss" "$target/$gtk/gtk.css"
            $SASSC "$SRC/main/$gtk/gtk-Dark.scss" "$target/$gtk/gtk-dark.css"
        done
        fix_colors "$target/gtk-4.0/"*.css
    done

    # libadwaita apps read only ~/.config/gtk-4.0: the solid dark theme goes there.
    if [ "$opacity" = solid ]; then
        mkdir -p "$GTK4_CONFIG"
        rm -rf "$GTK4_CONFIG/"{gtk.css,gtk-dark.css,gtk-Light.css,gtk-Dark.css,assets,windows-assets}
        $SASSC "$SRC/main/gtk-4.0/gtk-Light.scss" "$GTK4_CONFIG/gtk-Light.css"
        $SASSC "$SRC/main/gtk-4.0/gtk-Dark.scss" "$GTK4_CONFIG/gtk-Dark.css"
        fix_colors "$GTK4_CONFIG/gtk-Light.css" "$GTK4_CONFIG/gtk-Dark.css"
        ln -sf "$GTK4_CONFIG/gtk-Dark.css" "$GTK4_CONFIG/gtk.css"
        ln -sf "$GTK4_CONFIG/gtk-Dark.css" "$GTK4_CONFIG/gtk-dark.css"
        cp -r "$SRC/assets/gtk/common-assets/assets" "$GTK4_CONFIG"
        cp -r "$SRC/assets/gtk/scalable" "$GTK4_CONFIG/assets"
        cp -r "$SRC/assets/gtk/windows-assets/titlebutton" "$GTK4_CONFIG/windows-assets"
    fi
done
echo "Installed the MacTahoe themes in $THEMES and $GTK4_CONFIG"

# Icons: MacTahoe (light panel) and MacTahoe-dark, as upstream's installer
# assembles them with default options. Missing icons fall back to Adwaita.
I="$work/icons"
mkdir -p "$ICONS"
write_index() {
    sed -e "s/^Name=MacTahoe\$/Name=$1/" -e 's/^Inherits=.*/Inherits=Adwaita,hicolor/' "$I/src/index.theme" > "$ICONS/$1/index.theme"
}

base="$ICONS/MacTahoe"
rm -rf "$base"
mkdir -p "$base/status"
cp -r "$I/COPYING" "$I/AUTHORS" "$base"
write_index MacTahoe
cp -r "$I"/src/{actions,animations,apps,categories,devices,emotes,emblems,mimes,places,preferences} "$base"
cp -r "$I"/src/status/{16,22,24,32,symbolic} "$base/status"
rm -f "$base"/places/scalable/user-trash{,-full}-dark.svg
cp -r "$I"/links/{actions,apps,categories,devices,emotes,emblems,mimes,places,status,preferences} "$base"

dark="$ICONS/MacTahoe-dark"
rm -rf "$dark"
mkdir -p "$dark"/{apps,categories,emblems,devices,mimes,places,status}
cp -r "$I/COPYING" "$I/AUTHORS" "$dark"
write_index MacTahoe-dark
cp -r "$I/src/actions" "$dark"
cp -r "$I"/src/apps/{16,22,32,symbolic} "$dark/apps"
cp -r "$I"/src/categories/{22,symbolic} "$dark/categories"
cp -r "$I/src/emblems/symbolic" "$dark/emblems"
cp -r "$I/src/mimes/symbolic" "$dark/mimes"
cp -r "$I"/src/devices/{16,22,24,32,symbolic} "$dark/devices"
cp -r "$I"/src/places/{16,22,24,scalable,symbolic} "$dark/places"
cp -r "$I/src/status/symbolic" "$dark/status"
mv -f "$dark/places/scalable/user-trash-dark.svg" "$dark/places/scalable/user-trash.svg"
mv -f "$dark/places/scalable/user-trash-full-dark.svg" "$dark/places/scalable/user-trash-full.svg"
sed -i "s/#363636/#dedede/g" "$dark"/{actions,devices,places}/{16,22,24}/*.svg
sed -i "s/#363636/#dedede/g" "$dark"/apps/{16,22,32}/*.svg
sed -i "s/#363636/#dedede/g" "$dark"/categories/22/*.svg
sed -i "s/#363636/#dedede/g" "$dark"/{actions,devices}/32/*.svg
sed -i "s/#363636/#dedede/g" "$dark"/{actions,apps,categories,emblems,devices,mimes,places,status}/symbolic/*.svg
cp -r "$I"/links/actions/{16,22,24,32,symbolic} "$dark/actions"
cp -r "$I"/links/devices/{16,22,24,32,symbolic} "$dark/devices"
cp -r "$I"/links/places/{16,22,24,scalable,symbolic} "$dark/places"
cp -r "$I"/links/apps/{16,22,32,symbolic} "$dark/apps"
cp -r "$I"/links/categories/{22,symbolic} "$dark/categories"
cp -r "$I/links/mimes/symbolic" "$dark/mimes"
cp -r "$I/links/status/symbolic" "$dark/status"
for dir in animations emotes preferences; do ln -s "../MacTahoe/$dir" "$dark/$dir"; done
for dir in categories/32 emblems/16 emblems/22 emblems/24 mimes/16 mimes/22 mimes/scalable \
           apps/scalable devices/scalable status/16 status/22 status/24 status/32; do
    ln -s "../../MacTahoe/$dir" "$dark/$dir"
done
# Wi-Fi, volume and microphone: Adwaita's bold icons, which read like the
# macOS menu bar's. MacTahoe's are hairline-thin and look tiny in the top bar.
for adwaita in /usr/share/icons/Adwaita/symbolic/status/{network-wireless,audio-volume,microphone-sensitivity}-*symbolic.svg; do
    find "$base/status" "$dark/status" -name "$(basename "$adwaita")" -delete
done
for theme in "$base" "$dark"; do
    for dir in actions animations apps categories devices emotes emblems mimes places preferences status; do
        ln -sfn "$dir" "$theme/$dir@2x"
    done
    gtk-update-icon-cache -q "$theme"
done

# Cursors: the black macOS-style arrow.
rm -rf "$ICONS/MacTahoe-cursors"
mkdir -p "$ICONS/MacTahoe-cursors"
cp -r "$I/cursors/dist/"* "$ICONS/MacTahoe-cursors"
echo "Installed MacTahoe icons and cursors in $ICONS"
