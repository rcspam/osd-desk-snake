import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Presets tab: named copies of every setting (PresetLibrary), applied live with
// one click. Each action reports its error, if any, in the message at the top.
ColumnLayout {
    id: page

    required property var presets
    // Where import and export dialogs open: home at first, then the folder of the
    // last import or export, so a file just exported is found right away.
    property url lastFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)

    function folderOf(file) {
        const path = file.toString();
        return path.substring(0, path.lastIndexOf("/"));
    }

    function report(error) {
        message.text = error;
        message.visible = error !== "";
    }

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        QQC2.Button {
            icon.name: "document-save-as"
            text: i18n("Save current as…")
            onClicked: nameDialog.ask("")
        }
        QQC2.Button {
            icon.name: "document-import"
            text: i18n("Import…")
            onClicked: importDialog.open()
        }
        Item {
            Layout.fillWidth: true
        }
    }

    Kirigami.InlineMessage {
        id: message
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        type: Kirigami.MessageType.Error
        showCloseButton: true
    }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: list

            model: page.presets.names
            clip: true

            delegate: QQC2.ItemDelegate {
                id: row

                required property string modelData

                width: ListView.view.width
                highlighted: modelData === page.presets.currentName
                text: modelData
                onClicked: page.report(page.presets.apply(modelData))

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: row.modelData
                        elide: Text.ElideRight
                        font.bold: row.highlighted
                    }
                    QQC2.ToolButton {
                        icon.name: "document-export"
                        text: i18n("Export…")
                        display: QQC2.AbstractButton.IconOnly
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        onClicked: exportDialog.exportPreset(row.modelData)
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-rename"
                        text: i18n("Rename…")
                        display: QQC2.AbstractButton.IconOnly
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        onClicked: nameDialog.ask(row.modelData)
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-delete"
                        text: i18n("Delete")
                        display: QQC2.AbstractButton.IconOnly
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        onClicked: confirmDialog.ask(i18n("Delete preset"),
                                                     i18n("Delete the preset “%1”?", row.modelData),
                                                     i18n("Delete"), "edit-delete",
                                                     () => page.report(page.presets.remove(row.modelData)))
                    }
                }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: list.count === 0
                icon.name: "bookmarks"
                text: i18n("No presets yet")
                explanation: i18n("Set things up the way you like in the other tabs, then save them here as a preset.")
            }
        }
    }

    // Name of a new preset (oldName empty) or new name of an existing one.
    Kirigami.PromptDialog {
        id: nameDialog

        property string oldName

        function ask(name) {
            oldName = name;
            nameField.text = name;
            open();
            nameField.forceActiveFocus();
            nameField.selectAll();
        }

        function finish(name) {
            page.report(oldName === "" ? page.presets.save(name) : page.presets.rename(oldName, name));
        }

        title: oldName === "" ? i18n("Save preset") : i18n("Rename preset")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

        onAccepted: {
            const name = nameField.text.trim();
            const sameName = oldName !== "" && name.toLowerCase() === oldName.toLowerCase();
            if (name !== "" && !sameName && page.presets.contains(name)) {
                confirmDialog.ask(i18n("Replace preset"),
                                  i18n("A preset called “%1” already exists. Replace it?", name),
                                  i18n("Replace"), "document-replace", () => finish(name));
            } else {
                finish(name);
            }
        }

        QQC2.TextField {
            id: nameField
            placeholderText: i18n("Preset name")
            onAccepted: nameDialog.accept()
        }
    }

    // Yes/no question before replacing or deleting a preset.
    Kirigami.PromptDialog {
        id: confirmDialog

        property var action: null
        property string actionText
        property string actionIcon

        function ask(heading, question, label, iconName, callback) {
            confirmDialog.title = heading;
            confirmDialog.subtitle = question;
            confirmDialog.actionText = label;
            confirmDialog.actionIcon = iconName;
            confirmDialog.action = callback;
            confirmDialog.open();
        }

        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: confirmDialog.actionText
                icon.name: confirmDialog.actionIcon
                onTriggered: {
                    confirmDialog.close();
                    confirmDialog.action();
                }
            }
        ]
    }

    QtDialogs.FileDialog {
        id: importDialog

        title: i18n("Import preset")
        currentFolder: page.lastFolder
        nameFilters: [i18n("OSD Desk Snake presets (*.osdsnake)"), i18n("All files (*)")]
        onAccepted: {
            const file = selectedFile;
            page.lastFolder = page.folderOf(file);
            const found = page.presets.inspect(file);
            if (found.error !== "") {
                page.report(found.error);
            } else if (page.presets.contains(found.name)) {
                confirmDialog.ask(i18n("Replace preset"),
                                  i18n("A preset called “%1” already exists. Replace it?", found.name),
                                  i18n("Replace"), "document-replace",
                                  () => page.report(page.presets.importFrom(file)));
            } else {
                page.report(page.presets.importFrom(file));
            }
        }
    }

    QtDialogs.FileDialog {
        id: exportDialog

        property string presetName

        function exportPreset(name) {
            presetName = name;
            currentFolder = page.lastFolder;
            selectedFile = page.lastFolder + "/" + name.replace(/\//g, "-") + ".osdsnake";
            open();
        }

        title: i18n("Export preset")
        fileMode: QtDialogs.FileDialog.SaveFile
        defaultSuffix: "osdsnake"
        nameFilters: [i18n("OSD Desk Snake presets (*.osdsnake)")]
        onAccepted: {
            page.lastFolder = page.folderOf(selectedFile);
            page.report(page.presets.exportTo(presetName, selectedFile));
        }
    }
}
