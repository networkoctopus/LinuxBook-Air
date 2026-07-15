import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const CONTROL = '/usr/libexec/linuxbook-air-thunderbolt-control';
const ENABLED_COLOR = '#ed333b';
const DISABLED_COLOR = '#ffffff';

const ThunderboltIndicator = GObject.registerClass({
    GTypeName: 'LinuxBookAirThunderboltIndicator',
},
class ThunderboltIndicator extends PanelMenu.Button {
    _init(extension) {
        super._init(0.0, extension.metadata.name, false);

        this._enabled = false;
        this._state = 'disabled';
        this._busy = false;
        this._destroyed = false;

        const iconPath = extension.dir.get_child('icons').get_child('thunderbolt-symbolic.svg').get_path();
        this._icon = new St.Icon({
            gicon: Gio.icon_new_for_string(iconPath),
            style_class: 'system-status-icon',
        });
        this.add_child(this._icon);

        this._statusItem = new PopupMenu.PopupMenuItem('', {
            reactive: false,
            can_focus: false,
        });
        this.menu.addMenuItem(this._statusItem);

        this._actionItem = new PopupMenu.PopupMenuItem('Enable Thunderbolt');
        this._actionItem.connect('activate', () => this._requestToggle());
        this.menu.addMenuItem(this._actionItem);

        this._powerItem = new PopupMenu.PopupMenuItem('Disabled by default to save power', {
            reactive: false,
            can_focus: false,
        });
        this.menu.addMenuItem(this._powerItem);

        this.menu.connect('open-state-changed', (_menu, open) => {
            if (open)
                this._refresh();
        });

        // The system service powers Thunderbolt down before sleep. Refresh on
        // resume so the top-bar colour immediately reflects that transition.
        this._sleepSignalId = Gio.DBus.system.signal_subscribe(
            'org.freedesktop.login1',
            'org.freedesktop.login1.Manager',
            'PrepareForSleep',
            '/org/freedesktop/login1',
            null,
            Gio.DBusSignalFlags.NONE,
            (_connection, _sender, _path, _interface, _signal, parameters) => {
                const [preparingForSleep] = parameters.deepUnpack();
                if (!preparingForSleep)
                    this._refresh();
            }
        );

        this._refresh();
    }

    _setState(state) {
        const enabled = state === 'enabled';
        const powerdownIncomplete = state === 'powerdown-incomplete';
        const restartRequired = state === 'restart-required';
        const drawingPower = enabled || powerdownIncomplete;

        this._state = state;
        this._enabled = drawingPower;
        this._icon.set_style(`color: ${drawingPower ? ENABLED_COLOR : DISABLED_COLOR};`);
        if (enabled) {
            this._statusItem.label.text = 'Thunderbolt is enabled';
            this._actionItem.label.text = 'Disable until restart';
            this._powerItem.label.text = 'Higher power use; disables before sleep';
        } else if (powerdownIncomplete) {
            this._statusItem.label.text = 'Thunderbolt power-down is incomplete';
            this._actionItem.label.text = 'Retry full power-down';
            this._powerItem.label.text = 'Maximum power saving is not yet active';
        } else if (restartRequired) {
            this._statusItem.label.text = 'Thunderbolt is fully powered down';
            this._actionItem.label.text = 'Restart required to enable';
            this._powerItem.label.text = 'Maximum power saving is active';
        } else {
            this._statusItem.label.text = 'Thunderbolt is disabled';
            this._actionItem.label.text = 'Enable Thunderbolt';
            this._powerItem.label.text = 'Disabled by default to save power';
        }
        this._actionItem.setSensitive(!restartRequired && !this._busy);
        this.accessible_name = drawingPower
            ? powerdownIncomplete
                ? 'Thunderbolt power-down incomplete'
                : 'Thunderbolt enabled'
            : restartRequired
                ? 'Thunderbolt disabled until restart'
                : 'Thunderbolt disabled';
    }

    _setBusy(busy) {
        this._busy = busy;
        this._actionItem.setSensitive(!busy && this._state !== 'restart-required');
        if (busy) {
            this._statusItem.label.text = this._enabled
                ? 'Disabling Thunderbolt…'
                : 'Enabling Thunderbolt…';
        }
    }

    _spawn(argv, callback) {
        let process;
        try {
            process = Gio.Subprocess.new(
                argv,
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
        } catch (error) {
            callback(false, '', error.message);
            return;
        }

        process.communicate_utf8_async(null, null, (source, result) => {
            try {
                const [, stdout, stderr] = source.communicate_utf8_finish(result);
                callback(source.get_successful(), stdout.trim(), stderr.trim());
            } catch (error) {
                callback(false, '', error.message);
            }
        });
    }

    _refresh() {
        if (this._busy || this._destroyed)
            return;

        this._spawn([CONTROL, 'status'], (successful, stdout) => {
            if (this._destroyed)
                return;
            if (successful && ['enabled', 'disabled', 'powerdown-incomplete', 'restart-required'].includes(stdout))
                this._setState(stdout);
        });
    }

    _requestToggle() {
        if (this._busy)
            return;

        if (this._state === 'restart-required')
            return;

        const action = this._enabled ? 'disable' : 'enable';
        this._setBusy(true);
        this._spawn(['pkexec', CONTROL, action], (successful, _stdout, stderr) => {
            if (this._destroyed)
                return;

            this._setBusy(false);
            if (!successful && stderr)
                Main.notifyError('Thunderbolt', stderr);
            else if (successful && action === 'disable')
                Main.notify('Thunderbolt', 'Fully powered down. Restart required to enable it again.');
            this._refresh();
        });
    }

    destroy() {
        this._destroyed = true;
        if (this._sleepSignalId) {
            Gio.DBus.system.signal_unsubscribe(this._sleepSignalId);
            this._sleepSignalId = 0;
        }
        super.destroy();
    }
});

export default class ThunderboltExtension extends Extension {
    enable() {
        this._indicator = new ThunderboltIndicator(this);
        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
