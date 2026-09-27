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
        { name: "20-pills-crossfade-1-to-5", from: 0, progress: 0.5, cfg: { highlightMotion: 1 } },
        { name: "21-labels-fade-midway", hx: 1.5, cfg: { style: 1, highlight: 0, highlightMotion: 2 } }
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

        // Cells of a rendered variant: the items carrying a cell geometry.
        function cellsOf(item) {
            let cells = item.geo !== undefined ? [item] : [];
            for (let i = 0; i < item.children.length; i++) {
                cells = cells.concat(cellsOf(item.children[i]));
            }
            return cells;
        }

        function variant(name) {
            for (let i = 0; i < repeater.count; i++) {
                if (repeater.itemAt(i).variantName === name) {
                    return repeater.itemAt(i);
                }
            }
            return null;
        }

        // The occupied dot follows the windows on every desktop, the current one included.
        function test_currentDesktopShowsItsDot() {
            wait(100);
            const cells = cellsOf(variant("02-labels-full"));
            const current = cells.find(cell => cell.index === 1);
            const empty = cells.find(cell => cell.index === 3);
            const dot = cell => cell.children.find(child => child.objectName === "occupiedDot");
            verify(dot(current).visible && dot(current).opacity > 0.5, "current desktop, with windows: dot shown");
            verify(!dot(empty).visible, "desktop without windows: no dot");
        }

        function slidingHighlightOf(item) {
            if (item.objectName === "slidingHighlight") {
                return item;
            }
            for (let i = 0; i < item.children.length; i++) {
                const found = slidingHighlightOf(item.children[i]);
                if (found) {
                    return found;
                }
            }
            return null;
        }

        // "Slide with the switch": halfway between desktops 2 and 3, one highlight
        // sits between the two cells; "Fade with the switch" keeps one per cell.
        function test_highlightSlidesBetweenCells() {
            wait(100);
            const box = variant("18-labels-midway");
            const slider = slidingHighlightOf(box);
            verify(slider && slider.visible, "sliding highlight shown");
            const cells = cellsOf(box);
            const from = cells.find(cell => cell.index === 1);
            const to = cells.find(cell => cell.index === 2);
            const center = slider.rect.x + slider.rect.width / 2;
            const expected = (from.x + from.width / 2 + to.x + to.width / 2) / 2;
            verify(Math.abs(center - expected) < 1, "centered between the two cells: " + center + " vs " + expected);

            const fading = variant("21-labels-fade-midway");
            verify(!slidingHighlightOf(fading).visible, "no sliding highlight when fading");
        }

        // The line highlight sits LineOffset px (3 by default) under the label.
        function test_lineSitsUnderTheLabel() {
            wait(100);
            const box = variant("04-labels-line-template");
            const cell = cellsOf(box).find(c => c.index === 1);
            const line = slidingHighlightOf(box).lineRect;
            compare(line.y, cell.y + (cell.height + cell.contentHeight) / 2 + 3);
        }

        // The size floors sent to the settings app match what is drawn.
        function test_sizeFloorsMatchTheCells() {
            wait(100);
            const box = variant("16-labels-circle-square-hl");
            const indicator = box.children.find(child => child.sizeFloors !== undefined);
            const cells = cellsOf(box);
            compare(indicator.sizeFloors.CellWidth, Math.ceil(cells[0].width));
            compare(indicator.sizeFloors.CellHeight, Math.ceil(cells[0].width));
        }

        // Circle cells share one diameter, whatever the length of each label.
        function test_circleCellsShareOneDiameter() {
            wait(100);
            let box = null;
            for (let i = 0; i < repeater.count; i++) {
                if (repeater.itemAt(i).variantName === "16-labels-circle-square-hl") {
                    box = repeater.itemAt(i);
                }
            }
            const cells = cellsOf(box);
            verify(cells.length === stage.info.length, "one cell per desktop");
            for (const cell of cells) {
                compare(cell.width, cells[0].width, "same diameter for label " + cell.index);
                compare(cell.height, cell.width, "round");
            }
        }
    }
}
