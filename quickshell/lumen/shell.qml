import Quickshell

/// Entry point of the Quickshell front-end for `lumen`.
///
/// `lumen` runs `qs -p <this file>` once per prompt and waits for it to exit,
/// the way it used to run `rofi -dmenu`. `$LUMEN_MODE` says which of the two
/// prompts to show:
///
///   menu      the four modes — dark, light, time of day, season — and any
///             folders of your own
///   picker    the thumbnail grid for one wallpaper directory
///   folder    the same grid, on a folder of your own. It is neither dark nor
///             light the way `dark/` and `light/` are, so it asks once you have
///             chosen and answers `dark:<path>` or `light:<path>`
///   settings  the same grid, with the settings panel already out and picking
///             disabled — this is what `lumen --settings` runs
///
/// See Result.qml for how the answer travels back.
ShellRoot {
    id: root

    readonly property string mode: Quickshell.env("LUMEN_MODE") ?? "menu"

    LazyLoader {
        active: root.mode === "menu"

        ModeMenu {}
    }

    LazyLoader {
        active: root.mode === "picker" || root.mode === "settings" || root.mode === "folder"

        WallpaperPicker {
            // In settings mode the grid is there to be looked at, not picked
            // from: it is the live preview of what the panel is changing.
            preview: root.mode === "settings"
            asideOpen: root.mode === "settings"
            // `folder` is the same grid on one of your own folders. It is not
            // dark or light the way `dark/` and `light/` are, so it asks.
            askMode: root.mode === "folder"
        }
    }
}
