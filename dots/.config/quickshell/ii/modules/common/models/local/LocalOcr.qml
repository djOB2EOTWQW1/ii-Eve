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

    readonly property string scriptPath: Quickshell.shellPath("scripts/local-translator/tesseract-ocr.sh")

    function annotateImage(imageUri: string) {
        resetState();
        root.state = TranslatorApi.State.Preparing;

        const tessdataDir = Config.options.screenTranslator.local.tesseractDataDir
            || FileUtils.trimFileProtocol(`${Directories.home}/.local/share/tessdata`);
        const codes = LocalTranslator.installedTesseractCodes;

        if (!codes || codes.length === 0) {
            root.state = TranslatorApi.State.Error;
            root.errorMessage = Translation.tr("No language packs installed. Open settings → Services → Screen Translator.");
            root.error(root.errorMessage);
            return;
        }

        const langArg = codes.join("+");
        const imgPath = FileUtils.trimFileProtocol(imageUri);

        root.state = TranslatorApi.State.Processing;
        ocrProc.runSequence([
            ["bash", "-c",
                `'${StringUtils.shellSingleQuoteEscape(root.scriptPath)}' \
'${StringUtils.shellSingleQuoteEscape(imgPath)}' \
'${StringUtils.shellSingleQuoteEscape(tessdataDir)}' \
'${StringUtils.shellSingleQuoteEscape(langArg)}'`
            ],
            (out) => {
                root.handleApiOutput(out);
            }
        ]);
    }

    MultiTurnProcess {
        id: ocrProc
    }
}
