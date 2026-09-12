import QtQuick

/// One saved configuration: its name, a button that puts it back, one that
/// writes what is on screen into it, and a cross that throws it away.
///
/// Both buttons that write are armed by pressing twice, the same bargain the
/// Tags tab makes for a re-tag: one removes a file and the other overwrites
/// one, and the panel has no undo. *Update* began as a single press, on the
/// grounds that a button you confirm is a button you stop using — in the hand
/// that turned out to be wrong, because the row it sits on is a list you scroll
/// and the wrong one is one line away.
///
/// A dot and the name in the selection colour say the configuration on screen
/// already *is* this preset — applying it would change nothing. It is compared,
/// not remembered, so it goes out the moment you move a slider.
Item {
    id: preset

    required property string name
    /// Whether there is a file behind the row. `Default` is the rofi
    /// measurements rather than a preset on disk, so it can be neither written
    /// over nor deleted — both buttons key off this.
    property bool stored: true
    property bool busy: false
    property bool selected: false
    /// Whether the settings already hold everything this preset does.
    property bool active: false

    property var apply: null
    /// Writes the configuration on screen over this preset.
    property var revise: null
    property var erase: null
    /// Puts this preset's file on the clipboard, so it can be pasted
    /// somewhere else — another machine, a message to whoever wants it.
    property var copy: null

    /// Which button is waiting for its second press: `erase`, `update`, or
    /// nothing. One string rather than a flag each, so that arming one disarms
    /// the other — you cannot be half-way to two different answers at once.
    property string armed: ""

    /// Walking away forgets whatever was armed.
    onSelectedChanged: {
        if (!preset.selected)
            preset.armed = "";
    }

    /// Enter on the row, and a click on the button.
    function flip() {
        preset.armed = "";
        if (preset.apply)
            preset.apply();
    }

    /// `u` on the row, and a click on *Update*.
    ///
    /// Not called `update`: every Item has one of those already, so the panel's
    /// `item.overwrite ? …` — which is how it tells the rows that can do a thing
    /// from the rows that cannot — would have been true of every row on screen,
    /// and pressing `u` on a slider would have quietly asked it to repaint.
    function overwrite() {
        if (!preset.stored)
            return;
        if (preset.armed !== "update") {
            preset.armed = "update";
            return;
        }
        preset.armed = "";
        if (preset.revise)
            preset.revise();
    }

    /// `x` or Delete on the row, and a click on the cross.
    function remove() {
        if (!preset.stored)
            return;
        if (preset.armed !== "erase") {
            preset.armed = "erase";
            return;
        }
        preset.armed = "";
        if (preset.erase)
            preset.erase();
    }

    /// `c` on the row, and a click on *Copy*. No second press: unlike
    /// updating or deleting, putting something on the clipboard changes
    /// nothing this row holds, so there is nothing here to confirm.
    function copyOut() {
        if (preset.copy)
            preset.copy();
    }

    implicitHeight: 44

    /// The one thing on the row that is not a button: it says you are here.
    /// The space it takes is held whether it is lit or not, so a preset does not
    /// jump sideways the moment it becomes the current one.
    Rectangle {
        id: mark

        x: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 10
        radius: width / 2
        color: Colors.selected
        opacity: preset.active ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Style.fadeDuration
            }
        }
    }

    Text {
        x: mark.x + mark.width + 8
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - buttons.width - 16 - x
        elide: Text.ElideRight
        text: preset.name
        color: preset.active ? Colors.selected : Colors.foreground
        opacity: (preset.active || preset.selected) ? 1 : 0.75
        font.family: Style.textFont
        font.pixelSize: Style.textSize

        Behavior on color {
            ColorAnimation {
                duration: Style.fadeDuration
            }
        }
    }

    Row {
        id: buttons

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Rectangle {
            id: cross

            readonly property bool ready: preset.armed === "erase"

            visible: preset.stored
            width: cross.ready ? erase.implicitWidth + 24 : 26
            height: 26
            radius: height / 2
            color: cross.ready ? Colors.urgent : "transparent"
            border.width: 3
            border.color: Colors.urgent
            opacity: cross.ready ? 1 : 0.45

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
                id: erase

                anchors.centerIn: parent
                text: cross.ready ? "Press again" : "×"
                color: cross.ready ? Colors.background : Colors.urgent
                font.family: Style.textFont
                font.pixelSize: Style.textSize * (cross.ready ? 0.8 : 1)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: preset.remove()
            }
        }

        /// Takes the whole configuration as it stands and puts it in the file,
        /// so that a look you keep tuning stays one preset rather than becoming
        /// `rounded`, `rounded 2` and `rounded final`.
        Rectangle {
            id: update

            readonly property bool ready: preset.armed === "update"

            visible: preset.stored
            width: revise.implicitWidth + 26
            height: 26
            radius: height / 2
            // Armed in the selection colour rather than the red the cross uses:
            // this one overwrites a preset, it does not throw one away.
            color: update.ready ? Colors.selected : "transparent"
            border.width: 3
            border.color: update.ready ? Colors.selected : Colors.foreground
            opacity: update.ready ? 1 : 0.55

            Behavior on color {
                ColorAnimation {
                    duration: Style.fadeDuration
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Style.fadeDuration
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: revise

                anchors.centerIn: parent
                text: update.ready ? "Press again" : "Update"
                color: update.ready ? Colors.background : Colors.foreground
                font.family: Style.textFont
                font.pixelSize: Style.textSize * 0.8
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: preset.overwrite()
            }
        }

        /// Visible on every row, `Default` included — there is no file behind
        /// it, but the rofi measurements are still worth copying out.
        Rectangle {
            width: copyLabel.implicitWidth + 26
            height: 26
            radius: height / 2
            color: "transparent"
            border.width: 3
            border.color: Colors.foreground
            opacity: 0.55

            Text {
                id: copyLabel

                anchors.centerIn: parent
                text: "Copy"
                color: Colors.foreground
                font.family: Style.textFont
                font.pixelSize: Style.textSize * 0.8
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: preset.copyOut()
            }
        }

        Rectangle {
            width: verb.implicitWidth + 26
            height: 26
            radius: height / 2
            color: preset.busy ? Colors.selected : "transparent"
            border.width: 3
            border.color: Colors.selected

            Behavior on color {
                ColorAnimation {
                    duration: Style.fadeDuration
                }
            }

            Text {
                id: verb

                anchors.centerIn: parent
                text: preset.busy ? "Loading…" : "Apply"
                color: preset.busy ? Colors.background : Colors.foreground
                font.family: Style.textFont
                font.pixelSize: Style.textSize * 0.8
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: preset.flip()
            }
        }
    }
}
