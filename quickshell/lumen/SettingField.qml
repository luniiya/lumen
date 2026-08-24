import QtQuick

/// A line of text you type into — a folder's name, its path, its codepoint.
///
/// Not a TextInput, for the reason SettingName gives: the panel already owns the
/// keyboard and a focused field inside it would have to win it back and hand it
/// over again cleanly. The panel collects the letters and this only draws them.
Item {
    id: field

    required property string label
    required property string value
    /// Said under the value: what a path expands to, what a codepoint draws.
    property string note: ""
    /// What the line is waiting for, shown inside it while it is empty. A row
    /// that only says `empty` tells you nothing about how to stop it being so.
    property string hint: ""
    property bool bad: false
    property bool editing: false
    property bool selected: false

    property var begin: null

    /// Enter on the row starts typing into it.
    function flip() {
        if (field.begin)
            field.begin();
    }

    implicitHeight: field.note === "" ? 40 : 56

    Text {
        id: name

        x: 14
        y: 10
        width: parent.width * 0.32
        elide: Text.ElideRight
        text: field.label
        color: Colors.foreground
        opacity: field.selected ? 1 : 0.6
        font.family: Style.textFont
        font.pixelSize: Style.textSize * 0.92
    }

    Rectangle {
        id: box

        x: name.x + parent.width * 0.32 + 10
        y: 5
        width: parent.width - x
        height: 30
        radius: Style.picker.entryRadius + 4
        color: "transparent"
        border.width: 3
        border.color: field.editing ? Colors.urgent : (field.bad ? Colors.urgent : Colors.selected)
        opacity: field.editing ? 1 : 0.55

        Behavior on border.color {
            ColorAnimation {
                duration: Style.fadeDuration
            }
        }

        Text {
            id: typed

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 20
            elide: Text.ElideLeft
            text: field.value
            color: Colors.foreground
            font.family: Style.textFont
            font.pixelSize: Style.textSize * 0.88
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: field.value === ""
            text: field.editing ? "typing — enter to keep it" : (field.hint === "" ? "press enter to type" : field.hint)
            color: Colors.foreground
            opacity: 0.4
            font.family: Style.textFont
            font.pixelSize: Style.textSize * 0.88
        }

        Rectangle {
            x: Math.min(10 + typed.implicitWidth + 2, parent.width - 6)
            anchors.verticalCenter: parent.verticalCenter
            visible: field.editing
            width: 2
            height: parent.height * 0.55
            color: Colors.foreground

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: field.editing

                NumberAnimation {
                    to: 0
                    duration: 480
                }
                NumberAnimation {
                    to: 1
                    duration: 480
                }
            }
        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: field.flip()
    }

    Text {
        x: box.x + 4
        y: box.y + box.height + 2
        width: parent.width - x
        elide: Text.ElideRight
        visible: field.note !== ""
        text: field.note
        color: field.bad ? Colors.urgent : Colors.foreground
        opacity: field.bad ? 0.9 : 0.5
        font.family: Style.textFont
        font.pixelSize: Style.textSize * 0.78
    }
}
