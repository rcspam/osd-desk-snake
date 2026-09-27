import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/ui/logic.js" as Logic

// Loads each preset of tests/presets like the settings app writes them, renders
// the indicator at rest and halfway between two desktops into
// preview-out/presets/, and checks that nothing is drawn outside the indicator:
// the OSD window has the indicator's size in KWin, anything beyond is cut off.
// Run through tests/run-tests.sh (needs QML_XHR_ALLOW_FILE_READ=1).
Item {
    id: stage
    width: 1400
    height: 900

    readonly property var presetFiles: [
        "night-circles", "big-pills", "tiny-diamonds", "underlined-names", "grid-icons",
        "vertical-template", "window-strip", "crossfade-bars", "extreme-offsets", "smallest-everything",
        "dotted-pills", "ringed-dots", "custom-colors", "custom-labels"
    ]

    readonly property var fakeDesktops: [{ id: "1", name: "Web" }, { id: "2", name: "Code" }, { id: "3", name: "Mail" },
                                         { id: "4", name: "Chat" }, { id: "5", name: "" }, { id: "6", name: "Music" }]
    readonly property var fakeWindows: [
        { desktops: [fakeDesktops[0]], normalWindow: true, icon: "internet-web-browser" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "utilities-terminal" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "accessories-text-editor" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "system-file-manager" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "utilities-terminal" },
        { desktops: [fakeDesktops[2]], normalWindow: true, icon: "internet-mail" },
        { desktops: [fakeDesktops[5]], normalWindow: true, icon: "multimedia-player" }
    ]
    readonly property var info: Logic.desktopInfo(fakeDesktops, fakeWindows, 3)

    Rectangle {
        anchors.fill: parent
        color: "#3a4a6a"
    }

    Component {
        id: indicatorComponent
        Indicator {
            settings: Settings {}
        }
    }

    // [Section] key=value, as KConfig writes it.
    function parseIni(text) {
        const sections = {};
        let current = null;
        text.split("\n").forEach(line => {
            const trimmed = line.trim();
            const header = trimmed.match(/^\[(.+)\]$/);
            if (header) {
                current = sections[header[1]] = {};
            } else if (current && trimmed.indexOf("=") > 0) {
                const at = trimmed.indexOf("=");
                current[trimmed.slice(0, at)] = trimmed.slice(at + 1);
            }
        });
        return sections;
    }

    function readPreset(stem) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("presets/" + stem + ".osdsnake"), false);
        request.send();
        return parseIni(request.responseText);
    }

    // Visible items of `item` drawn outside the indicator, as text.
    function overflows(indicator, item, found) {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (!child.visible || child.opacity === 0) {
                continue;
            }
            if (child.width > 0 && child.height > 0) {
                const r = child.mapToItem(indicator, 0, 0, child.width, child.height);
                if (r.x < -0.5 || r.y < -0.5 || r.x + r.width > indicator.width + 0.5 || r.y + r.height > indicator.height + 0.5) {
                    found.push(String(child).split("(")[0] + (child.objectName ? " " + child.objectName : "")
                               + " at " + [r.x, r.y, r.width, r.height].map(n => Math.round(n)).join(",")
                               + " in " + Math.round(indicator.width) + "x" + Math.round(indicator.height));
                }
            }
            overflows(indicator, child, found);
        }
        return found;
    }

    TestCase {
        name: "Presets"
        when: windowShown

        function test_presets_data() {
            return stage.presetFiles.map(stem => ({ tag: stem, stem: stem }));
        }

        function test_presets(data) {
            failOnWarning(/.*/);
            const preset = stage.readPreset(data.stem);
            verify(preset.Preset && preset.Preset.Name, "has a name");
            const values = preset.Settings || {};

            const indicator = indicatorComponent.createObject(stage, { x: 20, y: 20 });
            indicator.settings.load((key, fallback) => key in values ? values[key] : fallback);
            indicator.columns = Logic.gridSize(stage.info.length, 3, 2, indicator.settings.layout).columns;
            indicator.desktops = stage.info;
            indicator.currentIndex = 1;
            indicator.layoutNow();
            indicator.width = indicator.implicitWidth;
            indicator.height = indicator.implicitHeight;
            waitForRendering(indicator);
            grabImage(indicator).save("preview-out/presets/" + data.stem + "-rest.png");
            const problems = stage.overflows(indicator, indicator, []).map(p => "rest: " + p);

            // Halfway to the next desktop, along the row or down the column.
            const p = Logic.gridPoint(1, indicator.columns);
            indicator.highlight = indicator.columns > 1 ? Qt.point(p.x + 0.5, p.y) : Qt.point(p.x, p.y + 0.5);
            waitForRendering(indicator);
            grabImage(indicator).save("preview-out/presets/" + data.stem + "-mid.png");
            stage.overflows(indicator, indicator, []).forEach(problem => problems.push("mid: " + problem));

            indicator.destroy();
            verify(problems.length === 0, "drawn outside the indicator:\n  " + problems.join("\n  "));
        }
    }
}
