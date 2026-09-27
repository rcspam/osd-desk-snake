#!/usr/bin/env bash
# Install, reload or remove the OSD Desk Snake KWin script for the current user.
#
#   ./install.sh            install or upgrade the script and the settings app, load now
#   ./install.sh reload     load the working copy into the running KWin (no install)
#   ./install.sh app        build and install only the live settings app
#   ./install.sh uninstall  unload, disable and remove both
#
# KWin caches QML by file URL and never clears that cache when a script is
# unloaded, so reloading from the installed path would keep the old code.
# The live session therefore runs a copy under a unique path; the installed
# package is what KWin loads at the next login.
set -euo pipefail

ID=osd-desk-snake
here="$(cd "$(dirname "$0")" && pwd)"
pkg="$here/package"
runtime="${XDG_RUNTIME_DIR:-/tmp}"
qdbus=$(command -v qdbus6 || command -v qdbus-qt6 || echo /usr/lib/qt6/bin/qdbus)

scripting() { "$qdbus" org.kde.KWin /Scripting "org.kde.kwin.Scripting.$1" "${@:2}"; }

bindir="${XDG_BIN_HOME:-$HOME/.local/bin}"
datadir="${XDG_DATA_HOME:-$HOME/.local/share}"
app="$bindir/$ID-settings"
desktop="$datadir/applications/$ID-settings.desktop"
presets="$datadir/$ID/presets"

build_translations() {
    local po
    for po in "$here"/po/*.po; do
        [ -e "$po" ] || continue
        local lang dir
        lang="$(basename "$po" .po)"
        dir="$pkg/contents/locale/$lang/LC_MESSAGES"
        mkdir -p "$dir"
        msgfmt -o "$dir/$ID.mo" "$po"
        # Same catalog for the settings app, which looks in the XDG locale dirs.
        install -Dm644 "$dir/$ID.mo" "$datadir/locale/$lang/LC_MESSAGES/$ID.mo"
    done
}

install_app() {
    # KDE's CMake modules look for a git remote and complain when there is none.
    cmake -S "$here/settings-app" -B "$here/settings-app/build" -DCMAKE_BUILD_TYPE=Release 2>&1 >/dev/null |
        grep -vE "origin|branche|branch" >&2 || true
    cmake --build "$here/settings-app/build" -j"$(nproc)" >/dev/null
    install -Dm755 "$here/settings-app/build/bin/$ID-settings" "$app"
    mkdir -p "$(dirname "$desktop")"
    sed "s|@BINARY@|$app|" "$here/settings-app/$ID-settings.desktop.in" > "$desktop"
    # Shipped presets, where the app looks for them (XDG data dirs).
    mkdir -p "$presets" && cp "$here"/presets/*.osdsnake "$presets/"
    refresh_app_caches
    echo "Settings app installed: $app"
}

unload() {
    scripting unloadScript "$ID" >/dev/null || true
    rm -rf "$runtime"/$ID-live-*
}

# Makes the osd-desk-snake:// link of the System Settings page find the app.
refresh_app_caches() {
    command -v update-desktop-database >/dev/null && update-desktop-database -q "$(dirname "$desktop")" || true
    command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true
}

load_copy() {
    unload
    local copy="$runtime/$ID-live-$(date +%s%N)"
    cp -r "$pkg" "$copy"
    local sid
    sid=$(scripting loadDeclarativeScript "$copy/contents/ui/main.qml" "$ID")
    if [ "$sid" -lt 0 ]; then
        echo "KWin refused to load the script (id $sid)" >&2
        exit 1
    fi
    # Script.run on the new object is not enough in practice; start() runs every loaded script.
    scripting start
    echo "Loaded into KWin as script $sid"
}

case "${1:-install}" in
install)
    build_translations
    if kpackagetool6 --type KWin/Script --show "$ID" >/dev/null 2>&1; then
        kpackagetool6 --type KWin/Script --upgrade "$pkg"
    else
        kpackagetool6 --type KWin/Script --install "$pkg"
    fi
    kwriteconfig6 --file kwinrc --group Plugins --key "${ID}Enabled" true
    if [ "$(scripting isScriptLoaded desktopchangeosd)" = "true" ]; then
        echo "Note: the built-in desktop change OSD is also active." >&2
        echo "Turn it off in System Settings > Virtual Desktops." >&2
    fi
    load_copy
    install_app
    ;;
app)
    build_translations
    install_app
    ;;
reload)
    build_translations
    load_copy
    ;;
uninstall)
    unload
    kwriteconfig6 --file kwinrc --group Plugins --key "${ID}Enabled" --delete
    kpackagetool6 --type KWin/Script --remove "$ID" || true
    rm -f "$app" "$desktop" "$datadir"/locale/*/LC_MESSAGES/$ID.mo
    rm -rf "$datadir/$ID"
    refresh_app_caches
    echo "Removed. Settings are kept in kwinrc, group [Script-$ID]."
    ;;
*)
    echo "usage: $0 [install|reload|app|uninstall]" >&2
    exit 2
    ;;
esac
