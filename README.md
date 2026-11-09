# macOS look for Ubuntu

Makes Ubuntu 24.04 (GNOME 46, Wayland) look and feel like macOS Tahoe, without slowing it down: the themes are only stylesheets and icons, nothing extra runs in the background or uses the network, and blur is static (worked out once, not redrawn as windows move). The one small cost is the rounded corners: GNOME draws each rounded window through a shader.

## What you get

- **Apps:** the [MacTahoe](https://github.com/vinceliuice/MacTahoe-gtk-theme) theme, solid variant (see-through sidebars need live blur behind every window, which is slow), traffic-light buttons on the left, MacTahoe icons and cursor, and the Inter font (the open font closest to Apple's SF Pro, whose licence allows it only on Apple devices).
- **Top bar:** frosted; one size for all text (16 px) and icons (20 px); a logo menu at the left (About, System Settings, App Center, Force Quit, Sleep, Restart, Shut Down, Lock Screen, Log Out), then the focused app's name in bold; at the right, tray icons, the date and time, then Wi-Fi, volume and the battery at the far right. Wi-Fi, volume and microphone use Adwaita's bold icons, which read like the macOS menu bar's. No Activities pill, no Accessibility icon, notifications top-right.
- **Control Center** (Quick Settings): a dark glass panel of rounded tiles; a toggle's icon circle turns blue when it's on; sliders are thick white capsules.
- **Dock:** at the bottom, light frosted glass with a bright edge; it hides when a window touches it; the app grid (Launchpad) first, Trash last, dots under open apps.
- **Lock screen:** the wallpaper stays sharp, just a little darker; the date sits above a large clock near the top (Inter Display SemiBold, tightly spaced). Press a key and your picture, name and a frosted password field rise in near the bottom while the clock stays; the field glows blue as you type. Unlocking itself is GNOME's own.
- **Windows:** every window has rounded corners, 24 px like the theme's own, including apps that draw square ones such as Chrome and Electron apps ([Rounded Window Corners Reborn](https://extensions.gnome.org/extension/7048/rounded-window-corners-reborn/); GNOME's own apps round themselves). Minimising pours the window into the dock like the genie effect ([Compiz alike magic lamp effect](https://extensions.gnome.org/extension/3740/compiz-alike-magic-lamp-effect/)).
- **Screenshots** with the Mac keys, Super for Cmd: `Shift+Super+3` the whole screen, `Shift+Super+4` pick an area, `Shift+Super+5` the screenshot and recording panel. They go to Pictures/Screenshots and the clipboard. These keys no longer open the 3rd, 4th and 5th dock apps.
- **Files:** themed like Finder, medium icons; `Space` previews the selected file (GNOME Sushi).
- **Gestures**, via [Touchpad Gesture Customization](https://extensions.gnome.org/extension/7850/touchpad-gesture-customization/) and Mac Look:

  | Gesture | Does |
  |---|---|
  | 3 or 4 fingers up | Overview (Mission Control); again for the app grid (Launchpad) |
  | 3 or 4 fingers down | Back out of the overview |
  | 3 or 4 fingers left/right | Switch workspace (Spaces) |
  | Pinch with thumb and three fingers | Show the desktop |
  | Five fingers: pinch in, or any five-finger move | Open the app grid (Launchpad); again to close it |
  | 2 fingers click | Right click (anywhere) |
  | Tap | Click |

  Not possible on Ubuntu 24.04: three-finger drag (needs a newer libinput), Look Up and force click.

- **App switcher** (Mac Look): `Super+Tab` switches apps as `Cmd+Tab` does; while it's open, `` Super+` `` steps back to the previous app and `` Shift+Super+` `` forward again, as `` Cmd+` `` does on a Mac. Pressed on its own, `` Super+` `` switches between the windows of the app you're in.

## Install

```sh
./install.sh
```

Then log out and back in. It asks for your password once if it needs to install `git curl sassc fonts-inter gnome-sushi gnome-shell-extensions`. Safe to re-run.

It builds the theme from the upstream projects at pinned, reviewed commits ([MacTahoe-gtk-theme](https://github.com/vinceliuice/MacTahoe-gtk-theme), [MacTahoe-icon-theme](https://github.com/vinceliuice/MacTahoe-icon-theme)) by compiling their stylesheets with sassc; their own install scripts never run. It also fixes one colour syntax GTK 4.14 can't read (it dropped window shadows).

| File | Does |
|---|---|
| `install.sh` | Everything below, in order, then the settings |
| `theme.sh` | Builds the themes into `~/.themes` and `~/.config/gtk-4.0`, icons and cursors into `~/.local/share/icons` |
| `extensions.sh` | Installs [Blur my Shell](https://extensions.gnome.org/extension/3193/blur-my-shell/), [Just Perfection](https://extensions.gnome.org/extension/3843/just-perfection/), [Logo Menu](https://extensions.gnome.org/extension/4451/logo-menu/), Touchpad Gesture Customization, Rounded Window Corners Reborn and the magic lamp effect from extensions.gnome.org (every version there is reviewed by GNOME), and turns them on with User Themes and Mac Look |
| `mac-look@virallens.com/` | Mac Look, the GNOME Shell extension for the lock screen layout, the app name and battery position in the top bar, the Control Center, dock and top bar styles, the five-finger gesture and `` Super+` `` in the app switcher |
| `look.dconf` | The settings: theme, fonts, window buttons, dock, top bar, Files, lock screen background, touchpad and gestures, screenshot keys, window corners |
| `uninstall.sh` | Takes it all off again |

## Make it yours

Load your own settings after `install.sh`, e.g. larger text (`gsettings set org.gnome.desktop.interface text-scaling-factor 1.3`) or your own logo in the top bar:

```sh
dconf write /org/gnome/shell/extensions/Logo-menu/custom-icon-path "'$HOME/Pictures/logo.svg'"
dconf write /org/gnome/shell/extensions/Logo-menu/use-custom-icon true
```

## Uninstall

```sh
./uninstall.sh                  # settings back to how they were, extensions off
./uninstall.sh --remove-files   # also deletes the built themes, icons and Mac Look
```

Then log out and back in. `install.sh` saves your settings to `~/.local/state/macos-look/before.dconf` on its first run; without that file, settings go back to GNOME's defaults.

## Licences

The files in this folder are under the MIT licence (`LICENSE`). The theme, icons and cursors are [MacTahoe](https://github.com/vinceliuice/MacTahoe-gtk-theme) by Vince Liuice (GPL-3.0), downloaded and built on your machine, not included here. Inter is by Rasmus Andersson (SIL Open Font License). The extensions from extensions.gnome.org belong to their authors. macOS is a trademark of Apple; this project isn't affiliated with Apple and uses no Apple artwork or fonts.
