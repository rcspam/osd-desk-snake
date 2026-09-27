import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "fields.js" as Fields

// Live settings window. Every change is saved right away (SettingsStore), and
// the KWin script keeps the real indicator on screen while this window is open.
QQC2.ApplicationWindow {
    id: root

    required property var store
    required property var presets
    // Tab to show, from the osd-desk-snake:// link that opened the app.
    property string page
    readonly property int presetsTab: Fields.tabs.length

    function showPage(name) {
        if (name === "presets") {
            tabs.currentIndex = presetsTab;
        }
    }

    // Groups of a tab as one list: a "section" entry followed by its fields.
    function flatten(tab) {
        const out = [];
        tab.groups.forEach(group => {
            out.push({ kind: "section", key: "", label: group.title });
            group.fields.forEach(field => out.push(field));
        });
        return out;
    }

    title: i18n("OSD Desk Snake settings")
    width: Kirigami.Units.gridUnit * 38
    height: Kirigami.Units.gridUnit * 38
    minimumWidth: Kirigami.Units.gridUnit * 24
    minimumHeight: Kirigami.Units.gridUnit * 20
    visible: true

    header: QQC2.TabBar {
        id: tabs

        Repeater {
            model: Fields.tabs

            QQC2.TabButton {
                required property var modelData
                text: i18n(modelData.title)
            }
        }
        QQC2.TabButton {
            text: i18n("Presets")
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: tabs.currentIndex

        Repeater {
            model: Fields.tabs

            QQC2.ScrollView {
                id: scroll

                required property var modelData

                contentWidth: availableWidth

                // One form per tab, groups as sections, so labels line up across groups.
                Kirigami.FormLayout {
                    width: scroll.availableWidth

                    Repeater {
                        model: root.flatten(scroll.modelData)

                        FieldEditor {
                            required property var modelData
                            field: modelData
                            store: root.store
                            Kirigami.FormData.isSection: modelData.kind === "section"
                            Kirigami.FormData.label: modelData.kind === "check" ? "" : i18n(modelData.label)
                        }
                    }
                }
            }
        }
        PresetsPage {
            presets: root.presets
        }
    }

    Component.onCompleted: Qt.callLater(showPage, page)

    footer: QQC2.ToolBar {
        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Applied live.")
                elide: Text.ElideRight
                opacity: 0.7
            }
            QQC2.Button {
                icon.name: "edit-undo"
                text: i18n("Revert")
                QQC2.ToolTip.text: i18n("Back to the settings you had when this window opened.")
                QQC2.ToolTip.visible: hovered
                onClicked: root.store.revert()
            }
            QQC2.Button {
                icon.name: "document-revert"
                text: i18n("Defaults")
                onClicked: root.store.defaults()
            }
            QQC2.Button {
                icon.name: "dialog-close"
                text: i18n("Close")
                onClicked: root.close()
            }
        }
    }
}
