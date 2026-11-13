// Finishing touches for the macOS look:
//
// - Lock screen like macOS Tahoe: a short date above a large clock (hours
//   and minutes, no seconds) near
//   the top of the screen, so the wallpaper stays in view. When you press a
//   key, the clock stays and your picture, name and password field rise in
//   near the bottom of the screen. Only where GNOME's own pieces sit and how
//   they look changes; unlocking itself is GNOME's. If anything here fails,
//   the normal lock screen shows.
// - The focused app's name next to the logo menu, as on a Mac (GNOME's own
//   app menu button, which GNOME 45 took out of the top bar). It is added
//   without redrawing the top bar, which would bring back what Just
//   Perfection hides (the App menu is back extension does that).
// - No Activities pill next to the logo menu, even after the top bar is
//   redrawn (as GNOME does after unlocking).
// - Five fingers: the app grid (Launchpad). Pinch them in to open it and
//   spread them to close it; any other five-finger move opens or closes it,
//   because libinput judges pinch or swipe by the first two fingers down,
//   which move the same way when a hand closes, so most five-finger pinches
//   arrive as swipes. GNOME and Touchpad Gesture Customization use 3 and 4.
// - The battery at the far right of the top bar, with the date and time just
//   before Wi-Fi, volume and battery. Just Perfection puts the clock at the
//   end of the right side; this only swaps the order there, which moves
//   nothing in or out of the bar, so Just Perfection doesn't react to it.
// - In the Super+Tab app switcher, Super+` steps back to the previous app
//   (and Shift+Super+` forward again), as Cmd+` does in the Mac's Cmd+Tab
//   switcher. Pressed on its own, Super+` still switches between the
//   windows of the app you're in, as on a Mac.
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import St from 'gi://St';
import * as AltTab from 'resource:///org/gnome/shell/ui/altTab.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

/** Where the top of the date sits, as a share of the screen height. */
const CLOCK_TOP = 0.08;
const STYLE_CLASS = 'mac-lockscreen-clock';
/** How far the fingers must close (or spread) to count as a pinch. */
const PINCH_IN = 0.8;
const PINCH_OUT = 1.25;
/** Where the bottom of the password prompt sits, as a share of the screen height from the bottom. */
const PROMPT_BOTTOM = 0.07;
/** How far (in pixels) the prompt rises as it fades in. */
const PROMPT_RISE = 36;

/**
 * GNOME's app switcher key handler, with Super+` (GNOME's "switch windows of
 * an app" key) and Shift+Super+` moving between apps while the apps row has
 * the focus. Once you're among one app's windows (Super+` alone, or Down),
 * GNOME's own handling stays.
 */
function appSwitcherKeys(original) {
    return function (keysym, action) {
        if (!this._thumbnailsFocused) {
            if (action === Meta.KeyBindingAction.SWITCH_GROUP) {
                this._select(this._previous());
                return Clutter.EVENT_STOP;
            }
            if (action === Meta.KeyBindingAction.SWITCH_GROUP_BACKWARD) {
                this._select(this._next());
                return Clutter.EVENT_STOP;
            }
        }
        return original.call(this, keysym, action);
    };
}

/** Runs fn once GNOME's own handlers for the current event have run. */
function later(fn) {
    global.compositor.get_laters().add(Meta.LaterType.BEFORE_REDRAW, () => {
        fn();
        return false;
    });
}

export default class MacLook extends Extension {
    enable() {
        // GNOME adds the lock screen to this group before it builds the
        // clock, so styling waits until the frame is about to be drawn.
        this._group = Main.screenShield._lockDialogGroup;
        this._group.connectObject('child-added', (_group, dialog) => later(() => this._style(dialog)), this);
        for (const dialog of this._group.get_children())
            this._style(dialog);

        this._activities = Main.panel.statusArea.activities?.container ?? null;
        this._activities?.connectObject('notify::visible', () => this._hideActivities(), this);
        this._hideActivities();

        this._addAppName();
        // GNOME rebuilds the top bar when the session mode changes (unlocking).
        Main.sessionMode.connectObject('updated', () => later(() => {
            this._showAppName();
            this._placeClock();
        }), this);
        Main.overview.connectObject('hidden', () => later(() => this._showAppName()), this);
        Shell.WindowTracker.get_default().connectObject('notify::focus-app', () => later(() => this._showAppName()), this);

        global.stage.connectObject('captured-event::touchpad', (_stage, event) => this._onTouchpad(event), this);

        Main.panel._rightBox.connectObject('child-added', () => later(() => this._placeClock()), this);
        this._placeClock();

        const switcher = AltTab.AppSwitcherPopup.prototype;
        this._switcherKeys = switcher._keyPressHandler;
        switcher._keyPressHandler = appSwitcherKeys(this._switcherKeys);
    }

