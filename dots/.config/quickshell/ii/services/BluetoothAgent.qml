pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Keeps a persistent bluetoothctl pairing agent running in the background.
 *
 * Quickshell.Bluetooth does not register a BlueZ pairing agent on its own — so when
 * pairing is initiated from QML, BlueZ has no one to answer pairing/passkey
 * confirmation requests and the remote device gets a rejection (phone shows the
 * 6-digit PIN, then "wrong PIN" a couple seconds later).
 *
 * Running `bluetoothctl --agent NoInputNoOutput` registers a "Just Works" agent:
 * BlueZ auto-accepts confirmation prompts, so the user only has to confirm on the
 * remote device. This matches the behavior most Linux desktops get from
 * blueman-applet / bluedevil running their own agent.
 */
Singleton {
    id: root

    property bool running: agentProc.running

    function load() {} // touch to instantiate the singleton from shell.qml

    Process {
        id: agentProc
        running: true
        command: ["bluetoothctl", "--agent", "NoInputNoOutput"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        onExited: (exitCode, exitStatus) => {
            // Re-launch after a short delay so we keep an agent alive even if
            // bluetoothctl exits (e.g. adapter disappeared briefly).
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        repeat: false
        onTriggered: agentProc.running = true
    }
}
