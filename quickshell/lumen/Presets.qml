pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel

/// Whole configurations, saved to a file and put back on demand.
///
/// One JSON file per preset in `~/.config/lumen/presets`, in the same shape as
/// `settings.json` itself — so a preset is something you can read, hand-edit,
/// send to someone, or drop into the folder straight out of a git repository.
///
/// `Default` is not a file. It is the rofi measurements Settings already
/// carries, which is what makes it the one preset that can never go missing.
Singleton {
    id: root

    readonly property string directory: `${Quickshell.env("HOME")}/.config/lumen/presets`
    readonly property string url: `file://${root.directory}`

    /// Names as shown, without the `.json`.
    property var names: []
    /// The last thing that happened, printed under the rows.
    property string status: ""
    /// Which preset is on its way in, so a second press cannot race the read.
    property string pending: ""

    /// What each preset holds, parsed, keyed by name. Filled in as the files
    /// are read; what `isCurrent` compares the live configuration against.
    property var contents: ({})

    /// A configuration read off the clipboard, waiting on a name — see
    /// `pasteFromClipboard` and `savePasted`. Cleared once it is written, so a
    /// stray Enter afterwards cannot save it again under a second name.
    property var pastedValues: null

    /// Fired once a paste has parsed as something worth naming, which is what
    /// the panel is waiting for to open the same naming row a Save does.
    signal pasteReady

    function path(name: string): string {
        return `${root.directory}/${name}.json`;
    }

    function refresh() {
        const found = [];
        // A folder that is not there yet leaves the model listing whatever it
        // could reach instead — the first run showed `settings.json` from a
        // directory above. Nothing counts until it is looking where we asked.
        if (String(folder.folder) === root.url) {
            for (let i = 0; i < folder.count; i++) {
                found.push(String(folder.get(i, "fileName")).replace(/\.json$/, ""));
            }
        }
        root.names = found;
        root.reread();
    }

    /// Reads any preset we do not already hold the contents of.
    ///
    /// Nothing is dropped here. A rescan points the model away from the folder
    /// and back, so `names` goes empty and full again in the same breath, and
    /// forgetting on the empty half would blank every row's marker for a frame.
    /// Rows only exist for names in `names`, so an entry left behind is unread
    /// rather than wrong.
    function reread() {
        for (const name of root.names) {
            if (!(name in root.contents))
                peek.createObject(root, {
                    name: name,
                    path: root.path(name)
                });
        }
    }

    /// Records what a preset holds without reading it back.
    ///
    /// We have just written the file, so we know its contents exactly — and a
    /// read fired straight after an atomic write is a race worth not having.
    /// The map is replaced rather than edited: the same object mutated in place
    /// is the same object, and nothing bound to it would hear about it.
    function remember(name: string, values: var) {
        const next = Object.assign({}, root.contents);
        next[name] = values;
        root.contents = next;
    }

    function forget(name: string) {
        const next = Object.assign({}, root.contents);
        delete next[name];
        root.contents = next;
    }

    /// Whether the configuration on screen already is this preset.
    ///
    /// More than one row can say so at once, and that is not a bug: a
    /// colours-only preset and a whole one can both be satisfied, and applying
    /// either would change nothing. `Default` is not a file — it is the rofi
    /// measurements Settings carries.
    function isCurrent(name: string): bool {
        if (name === "")
            return Settings.satisfies(Settings.defaults);
        const held = root.contents[name];
        return held ? Settings.satisfies(held) : false;
    }

    /// FolderListModel has no refresh of its own, and does not reliably notice
    /// our own writes. Pointing it away and back is what makes it look again.
    function rescan() {
        folder.folder = "";
        folder.folder = root.url;
        root.refresh();
    }

    /// Puts the rofi measurements back, with no file in the way.
    function applyDefault() {
        Settings.applyValues(Settings.defaults);
        root.status = "Default applied.";
    }

    function apply(name: string) {
        root.pending = name;
        const wanted = root.path(name);
        // Applying the same preset twice leaves the path alone, and a path that
        // does not change never reloads — so ask for the read outright.
        if (reader.path === wanted)
            reader.reload();
        else
            reader.path = wanted;
    }

    function save(name: string) {
        const clean = root.clean(name);
        if (!clean) {
            root.status = "That name has nothing in it.";
            return;
        }
        const values = Settings.snapshot();
        root.write(clean, values);
        root.remember(clean, values);
        root.status = `Saved as ${clean}.`;
        Qt.callLater(root.rescan);
    }

    /// Writes what is on screen into a preset that is already there, so that
    /// tuning a saved look is one button rather than deleting it and typing the
    /// name again.
    ///
    /// It reads the file before it writes, and puts back only the keys that file
    /// already held — which is what makes it the exact inverse of `apply`.
    /// Applying a colours-only preset leaves your layout alone; updating one has
    /// to leave the layout out of the file, or the first update would quietly
    /// turn it into a whole configuration and it would never restyle only the
    /// palette again.
    ///
    /// There is no rescan afterwards: the name is already in the list and the
    /// file already in the folder.
    function overwrite(name: string) {
        const clean = root.clean(name);
        if (!clean)
            return;
        sieve.createObject(root, {
            name: clean,
            path: root.path(clean)
        });
    }

    /// A set of values, to the file of a preset that has already been named.
    ///
    /// A FileView takes a new path asynchronously, so a writer that is kept
    /// around and re-pointed puts the second preset over the first — which is
    /// exactly what it did. One writer per write has no path to change.
    /// `setText` also makes the folders it needs, so the first preset works on a
    /// machine that has never had a presets directory.
    function write(name: string, values: var) {
        const writer = pen.createObject(root, {
            path: root.path(name)
        });
        writer.setText(JSON.stringify(values, null, 2) + "\n");
        writer.destroy(2000);
    }

    function remove(name: string) {
        root.forget(name);
        eraser.command = ["rm", "-f", root.path(name)];
        eraser.running = true;
        root.status = `Deleted ${name}.`;
    }

    /// Puts one preset's file on the clipboard — the same JSON `save` would
    /// write, so pasting it back anywhere, on this machine or another, gives
    /// the exact preset back. `Default` has no file, so it is `defaults`
    /// itself: everything a preset can carry, at the rofi measurements.
    function copyToClipboard(name: string) {
        const values = name === "" ? Settings.defaults : root.contents[name];
        if (!values) {
            root.status = `${name || "Default"} is not read yet — try again in a moment.`;
            return;
        }
        copier.command = ["wl-copy", JSON.stringify(values, null, 2)];
        copier.running = true;
        root.status = `${name || "Default"} copied to the clipboard.`;
    }

    /// Reads the clipboard, asking `handlePaste` to make sense of it.
    function pasteFromClipboard() {
        paster.running = true;
    }

    /// What a paste turned out to hold. Anything that is not an object a
    /// preset could be is a clipboard with something else in it — a wallpaper
    /// path, a URL, whatever was last copied — and is reported rather than
    /// saved under a blank name.
    function handlePaste(text: string) {
        let values;
        try {
            values = JSON.parse(text);
        } catch (error) {
            values = null;
        }
        if (!values || typeof values !== "object") {
            root.status = "The clipboard does not hold a preset.";
            return;
        }
        root.pastedValues = values;
        root.status = "Clipboard read — name it to save.";
        root.pasteReady();
    }

    /// Writes what `pasteFromClipboard` read in under a new name — the
    /// clipboard's half of `save`, which writes what is on screen instead.
    function savePasted(name: string) {
        const clean = root.clean(name);
        if (!clean) {
            root.status = "That name has nothing in it.";
            return;
        }
        if (!root.pastedValues) {
            root.status = "Nothing pasted yet.";
            return;
        }
        root.write(clean, root.pastedValues);
        root.remember(clean, root.pastedValues);
        root.pastedValues = null;
        root.status = `Saved as ${clean}, from the clipboard.`;
        Qt.callLater(root.rescan);
    }

    /// A preset name becomes a filename, so it may not wander out of the folder
    /// or hide itself. Everything else is left alone: people name things with
    /// spaces and accents, and there is no reason to mangle that.
    function clean(name: string): string {
        return name.replace(/[\/\\]/g, " ") // no wandering out of the folder
        .replace(/\.+/g, ".")              // and no `...` left behind by it
        .replace(/^[.\s]+/, "")            // nor a leading dot, which hides it
        .replace(/\s+/g, " ").trim();
    }

    FolderListModel {
        id: folder

        folder: root.url
        nameFilters: ["*.json"]
        showDirs: false
        sortField: FolderListModel.Name

        onCountChanged: root.refresh()
    }

    FileView {
        id: reader

        printErrors: false // a preset deleted from under us is not a crash

        onLoaded: {
            const name = root.pending;
            root.pending = "";
            try {
                Settings.applyValues(JSON.parse(reader.text()));
                root.status = `${name} applied.`;
            } catch (error) {
                root.status = `${name} is not readable JSON.`;
            }
        }

        onLoadFailed: {
            root.status = `${root.pending} could not be read.`;
            root.pending = "";
        }
    }

    /// The read an update does first, so that it can put back what the preset
    /// holds rather than everything.
    ///
    /// One reader per update, for the same reason there is one writer per write:
    /// a FileView takes a new path asynchronously, so a single reader re-pointed
    /// at a second preset before the first has landed drops that first update on
    /// the floor — and the status line, already showing the second name, says
    /// nothing about it. The name rides on the reader instead, so two updates in
    /// flight cannot mistake each other's file.
    Component {
        id: sieve

        FileView {
            id: view

            property string name: ""

            printErrors: false

            onLoaded: {
                try {
                    const values = Settings.snapshot(JSON.parse(view.text()));
                    root.write(view.name, values);
                    root.remember(view.name, values);
                    root.status = `${view.name} updated.`;
                } catch (error) {
                    root.status = `${view.name} is not readable JSON.`;
                }
                view.destroy(2000);
            }

            onLoadFailed: {
                root.status = `${view.name} could not be read.`;
                view.destroy(2000);
            }
        }
    }

    /// Reads a preset so its row can say whether it is what you have. One
    /// reader per file, for the same reason updating has one: a rescan sets
    /// several going at once, and a single re-pointed FileView would keep only
    /// the last of them.
    Component {
        id: peek

        FileView {
            id: view

            property string name: ""

            printErrors: false

            onLoaded: {
                let held = null;
                try {
                    held = JSON.parse(view.text());
                } catch (error) {
                    held = null; // hand-edited into nonsense: never "current"
                }
                root.remember(view.name, held);
                view.destroy(2000);
            }

            onLoadFailed: view.destroy(2000)
        }
    }

    Component {
        id: pen

        FileView {
            atomicWrites: true
            printErrors: false
        }
    }

    Process {
        id: eraser

        onExited: Qt.callLater(root.rescan)
    }

    /// The text goes on the command line rather than through stdin: `wl-copy`
    /// takes it as literal argv either way, and a real argument needs no pipe
    /// to close before the clipboard is holding anything.
    Process {
        id: copier
    }

    Process {
        id: paster

        command: ["wl-paste", "-n"]

        stdout: StdioCollector {
            id: pasted

            waitForEnd: true
            onStreamFinished: root.handlePaste(pasted.text)
        }
    }

    /// The directory has to be there before the model looks at it. `setText`
    /// makes it when a preset is saved, but the list is drawn long before that.
    Process {
        id: maker

        command: ["mkdir", "-p", root.directory]
        running: true

        onExited: root.rescan()
    }

    Component.onCompleted: root.refresh()
}
