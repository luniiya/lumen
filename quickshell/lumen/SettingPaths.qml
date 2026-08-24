import QtQuick

/// What is actually in the folder you are half-way through typing.
///
/// The panel has no file dialog and no clipboard, so a path is typed — and a
/// path typed blind is a path with a typo in it, which shows up much later as a
/// menu entry that opens on nothing. This lists the directories that are really
/// there, filtered by what you have written so far, and `Tab` takes one.
///
/// Only directories: a wallpaper folder is a folder, and listing the images
/// inside it would bury the one thing you are looking for.
Item {
    id: paths

    /// Directory names, already filtered.
    required property var names
    required property int index
    /// What the names hang off, shown so you can see where you are.
    required property string base
    property bool selected: false
    property var chose: null

    implicitHeight: paths.names.length === 0 ? 34 : 34 + Math.ceil(paths.names.length / 2) * 30

    Text {
        id: here

        x: 14
        y: 6
        width: parent.width - 28
        elide: Text.ElideLeft
        text: paths.names.length === 0 ? "Nothing to go into here" : `${paths.base}  ·  tab takes one, ↑↓ to look`
        color: Colors.foreground
        opacity: paths.names.length === 0 ? 0.45 : 0.55
        font.family: Style.textFont
        font.pixelSize: Style.textSize * 0.78
    }

    Grid {
        x: 14
        y: 30
        width: parent.width - 28
        columns: 2
        columnSpacing: 8
        rowSpacing: 4

        Repeater {
            model: paths.names

            delegate: Rectangle {
                id: candidate

                required property int index
                required property string modelData
                readonly property bool under: paths.selected && paths.index === candidate.index

                width: (paths.width - 36) / 2
                height: 26
                radius: 7
                color: candidate.under ? Colors.selected : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Style.fadeDuration
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideMiddle
                    text: candidate.modelData
                    color: candidate.under ? Colors.background : Colors.foreground
                    opacity: candidate.under ? 1 : 0.8
                    font.family: Style.textFont
                    font.pixelSize: Style.textSize * 0.85
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (paths.chose)
                            paths.chose(candidate.index);
                    }
                }
            }
        }
    }
}