    disable() {
        if (this._switcherKeys) {
            AltTab.AppSwitcherPopup.prototype._keyPressHandler = this._switcherKeys;
            this._switcherKeys = null;
        }
        Main.panel._rightBox.disconnectObject(this);
        // The clock back at the end, where Just Perfection puts it.
        const clock = Main.panel.statusArea.dateMenu?.container;
        if (clock?.get_parent() === Main.panel._rightBox)
            Main.panel._rightBox.set_child_above_sibling(clock, null);
        global.stage.disconnectObject(this);
        Main.sessionMode.disconnectObject(this);
        Main.overview.disconnectObject(this);
        Shell.WindowTracker.get_default().disconnectObject(this);
        this._appMenu?.destroy();
        this._appMenu = null;

        this._group.disconnectObject(this);
        for (const dialog of this._group.get_children())
            this._unstyle(dialog);
        this._group = null;

        this._activities?.disconnectObject(this);
        if (this._activities && Main.sessionMode.panel.left.includes('activities'))
            this._activities.show();
        this._activities = null;
    }

    _addAppName() {
        const panel = Main.panel;
        if (panel.statusArea.appMenu)
            return; // already shown by GNOME or another extension
        const appMenu = panel._ensureIndicator('appMenu');
        if (!appMenu)
            return;
        panel._addToPanelBox('appMenu', appMenu, panel._leftBox.get_n_children(), panel._leftBox);
        // No spinner while an app starts; a Mac shows just the name.
        appMenu._spinner?.get_parent()?.remove_child(appMenu._spinner);
        this._appMenu = appMenu;
        this._showAppName();
    }

    _showAppName() {
        const appMenu = this._appMenu;
        if (!appMenu || Main.sessionMode.isLocked)
            return;
        // GNOME hides it on the lock screen and, as it isn't one of its own
        // top bar items, never shows it again after unlocking.
        if (!appMenu.container.visible)
            appMenu.container.show();
        // Created while the overview is open (as at login), the button
        // starts hidden and GNOME only fades it in; _visible is GNOME's
        // own "should be visible" flag.
        if (appMenu._visible && !appMenu.visible)
            appMenu.show();
    }

    _onTouchpad(event) {
        const type = event.type();
        const pinch = type === Clutter.EventType.TOUCHPAD_PINCH;
        if ((!pinch && type !== Clutter.EventType.TOUCHPAD_SWIPE) ||
            event.get_touchpad_gesture_finger_count() !== 5)
            return Clutter.EVENT_PROPAGATE;
        if (Main.sessionMode.isLocked)
            return Clutter.EVENT_PROPAGATE;
        switch (event.get_gesture_phase()) {
        case Clutter.TouchpadGesturePhase.BEGIN:
            this._pinchScale = 1;
            break;
        case Clutter.TouchpadGesturePhase.UPDATE:
            // Relative to where the fingers started.
            if (pinch)
                this._pinchScale = event.get_gesture_pinch_scale();
            break;
        case Clutter.TouchpadGesturePhase.END:
            if (!pinch)
                this._toggleApps();
            else if (this._pinchScale < PINCH_IN)
                Main.overview.showApps();
            else if (this._pinchScale > PINCH_OUT && Main.overview.visible)
                Main.overview.hide();
            this._pinchScale = 1;
            break;
        case Clutter.TouchpadGesturePhase.CANCEL:
            this._pinchScale = 1;
            break;
        }
        // Not passed on to apps, which would zoom.
        return Clutter.EVENT_STOP;
    }

    _toggleApps() {
        if (Main.overview.visible)
            Main.overview.hide();
        else
            Main.overview.showApps();
    }

    _placeClock() {
        const box = Main.panel._rightBox;
        const clock = Main.panel.statusArea.dateMenu?.container;
        const status = Main.panel.statusArea.quickSettings?.container;
        // Only when Just Perfection has put the clock on the right side.
        if (!clock || !status || clock.get_parent() !== box || status.get_parent() !== box)
            return;
        // Reordering children emits no child-added, so this can't loop.
        if (box.get_last_child() !== status)
            box.set_child_above_sibling(status, null);
        if (status.get_previous_sibling() !== clock)
            box.set_child_below_sibling(clock, status);
    }

    _hideActivities() {
        if (this._activities?.visible)
            this._activities.hide();
    }

