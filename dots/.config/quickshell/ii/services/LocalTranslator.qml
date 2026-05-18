pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.utils

Singleton {
    id: root

    readonly property var languageRegistry: [
        { name: "English",               tess: "eng",     argos: "en" },
        { name: "Japanese",              tess: "jpn",     argos: "ja" },
        { name: "Korean",                tess: "kor",     argos: "ko" },
        { name: "Chinese (Simplified)",  tess: "chi_sim", argos: "zh" },
        { name: "Chinese (Traditional)", tess: "chi_tra", argos: "zt" },
        { name: "Russian",               tess: "rus",     argos: "ru" },
        { name: "Spanish",               tess: "spa",     argos: "es" },
        { name: "French",                tess: "fra",     argos: "fr" },
        { name: "German",                tess: "deu",     argos: "de" },
        { name: "Italian",               tess: "ita",     argos: "it" },
        { name: "Portuguese",            tess: "por",     argos: "pt" },
        { name: "Arabic",                tess: "ara",     argos: "ar" },
        { name: "Hindi",                 tess: "hin",     argos: "hi" },
        { name: "Turkish",               tess: "tur",     argos: "tr" },
        { name: "Vietnamese",            tess: "vie",     argos: "vi" },
        { name: "Thai",                  tess: "tha",     argos: "th" },
        { name: "Polish",                tess: "pol",     argos: "pl" },
        { name: "Ukrainian",             tess: "ukr",     argos: "uk" },
        { name: "Dutch",                 tess: "nld",     argos: "nl" },
        { name: "Swedish",               tess: "swe",     argos: "sv" },
        { name: "Finnish",               tess: "fin",     argos: "fi" },
        { name: "Norwegian",             tess: "nor",     argos: "nb" },
        { name: "Danish",                tess: "dan",     argos: "da" },
        { name: "Czech",                 tess: "ces",     argos: "cs" },
        { name: "Greek",                 tess: "ell",     argos: "el" },
        { name: "Hebrew",                tess: "heb",     argos: "he" },
        { name: "Indonesian",            tess: "ind",     argos: "id" },
        { name: "Hungarian",             tess: "hun",     argos: "hu" },
        { name: "Romanian",              tess: "ron",     argos: "ro" },
        { name: "Bulgarian",             tess: "bul",     argos: "bg" }
    ]

    readonly property string scriptDir: Quickshell.shellPath("scripts/local-translator")

    property var status: ({})

    property bool initialised: false

    property var installedTesseractCodes: []

    function initOnce(): void {
        if (root.initialised) return;
        root.initialised = true;
        initProc.runSequence([
            ["bash", "-c", `'${root.scriptDir}/tessdata-init.sh'`],
            (_) => { root.refreshStatus(); }
        ]);
    }

    function refreshStatus(): void {
        var tessOut = null;
        var argosOut = null;

        function maybeFinalize() {
            if (tessOut === null || argosOut === null) return;
            root._rebuildStatus(tessOut, argosOut);
        }

        tessProc.runSequence([
            ["bash", "-c", `'${root.scriptDir}/tesseract-list.sh'`],
            (out) => { tessOut = out; maybeFinalize(); return out; }
        ]);
        argosProc.runSequence([
            ["bash", "-c", `'${root.scriptDir}/argos-list-venv.sh'`],
            (out) => { argosOut = out; maybeFinalize(); return out; }
        ]);
    }

    function _rebuildStatus(tessJson: string, argosJson: string): void {
        var tess, argos;
        try { tess = JSON.parse(tessJson); } catch (e) { tess = { system: [], user: [] }; }
        try { argos = JSON.parse(argosJson); } catch (e) { argos = []; }

        const targetLang = Config.options.screenTranslator.targetLanguage || Translation.languageCode;
        const target2 = (targetLang || "").split(/[-_]/)[0];

        const sysSet = new Set(tess.system);
        const userSet = new Set(tess.user);
        const argosPairs = new Set(argos.map(p => p.from + "->" + p.to));

        const newStatus = {};
        const installedCodes = [];

        for (const entry of root.languageRegistry) {
            const tcode = entry.tess;
            const acode = entry.argos;
            const prev = root.status[tcode] || {};

            let tessState = "missing";
            if (userSet.has(tcode)) tessState = "user";
            else if (sysSet.has(tcode)) tessState = "system";
            if (tessState === "missing" && sysSet.has(tcode)) tessState = "system";

            const reachable = userSet.has(tcode) || sysSet.has(tcode);
            if (reachable) installedCodes.push(tcode);

            let argosState = "missing";
            if (!target2 || acode === target2) {
                argosState = "n/a";
            } else if (argosPairs.has(acode + "->" + target2)) {
                argosState = "user";
            } else if (argosPairs.has(acode + "->en") && argosPairs.has("en->" + target2)) {
                argosState = "user";
            }

            newStatus[tcode] = {
                tesseract: tessState,
                argos: argosState,
                busy: prev.busy || false,
                error: ""
            };
        }

        root.status = newStatus;
        root.installedTesseractCodes = installedCodes;
    }

    function rowState(tcode: string): string {
        const s = root.status[tcode];
        if (!s) return "missing";
        if (s.error) return "error";
        if (s.busy) return s.busy;

        const t = s.tesseract;
        const a = s.argos;

        const aOk = (a === "user" || a === "system" || a === "n/a");
        const tOk = (t === "user" || t === "system");

        if (tOk && aOk) {
            if (t === "system" && (a === "system" || a === "n/a")) return "system";
            return "installed";
        }
        if (tOk || aOk) return "partial";
        return "missing";
    }

    function installLanguage(tcode: string): void {
        const entry = root.languageRegistry.find(e => e.tess === tcode);
        if (!entry) return;
        const s = root.status[tcode];
        if (!s) return;

        s.busy = "installing";
        s.error = "";
        root.statusChanged();

        const targetLang = Config.options.screenTranslator.targetLanguage || Translation.languageCode;
        const target2 = (targetLang || "").split(/[-_]/)[0];
        const model = Config.options.screenTranslator.local.tesseractModel || "fast";

        const seq = [];

        if (s.tesseract === "missing") {
            seq.push(["bash", "-c",
                `'${root.scriptDir}/tesseract-install.sh' '${tcode}' '${model}'`
            ]);
            seq.push((_) => null);
        }

        if (entry.argos !== target2 && target2 && s.argos === "missing") {
            seq.push(["bash", "-c",
                `'${root.scriptDir}/argos-install-venv.sh' '${entry.argos}' '${target2}' || \
('${root.scriptDir}/argos-install-venv.sh' '${entry.argos}' 'en' && \
 '${root.scriptDir}/argos-install-venv.sh' 'en' '${target2}')`
            ]);
            seq.push((_) => null);
        }

        seq.push((_) => {
            s.busy = false;
            root.refreshStatus();
            notifyProc.runSequence([
                ["bash", "-c",
                    `notify-send -a 'Shell' 'Language installed' '${entry.name} is ready'`]
            ]);
        });

        installProc.runSequence(seq);
    }

    function uninstallLanguage(tcode: string): void {
        const entry = root.languageRegistry.find(e => e.tess === tcode);
        if (!entry) return;
        const s = root.status[tcode];
        if (!s) return;

        s.busy = "uninstalling";
        root.statusChanged();

        const targetLang = Config.options.screenTranslator.targetLanguage || Translation.languageCode;
        const target2 = (targetLang || "").split(/[-_]/)[0];

        const seq = [];
        seq.push(["bash", "-c",
            `'${root.scriptDir}/tesseract-uninstall.sh' '${tcode}'`
        ]);
        seq.push((_) => null);

        if (entry.argos !== target2 && target2) {
            seq.push(["bash", "-c",
                `'${root.scriptDir}/argos-uninstall-venv.sh' '${entry.argos}' '${target2}' || true; \
'${root.scriptDir}/argos-uninstall-venv.sh' '${entry.argos}' 'en' || true`
            ]);
            seq.push((_) => null);
        }

        seq.push((_) => {
            s.busy = false;
            root.refreshStatus();
        });

        uninstallProc.runSequence(seq);
    }

    onStatusChanged: {}

    Component.onCompleted: root.initOnce()

    MultiTurnProcess { id: initProc }
    MultiTurnProcess { id: tessProc }
    MultiTurnProcess { id: argosProc }
    MultiTurnProcess { id: installProc }
    MultiTurnProcess { id: uninstallProc }
    MultiTurnProcess { id: notifyProc }

    Connections {
        target: Config.options.screenTranslator
        function onTargetLanguageChanged() {
            root.refreshStatus();
        }
    }
}
