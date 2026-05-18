pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.services
import ".."

TranslatorApi {
    id: root

    readonly property string scriptPath: Quickshell.shellPath("scripts/local-translator/argos-translate-venv.sh")

    property list<string> pendingStrings

    function translateStrings(strings: list<string>) {
        resetState();
        root.pendingStrings = strings;
        root.state = TranslatorApi.State.Preparing;

        const targetLang = Config.options.screenTranslator.targetLanguage || Translation.languageCode;
        const tess2argos = {};
        for (const e of LocalTranslator.languageRegistry) tess2argos[e.tess] = e.argos;
        const sources = LocalTranslator.installedTesseractCodes
            .map(t => tess2argos[t])
            .filter(c => !!c);

        const payload = {
            target: targetLang,
            strings: strings,
            sources: sources
        };

        root.state = TranslatorApi.State.Processing;
        transProc.runSequence([
            ["bash", "-c",
                `printf '%s' '${StringUtils.shellSingleQuoteEscape(JSON.stringify(payload))}' \
| '${StringUtils.shellSingleQuoteEscape(root.scriptPath)}'`
            ],
            (out) => {
                root.handleApiOutput(out);
            }
        ]);
    }

    MultiTurnProcess {
        id: transProc
    }
}
