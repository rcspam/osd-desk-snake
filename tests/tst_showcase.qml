import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/ui/logic.js" as Logic

// Renders the style overview of the README, one row per style family, into
// ./preview-out/styles.png (copy it to docs/styles.png). Run through tests/run-tests.sh.
Item {
    id: stage
    width: rows.implicitWidth + 64
    height: rows.implicitHeight + 56

    readonly property var fakeDesktops: [{ id: "1", name: "Web" }, { id: "2", name: "Code" },
                                         { id: "3", name: "Mail" }, { id: "4", name: "Music" }]
    readonly property var fakeWindows: [
        { desktops: [fakeDesktops[0]], normalWindow: true, icon: "internet-web-browser" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "utilities-terminal" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "accessories-text-editor" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "system-file-manager" },
        { desktops: [fakeDesktops[1]], normalWindow: true, icon: "utilities-terminal" },
        { desktops: [fakeDesktops[2]], normalWindow: true, icon: "internet-mail" },
        { desktops: [fakeDesktops[3]], normalWindow: true, icon: "multimedia-player" }
    ]
    readonly property var info: Logic.desktopInfo(fakeDesktops, fakeWindows, 3)
    readonly property string iconList: "internet-web-browser, utilities-terminal, internet-mail, multimedia-player"

    // Settings overrides on top of the defaults; kwinColumns lays the desktops out as a grid.
    readonly property var families: [
        { name: "Pills", variants: [
            { cfg: {} },
            { cfg: { pillShape: 1, pillActiveHeight: 18 } },
            { cfg: { pillShape: 2, backgroundMode: 3, backgroundOpacity: 50 } },
            { cfg: { pillShape: 3, pillActiveHeight: 18, backgroundMode: 3 } },
            { cfg: { pillShape: 4, pillHeight: 12, pillActiveHeight: 12 } },
            { cfg: { backgroundMode: 3, layout: 0, useThemeColors: false, activeColor: "#ffe66d" }, kwinColumns: 2 }
        ] },
        { name: "Labels", variants: [
            { cfg: { style: 1 } },
            { cfg: { style: 1, highlight: 1, labelSource: 1, squareSize: 30 } },
            { cfg: { style: 1, highlight: 2, labelSource: 2, labelTemplate: "D%d" } },
            { cfg: { style: 1, cellShape: 1, highlight: 0 } }
        ] },
        { name: "Icons", variants: [
            { cfg: { style: 2, highlight: 3, iconList: stage.iconList } },
            { cfg: { style: 2, cellShape: 2, highlight: 1, iconList: stage.iconList } }
        ] },
        { name: "Open windows", variants: [
            { cfg: { style: 3 } }
        ] }
    ]

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#2b4a6f" }
            GradientStop { position: 1; color: "#6b3f5f" }
        }
    }

    Column {
        id: rows
        x: 32
        y: 28
        spacing: 28

        Repeater {
            model: stage.families

            Row {
                id: familyRow
                required property var modelData
                spacing: 36

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 130
                    text: familyRow.modelData.name
                    color: "white"
                    opacity: 0.75
                    font.pixelSize: 15
                }

                Repeater {
                    model: familyRow.modelData.variants

                    Item {
                        id: box
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
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
                            currentIndex: 1
                            highlight: {
                                const p = Logic.gridPoint(currentIndex, columns);
                                return Qt.point(p.x, p.y);
                            }
                            fromIndex: 1
                            crossProgress: 1
                            columns: Logic.gridSize(stage.info.length, box.modelData.kwinColumns || stage.info.length,
                                                    2, settings.layout).columns
                        }
                    }
                }
            }
        }
    }

    TestCase {
        name: "Showcase"
        when: windowShown

        function test_render() {
            wait(500);
            verify(stage.width > 64 && stage.height > 56, "the showcase has content");
            grabImage(stage).save("preview-out/styles.png");
        }
    }
}
