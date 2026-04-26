// Centralized keyboard handler shared by the attached PanelWindow and the
// detached FloatingWindow. `content` is a LauncherContent instance exposing
// vimium/selection/settings state; `options` carries window-specific hooks:
//   onEscapeDismissIfIdle: close the attached window when Escape is pressed
//                          and no modal state is active (omitted in detached).
//   onToggleDetach:        toggle detach on Ctrl+D.
//   onToggleHelp:          toggle the help overlay on Ctrl+/.

function handleKey(event, content, options) {
    options = options || {}
    const inSettings = content.inSettings

    if (event.key === Qt.Key_Escape) {
        _handleEscape(event, content, inSettings, options)
        return
    }

    if ((event.modifiers & Qt.ControlModifier)
        && (event.key === Qt.Key_Slash || event.text === "/")) {
        if (options.onToggleHelp) options.onToggleHelp()
        event.accepted = true
        return
    }

    if (event.key === Qt.Key_F && !event.modifiers) {
        if (!content.canActivateVimium) return
        if (_activateVimium(event, content, inSettings)) return
        // Vimium already active in this mode — fall through so F is
        // consumed as a hint character by the typing handler below.
    }

    if (content.isFolderOpen && content.folderVimiumActive) {
        _handleTyping(event, content, "folderVimiumTyped")
        return
    }
    if (!inSettings && content.vimiumActive) {
        _handleTyping(event, content, "vimiumTyped")
        return
    }
    if (inSettings && content.settingsVimiumActive) {
        _handleTyping(event, content, "settingsVimiumTyped")
        return
    }

    if (event.modifiers === Qt.ControlModifier) {
        if (event.key === Qt.Key_D && options.onToggleDetach) {
            options.onToggleDetach()
        }
        event.accepted = true
    }
}

function _handleEscape(event, content, inSettings, options) {
    if (content.helpOverlayShown) {
        content.toggleHelp()
        event.accepted = true
        return
    }
    if (content.isFolderOpen && content.folderVimiumActive) {
        content.folderVimiumActive = false
        content.folderVimiumTyped = ""
        event.accepted = true
        return
    }
    if (content.isFolderOpen && content.isFolderSelectionModeActive) {
        content.exitFolderSelectionMode()
        event.accepted = true
        return
    }
    if (!inSettings && content.vimiumActive) {
        content.vimiumActive = false
        content.vimiumTyped = ""
        event.accepted = true
        return
    }
    if (inSettings && content.settingsVimiumActive) {
        content.settingsVimiumActive = false
        content.settingsVimiumTyped = ""
        event.accepted = true
        return
    }
    if (content.selectionModeActive) {
        content.exitSelectionMode()
        event.accepted = true
        return
    }
    if (content.isFolderOpen) {
        content.closeFolder()
        event.accepted = true
        return
    }
    if (!inSettings && options.onEscapeDismissIfIdle) {
        options.onEscapeDismissIfIdle()
    }
}

// Activates the vimium mode matching the current UI state. Returns true if
// a new mode was activated and the F keypress should be consumed.
function _activateVimium(event, content, inSettings) {
    if (inSettings) {
        if (!content.settingsVimiumActive) {
            content.settingsVimiumActive = true
            content.settingsVimiumTyped = ""
            event.accepted = true
            return true
        }
    } else if (content.isFolderOpen) {
        if (!content.folderVimiumActive) {
            content.folderVimiumActive = true
            content.folderVimiumTyped = ""
            event.accepted = true
            return true
        }
    } else if (!content.vimiumActive) {
        content.vimiumActive = true
        content.vimiumTyped = ""
        event.accepted = true
        return true
    }
    return false
}

function _handleTyping(event, content, typedProp) {
    if (event.key === Qt.Key_Backspace && content[typedProp].length > 0) {
        content[typedProp] = content[typedProp].slice(0, -1)
        event.accepted = true
        return
    }
    const ch = event.text.toUpperCase()
    if (event.text.length > 0 && ch >= "A" && ch <= "Z") {
        content[typedProp] += ch
        event.accepted = true
    }
}
