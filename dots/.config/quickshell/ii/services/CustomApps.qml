pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Stores user-added binaries/applications (native, .AppImage, .exe, ...) in a
 * dedicated JSON file at ~/.local/state/quickshell/user/customApps.json.
 * Handles launch routing: .exe goes through portproton (preferred) or wine,
 * everything else is exec'd directly.
 */
Singleton {
    id: root

    property string filePath: Directories.customAppsPath
    property alias entries: customAppsAdapter.entries
    property alias dirs: customAppsAdapter.dirs
    property bool ready: false

    property bool winePresent: false
    property bool portprotonPresent: false

    readonly property var binaryExtensions: [
        "appimage", "exe", "sh", "bash", "zsh", "fish",
        "bin", "run", "py", "pl", "rb", "lua", "js"
    ]

    signal changed()
    signal addRejected(string reason)

    Process {
        running: true
        command: ["bash", "-c", "command -v wine"]
        onExited: (exitCode, exitStatus) => {
            root.winePresent = (exitCode === 0)
        }
    }

    Process {
        running: true
        command: ["bash", "-c", "command -v portproton"]
        onExited: (exitCode, exitStatus) => {
            root.portprotonPresent = (exitCode === 0)
        }
    }

    function indexOfPath(path) {
        const trimmed = FileUtils.trimFileProtocol(path)
        for (let i = 0; i < root.entries.length; i++) {
            if (root.entries[i].path === trimmed) return i
        }
        return -1
    }

    function isLikelyBinary(path) {
        if (!path) return false
        const basename = String(path).split('/').pop()
        if (basename.length === 0) return false
        const dot = basename.lastIndexOf('.')
        if (dot < 0) return true
        if (dot === 0) return false
        const ext = basename.substring(dot + 1).toLowerCase()
        return root.binaryExtensions.indexOf(ext) >= 0
    }

    function addApp(filePath) {
        const path = FileUtils.trimFileProtocol(filePath)
        if (!path || path.length === 0) return false
        if (root.indexOfPath(path) !== -1) return false
        if (!root.isLikelyBinary(path)) {
            console.warn("[CustomApps] rejected non-binary:", path)
            root.addRejected(path)
            return false
        }

        const basename = path.split('/').pop()
        const name = basename.replace(/\.(AppImage|appimage|exe)$/i, '')
        const icon = root.guessIconFor(path)

        const next = Array.from(root.entries)
        next.push({ name: name, path: path, icon: icon })
        customAppsAdapter.entries = next
        root.changed()
        return true
    }

    function indexOfDir(dirPath) {
        const trimmed = FileUtils.trimFileProtocol(dirPath)
        for (let i = 0; i < root.dirs.length; i++) {
            if (root.dirs[i] === trimmed) return i
        }
        return -1
    }

    function addDir(dirPath) {
        const path = FileUtils.trimFileProtocol(dirPath)
        if (!path || path.length === 0) return false
        if (root.indexOfDir(path) !== -1) return false
        const next = Array.from(root.dirs)
        next.push(path)
        customAppsAdapter.dirs = next
        return true
    }

    function removeDirAt(index) {
        if (index < 0 || index >= root.dirs.length) return false
        const next = Array.from(root.dirs)
        next.splice(index, 1)
        customAppsAdapter.dirs = next
        return true
    }

    function removeAppAt(index) {
        if (index < 0 || index >= root.entries.length) return false
        const next = Array.from(root.entries)
        next.splice(index, 1)
        customAppsAdapter.entries = next
        root.changed()
        return true
    }

    function guessIconFor(path) {
        const basename = path.split('/').pop()
        const stem = basename.replace(/\.(AppImage|appimage|exe|sh|bin|run)$/i, '')
        if (basename.toLowerCase().endsWith('.exe')) {
            if (AppSearch.iconExists(stem)) return stem
            const lower = stem.toLowerCase()
            if (AppSearch.iconExists(lower)) return lower
            return "wine"
        }
        return AppSearch.guessIcon(stem)
    }

    function shellQuote(s) {
        return `'${String(s).replace(/'/g, `'\\''`)}'`
    }

    function launch(entry) {
        if (!entry || !entry.path) return
        const path = entry.path
        const lower = path.toLowerCase()

        if (lower.endsWith('.exe')) {
            if (root.portprotonPresent) {
                Quickshell.execDetached({ command: ["portproton", "--launch", path] })
                return
            }
            if (root.winePresent) {
                Quickshell.execDetached({ command: ["wine", path] })
                return
            }
            console.warn("[CustomApps] cannot launch .exe: neither portproton nor wine is installed:", path)
            return
        }

        // Native binary / .AppImage / script — ensure +x, then exec directly
        Quickshell.execDetached({
            command: ["bash", "-c", `chmod +x ${root.shellQuote(path)} 2>/dev/null; exec ${root.shellQuote(path)}`]
        })
    }

    Timer { id: writeTimer; interval: 100; repeat: false; onTriggered: fileView.writeAdapter() }
    Timer { id: reloadTimer; interval: 100; repeat: false; onTriggered: fileView.reload() }

    FileView {
        id: fileView
        path: root.filePath
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) writeTimer.restart()
        }

        adapter: JsonAdapter {
            id: customAppsAdapter
            property list<var> entries: []
            property list<string> dirs: []
        }
    }
}
