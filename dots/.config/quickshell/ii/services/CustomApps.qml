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
    property string iconCacheDir: FileUtils.trimFileProtocol(`${Directories.cache}/customApps/icons`)
    property string exeIconScript: FileUtils.trimFileProtocol(`${Directories.scriptPath}/icons/extract-exe-icon-venv.sh`)
    property alias entries: customAppsAdapter.entries
    property alias dirs: customAppsAdapter.dirs
    property alias folders: customAppsAdapter.folders
    property bool ready: false

    property bool winePresent: false
    property bool portprotonPresent: false

    readonly property var binaryExtensions: [
        "appimage", "exe", "sh", "bash", "zsh", "fish",
        "bin", "run", "py", "pl", "rb", "lua", "js",
        "x86_64", "x86_32", "x86", "arm64", "aarch64",
        "love", "jar"
    ]

    readonly property var binaryDirPrefixes: [
        "/usr/bin/", "/usr/local/bin/", "/usr/sbin/",
        "/bin/", "/sbin/", "/opt/"
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

    Process {
        running: true
        command: ["mkdir", "-p", root.iconCacheDir]
    }

    property var _iconQueue: []
    property var _currentIconTask: null

    Process {
        id: iconExtractor
        stdout: StdioCollector {
            id: iconExtractorOut
        }
        onExited: (exitCode, exitStatus) => {
            const task = root._currentIconTask
            root._currentIconTask = null
            if (task && exitCode === 0) {
                root._applyExtractedIcon(task.targetPath || task.exePath, task.outPath)
            }
            root._processIconQueue()
        }
    }

    property var _siblingQueue: []
    property var _currentSiblingTask: null

    Process {
        id: siblingExeFinder
        stdout: StdioCollector {
            id: siblingExeFinderOut
        }
        onExited: (exitCode, exitStatus) => {
            const task = root._currentSiblingTask
            root._currentSiblingTask = null
            if (task && exitCode === 0) {
                const found = String(siblingExeFinderOut.text || "").trim()
                if (found.length > 0) {
                    root._enqueueExeIcon(found, root._exeIconCachePath(found), task.scriptPath)
                }
            }
            root._processSiblingQueue()
        }
    }

    function _hashPath(path) {
        let h = 5381
        const s = String(path)
        for (let i = 0; i < s.length; i++) {
            h = ((h << 5) + h + s.charCodeAt(i)) | 0
        }
        return (h >>> 0).toString(16)
    }

    function _exeIconCachePath(exePath) {
        return `${root.iconCacheDir}/${root._hashPath(exePath)}.png`
    }

    function _processIconQueue() {
        if (root._currentIconTask) return
        if (root._iconQueue.length === 0) return
        const task = root._iconQueue.shift()
        root._currentIconTask = task
        iconExtractor.command = ["bash", root.exeIconScript, task.exePath, task.outPath]
        iconExtractor.running = true
    }

    function _enqueueExeIcon(exePath, outPath, targetPath) {
        root._iconQueue.push({
            exePath: exePath,
            outPath: outPath,
            targetPath: targetPath || exePath
        })
        root._processIconQueue()
    }

    function _applyExtractedIcon(targetPath, iconPath) {
        const idx = root.indexOfPath(targetPath)
        if (idx < 0) return
        const next = Array.from(root.entries)
        const updated = Object.assign({}, next[idx])
        updated.icon = iconPath
        next[idx] = updated
        customAppsAdapter.entries = next
        root.changed()
    }

    function _processSiblingQueue() {
        if (root._currentSiblingTask) return
        if (root._siblingQueue.length === 0) return
        const task = root._siblingQueue.shift()
        root._currentSiblingTask = task
        // Prefer a same-stem .exe, otherwise any .exe in the same directory.
        const script = 'p="$1"; d="$(dirname "$p")"; b="$(basename "$p")"; s="${b%.*}";' +
            ' if [ -f "$d/$s.exe" ]; then printf %s "$d/$s.exe"; exit 0; fi;' +
            ' find "$d" -maxdepth 1 -type f -iname "*.exe" 2>/dev/null | head -n1'
        siblingExeFinder.command = ["bash", "-c", script, "_", task.scriptPath]
        siblingExeFinder.running = true
    }

    function _enqueueSiblingExeLookup(scriptPath) {
        root._siblingQueue.push({ scriptPath: scriptPath })
        root._processSiblingQueue()
    }

    function _upgradeExeIcons() {
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i]
            if (!e || !e.path) continue
            if (!String(e.path).toLowerCase().endsWith('.exe')) continue
            if (e.icon && String(e.icon).startsWith('/')) continue
            root._enqueueExeIcon(e.path, root._exeIconCachePath(e.path))
        }
    }

    function _upgradeScriptIcons() {
        const next = Array.from(root.entries)
        let changed = false
        for (let i = 0; i < next.length; i++) {
            const e = next[i]
            if (!e || !e.path) continue
            if (String(e.path).toLowerCase().endsWith('.exe')) continue
            if (e.icon && String(e.icon).startsWith('/')) continue
            // Re-evaluate with the new conservative logic. Old fuzzy-match
            // garbage gets overwritten; legitimate icon names stay.
            const conservative = root.guessIconFor(e.path)
            if (e.icon !== conservative) {
                const updated = Object.assign({}, e)
                updated.icon = conservative
                next[i] = updated
                changed = true
            }
            if (conservative === "application-x-executable") {
                root._enqueueSiblingExeLookup(e.path)
            }
        }
        if (changed) {
            customAppsAdapter.entries = next
            root.changed()
        }
    }

    onReadyChanged: if (root.ready) {
        root._upgradeExeIcons()
        root._upgradeScriptIcons()
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
        const s = String(path)
        const basename = s.split('/').pop()
        if (basename.length === 0) return false
        const dot = basename.lastIndexOf('.')
        if (dot === 0) return false
        if (dot < 0) {
            for (let i = 0; i < root.binaryDirPrefixes.length; i++) {
                if (s.startsWith(root.binaryDirPrefixes[i])) return true
            }
            return false
        }
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
        const _dot = basename.lastIndexOf('.')
        const name = (_dot > 0) ? basename.substring(0, _dot) : basename
        const icon = root.guessIconFor(path)

        const next = Array.from(root.entries)
        next.push({ name: name, path: path, icon: icon })
        customAppsAdapter.entries = next
        root.changed()

        if (path.toLowerCase().endsWith('.exe')) {
            root._enqueueExeIcon(path, root._exeIconCachePath(path))
        } else if (icon === "application-x-executable") {
            root._enqueueSiblingExeLookup(path)
        }
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

        const nextFolders = Array.from(root.folders)
        for (let i = 0; i < nextFolders.length; i++) {
            const f = Object.assign({}, nextFolders[i])
            const appIndices = Array.from(f.appIndices || [])
            const patched = []
            for (let j = 0; j < appIndices.length; j++) {
                const v = appIndices[j]
                if (v === index) continue
                patched.push(v > index ? v - 1 : v)
            }
            f.appIndices = patched
            nextFolders[i] = f
        }
        customAppsAdapter.folders = nextFolders

        root.changed()
        return true
    }

    function _folderIndexOfId(id) {
        for (let i = 0; i < root.folders.length; i++) {
            if (root.folders[i].id === id) return i
        }
        return -1
    }

    function folderById(id) {
        const i = root._folderIndexOfId(id)
        return i >= 0 ? root.folders[i] : null
    }

    function createFolder(name) {
        const trimmed = String(name || "").trim()
        if (trimmed.length === 0) return ""
        const id = "folder_" + Date.now() + "_" + Math.floor(Math.random() * 10000)
        const next = Array.from(root.folders)
        next.push({ id: id, name: trimmed, icon: "folder", appIndices: [] })
        customAppsAdapter.folders = next
        root.changed()
        return id
    }

    function createDefaultFolder() {
        const base = "New folder"
        let name = base
        let counter = 1
        while (true) {
            let exists = false
            for (let i = 0; i < root.folders.length; i++) {
                if (root.folders[i].name === name) { exists = true; break }
            }
            if (!exists) break
            name = base + "(" + counter + ")"
            counter++
        }
        return root.createFolder(name)
    }

    function removeFolderAt(index) {
        if (index < 0 || index >= root.folders.length) return false
        const next = Array.from(root.folders)
        next.splice(index, 1)
        customAppsAdapter.folders = next
        root.changed()
        return true
    }

    function renameFolder(folderId, newName) {
        const fi = root._folderIndexOfId(folderId)
        if (fi < 0) return false
        const trimmed = String(newName || "").trim()
        if (trimmed.length === 0) return false
        const next = Array.from(root.folders)
        const f = Object.assign({}, next[fi])
        f.name = trimmed
        next[fi] = f
        customAppsAdapter.folders = next
        root.changed()
        return true
    }

    function renameAppAt(index, newName) {
        if (index < 0 || index >= root.entries.length) return false
        const trimmed = String(newName || "").trim()
        if (trimmed.length === 0) return false
        const next = Array.from(root.entries)
        const e = Object.assign({}, next[index])
        e.name = trimmed
        next[index] = e
        customAppsAdapter.entries = next
        root.changed()
        return true
    }

    function addAppToFolder(folderId, entryIndex) {
        if (entryIndex < 0 || entryIndex >= root.entries.length) return false
        const next = Array.from(root.folders)
        let changed = false
        for (let i = 0; i < next.length; i++) {
            const f = Object.assign({}, next[i])
            const appIndices = Array.from(f.appIndices || [])
            const pos = appIndices.indexOf(entryIndex)
            if (f.id === folderId) {
                if (pos < 0) {
                    appIndices.push(entryIndex)
                    changed = true
                }
            } else if (pos >= 0) {
                appIndices.splice(pos, 1)
                changed = true
            }
            f.appIndices = appIndices
            next[i] = f
        }
        if (!changed) return false
        customAppsAdapter.folders = next
        root.changed()
        return true
    }

    function removeAppFromFolder(folderId, entryIndex) {
        const fi = root._folderIndexOfId(folderId)
        if (fi < 0) return false
        const next = Array.from(root.folders)
        const f = Object.assign({}, next[fi])
        const appIndices = Array.from(f.appIndices || [])
        const pos = appIndices.indexOf(entryIndex)
        if (pos < 0) return false
        appIndices.splice(pos, 1)
        f.appIndices = appIndices
        next[fi] = f
        customAppsAdapter.folders = next
        root.changed()
        return true
    }

    function _isEntryInAnyFolder(entryIndex) {
        for (let i = 0; i < root.folders.length; i++) {
            const appIndices = root.folders[i].appIndices || []
            for (let j = 0; j < appIndices.length; j++) {
                if (appIndices[j] === entryIndex) return true
            }
        }
        return false
    }

    function rootEntriesList() {
        const out = []
        for (let i = 0; i < root.entries.length; i++) {
            if (root._isEntryInAnyFolder(i)) continue
            const e = root.entries[i]
            out.push({
                name: e.name,
                path: e.path,
                icon: e.icon,
                _originalIndex: i,
                _isFolder: false
            })
        }
        return out
    }

    readonly property var rootEntries: {
        root.entries
        root.folders
        return rootEntriesList()
    }

    function appsInFolder(folderId) {
        const fi = root._folderIndexOfId(folderId)
        if (fi < 0) return []
        const appIndices = root.folders[fi].appIndices || []
        const out = []
        for (let i = 0; i < appIndices.length; i++) {
            const idx = appIndices[i]
            if (idx < 0 || idx >= root.entries.length) continue
            const e = root.entries[idx]
            out.push({
                name: e.name,
                path: e.path,
                icon: e.icon,
                _originalIndex: idx,
                _isFolder: false
            })
        }
        return out
    }

    function folderPreviewIcons(folder, maxCount) {
        if (!folder) return []
        const indices = folder.appIndices || []
        const out = []
        const limit = Math.min(maxCount ?? 4, indices.length)
        for (let i = 0; i < limit; i++) {
            const idx = indices[i]
            if (idx < 0 || idx >= root.entries.length) continue
            out.push(root.entries[idx].icon || "")
        }
        return out
    }

    function guessIconFor(path) {
        const basename = path.split('/').pop()
        const _d = basename.lastIndexOf('.')
        const stem = (_d > 0) ? basename.substring(0, _d) : basename
        if (basename.toLowerCase().endsWith('.exe')) {
            if (AppSearch.iconExists(stem)) return stem
            const lower = stem.toLowerCase()
            if (AppSearch.iconExists(lower)) return lower
            return "wine"
        }
        // For scripts/native binaries we intentionally skip fuzzy matching —
        // it produces unrelated system icons for arbitrary script names.
        // A sibling .exe lookup will replace this with a real icon if possible.
        const entry = DesktopEntries.byId(stem)
        if (entry) return entry.icon
        if (AppSearch.iconExists(stem)) return stem
        const lower = stem.toLowerCase()
        if (AppSearch.iconExists(lower)) return lower
        const kebab = lower.replace(/\s+/g, "-")
        if (AppSearch.iconExists(kebab)) return kebab
        return "application-x-executable"
    }

    function shellQuote(s) {
        return `'${String(s).replace(/'/g, `'\\''`)}'`
    }

    function launch(entry) {
        if (!entry || !entry.path) return
        const useDGpu = entry.gpu === "dGPU" && GpuInfo.hybrid
        const envList = useDGpu ? GpuInfo.dGpuEnv : []
        const envPrefix = envList.length > 0 ? ["env", ...envList] : []

        const path = entry.path
        const lower = path.toLowerCase()

        if (lower.endsWith('.exe')) {
            if (root.portprotonPresent) {
                Quickshell.execDetached({ command: [...envPrefix, "portproton", "--launch", path] })
                return
            }
            if (root.winePresent) {
                Quickshell.execDetached({ command: [...envPrefix, "wine", path] })
                return
            }
            console.warn("[CustomApps] cannot launch .exe: neither portproton nor wine is installed:", path)
            return
        }

        // Native binary / .AppImage / script — ensure +x, then exec directly
        Quickshell.execDetached({
            command: [...envPrefix, "bash", "-c", `chmod +x ${root.shellQuote(path)} 2>/dev/null; exec ${root.shellQuote(path)}`]
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
            property list<var> folders: []
        }
    }
}