    _style(dialog) {
        const clock = dialog._clock;
        if (!clock?._time || !clock._date || clock.has_style_class_name(STYLE_CLASS))
            return;
        try {
            clock.add_style_class_name(STYLE_CLASS);
            clock.set_child_below_sibling(clock._date, clock._time);
            // Connected after GNOME's own handler, so this text is the one that stays.
            clock._wallClock?.connectObject('notify::clock', () => this._macClock(clock), this);
            this._macClock(clock);
            // GNOME animates the clock's own position when the password
            // prompt opens, so the labels inside it are moved instead.
            clock.connectObject('notify::allocation', () => this._place(clock), this);
            this._place(clock);

            // GNOME swaps the clock for the password prompt as this goes 0 -> 1.
            const prompt = dialog._promptBox;
            dialog._adjustment.connectObject('notify::value', () => this._arrange(dialog), this);
            prompt.connectObject('child-added', (_box, child) => this._watchPrompt(dialog, child), this);
            for (const child of prompt.get_children())
                this._watchPrompt(dialog, child);
            this._arrange(dialog);
        } catch (e) {
            console.error(`mac-look: ${e}`);
            this._unstyle(dialog);
        }
    }

    /** The time without seconds and a short date ("Fri Nov 13"), as a Mac's lock screen has them. */
    _macClock(clock) {
        this._interface ??= new Gio.Settings({schema_id: 'org.gnome.desktop.interface'});
        const now = GLib.DateTime.new_now_local();
        const twelveHour = this._interface.get_string('clock-format') === '12h';
        clock._time.text = now.format(twelveHour ? '%-I:%M' : '%H:%M');
        clock._date.text = now.format('%a %b %-d');
    }

    _place(clock) {
        const stack = clock.get_parent();
        const box = stack?.get_parent();
        const first = clock.get_first_child();
        if (!box || !first)
            return;
        const height = box.allocation.get_height();
        if (height <= 0)
            return;
        const top = box.allocation.y1 + stack.allocation.y1 + clock.allocation.y1 + first.allocation.y1;
        const shift = Math.min(0, Math.round(height * CLOCK_TOP - top));
        for (const label of clock.get_children())
            label.translation_y = shift;
    }

    _watchPrompt(dialog, authPrompt) {
        // Its natural height, not the whole column: GNOME lets the picture
        // and the message below the field stretch to fill it.
        authPrompt.y_expand = false;
        authPrompt.connectObject('notify::allocation', () => this._arrange(dialog), this);
        this._arrange(dialog);
    }

    /** Lays out the lock screen for how far GNOME is into showing the prompt. */
    _arrange(dialog) {
        const progress = dialog._adjustment.value;
        const clock = dialog._clock;
        const prompt = dialog._promptBox;
        const {scaleFactor} = St.ThemeContext.get_for_stage(global.stage);

        // The clock stays while you type, as on a Mac; GNOME fades it out.
        clock.set({visible: true, opacity: 255, scale_x: 1, scale_y: 1, translation_y: 0});
        clock._hint?.set({visible: progress === 0});
        // Notifications sit at the bottom, where the prompt now goes.
        dialog._notificationsBox?.set({opacity: Math.round(255 * (1 - progress))});

        // The prompt rises into place near the bottom as it fades in.
        prompt.set({
            scale_x: 1,
            scale_y: 1,
            translation_y: this._promptShift(prompt) + Math.round(PROMPT_RISE * (1 - progress) * scaleFactor),
        });
    }

    _promptShift(prompt) {
        const stack = prompt.get_parent();
        const box = stack?.get_parent();
        const content = prompt.get_first_child();
        if (!box || !content)
            return 0;
        const height = box.allocation.get_height();
        if (height <= 0 || content.allocation.get_height() <= 0)
            return 0;
        const bottom = stack.allocation.y1 + prompt.allocation.y1 + content.allocation.y2;
        return Math.max(0, Math.round(height * (1 - PROMPT_BOTTOM) - bottom));
    }

    _unstyle(dialog) {
        dialog._adjustment?.disconnectObject(this);
        dialog._promptBox?.disconnectObject(this);
        for (const child of dialog._promptBox?.get_children() ?? []) {
            child.disconnectObject(this);
            child.y_expand = true;
        }
        dialog._clock?._hint?.set({visible: true});
        dialog._notificationsBox?.set({opacity: 255});
        if (dialog._adjustment)
            dialog._setTransitionProgress?.(dialog._adjustment.value);

        const clock = dialog._clock;
        if (!clock?._time || !clock._date)
            return;
        clock.disconnectObject(this);
        clock._wallClock?.disconnectObject(this);
        clock._updateClock?.();
        clock.remove_style_class_name(STYLE_CLASS);
        clock.set_child_below_sibling(clock._time, clock._date);
        for (const label of clock.get_children())
            label.translation_y = 0;
    }
}
