# OSD Desk Snake

An on-screen indicator for KDE Plasma 6 that shows up when you switch virtual
desktops, in the style of the [Kara](https://github.com/dhruv8sh/kara) pager.
The highlight slides from one desktop to the next with KWin's animation, and
follows your fingers during touchpad swipes.

![OSD Desk Snake switching desktops](docs/demo.gif)

The highlight slides as desktops change. Some of the styles:

![Styles](docs/styles.png)

- Styles: pills (pill, circle, square, diamond, bar), labels (number, desktop
  name, template, custom list), icons, open windows.
- Highlights: full, square, line, full with line; cells rounded, round or square.
- Marks the desktops that hold windows; follows the KWin desktop grid.
- Position: nine anchors with margin and offsets, or free position; drag it
  with the mouse while the settings app is open, with optional snapping.
- Timing: delay, fade in, display time, fade out, zoom effect, highlight
  motion (follow the switch or cross-fade once done), duration and curve.
- Plasma theme colors or custom ones, Plasma or custom background with opacity.
- Live settings app, and the usual page in System Settings.
- English and French.

It is a KWin script (pure QML) plus a small settings app (C++/QML, Kirigami).
Tested on Plasma 6.6 (Wayland).

## Install

### Packages (amd64)

Download the package for your distribution from the
[Releases](https://github.com/rcspam/osd-desk-snake/releases) page:

```sh
sudo apt install ./osd-desk-snake_0.1.0_amd64.deb              # Debian, Ubuntu, KDE neon, Tuxedo OS
sudo dnf install ./osd-desk-snake-0.1.0-1.fc44.x86_64.rpm      # Fedora
sudo pacman -U ./osd-desk-snake-0.1.0-1-x86_64.pkg.tar.zst     # Arch, or makepkg -si in packaging/arch
```

Then enable it in System Settings > Window Management > KWin Scripts. The .deb
is built on Ubuntu 24.04 with Qt 6.10 and KDE Frameworks 6.24: it needs those
versions or newer. The packages are made with `packaging/build-packages.sh`.

### From source

Build dependencies (Debian, Ubuntu, KDE neon names):

```sh
sudo apt install cmake g++ extra-cmake-modules qt6-base-dev qt6-declarative-dev \
    libkf6config-dev libkf6i18n-dev libkf6windowsystem-dev gettext kpackagetool6 qdbus-qt6
```

Then, from a clone of this repository:

```sh
./install.sh             # install or upgrade the script and the settings app, load now
./install.sh reload      # load the working copy into the running KWin
./install.sh app         # rebuild and reinstall only the settings app
./install.sh uninstall
```

Everything goes to your home directory, no root needed. Turn off the built-in
OSD in System Settings > Virtual Desktops if it is on.

Only want the script, without compiling? `kpackagetool6 --type KWin/Script
--install package`, then enable it in System Settings > KWin Scripts. You get
the System Settings page, without the live settings app and mouse dragging.
For color pickers on that page: `sudo apt install libkf6widgetsaddons-dev`.

## Configure

Two ways, same settings:

- OSD Desk Snake Settings, in the application menu (`osd-desk-snake-settings`):
  every change is saved and shown on the real indicator right away, while the
  indicator stays on screen. Revert goes back to the settings you had when the
  window opened. While it is open the indicator can also be dragged: in anchor
  mode it snaps to the nearest anchor (Snap to anchors), in free mode it keeps
  the exact spot.
- System Settings > Window Management > KWin Scripts > OSD Desk Snake > Configure:
  changes show up on Apply. A link at the top of that page opens the settings
  app when it is installed.

While the settings dialog is open, the indicator stays on screen and picks up
every Apply within a second. KWin does not reload script settings by itself, so
OSD Desk Snake asks it to: every second while the dialog is open, and about 0.7 s
after a desktop switch otherwise (at most every 3 s).

## Develop

```sh
tests/run-tests.sh           # unit tests + PNG previews of every style in tests/preview-out
python3 tools/gen_config_ui.py   # regenerate config.ui, the app form model and schema.js
cmake -S settings-app -B settings-app/build && cmake --build settings-app/build
settings-app/build/bin/settingsstoretest
```

The settings app (C++/QML, Kirigami) reads the script schema `main.xml` at build
time and writes kwinrc through KConfigLoader, so defaults are never written.

To add a setting: declare it in `contents/config/main.xml` (type and default,
the only place defaults are written), add a typed property to
`contents/ui/Settings.qml`, add a row to the table in `tools/gen_config_ui.py`,
then run the generator. It writes `config.ui`, the settings app form model and
`contents/ui/schema.js`; `tests/tst_fields.qml` checks that everything matches.
Logs: `journalctl --user -b | grep -i osd-desk-snake`.
