pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property int monitorIndex 
    required property var panelWindow

    readonly property bool hyprscrollingEnabled: true //FIXME
    readonly property list<int> workspaceMap: Config.options.overview.workspaceMap
    readonly property string backgroundStyle: Config.options.overview.scrollingStyle.backgroundStyle

    property int workspaceOffset: root.extendWorkspaceMap(workspaceMap)[root.monitorIndex]

    property int windowRounding: Appearance.rounding.normal 
    readonly property int rows: 10 
    readonly property int columns: 1
    readonly property int workspacesShown: root.rows * root.columns

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - workspaceOffset - 1) / workspacesShown)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)

    property real normalWindowOffset: root.hyprscrollingEnabled ? 0 : root.workspaceImplicitWidth / 2 // if someone uses default layout with this scrolling overview, we have to add this offset to center the windows
    
    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ? 
        ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scaleRatio / monitor.scale) :
        ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scaleRatio / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? 
        ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scaleRatio / monitor.scale) :
        ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scaleRatio / monitor.scale)

    implicitWidth: monitor.width 
    implicitHeight: monitor.height
    
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 10

    property int dragDropType: -1 // 0: workspace, 1: window
    
    property string draggingFromWindowAddress
    property string draggingTargetWindowAdress
    property string draggingDirection  // options: 'l' or 'r' // only for window dragging

    property bool draggingWindowsFloating
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    property var activeWindowData
    property var activeWindow: windows.find(w =>
        w.focusHistoryID === 0 &&
        w.workspace?.id === monitor.activeWorkspace?.id &&
        w.monitor === monitor.id
    )

    property real scaleRatio: Config.options.overview.scale * 1.25 // 1.25 to make it almost same size as classic overview
    
    property int currentWorkspace: monitor.activeWorkspace?.id - root.workspaceOffset
    property var focusedXPerWorkspace: []
    property var lastFocusedPerWorkspace: []

    property int scrollWorkspace: 0 // y scrolling workspace
    property int scrollWindow: 0 // for x scrolling
    property real scrollY: 0
    property real scrollX: 0

    onCurrentWorkspaceChanged: updateScrollProps()
    onScrollWorkspaceChanged: scrollY = (scrollWorkspace - 1) * workspaceImplicitHeight
    onScrollWindowChanged: scrollX = scrollWindow * workspaceImplicitWidth

    Component.onCompleted: {
        // console.log("monitorIndex:", monitorIndex, "workspaceMap:", workspaceMap, "workspaceOffset:", workspaceOffset)
        updateScrollProps()
        HyprlandData.windowListChanged()
    }

    // We extend the workspaceMap to have at least 10 workspaces
    function extendWorkspaceMap(map) {
        let arr = map.slice()
        const step = arr[arr.length - 1] - arr[arr.length - 2]
        while (arr.length < 10) {
            arr.push(arr[arr.length - 1] + step)
        }
        return arr
    }

    // Helper functions
    function updateScrollProps() {
        scrollWorkspace = currentWorkspace - 1
        scrollY = (scrollWorkspace - 1) * workspaceImplicitHeight
    }

    function getWsRow(ws) {
        var wsAdjusted = ws - root.workspaceOffset
        var normalRow = Math.floor((wsAdjusted - 1) / root.columns) % root.rows;
        return (Config.options.overview.orderBottomUp ? root.rows - normalRow - 1 : normalRow);
    }

    function getWsColumn(ws) {
        var wsAdjusted = ws - root.workspaceOffset
        var normalCol = (wsAdjusted - 1) % root.columns;
        return (Config.options.overview.orderRightLeft ? root.columns - normalCol - 1 : normalCol);
    }

    function getWsInCell(ri, ci) {
        var wsInCell = (Config.options.overview.orderBottomUp ? root.rows - ri - 1 : ri) 
                    * root.columns 
                    + (Config.options.overview.orderRightLeft ? root.columns - ci - 1 : ci) 
                    + 1
        return wsInCell + root.workspaceOffset
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onWheel: function(wheel) {
            const shiftPressed = wheel.modifiers & Qt.ShiftModifier
            
            
            if (shiftPressed && wheel.angleDelta.y > 0) {
                if (root.scrollWindow > 2) return
                root.scrollWindow += 1
            } else if (shiftPressed && wheel.angleDelta.y < 0) {
                if (root.scrollWindow < -2) return
                root.scrollWindow -= 1
            } else {
                if (wheel.angleDelta.y > 0) {
                    if (root.scrollWorkspace === 0) return
                    root.scrollWorkspace -= 1
                } else {
                    if (root.scrollWorkspace === root.workspacesShown - 1) return
                    root.scrollWorkspace += 1
                }
            }
        }
        onClicked: {
            GlobalStates.overviewOpen = false;
        }
    }

    onWindowsChanged: {
        lastFocusedPerWorkspace = []; focusedXPerWorkspace = [];
        
        const startWs = root.workspaceOffset + 1; // maybe we have to fix this
        const endWs = root.workspaceOffset + 10;

        for (var ws = startWs; ws <= endWs; ws++) {
            var windowsInWS = root.windows.filter(function(w) {
                return w.workspace.id === ws && w.monitor === root.monitor.id;
            });

            if (windowsInWS.length === 0) {
                lastFocusedPerWorkspace.push(null);
                focusedXPerWorkspace.push(null);
            } else {
                var lastFocused = windowsInWS.reduce(function(a, b) {
                    return (a.focusHistoryID < b.focusHistoryID) ? a : b;
                });
                lastFocusedPerWorkspace.push(lastFocused);
                
                var monitorX = (root.monitor?.x ?? 0);
                var monitorReservedX = (root.monitorData?.reserved?.[0] ?? 0);
                var localX = (lastFocused.at[0] - monitorX - monitorReservedX) * root.scaleRatio;
                
                focusedXPerWorkspace.push(localX);
            }
        }
    }


    Item {
        id: windowContainer
        anchors.centerIn: parent

        property var targetPositions: {
            let pos = [];
            let currentX = 0;
            let spacing = 120 * root.scaleRatio;
            const vals = windowScriptModel.values;
            if (!vals) return [];
            
            const activeAddr = root.activeWindow?.address;
            let activeIdx = -1;
            
            for (let i = 0; i < vals.length; i++) {
                const win = windowByAddress[vals[i]];
                if (!win) { pos.push(currentX); continue; }
                const w = win.size[0] * root.scaleRatio;
                pos.push(currentX + w / 2);
                currentX += w + spacing;
                if (vals[i] === activeAddr) activeIdx = i;
            }
            
            const shiftX = (activeIdx !== -1) ? pos[activeIdx] : (currentX - spacing) / 2;
            return pos.map(p => p - shiftX);
        }

        ScriptModel {
            id: windowScriptModel
            values: {
                return ToplevelManager.toplevels.values
                    .filter((toplevel) => {
                        const address = `0x${toplevel.HyprlandToplevel?.address}`
                        const win = windowByAddress[address]
                        return win && win.workspace?.id === monitor.activeWorkspace?.id
                    })
                    .sort((a, b) => {
                        const wa = windowByAddress[`0x${a.HyprlandToplevel.address}`]
                        const wb = windowByAddress[`0x${b.HyprlandToplevel.address}`]
                        return wa.at[0] - wb.at[0] 
                    })
                    .map(t => `0x${t.HyprlandToplevel.address}`)
            }
        }

        Repeater { 
            id: windowRepeater
            model: windowScriptModel
            delegate: Item {
                id: windowDelegate
                required property string modelData
                required property int index

                property string address: modelData
                property var toplevel: {
                    const allToplevels = ToplevelManager.toplevels.values;
                    for (let i = 0; i < allToplevels.length; i++) {
                        if (`0x${allToplevels[i].HyprlandToplevel.address}` === address) return allToplevels[i];
                    }
                    return null;
                }
                property var windowData: windowByAddress[address]
                
                readonly property bool isActive: address === root.activeWindow?.address

                // State control for animation
                property bool initialized: false
                Component.onCompleted: Qt.callLater(() => initialized = true)
                readonly property bool showOverview: GlobalStates.overviewOpen && initialized

                property int animDuration: 500

                // Target state (Overview)
                readonly property real targetWidth: (windowData?.size[0] ?? 0) * root.scaleRatio
                readonly property real targetHeight: (windowData?.size[1] ?? 0) * root.scaleRatio
                readonly property real overviewX: (windowContainer.targetPositions[index] ?? 0) - targetWidth / 2
                readonly property real overviewY: -targetHeight / 2

                // Entry state (Real screen position relative to center)
                readonly property real entryX: ((windowData?.at[0] ?? 0) - monitor.x) - monitor.width / 2
                readonly property real entryY: ((windowData?.at[1] ?? 0) - monitor.y) - monitor.height / 2

                width: showOverview ? targetWidth : (windowData?.size[0] ?? 0)
                height: showOverview ? targetHeight : (windowData?.size[1] ?? 0)
                x: showOverview ? overviewX : entryX
                y: showOverview ? overviewY : entryY

                Behavior on x { NumberAnimation { duration: animDuration; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: animDuration; easing.type: Easing.OutQuint } }
                Behavior on width { NumberAnimation { duration: animDuration; easing.type: Easing.OutQuint } }
                Behavior on height { NumberAnimation { duration: animDuration; easing.type: Easing.OutQuint } }

                ScreencopyView {
                    id: preview
                    anchors.fill: parent
                    captureSource: windowDelegate.toplevel
                    live: true
                    
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: preview.width
                            height: preview.height
                            radius: root.windowRounding * 0.8
                        }
                    }

                    Rectangle { 
                        z: -1
                        anchors.fill: parent
                        color: Appearance.colors.colLayer2
                        radius: root.windowRounding * 0.8
                        opacity: 0.5
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: root.windowRounding * 0.8
                    border.width: isActive ? 2 : 1
                    border.color: isActive ? Appearance.colors.colSecondary : ColorUtils.transparentize(Appearance.colors.colOutline, 0.3)
                    
                    Behavior on border.width { NumberAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                }

                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true
                    color: Qt.rgba(0,0,0,0.4)
                    radius: isActive ? 20 : 6
                    samples: 16
                    verticalOffset: isActive ? 8 : 2
                }
            }
        }
    }

    /* Rectangle { // Background
        id: overviewBackground
        anchors.fill: parent
        color: "transparent"
        property bool overviewOpen: GlobalStates.overviewOpen
        Component.onCompleted: {
            //? Blur is not actually a blur, it gets automatically applied when we set an item's opacity to >= 0.8
            const opacity = backgroundStyle == "dim" ? Config.options.overview.scrollingStyle.dimPercentage / 100 : backgroundStyle == "blur" ? 0.8 : 0
            color = Qt.rgba(0,0,0,opacity)
        }
        onOverviewOpenChanged: {
            if (overviewOpen) return
            color = "transparent"
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        StyledFlickable {
            id: windowSpace
            anchors.horizontalCenter: parent.horizontalCenter
            contentWidth: parent.implicitWidth
            contentHeight: parent.implicitHeight
            contentY: root.scrollY
            //contentX: root.scrollX

            Repeater {
                model: root.workspacesShown
                delegate: Rectangle {
                    required property int index
                    property int wsId: index + 1 + root.workspaceOffset
                    property int rowIndex: getWsRow(wsId)
                    property int colIndex: getWsColumn(wsId)
                    property bool hovering: false
                    property bool isScrolledWorkspace: wsId - 1 === root.scrollWorkspace + root.workspaceOffset
                    anchors.horizontalCenter: parent.horizontalCenter

                    y: (root.workspaceImplicitHeight + root.workspaceSpacing) * rowIndex - 3
                    implicitWidth: isScrolledWorkspace ? root.workspaceImplicitWidth * 1.5 : root.workspaceImplicitWidth
                    implicitHeight: root.workspaceImplicitHeight
                    color: hovering ? ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 0.7) : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.5)
                    radius: root.windowRounding

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                    Behavior on implicitWidth {
                        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
                    }

                    StyledText {
                        text: wsId
                        anchors.centerIn: parent
                        font.pixelSize: 64
                        color: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer,0.5)
                        
                        // text flashes over windowses for a split second if we dont put this animation
                        opacity: 0.0  
                        Component.onCompleted: opacity = 1
                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                    
                    DropArea { // Workspace drop
                        anchors.fill: parent
                        onEntered: {
                            root.dragDropType = 0
                            root.draggingTargetWorkspace = wsId
                            hovering = true
                        }
                        onExited: {
                            root.dragDropType = -1
                            if (root.draggingTargetWorkspace == wsId) root.draggingTargetWorkspace = -1
                            hovering = false
                        }
                    }
                }
            }

            // Window repeater
            Repeater { 
                id: windowRepeater
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel?.address}`
                            const win = windowByAddress[address]
                            if (!win) return false

                            const inWorkspaceGroup =
                                (root.workspaceGroup * root.workspacesShown + root.workspaceOffset <
                                win.workspace?.id &&
                                win.workspace?.id <=
                                (root.workspaceGroup + 1) * root.workspacesShown + root.workspaceOffset)

                            return inWorkspaceGroup
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property int index
                    required property var modelData
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id == monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    windowRounding: root.windowRounding
                    toplevel: modelData
                    monitorData: this.monitor
                    scale: root.scaleRatio
                    widgetMonitor: HyprlandData.monitors.find(m => m.id == root.monitor.id) // used by overview window
                    windowData: windowByAddress[address]
                    hyprscrollingEnabled: root.hyprscrollingEnabled

                    property int wsId: windowData?.workspace?.id

                    property var wsWindowsSorted: {
                        const arr = []
                        const all = windowRepeater.model.values

                        for (let i = 0; i < all.length; i++) {
                            const t = all[i]
                            const addr = `0x${t.HyprlandToplevel.address}`
                            const w = windowByAddress[addr]

                            if (!w) continue
                            if (w.floating) continue
                            if (w.workspace?.id !== wsId) continue

                            arr.push(w)
                        }

                        arr.sort((a, b) => a.at[0] - b.at[0])
                        return arr
                    }

                    property int wsIndex: {
                        for (let i = 0; i < wsWindowsSorted.length; i++) {
                            if (wsWindowsSorted[i].address === windowData.address)
                                return i
                        }
                        return 0
                    }

                   function calculateXPos(extraOffset = 0) {
                        const arrayIndex = wsId - root.workspaceOffset - 1;
                        const focusedX = root.focusedXPerWorkspace[arrayIndex] ?? null;
                        const monitorX = root.monitor?.x || 0;
                        const reservedX = root.monitorData?.reserved?.[0] || 0;

                        if (focusedX === null) {
                            let x = xOffset + extraOffset;
                            for (let i = 0; i < wsIndex; i++) {
                                const winWidth = (wsWindowsSorted[i]?.size?.[0] || 0) * root.scaleRatio;
                                x += winWidth;
                            }
                            return x;
                        }

                        const focusedWindow = root.lastFocusedPerWorkspace[arrayIndex];
                        if (!focusedWindow) {
                            return xOffset + extraOffset;
                        }

                        const focusedWidth = (focusedWindow.size?.[0] || 0) * root.scaleRatio;
                        const workspaceCenterX = xOffset + root.workspaceImplicitWidth / 2;
                        const focusedStartX = workspaceCenterX - focusedWidth / 2;
                        const windowRealX = (windowData.at[0] - monitorX - reservedX) * root.scaleRatio;
                        const deltaX = windowRealX - focusedX;
                        return focusedStartX + deltaX + extraOffset - root.workspaceImplicitWidth / 2;
                    }

                    property bool isActiveWindow: { // we have to set root.activeWindowData here instead of component.oncompleted
                        if (window.address == root.activeWindow?.address) {
                            root.activeWindowData = {
                                x: scrollX,
                                y: scrollY,
                                width: scrollWidth,
                                height: scrollHeight
                            }
                            return true
                        }
                        return false
                    }

                    property bool isActiveWorkspace: wsId == root.scrollWorkspace + 1
                    property real extraScrollX: isActiveWorkspace ? root.scrollX : 0
                    
                    property int wsCount: wsWindowsSorted.length || 1

                    scrollWidth:  windowData.size[0] * root.scaleRatio 
                    scrollHeight: windowData.size[1] * root.scaleRatio

                    scrollX: windowData.floating ? xOffset + xWithinWorkspaceWidget : calculateXPos(extraScrollX)
                    scrollY: windowData.floating ? yOffset + yWithinWorkspaceWidget : yOffset

                    // Offset on the canvas
                    property int workspaceColIndex: getWsColumn(windowData?.workspace.id)
                    property int workspaceRowIndex: getWsRow(windowData?.workspace.id)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex - root.normalWindowOffset
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex
                    property real xWithinWorkspaceWidget: Math.max((windowData?.at[0] - (monitor?.x ?? 0) - monitorData?.reserved[0]) * root.scaleRatio, 0) - root.workspaceImplicitWidth / 2
                    property real yWithinWorkspaceWidget: Math.max((windowData?.at[1] - (monitor?.y ?? 0) - monitorData?.reserved[1]) * root.scaleRatio, 0)                    

                    property int hoveringDir: 0 // 0: none, 1: right, 2: left
                    property bool hovering: false

                    Loader { // Hover indicator (only works with hyprscrolling)
                        active: root.hyprscrollingEnabled && !root.draggingWindowsFloating
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: Rectangle {
                            anchors.verticalCenter: parent.verticalCenter            

                            x: hoveringDir == 1 ? window.width / 2 : 0
                            implicitWidth: window.hovering ? window.width / 2 : 0
                            implicitHeight: window.height

                            color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.8)
                            opacity: window.hovering ? 1 : 0
                            radius: root.windowRounding

                            Behavior on x {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                            Behavior on opacity {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                        }
                    }
                    

                    DropArea { // Window drop
                        anchors.fill:  parent 
                        onEntered: {
                            parent.hovering = true
                            root.dragDropType = 1 // window
                            root.draggingTargetWindowAdress = windowData?.address
                            root.draggingTargetWorkspace = window?.wsId
                            const localX = drag.x
                            const half = width / 2

                            if (localX < half) { // l and r for dispatch
                                root.draggingDirection = "l"
                                hoveringDir = 2
                            } else {
                                root.draggingDirection = "r"
                                hoveringDir = 1
                            }
                        }
                        onExited: {
                            parent.hovering = false
                            root.dragDropType = -1
                            if (root.draggingTargetWindowAdress == windowData?.address) root.draggingTargetWindowAdress = ""
                        }
                    }

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay 
                        repeat: false
                        running: false
                        onTriggered: {
                            if (windowData?.floating) return
                            window.x = calculateXPos()
                            window.y = yOffset
                        }
                    }

                    z: Drag.active ? root.windowDraggingZ : (root.windowZ + windowData?.floating)
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true // For hover color change
                        onExited: hovered = false // For hover color change
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = windowData?.workspace.id
                            root.draggingFromWindowAddress = windowData?.address
                            root.draggingWindowsFloating = windowData?.floating
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                            // console.log(`[OverviewWindow] Dragging window ${windowData?.address} from position (${window.x}, ${window.y})`)
                        }
                        onReleased: { // Dropping Event

                            if (root.dragDropType === 0) { // Workspace drop
                                const targetWorkspace = root.draggingTargetWorkspace
                                root.draggingFromWorkspace = -1

                                window.pressed = false
                                window.Drag.active = false
                                
                                if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                    Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${window.windowData?.address}`)
                                    updateWindowPosition.restart()
                                } else {
                                    if (!window.windowData.floating) {
                                        updateWindowPosition.restart()
                                        return
                                    }
                                    const percentageX = Math.round((window.x - xOffset) / root.workspaceImplicitWidth * 100)
                                    const percentageY = Math.round((window.y - yOffset) / root.workspaceImplicitHeight * 100)
                                    Hyprland.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${window.windowData?.address}`)
                                }
                                
                            } else if (root.dragDropType === 1) { // Window drop
                                const targetWindowAdress = root.draggingTargetWindowAdress
                                const targetWorkspace = root.draggingTargetWorkspace

                                window.pressed = false
                                window.Drag.active = false
                                
                                
                                if (targetWindowAdress !== "" && targetWindowAdress !== windowData?.address) {
                                    if (root.draggingTargetWorkspace === root.draggingFromWorkspace) { // direct same workspace swap (plugin supports)
                                        Hyprland.dispatch(`layoutmsg swapaddrdir ${targetWindowAdress} ${root.draggingDirection} ${window.windowData?.address} true`)
                                    } else { // different workspace
                                        Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${root.draggingFromWindowAddress}`)
                                        Qt.callLater(() => {
                                            Hyprland.dispatch(`layoutmsg swapaddrdir ${targetWindowAdress} ${root.draggingDirection} ${window.windowData?.address} true`)
                                        })
                                    }
                                }
                            } else {
                                
                                window.pressed = false
                                window.Drag.active = false
                            }
                            
                            Qt.callLater(() => {
                                root.draggingFromWindowAddress = "";
                                root.draggingTargetWindowAdress = "";
                                updateWindowPosition.restart();
                                HyprlandData.updateWindowList();
                            })   
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                if (!root.hyprscrollingEnabled) {
                                    Hyprland.dispatch(`focuswindow address:${windowData.address}`)
                                    GlobalStates.overviewOpen = false; 
                                    return
                                }

                                Hyprland.dispatch(`focuswindow address:${windowData.address}`)
                                GlobalStates.overviewOpen = false;
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`closewindow address:${windowData.address}`)
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${windowData?.title}${windowData?.xwayland ? "[XWayland] " : ""}`
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int rowIndex: getWsRow(monitor.activeWorkspace?.id)
                property int colIndex: getWsColumn(monitor.activeWorkspace?.id)

                z: 999

                x: root.hyprscrollingEnabled ? root.activeWindowData?.x ?? 0 : (root.workspaceImplicitWidth + workspaceSpacing) * colIndex - normalWindowOffset
                y: root.hyprscrollingEnabled ? root.activeWindowData?.y ?? 0 : (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                width: root.hyprscrollingEnabled ? root.activeWindowData?.width ?? 0 : root.workspaceImplicitWidth + 4
                height: root.hyprscrollingEnabled ? root.activeWindowData?.height ?? 0 : root.workspaceImplicitHeight

                radius: root.windowRounding
                color: "transparent"
                border.width: 2
                border.color: root.activeWindow ? Appearance.colors.colSecondary : "transparent"
                Behavior on x {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on width {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on height {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

        }
    } */
}
