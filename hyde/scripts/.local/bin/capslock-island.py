#!/usr/bin/env python3
"""Event-driven, click-through Caps Lock indicator for Hyprland."""
import argparse
import json
import logging
import os
import signal
import socket
import threading
import time
from pathlib import Path

import cairo
import evdev
import gi

gi.require_version('Gdk', '3.0')
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
gi.require_version('Pango', '1.0')
gi.require_version('PangoCairo', '1.0')
gi.require_version('GLibUnix', '2.0')
from gi.repository import Gdk, Gio, GLib, GLibUnix, Gtk, GtkLayerShell, Pango, PangoCairo

LOG = logging.getLogger('capslock-island')
GEOMETRY_EVENTS = {
    'activewindowv2', 'workspace', 'workspacev2', 'focusedmon', 'movewindowv2',
    'openwindow', 'closewindow', 'changefloatingmode', 'fullscreen',
    'monitoraddedv2', 'monitorremoved', 'configreloaded', 'activespecial',
    'togglegroup', 'moveintogroup', 'moveoutofgroup',
}


def ipc_path(name):
    return Path(os.environ['XDG_RUNTIME_DIR']) / 'hypr' / os.environ['HYPRLAND_INSTANCE_SIGNATURE'] / name


def read_ipc(command):
    with socket.socket(socket.AF_UNIX) as channel:
        channel.settimeout(0.5)
        channel.connect(str(ipc_path('.socket.sock')))
        channel.sendall(('j/' + command).encode())
        chunks = []
        while chunk := channel.recv(65536):
            chunks.append(chunk)
    return json.loads(b''.join(chunks))


def geometry(window, monitors):
    """Keep Hyprland's logical coordinates; do not scale them twice."""
    if not window.get('mapped') or window.get('hidden') or not window.get('visible', True):
        return None
    monitor = next((m for m in monitors if m['id'] == window.get('monitor')), None)
    if not monitor:
        return None
    x, y = window['at']
    width, height = window['size']
    if width < 80 or height < 60:
        return None
    surface_width = min(340, width)
    return (monitor['x'], monitor['y'],
            max(0, round(x - monitor['x'] + (width - surface_width) / 2)),
            max(0, round(y - monitor['y'] - 1)), surface_width,
            max(30, min(220, width - 50)))


def animation_value(start, target, fraction):
    t = max(0.0, min(1.0, fraction))
    if target > start:
        c = 1.2
        eased = 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2
    else:
        eased = 1 - (1 - t) ** 3
    return start + (target - start) * eased


