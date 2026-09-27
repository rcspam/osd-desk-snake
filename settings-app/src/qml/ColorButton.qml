import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs

// Same button as KQuickControls.ColorButton, except that every click opens a new
// dialog. With Qt 6.10.2 a ColorDialog opened a second time shows a blank
// saturation/lightness area (fixed in Qt 6.10.3, qtdeclarative c5d48bbbd6).
QQC2.Button {
    id: root

    property color color
    property string dialogTitle
    property bool showAlphaChannel: true
    // The dialog while it is open, null otherwise.
    property QtDialogs.ColorDialog dialog: null

    signal accepted(color color)

    readonly property real _margins: 4

    implicitWidth: 40 + _margins * 2
    Accessible.name: dialogTitle

    // Checkerboard behind translucent colors.
    Canvas {
        anchors.fill: colorBlock
        visible: root.color.a < 1

        onPaint: {
            const ctx = getContext("2d");
            ctx.fillStyle = "white";
            ctx.fillRect(0, 0, width, height);
            ctx.fillStyle = "black";
            for (let x = 0; x < width; x += 16) {
                for (let y = 0; y < height; y += 16) {
                    ctx.fillRect(x, y, 8, 8);
                    ctx.fillRect(x + 8, y + 8, 8, 8);
                }
            }
        }
    }

    Rectangle {
        id: colorBlock

        anchors.centerIn: parent
        width: parent.width - root._margins * 2
        height: parent.height - root._margins * 2
        color: root.enabled ? root.color : disabledPalette.button

        SystemPalette {
            id: disabledPalette
            colorGroup: SystemPalette.Disabled
        }
    }

    Component {
        id: dialogComponent

        QtDialogs.ColorDialog {
            title: root.dialogTitle
            selectedColor: root.color
            parentWindow: root.Window.window
            options: root.showAlphaChannel ? QtDialogs.ColorDialog.ShowAlphaChannel : 0
            onAccepted: {
                root.color = selectedColor;
                root.accepted(selectedColor);
                destroy();
            }
            onRejected: destroy()
        }
    }

    onClicked: {
        dialog = dialogComponent.createObject(root);
        dialog.open();
    }
}
