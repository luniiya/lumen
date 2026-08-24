import QtQuick

/// A plate of glyphs to pick a folder's icon from.
///
/// The codepoint field beside it reaches every glyph the font has; this reaches
/// the twenty you were probably going to choose anyway, and does it without
/// anyone having to look a number up. `h` and `l` walk it, Enter takes the one
/// under the cursor — the panel's own keys, over a strip instead of a list.
Item {
    id: plate

    /// Codepoints in hex, the way they are stored.
    readonly property var glyphs: ["f07b", "f03e", "f005", "f004", "f11b", "f008", "f001", "f030", "f0c2", "f1fc", "f02c", "f0e7", "f186", "f185", "f06c", "f1b0", "f0f3", "f015", "f1bb", "f2dc"]

    required property string value
    property bool selected: false
    property var chose: null

    property int cursor: Math.max(0, plate.glyphs.indexOf(plate.value))

    /// h and l on the row, rather than a value to slide.
    function nudge(amount: real) {
        const next = plate.cursor + (amount > 0 ? 1 : -1);
        if (next >= 0 && next < plate.glyphs.length)
            plate.cursor = next;
    }

    function flip() {
        if (plate.chose)
            plate.chose(plate.glyphs[plate.cursor]);
    }

    implicitHeight: 82

    Text {
        x: 14
        y: 8
        text: "Pick one"
        color: Colors.foreground
        opacity: plate.selected ? 1 : 0.6
        font.family: Style.textFont
        font.pixelSize: Style.textSize * 0.92
    }

    Flow {
        x: 14
        y: 30
        width: parent.width - 28
        spacing: 6

        Repeater {
            model: plate.glyphs

            delegate: Rectangle {
                id: cell

                required property int index
                required property string modelData
                readonly property bool under: plate.selected && plate.cursor === cell.index
                readonly property bool taken: plate.value === cell.modelData

                width: 30
                height: 30
                radius: 8
                color: cell.taken ? Colors.selected : "transparent"
                border.width: cell.under ? 3 : 0
                border.color: Colors.urgent

                Behavior on color {
                    ColorAnimation {
                        duration: Style.fadeDuration
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(parseInt(cell.modelData, 16))
                    color: cell.taken ? Colors.background : Colors.foreground
                    opacity: cell.taken ? 1 : 0.75
                    font.family: Style.iconFont
                    font.pixelSize: Style.textSize
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        plate.cursor = cell.index;
                        plate.flip();
                    }
                }
            }
        }
    }
}