class Island:
    def __init__(self, preview=False):
        self.preview = preview
        self.closed = False
        self.enabled = False
        self.available = False
        self.progress = 0.0
        self.target = 0.0
        self.animation_tick = 0
        self.geometry_source = 0
        self.settle_sources = []
        self.scan_source = 0
        self.reconnect_source = 0
        self.event_source = 0
        self.events = None
        self.event_buffer = b''
        self.devices = {}
        self.monitor = None
        self.last_geometry = None
        self.geometry_requests = 0
        self.draws = 0
        self.requested = threading.Event()
        self.stopping = threading.Event()
        self.worker = threading.Thread(target=self.query_worker, daemon=True)
        self.worker.start()
        self.build_window()
        self.connect_events()
        self.input_monitor = Gio.File.new_for_path('/dev/input').monitor_directory(Gio.FileMonitorFlags.NONE, None)
        self.input_monitor.connect('changed', self.input_changed)
        self.scan_devices()
        if preview:
            self.set_enabled(True)
            GLib.timeout_add(2000, self.preview_close)
            GLib.timeout_add(2600, self.quit)

    def build_window(self):
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_title('Caps Lock')
        self.window.set_decorated(False)
        self.window.set_accept_focus(False)
        self.window.set_app_paintable(True)
        self.window.set_visual(self.window.get_screen().get_rgba_visual())
        self.window.set_size_request(340, 66)
        self.window.connect('draw', self.draw)
        self.window.connect('realize', self.pass_through)
        self.window.connect('map-event', self.pass_through)
        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, 'capslock-island')
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_exclusive_zone(self.window, -1)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.LEFT, True)
        provider = Gtk.CssProvider()
        provider.load_from_data(b'window { background-color: transparent; box-shadow: none; }')
        self.window.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.text_layout = self.window.create_pango_layout('CAPS LOCK')
        self.text_layout.set_font_description(Pango.FontDescription('Sans Bold 10'))
        attrs = Pango.AttrList()
        attrs.insert(Pango.attr_letter_spacing_new(1500))
        self.text_layout.set_attributes(attrs)

    def pass_through(self, *_):
        native = self.window.get_window()
        if native:
            native.input_shape_combine_region(cairo.Region(), 0, 0)
        return False

    def set_enabled(self, enabled):
        if enabled == self.enabled or self.closed:
            return
        self.enabled = enabled
        if enabled:
            self.schedule_geometry(settle=True)
        else:
            self.cancel_geometry()
            self.animate_to(0.0)

    def scan_devices(self):
        self.scan_source = 0
        paths = set(evdev.list_devices())
        for path in set(self.devices) - paths:
            self.remove_device(path)
        for path in paths - self.devices.keys():
            device = None
            try:
                device = evdev.InputDevice(path)
                caps = device.capabilities(absinfo=False)
                has_caps = evdev.ecodes.LED_CAPSL in caps.get(evdev.ecodes.EV_LED, [])
                if not has_caps and not any(k in caps for k in (evdev.ecodes.EV_KEY, evdev.ecodes.EV_REL, evdev.ecodes.EV_ABS)):
                    device.close()
                    continue
                state = has_caps and evdev.ecodes.LED_CAPSL in device.leds()
                watch = GLib.io_add_watch(device.fd, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self.input_ready, path)
                self.devices[path] = [device, watch, state, has_caps]
            except OSError as error:
                if device:
                    device.close()
                LOG.debug('Cannot read %s: %s', path, error)
        if not self.preview:
            self.set_enabled(any(item[2] for item in self.devices.values()))
        return False

    def remove_device(self, path, remove_source=True):
        item = self.devices.pop(path, None)
        if item:
            if remove_source:
                GLib.source_remove(item[1])
            item[0].close()

    def input_changed(self, _monitor, file, _other, _event):
        if file.get_basename().startswith('event') and not self.scan_source:
            self.scan_source = GLib.timeout_add(100, self.scan_devices)

    def input_ready(self, _fd, condition, path):
        if condition & (GLib.IO_HUP | GLib.IO_ERR):
            self.remove_device(path, remove_source=False)
            if not self.scan_source:
                self.scan_source = GLib.timeout_add(100, self.scan_devices)
            return False
        item = self.devices.get(path)
        if not item:
            return False
        activity = False
        changed = False
        try:
            for event in item[0].read():
                if event.type == evdev.ecodes.EV_LED and event.code == evdev.ecodes.LED_CAPSL:
                    item[2] = bool(event.value)
                    changed = True
                elif self.enabled and event.type in (evdev.ecodes.EV_KEY, evdev.ecodes.EV_REL, evdev.ecodes.EV_ABS):
                    activity = True
        except BlockingIOError:
            pass
        except OSError:
            self.remove_device(path, remove_source=False)
            if not self.scan_source:
                self.scan_source = GLib.timeout_add(100, self.scan_devices)
            return False
        if changed and not self.preview:
            self.set_enabled(any(entry[2] for entry in self.devices.values()))
        if activity:
            self.schedule_geometry(settle=True)
        return True

    def connect_events(self):
        self.reconnect_source = 0
        if self.closed:
            return False
        try:
            channel = socket.socket(socket.AF_UNIX)
            channel.connect(str(ipc_path('.socket2.sock')))
            channel.setblocking(False)
            self.events = channel
            self.event_buffer = b''
            self.event_source = GLib.io_add_watch(channel.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self.events_ready)
            if self.enabled:
                self.schedule_geometry(settle=True)
        except OSError:
            channel.close()
            self.reconnect_source = GLib.timeout_add(2000, self.connect_events)
        return False

    def events_ready(self, _fd, condition):
        try:
            data = self.events.recv(65536) if not condition & (GLib.IO_HUP | GLib.IO_ERR) else b''
        except BlockingIOError:
            return True
        except OSError:
            data = b''
        if not data:
            self.events.close()
            self.events = None
            self.event_source = 0
            self.suppress()
            self.reconnect_source = GLib.timeout_add(2000, self.connect_events)
            return False
        self.event_buffer += data
        lines = self.event_buffer.split(b'\n')
        self.event_buffer = lines.pop()
        if any(line.split(b'>>', 1)[0].decode(errors='replace') in GEOMETRY_EVENTS for line in lines):
            self.schedule_geometry(settle=True)
        return True

    def cancel_geometry(self):
        if self.geometry_source:
            GLib.source_remove(self.geometry_source)
            self.geometry_source = 0
        for source in self.settle_sources:
            GLib.source_remove(source)
        self.settle_sources = []

    def schedule_geometry(self, settle=False):
        if self.closed or not self.enabled:
            return
        if not self.geometry_source:
            self.geometry_source = GLib.timeout_add(24, self.flush_geometry)
        if settle:
            for source in self.settle_sources:
                GLib.source_remove(source)
            self.settle_sources = []
            for delay in (140, 350):
                holder = []
                def reconcile(holder=holder):
                    if holder[0] in self.settle_sources:
                        self.settle_sources.remove(holder[0])
                    self.flush_geometry()
                    return False
                holder.append(GLib.timeout_add(delay, reconcile))
                self.settle_sources.append(holder[0])

    def flush_geometry(self):
        self.geometry_source = 0
        if self.enabled and not self.closed:
            self.requested.set()
        return False

    def query_worker(self):
        while True:
            self.requested.wait()
            self.requested.clear()
            if self.stopping.is_set():
                return
            try:
                self.geometry_requests += 1
                result = geometry(read_ipc('activewindow'), read_ipc('monitors'))
            except (OSError, ValueError, KeyError, TypeError):
                result = None
            GLib.idle_add(self.place, result)

    def suppress(self):
        self.available = False
        self.last_geometry = None
        if self.animation_tick:
            self.window.remove_tick_callback(self.animation_tick)
            self.animation_tick = 0
        self.progress = 0.0
        self.window.hide()

    def place(self, result):
        if self.closed or not self.enabled:
            return False
        if result is None:
            self.suppress()
            return False
        if result != self.last_geometry:
            mx, my, left, top, width, self.max_width = result
            display = Gdk.Display.get_default()
            target = next((display.get_monitor(i) for i in range(display.get_n_monitors())
                           if (display.get_monitor(i).get_geometry().x,
                               display.get_monitor(i).get_geometry().y) == (mx, my)), None)
            if target is None:
                self.suppress()
                return False
            if target != self.monitor:
                self.monitor = target
                GtkLayerShell.set_monitor(self.window, target)
            self.window.set_size_request(width, 66)
            self.window.resize(width, 66)
            GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.LEFT, left)
            GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.TOP, top)
            self.last_geometry = result
            self.window.queue_draw()
        self.available = True
        if not self.window.get_visible():
            self.window.show_all()
            self.animate_to(1.0)
        elif self.target != 1.0:
            self.animate_to(1.0)
        return False

    def animate_to(self, target):
        if not self.available or not self.window.get_visible():
            self.progress = 0.0
            return
        self.start_progress = self.progress
        self.target = target
        self.animation_start = time.monotonic()
        self.animation_duration = (0.22 if target else 0.18) * min(1, abs(target - self.progress))
        self.animation_duration = max(0.04, self.animation_duration)
        if not self.animation_tick:
            self.animation_tick = self.window.add_tick_callback(self.animate)

    def animate(self, *_):
        fraction = (time.monotonic() - self.animation_start) / self.animation_duration
        self.progress = animation_value(self.start_progress, self.target, fraction)
        self.window.queue_draw()
        if fraction >= 1:
            self.progress = self.target
            self.animation_tick = 0
            if self.target == 0:
                self.window.hide()
            return False
        return True

    def preview_close(self):
        self.set_enabled(False)
        return False

    def quit(self, *_):
        if self.closed:
            return False
        self.closed = True
        self.cancel_geometry()
        for source in (self.scan_source, self.reconnect_source, self.event_source):
            if source:
                GLib.source_remove(source)
        self.input_monitor.cancel()
        for path in list(self.devices):
            self.remove_device(path)
        if self.events:
            self.events.close()
        self.stopping.set()
        self.requested.set()
        self.window.destroy()
        if Gtk.main_level():
            Gtk.main_quit()
        return False

    def draw(self, widget, cr):
        self.draws += 1
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)
        p = self.progress
        if not self.available or p <= 0.001:
            return False
        center = widget.get_allocated_width() / 2
        half = (48 + (getattr(self, 'max_width', 220) - 48) * p) / 2
        height = 2 + 43 * p
        radius = min(17, height / 2)
        shoulder = min(18, height / 2)
        # Concave shoulders join the border; rounded corners grow inward.
        cr.move_to(center - half - shoulder, 0)
        cr.line_to(center + half + shoulder, 0)
        cr.curve_to(center + half, 0, center + half, shoulder, center + half, shoulder)
        cr.line_to(center + half, height - radius)
        cr.curve_to(center + half, height, center + half - radius, height,
                    center + half - radius, height)
        cr.line_to(center - half + radius, height)
        cr.curve_to(center - half, height, center - half, height - radius,
                    center - half, height - radius)
        cr.line_to(center - half, shoulder)
        cr.curve_to(center - half, 0, center - half - shoulder, 0,
                    center - half - shoulder, 0)
        cr.close_path()
        gradient = cairo.LinearGradient(0, 0, 0, height)
        gradient.add_color_stop_rgba(0, .23, .025, .045, .99)
        gradient.add_color_stop_rgba(1, .075, .012, .022, .99)
        cr.set_source(gradient)
        cr.fill_preserve()
        cr.set_source_rgba(1, .22, .31, .95)
        cr.set_line_width(1.3)
        cr.stroke()
        alpha = max(0, min(1, (p - .65) / .35))
        if not alpha:
            return False
        cr.save()
        cr.rectangle(center - half + 8, 3, half * 2 - 16, height - 7)
        cr.clip()
        cy = height / 2
        cr.set_source_rgba(1, .4, .46, alpha)
        ix = center - 68
        cr.set_line_width(1.8)
        cr.set_line_join(cairo.LINE_JOIN_ROUND)
        cr.move_to(ix, cy - 8)
        cr.line_to(ix - 6, cy - 1)
        cr.line_to(ix - 2.5, cy - 1)
        cr.line_to(ix - 2.5, cy + 3)
        cr.line_to(ix + 2.5, cy + 3)
        cr.line_to(ix + 2.5, cy - 1)
        cr.line_to(ix + 6, cy - 1)
        cr.close_path()
        cr.stroke()
        cr.move_to(ix - 3, cy + 7)
        cr.line_to(ix + 3, cy + 7)
        cr.stroke()
        layout = self.text_layout
        tw, th = layout.get_pixel_size()
        cr.set_source_rgba(1, .91, .92, alpha)
        cr.move_to(center - tw / 2 + 12, cy - th / 2)
        PangoCairo.show_layout(cr, layout)
        cr.restore()
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview', action='store_true', help='show a brief animation without toggling Caps Lock')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    if not GtkLayerShell.is_supported():
        raise SystemExit('A Wayland compositor with layer-shell is required')
    for key in ('XDG_RUNTIME_DIR', 'HYPRLAND_INSTANCE_SIGNATURE'):
        if not os.environ.get(key):
            raise SystemExit(f'{key} is missing; start from your Hyprland session')
    island = Island(preview=args.preview)
    if not any(item[3] for item in island.devices.values()):
        LOG.warning('No readable Caps Lock LED devices; check /dev/input permissions')
    for sig in (signal.SIGTERM, signal.SIGINT):
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, sig, island.quit)
    LOG.info('Caps Lock island ready (%d input devices)', len(island.devices))
    Gtk.main()


if __name__ == '__main__':
    main()
