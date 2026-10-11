pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

/// The four-way mode chooser — the Quickshell twin of `wallpaperchoise.rasi`.
///
/// Two entries are visible at a time and the other two live on a second row, the
/// same way rofi lays out four items in a two-column list that is one row tall.
/// Moving down scrolls that row into view; here it slides instead of jumping.
OverlayWindow {
    id: win

    cardWidth: Style.menu.width
    cardHeight: Style.menu.height
    windowName: "menu"

    /// The strings written to the result file are what `lumen` matches on.
    /// The glyphs are the Nerd Font codepoints the rofi menu was fed.
    readonly property var builtIn: [
        {
            id: "dark",
            glyph: String.fromCodePoint(0xf4ee),
            setting: "dark"
        },
        {
            id: "light",
            glyph: String.fromCodePoint(0xf522),
            setting: "light"
        },
        {
            id: "time",
            glyph: String.fromCodePoint(0xf1803),
            setting: "time"
        },
        {
            id: "season",
            glyph: String.fromCodePoint(0xf1a79),
            setting: "season"
        }
    ]

    /// The way into the settings, switched with `modes.cog`. Off, `s` and
    /// Ctrl+, still open them, and the cog comes back once every other entry
    /// is switched off, so an empty menu still has a way back.
    readonly property var cog: ({
            id: "settings",
            glyph: String.fromCodePoint(0xf0493)
        })

    /// True while Season's question is up — dark or light, asked on a card of
    /// its own that takes the bar's place.
    ///
    /// A season says nothing about the hour, so the evening is as likely to
    /// want dark as the morning light. It is not a second page of entries: the
    /// same glyphs in the same bar read as the menu having lost its own, so the
    /// question says what it is asking, and which season it is asking about.
    property bool askingSeason: false
    /// Which of the two the cursor is on while it is.
    property bool seasonDark: true

    /// The season `lumen` will draw from — the same months as its own
    /// `saison_for_month`, so the card never names one and opens another.
    readonly property var season: {
        const month = new Date().getMonth() + 1;
        if (month === 12 || month <= 2)
            return {
                name: "Winter",
                glyph: String.fromCodePoint(0xf0717)
            };
        if (month <= 5)
            return {
                name: "Spring",
                glyph: String.fromCodePoint(0xf024a)
            };
        if (month <= 8)
            return {
                name: "Summer",
                glyph: String.fromCodePoint(0xf05a8)
            };
        return {
            name: "Autumn",
            glyph: String.fromCodePoint(0xf032a)
        };
    }

    /// The four built-in entries you have left switched on, in the order you
    /// put them in, then your own folders, then the cog.
    ///
    /// A folder answers with its path rather than with a name, so `lumen` never
    /// has to know what your categories are: it opens the picker on whatever it
    /// was handed. The mode is not decided here — it is asked for once you have
    /// picked an image.
    readonly property var entries: {
        const out = Settings.modeOrder().map(id => win.builtIn.find(entry => entry.id === id)).filter(entry => Settings.modes[entry.setting]);
        for (const folder of Settings.folders ?? []) {
            if (!folder || !folder.on || !folder.path)
                continue;
            out.push({
                id: "folder:" + folder.path,
                glyph: Settings.glyph(folder.icon)
            });
        }
        if (Settings.modes.cog || out.length === 0)
            out.push(win.cog);
        return out;
    }

    // Switching an entry off under the cursor must not leave the selection past
    // the end of the menu.
    onEntriesChanged: {
        if (win.currentIndex >= win.entries.length)
            win.currentIndex = Math.max(0, win.entries.length - 1);
    }

    property int currentIndex: 0
    readonly property int currentColumn: currentIndex % Style.menu.columns
    readonly property int currentRow: Math.floor(currentIndex / Style.menu.columns)
    readonly property int rowCount: Math.ceil(entries.length / Style.menu.columns)

    function move(columns: int, rows: int) {
        const column = Math.max(0, Math.min(Style.menu.columns - 1, win.currentColumn + columns));
        const row = Math.max(0, Math.min(win.rowCount - 1, win.currentRow + rows));
        const index = row * Style.menu.columns + column;
        if (index < win.entries.length)
            win.currentIndex = index;
    }

    /// Opens the season's question, the cursor already on what the hour
    /// suggests — the same split as Time, so Enter alone does the obvious.
    function askSeason() {
        const hour = new Date().getHours();
        win.seasonDark = !(hour >= 7 && hour < 18);
        win.askingSeason = true;
    }

    function answerSeason(dark: bool) {
        Result.accept(dark ? "season:dark" : "season:light");
    }

    /// The question owns the keyboard while it is up, and swallows the rest:
    /// a `j` meant for it must not walk the menu hidden underneath.
    function seasonKey(event): bool {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_H:
            win.seasonDark = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_L:
            win.seasonDark = false;
            break;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            win.seasonDark = !win.seasonDark;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            win.answerSeason(win.seasonDark);
            break;
        case Qt.Key_Escape:
        case Qt.Key_Q:
        case Qt.Key_Backspace:
            win.askingSeason = false; // back to the menu, still on Season
            break;
        }
        return true;
    }

    function activate() {
        const entry = win.entries[win.currentIndex];
        if (!entry)
            return;

        // `ask` opens the question; anything else has been answered once and
        // for all in the panel, and goes straight out.
        if (entry.id === "season") {
            const theme = Settings.modes.seasonTheme;
            if (theme === "dark" || theme === "light" || theme === "auto")
                Result.accept("season:" + theme);
            else
                win.askSeason();
            return;
        }

        // The cog is a way into the panel rather than an answer for `lumen`,
        // which is still waiting on the four it knows about.
        if (entry.id === "settings") {
            settings.openAt("modes");
            win.asideOpen = true;
            return;
        }

        Result.accept(entry.id);
    }

    /// The settings panel opens from here too, on the same Ctrl+, as the picker.
    asideWidth: 470

    aside: SettingsPanel {
        id: settings

        scope: "menu"

        anchors.fill: parent
        onClosed: win.asideOpen = false
    }

    // Nothing is typed here, so the vim keys need no mode: `hjkl` move, `q`
    // quits, `s` opens the settings. The picker that comes next spells them
    // the same way.
    onKeyPressed: event => {
        if (event.key === Qt.Key_Comma && (event.modifiers & Qt.ControlModifier) !== 0) {
            win.asideOpen = !win.asideOpen;
            event.accepted = true;
            return;
        }

        // While the panel is out, the keys belong to it.
        if (win.asideOpen) {
            event.accepted = settings.handleKey(event);
            return;
        }

        if (win.askingSeason) {
            event.accepted = win.seasonKey(event);
            return;
        }

        switch (event.key) {
        case Qt.Key_Escape:
        case Qt.Key_Q:
            Result.cancel();
            break;
        case Qt.Key_S:
            // The cog's job, whether or not the menu is showing it.
            settings.openAt("modes");
            win.asideOpen = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_H:
            win.move(-1, 0);
            break;
        case Qt.Key_Right:
        case Qt.Key_L:
            win.move(1, 0);
            break;
        case Qt.Key_Up:
        case Qt.Key_K:
            win.move(0, -1);
            break;
        case Qt.Key_Down:
        case Qt.Key_J:
            win.move(0, 1);
            break;
        case Qt.Key_Tab:
            win.currentIndex = (win.currentIndex + 1) % win.entries.length;
            break;
        case Qt.Key_Backtab:
            win.currentIndex = (win.currentIndex + win.entries.length - 1) % win.entries.length;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            win.activate();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    /// `window { background-image: url(…, width); border: 3px; border-radius: 20px; }`
    ClippingRectangle {
        anchors.fill: parent
        radius: Style.menu.radius
        color: Colors.background
        border.width: Style.menu.border
        border.color: Colors.urgent
        contentUnderBorder: true // the wallpaper runs to the very edge, as in rasi

        WallpaperBackdrop {}

        /// The white bar: the element backgrounds, which butt against each other
        /// and read as a single capsule. It also clips the second row while it
        /// slides in.
        ClippingRectangle {
            x: Style.menu.insetX
            y: Style.menu.insetY
            width: Style.menu.barWidth
            height: Style.menu.barHeight
            radius: height / 2
            color: Colors.background

            // Steps back while Season's question is up, and takes no clicks
            // meant for the card in front of it.
            enabled: !win.askingSeason
            opacity: win.askingSeason ? 0 : 1
            scale: win.askingSeason ? 0.94 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Style.fadeDuration
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Style.moveDuration
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: rows

                width: parent.width
                height: Style.menu.cellHeight * win.rowCount
                // Keeps the selected row in view; rofi scrolls here too, in one step.
                y: -win.currentRow * Style.menu.cellHeight

                Behavior on y {
                    NumberAnimation {
                        duration: Style.scrollDuration
                        easing.type: Easing.OutCubic
                    }
                }

                /// Selected element. One pill for the whole menu rather than one
                /// per entry, so that it slides from entry to entry.
                Rectangle {
                    id: pill

                    x: win.currentColumn * Style.menu.cellWidth + Style.menu.pillInset
                    y: win.currentRow * Style.menu.cellHeight + Style.menu.pillInset
                    width: Style.menu.cellWidth - Style.menu.pillInset * 2
                    height: Style.menu.cellHeight - Style.menu.pillInset * 2
                    radius: height / 2
                    color: Colors.selected

                    Behavior on x {
                        NumberAnimation {
                            duration: Style.moveDuration
                            easing.type: Style.springEasing
                            easing.overshoot: Style.overshoot(0.05)
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: Style.scrollDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    /// `element-text { border: 9px; border-radius: 50px; }` — a ring
                    /// of window background inside the pill. It is drawn on every
                    /// element in rofi, but white on white is invisible, so only
                    /// the selected one ever shows.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Style.menu.ringInset
                        radius: height / 2
                        color: "transparent"
                        border.width: Style.menu.ringWidth
                        border.color: Colors.background
                    }
                }

                Repeater {
                    model: win.entries

                    delegate: Item {
                        id: cell

                        required property int index
                        required property var modelData
                        readonly property bool current: win.currentIndex === cell.index

                        x: (cell.index % Style.menu.columns) * Style.menu.cellWidth
                        y: Math.floor(cell.index / Style.menu.columns) * Style.menu.cellHeight
                        width: Style.menu.cellWidth
                        height: Style.menu.cellHeight

                        Text {
                            id: glyph

                            anchors.centerIn: parent
                            text: cell.modelData.glyph
                            color: Colors.foreground
                            font.family: Style.iconFont
                            font.pixelSize: Style.iconSize

                            // A nudge as the selection lands on the entry, and a
                            // smaller one while the pointer is over it.
                            readonly property real lift: cell.current ? Style.liftBy(6.7) : (hover.hovered ? Style.liftBy(3.3) : 1)

                            /// Never far enough to reach the edge of the white
                            /// bar. The bar is a ClippingRectangle — it has to
                            /// be, or the second row would show above and below
                            /// it as it slides in — so a glyph that grows past
                            /// it does not come back bigger, it comes back with
                            /// flat sides where the clip cut it. At the top of
                            /// the lift slider the menu's glyphs were sliced
                            /// square across the top and the bottom.
                            readonly property real ceiling: glyph.implicitHeight > 0 ? Math.max(1, (Style.menu.barHeight - 6) / glyph.implicitHeight) : 1

                            scale: Math.min(glyph.lift, glyph.ceiling)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Style.fadeDuration
                                    easing.type: Style.springEasing
                                    easing.overshoot: Style.overshoot(1)
                                }
                            }
                        }

                        HoverHandler {
                            id: hover
                            cursorShape: Qt.PointingHandCursor // element { cursor: pointer; }
                            onHoveredChanged: {
                                if (hovered)
                                    win.currentIndex = cell.index;
                            }
                        }

                        TapHandler {
                            onTapped: {
                                win.currentIndex = cell.index;
                                win.activate();
                            }
                        }
                    }
                }
            }
        }

        /// Season's question: dark or light, on a capsule of its own.
        ///
        /// Same footprint as the bar it replaces, so it reads as the menu
        /// answering rather than as another window — but laid out like a
        /// question, with the season it is about on the left and the two
        /// answers, glyph and word, on the right. Declared after the bar so it
        /// paints over it.
        Rectangle {
            id: question

            x: Style.menu.insetX
            y: Style.menu.insetY
            width: Style.menu.barWidth
            height: Style.menu.barHeight
            radius: height / 2
            color: Colors.background

            enabled: win.askingSeason
            visible: opacity > 0
            opacity: win.askingSeason ? 1 : 0
            scale: win.askingSeason ? 1 : 1.05

            Behavior on opacity {
                NumberAnimation {
                    duration: Style.fadeDuration
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Style.moveDuration
                    easing.type: Style.springEasing
                    easing.overshoot: Style.overshoot(0.4)
                }
            }

            /// Height of the two answers, inset the way the menu's own pill is.
            readonly property real pillHeight: Math.max(24, height - Style.menu.pillInset * 2 - 8)
            readonly property real pillWidth: Math.max(pillHeight * 1.3, Style.textSize * 6.5)
            readonly property real gap: Math.max(8, height * 0.12)
            /// Below this the season's name goes, before anything overlaps.
            readonly property bool roomForTitle: width - answers.width - back.width - emblem.width - gap * 5 >= title.implicitWidth

            Row {
                anchors.left: parent.left
                anchors.leftMargin: question.gap
                anchors.verticalCenter: parent.verticalCenter
                spacing: question.gap

                /// Back to the menu — the same as Esc.
                Rectangle {
                    id: back

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(24, question.pillHeight * 0.55)
                    height: width
                    radius: height / 2
                    color: backHover.hovered ? Qt.alpha(Colors.foreground, 0.12) : "transparent"
                    border.width: 2
                    border.color: Qt.alpha(Colors.foreground, 0.35)

                    Behavior on color {
                        ColorAnimation {
                            duration: Style.fadeDuration
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xf004d)
                        color: Colors.foreground
                        font.family: Style.iconFont
                        font.pixelSize: back.height * 0.5
                    }

                    HoverHandler {
                        id: backHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: win.askingSeason = false
                    }
                }

                Text {
                    id: emblem

                    anchors.verticalCenter: parent.verticalCenter
                    text: win.season.glyph
                    color: Colors.selected
                    font.family: Style.iconFont
                    font.pixelSize: Math.min(Style.iconSize, question.pillHeight * 0.75)
                }

                Column {
                    id: title

                    anchors.verticalCenter: parent.verticalCenter
                    visible: question.roomForTitle
                    spacing: 2

                    Text {
                        text: win.season.name
                        color: Colors.foreground
                        font.family: Style.textFont
                        font.pixelSize: Style.textSize * 1.35
                        font.bold: true
                    }

                    Text {
                        text: "dark or light?"
                        color: Colors.foreground
                        opacity: 0.6
                        font.family: Style.textFont
                        font.pixelSize: Style.textSize * 0.85
                    }
                }
            }

            /// The two answers. One highlight slides between them, the way the
            /// menu's pill slides between entries.
            Item {
                id: answers

                anchors.right: parent.right
                anchors.rightMargin: question.gap
                anchors.verticalCenter: parent.verticalCenter
                width: question.pillWidth * 2 + 6
                height: question.pillHeight

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Qt.alpha(Colors.foreground, 0.2)
                }

                Rectangle {
                    x: win.seasonDark ? 0 : question.pillWidth + 6
                    width: question.pillWidth
                    height: parent.height
                    radius: height / 2
                    color: Colors.selected

                    Behavior on x {
                        NumberAnimation {
                            duration: Style.moveDuration
                            easing.type: Style.springEasing
                            easing.overshoot: Style.overshoot(0.05)
                        }
                    }

                    // The menu pill's ring, so the answer looks picked the same
                    // way an entry does.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Math.min(Style.menu.ringInset, parent.height / 4)
                        radius: height / 2
                        color: "transparent"
                        border.width: Math.min(Style.menu.ringWidth, parent.height / 6)
                        border.color: Colors.background
                    }
                }

                Repeater {
                    model: [
                        {
                            label: "Dark",
                            glyph: String.fromCodePoint(0xf4ee),
                            dark: true
                        },
                        {
                            label: "Light",
                            glyph: String.fromCodePoint(0xf522),
                            dark: false
                        }
                    ]

                    delegate: Item {
                        id: answer

                        required property var modelData
                        readonly property bool current: win.seasonDark === answer.modelData.dark

                        x: answer.modelData.dark ? 0 : question.pillWidth + 6
                        width: question.pillWidth
                        height: question.pillHeight

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            opacity: answer.current ? 1 : 0.55
                            scale: answer.current ? Style.lift : 1

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Style.fadeDuration
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Style.fadeDuration
                                    easing.type: Style.springEasing
                                    easing.overshoot: Style.overshoot(1)
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: answer.modelData.glyph
                                color: Colors.foreground
                                font.family: Style.iconFont
                                font.pixelSize: Math.min(Style.iconSize * 0.6, question.pillHeight * 0.45)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: answer.modelData.label
                                color: Colors.foreground
                                font.family: Style.textFont
                                font.pixelSize: Style.textSize
                            }
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered)
                                    win.seasonDark = answer.modelData.dark;
                            }
                        }

                        TapHandler {
                            onTapped: win.answerSeason(answer.modelData.dark)
                        }
                    }
                }
            }
        }
    }
}
