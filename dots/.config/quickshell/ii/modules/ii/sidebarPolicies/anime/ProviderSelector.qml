import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    implicitWidth: providerContentLayout.implicitWidth
    implicitHeight: providerContentLayout.implicitHeight
    anchors.horizontalCenter: parent.horizontalCenter

    ColumnLayout {
        id: providerContentLayout
        width: 330
        anchors.horizontalCenter: parent.horizontalCenter

        StyledComboBox {
            id: booruProviderSelector
            width: parent.width

            buttonIcon: "image_search"
            textRole: "title"
            model: [
                { title: "yande.re",   icon: "image",         value: "yandere" },
                { title: "Konachan",   icon: "wallpaper",     value: "konachan" },
                { title: "Zerochan",   icon: "child_care",    value: "zerochan" },
                { title: "Danbooru",   icon: "photo_library", value: "danbooru" },
                { title: "Gelbooru",   icon: "collections",   value: "gelbooru" },
                { title: "waifu.im",   icon: "favorite",      value: "waifu.im" },
                { title: "Alcy",       icon: "landscape",     value: "t.alcy.cc" }
            ]
            enabled: true

            currentIndex: {
                const providers = booruProviderSelector.model;
                for (var i = 0; i < providers.length; i++) {
                    if (providers[i].value === Booru.currentProvider) {
                        return i;
                    }
                }
                return 0;
            }

            onActivated: index => {
                Persistent.states.booru.provider = booruProviderSelector.model[index].value
            }
        }
    }
}
