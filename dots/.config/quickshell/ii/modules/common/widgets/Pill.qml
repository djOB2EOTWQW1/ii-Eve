import QtQuick
import qs.modules.common

Rectangle {
    // small tweak for no rounding mode
    radius: Config.options.appearance.noRoundingMode ? 0 : Math.min(width, height) / 2
}