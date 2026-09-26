import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/ui/logic.js" as Logic

// Renders every style outside KWin and saves PNGs into ./preview-out/
// (relative to the working directory). Run through tests/run-tests.sh.
Item {
    id: stage
    width: 1100
    height: 900

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
        gradient: Gradient {
            GradientStop { position: 0; color: "#2b4a6f" }
            GradientStop { position: 1; color: "#6b3f5f" }
        }
    }

    // Each variant: a settings override map applied on top of the defaults.
    readonly property var variants: [
        { name: "01-pills", cfg: {} },
        { name: "02-labels-full", cfg: { style: 1 } },
        { name: "03-labels-square-names", cfg: { style: 1, highlight: 1, labelSource: 1, squareSize: 30 } },
        { name: "04-labels-line-template", cfg: { style: 1, highlight: 2, labelSource: 2, labelTemplate: "D%d" } },
        { name: "05-icons-fullline", cfg: { style: 2, highlight: 3, iconList: "internet-web-browser, utilities-terminal, internet-mail" } },
        { name: "06-tasks", cfg: { style: 3 } },
        { name: "07-pills-custom-bg-grid", cfg: { backgroundMode: 3, layout: 0, useThemeColors: false, activeColor: "#ffe66d" } },
        { name: "08-labels-transparent-caption", cfg: { style: 1, backgroundMode: 2, caption: 2, labelSource: 1 } },
        { name: "09-labels-vertical", cfg: { style: 1, layout: 2, highlight: 2 } },
        { name: "10-pills-circle", cfg: { pillShape: 1, pillActiveHeight: 18 } },
        { name: "11-pills-diamond", cfg: { pillShape: 3, pillActiveHeight: 18, backgroundMode: 3 } },
        { name: "12-pills-bar", cfg: { pillShape: 4, pillHeight: 12, pillActiveHeight: 12 } },
        { name: "13-pills-square-bg50", cfg: { pillShape: 2, backgroundMode: 3, backgroundOpacity: 50 } },
        { name: "14-labels-circle-cells", cfg: { style: 1, cellShape: 1, highlight: 0 } },
        { name: "15-icons-square-cells", cfg: { style: 2, cellShape: 2, highlight: 1 } },
        { name: "16-labels-circle-square-hl", cfg: { style: 1, cellShape: 1, highlight: 1, labelSource: 1 } },
        { name: "17-pills-midway", hx: 1.5, cfg: {} },
        { name: "18-labels-midway", hx: 1.5, cfg: { style: 1, highlight: 0 } },
        { name: "19-icons-line-quarter", hx: 1.25, cfg: { style: 2, highlight: 2 } },
        { name: "20-pills-crossfade-1-to-5", from: 0, progress: 0.5, cfg: { highlightMotion: 1 } }
    ]

    Flow {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24

        Repeater {
            id: repeater
            model: stage.variants

            Item {
                id: box
                required property var modelData
                readonly property string variantName: modelData.name
                width: indicator.width
                height: indicator.height

                Settings {
                    id: settings
                    Component.onCompleted: {
                        load(null);
                        const cfg = box.modelData.cfg;
                        for (const k in cfg) {
                            settings[k] = cfg[k];
                        }
                    }
                }

                Indicator {
                    id: indicator
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: implicitHeight
                    settings: settings
                    desktops: stage.info
                    currentIndex: box.modelData.from !== undefined ? 4 : 1
                    // Between two desktops when the variant sets hx, else on the current desktop.
                    highlight: {
                        const p = box.modelData.hx !== undefined ? { x: box.modelData.hx, y: 0 } : Logic.gridPoint(currentIndex, columns);
                        return Qt.point(p.x, p.y);
                    }
                    fromIndex: box.modelData.from !== undefined ? box.modelData.from : 1
                    crossProgress: box.modelData.progress !== undefined ? box.modelData.progress : 1
                    columns: Logic.gridSize(stage.info.length, box.variantName.indexOf("grid") >= 0 ? 3 : 6, 2, settings.layout).columns
                }
            }
        }
    }

    TestCase {
        name: "Preview"
        when: windowShown

        function test_render() {
            wait(500);
            for (let i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i);
                verify(item.width > 0 && item.height > 0, item.variantName + " has a size");
                grabImage(item).save("preview-out/" + item.variantName + ".png");
            }
            grabImage(stage).save("preview-out/00-all.png");
        }
    }
}
