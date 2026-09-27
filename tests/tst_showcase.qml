import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/ui/logic.js" as Logic

// Renders the style overview of the README from presets of tests/presets, two
// per row with a caption, into ./preview-out/styles.png (copy it to
// docs/styles.png). Each preset gets the Size (zoom) that brings it to about the
// same height, so small ones stay readable and wide ones fit their cell.
// Run through tests/run-tests.sh (needs QML_XHR_ALLOW_FILE_READ=1).
Item {
    id: stage
    width: margin * 2 + cellWidth * 2 + gap
    height: 400

    readonly property int margin: 40
    readonly property int gap: 40
    readonly property int cellWidth: 460
    readonly property int targetHeight: 72

    readonly property var entries: [
        { file: "big-pills", caption: "Pills" },
        { file: "custom-colors", caption: "Custom colors" },
        { file: "tiny-diamonds", caption: "Diamonds" },
        { file: "dotted-pills", caption: "A dot on desktops with windows" },
        { file: "crossfade-bars", caption: "Bars" },
        { file: "night-circles", caption: "Circles, custom labels" },
        { file: "custom-labels", caption: "Labels" },
        { file: "underlined-names", caption: "Desktop names, line highlight" },
        { file: "grid-icons", caption: "Icons" },
        { file: "window-strip", caption: "Open windows" }
    ]

    readonly property var fakeDesktops: [{ id: "1", name: "Web" }, { id: "2", name: "Code" },
                                         { id: "3", name: "Mail" }, { id: "4", name: "Music" }]
    readonly property var fakeWindows: [
        { desktops: [fakeDesktops[0]], normalWindow: true, icon: "internet-web-browser" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "utilities-terminal" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "accessories-text-editor" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "system-file-manager" },
        { desktops: [fakeDesktops[2]], normalWindow: true, icon: "internet-mail" },
        { desktops: [fakeDesktops[3]], normalWindow: true, icon: "multimedia-player" }
    ]
    readonly property var info: Logic.desktopInfo(fakeDesktops, fakeWindows, 3)

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#2b4a6f" }
            GradientStop { position: 1; color: "#6b3f5f" }
        }
    }

    Component {
        id: indicatorComponent
        Indicator {
            settings: Settings {}
        }
    }

    Component {
        id: captionComponent
        Text {
            color: "white"
            opacity: 0.8
            font.pixelSize: 15
        }
    }

    function parseIni(text) {
        const sections = {};
        let current = null;
        text.split("\n").forEach(line => {
            const t = line.trim();
            const header = t.match(/^\[(.+)\]$/);
            if (header) {
                current = sections[header[1]] = {};
            } else if (current && t.indexOf("=") > 0) {
                current[t.slice(0, t.indexOf("="))] = t.slice(t.indexOf("=") + 1);
            }
        });
        return sections;
    }

    function readSettings(file) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("presets/" + file + ".osdsnake"), false);
        request.send();
        return parseIni(request.responseText).Settings || {};
    }

    // The preset at the Size that makes it about targetHeight tall and at most cellWidth wide.
    function makeIndicator(file) {
        const values = readSettings(file);
        const indicator = indicatorComponent.createObject(stage);
        const load = zoom => {
            indicator.settings.load((key, fallback) => key === "Zoom" && zoom ? zoom : (key in values ? values[key] : fallback));
            indicator.columns = Logic.gridSize(info.length, info.length, 1, indicator.settings.layout).columns;
            indicator.desktops = info;
            indicator.currentIndex = 1;
            indicator.layoutNow();
        };
        load(0);
        const k = Math.min(targetHeight / indicator.implicitHeight, cellWidth / indicator.implicitWidth);
        load(Math.max(25, Math.min(400, Math.round(indicator.settings.zoom * k))));
        indicator.width = indicator.implicitWidth;
        indicator.height = indicator.implicitHeight;
        return indicator;
    }

    TestCase {
        name: "Showcase"
        when: windowShown

        function test_render() {
            const items = stage.entries.map(entry => ({ indicator: stage.makeIndicator(entry.file), caption: entry.caption }));
            let y = stage.margin;
            for (let row = 0; row < items.length; row += 2) {
                const pair = items.slice(row, row + 2);
                const rowHeight = Math.max(...pair.map(item => item.indicator.height));
                pair.forEach((item, column) => {
                    const left = stage.margin + column * (stage.cellWidth + stage.gap);
                    item.indicator.x = left + (stage.cellWidth - item.indicator.width) / 2;
                    item.indicator.y = y + (rowHeight - item.indicator.height) / 2;
                    const caption = captionComponent.createObject(stage, { text: item.caption });
                    caption.x = left + (stage.cellWidth - caption.implicitWidth) / 2;
                    caption.y = y + rowHeight + 10;
                });
                y += rowHeight + 10 + 20 + 30;
            }
            stage.height = y - 30 + stage.margin;
            wait(300);
            verify(stage.height > 200, "laid out");
            grabImage(stage).save("preview-out/styles.png");
        }
    }
}
