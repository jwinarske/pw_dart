# pw_dart examples

CLI and Flutter examples that exercise the `pw_dart` package against a
running PipeWire daemon. Verified on **Fedora 43** with PipeWire 1.4.11
and WirePlumber 0.5.

## Examples

| File | What it does |
|---|---|
| `example.dart` | Minimal connect / snapshot / disconnect. |
| `pw_dump.dart` | Print the current graph as JSON (`--pretty` for indented). |
| `pw_mon.dart` | Live-stream graph events (NodeAdded, PortAdded, LinkAdded, …). |
| `pw_top.dart` | Periodic summary table of nodes/ports/links/devices. |
| `pw_dot.dart` | Render the graph as Graphviz DOT. |
| `pw_link.dart` | Create / destroy / list links from the command line. |
| `pw_cli.dart` | Interactive REPL for inspecting the graph. |
| `pw_libcamera.dart` | List `Video/Source` nodes exposed by the libcamera SPA, optionally watch hot-plug events with `--watch`. |
| `pw_v4l2.dart` | List V4L2 video sources, their device properties, ports, and controls (brightness, exposure, zoom, …). |
| `graph_viewer/` | Flutter desktop app: live patchbay/graph viewer with pan, zoom, drag-to-link, inspector, and Tokyo Night theme. |

Run any CLI example with:

```sh
dart run example/<file>.dart
```

Run the Flutter viewer with:

```sh
cd example/graph_viewer
flutter run -d linux
```

## Fedora setup

The CLI examples and the V4L2 example work out of the box on a stock
Fedora install with PipeWire and WirePlumber. The libcamera example
needs a few extra steps because Fedora's stock build does not include
the libcamera SPA plugin and WirePlumber's V4L2 monitor wins
arbitration over libcamera by default for UVC devices.

### 1. Build prerequisites

```sh
sudo dnf install \
  pipewire-devel \
  cmake gcc-c++ pkgconf-pkg-config
```

The package's `hook/build.dart` invokes CMake to build the native
`libpw_dart_native.so`. Glaze is fetched as a header-only dependency.

### 2. Enabling the libcamera SPA (only needed for `pw_libcamera.dart`)

#### 2a. Install the libcamera runtime and the PipeWire SPA plugin

```sh
sudo dnf install \
  libcamera libcamera-ipa libcamera-tools \
  pipewire-plugin-libcamera
```

Verify the plugin landed in the SPA search path:

```sh
ls /usr/lib64/spa-0.2/libcamera/      # libspa-libcamera.so
```

Confirm libcamera itself sees your hardware:

```sh
cam -l
```

> **Stale `cam` binary?** If `cam` complains about
> `libcamera.so.0.3: cannot open shared object file`, you have an old
> manual install at `/usr/local/sbin/cam`. Remove it and any leftover
> libs in `/usr/local/lib64/libcamera*`, then `sudo ldconfig` and use
> `/usr/bin/cam` from the rpm.

#### 2b. Force libcamera to win UVC arbitration

WirePlumber's `monitor-utils.lua` arbitrates between V4L2 and libcamera
and **unconditionally prefers V4L2** for any device both monitors see.
There is no rules-based override; you have to disable the V4L2 monitor
for the specific camera you want libcamera to claim.

Create `~/.config/wireplumber/wireplumber.conf.d/52-disable-v4l2-<name>.conf`:

```
monitor.v4l2.rules = [
  {
    matches = [
      { device.product.name = "MX Brio" }
    ]
    actions = {
      update-props = {
        device.disabled = true
      }
    }
  }
]
```

Replace `MX Brio` with your camera's `device.product.name` (find it
with `dart run example/pw_v4l2.dart`).

Then restart WirePlumber and verify a `libcamera_input.*` node appears:

```sh
systemctl --user restart wireplumber
pw-cli ls Node | grep -i libcamera
dart run example/pw_libcamera.dart
```

> **Heads up:** while the rule is active, the camera is reachable
> **only** through libcamera. Apps that talk to V4L2 directly (Cheese,
> OBS V4L2 input, browser MediaDevices) will not see it. Remove the
> file and restart WirePlumber to give the camera back to V4L2.

Note: libcamera-via-PipeWire only ever surfaces cameras for which
libcamera has a working pipeline handler. UVC webcams like the
Logitech MX Brio work via the `uvcvideo` pipeline handler; CSI sensors
(Raspberry Pi, IPU3/IPU6 laptops, Rockchip ISP) use their dedicated
handlers. If `cam -l` is empty for your hardware, libcamera has
nothing to expose and the V4L2 SPA is the only option.

### 3. Flutter graph viewer

The graph viewer is a regular Flutter desktop app under
`example/graph_viewer/`. Once Flutter Linux desktop is set up:

```sh
cd example/graph_viewer
flutter pub get
flutter run -d linux
```

Interactions:
- **Pan / zoom**: drag empty canvas, scroll to zoom.
- **Create link**: drag from any port dot to a compatible port dot.
  Compatibility (direction, media type, duplicate) is checked
  client-side; failures show a snackbar.
- **Delete link**: right-click or double-click the link's midpoint.
- **Inspect node**: tap a node. The inspector overlay appears in the
  top-right and auto-dismisses after 5 seconds (timer pauses on hover).
- **Search**: filter by name or media class via the app bar text field.
- **Fit to view**: bottom-left button re-centers and re-scales to fit
  the current graph; also runs automatically on first connect and when
  the node count more than doubles.
