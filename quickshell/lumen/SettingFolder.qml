import QtQuick

/// One folder of your own, as a row of the Entries tab: its glyph, its name, a
/// switch, and a cross.
///
/// The switch is what the four built-in entries have — a folder can be put away
/// without being forgotten, so a collection you only want in December does not
/// have to be typed in again every year. The cross is armed by pressing twice,
/// like a preset's: it forgets a folder, and the panel has no undo.
Item {
    id: folder

    required property string name
    required property string glyph
    required property bool on
    /// Whether it points anywhere yet. One that does not is never drawn in the
    /// menu, so the row has to say so rather than look finished.
    property bool ready: true
    property bool open: false
    property bool selected: false

    property var toggled: null
    property var erase: null
    property var unfold: null

    property bool armed: false

    onSelectedChanged: {
        if (!folder.selected)
            folder.armed = false;
    }

    /// Enter on the row: opens it for editing, or closes it.
    function flip() {
        folder.armed = false;
        if (folder.unfold)
            folder.unfold();
    }

    function remove() {
        if (!folder.armed) {
            folder.armed = true;
            return;
        }
        folder.armed = false;
        if (folder.erase)
            folder.erase();
    }

    implicitHeight: 44

    Text {
        id: mark

        x: 1
        anchors.verticalCenter: parent.verticalCenter
        text: folder.glyph
        color: !folder.ready ? Colors.urgent : (folder.on ? Colors.selected : Colors.foreground)
        opacity: (folder.on || !folder.ready) ? 1 : 0.4
        font.family: Style.iconFont
        font.pixelSize: Style.textSize * 1.2

        Behavior on color {
            ColorAnimation {
                duration: Style.fadeDuration
            }
        }
    }

    Text {
        id: title

        x: mark.x + mark.width + 10
        y: folder.ready ? 0 : 5
        height: folder.ready ? parent.height : parent.height - 10
        verticalAlignment: Text.AlignVCenter
        width: parent.width - buttons.width - 16 - x
        elide: Text.ElideRight
        text: folder.name === "" ? "Unnamed" : folder.name
        color: Colors.foreground
        opacity: folder.name === "" ? 0.4 : (folder.selected ? 1 : 0.75)
        font.family: Style.textFont
        font.pixelSize: Style.textSize
    }

    Text {
        x: title.x
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        width: title.width
        elide: Text.ElideRight
        visible: !folder.ready
        text: "enter to set its folder — it stays out of the menu until you do"
        color: Colors.urgent
        font.family: Style.textFont
        font.pixelSize: Style.textSize * 0.75
    }

    Row {
        id: buttons

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Rectangle {
            id: cross

            width: folder.armed ? gone.implicitWidth + 24 : 26
            height: 26
            radius: height / 2
            color: folder.armed ? Colors.urgent : "transparent"
            border.width: 3
            border.color: Colors.urgent
            opacity: folder.armed ? 1 : 0.45

            Behavior on width {
                NumberAnimation {
                    duration: Style.fadeDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Style.fadeDuration
                }
            }

            Text {
                id: gone

                anchors.centerIn: parent
                text: folder.armed ? "Press again" : "×"
                color: folder.armed ? Colors.background : Colors.urgent
                font.family: Style.textFont
                font.pixelSize: Style.textSize * (folder.armed ? 0.8 : 1)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: folder.remove()
            }
        }

        /// The same switch the four built-in entries have.
        Rectangle {
            width: 52
            height: 26
            radius: height / 2
            color: folder.on ? Colors.selected : "transparent"
            border.width: 3
            border.color: folder.on ? Colors.selected : Colors.foreground
            opacity: folder.on ? 1 : 0.55

            Behavior on color {
                ColorAnimation {
                    duration: Style.fadeDuration
                }
            }

            Rectangle {
                x: folder.on ? parent.width - width - 5 : 5
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: width / 2
                color: folder.on ? Colors.background : Colors.foreground

                Behavior on x {
                    NumberAnimation {
                        duration: Style.moveDuration
                        easing.type: Style.springEasing
                        easing.overshoot: Style.overshoot(0.1)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (folder.toggled)
                        folder.toggled();
                }
            }
        }
    }
}
