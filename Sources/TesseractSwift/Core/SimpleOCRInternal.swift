import Foundation
import Tesseract

/// Internal batch context to keep progress math self-contained.
struct OCRBatchContext {
    let completed: Int
    let total: Int
    let currentIndex: Int
    let origin: URL?

    static func single(origin: URL?) -> OCRBatchContext {
        OCRBatchContext(completed: 0, total: 1, currentIndex: 0, origin: origin)
    }
}

/// Single-responsibility recognizer that owns one TessBaseAPI lifecycle per call.
final class SimpleOCRRecognizer {
    func recognize(
        pix: PixImage?,
        config: OCRConfig,
        context: OCRBatchContext,
        progress: ((OCRProgress) -> Void)?
    ) async throws -> OCRResultPayload {
        guard let pix else { throw OCRClientError.invalidImage }

        if let dataPath = config.dataPath {
            setenv("TESSDATA_PREFIX", dataPath, 1)
        }

        TesseractSwiftLog.log("Initializing (lang=\(config.language), engine=\(config.engineMode), psm=\(config.pageSegmentation))")
        let api = try TesseractSwiftAPI(
            dataPath: config.dataPath,
            language: config.language,
            ocrEngineMode: config.engineMode,
            configs: [],
            variables: config.variables,
            setOnlyNonDebugParams: true,
            embeddedTrainedData: nil
        )

        api.pageSegmentationMode = config.pageSegmentation
        if config.disableBlockSeparators {
            _ = try? api.setVariable(name: "tessedit_write_block_separators", bool: false)
            _ = try? api.setVariable(name: "tessedit_write_line_separators", bool: false)
        }

        try api.setImage(pix)

        let monitor = TessMonitor()
        monitor?.setProgressHandler { _, _, _, _ in
            let p = Int(monitor?.progress ?? 0)
            progress?(OCRProgress(
                completed: context.completed,
                total: context.total,
                itemProgress: p,
                currentIndex: context.currentIndex,
                currentURL: context.origin
            ))
            return !Task.isCancelled
        }
        monitor?.setCancelHandler { _ in Task.isCancelled }

        try await api.recognizeAsync(monitor: monitor)

        let text = try api.getUTF8Text() ?? ""
        let conf = try? api.meanTextConfidence()
        TesseractSwiftLog.log("Finished OCR (chars=\(text.count), conf=\(conf ?? -1))")
        progress?(OCRProgress(
            completed: context.completed + 1,
            total: context.total,
            itemProgress: 100,
            currentIndex: context.currentIndex,
            currentURL: context.origin
        ))

        return OCRResultPayload(
            text: text,
            meanConfidence: conf,
            dataPathUsed: api.dataPath,
            engineUsed: config.engineMode,
            pageSegModeUsed: config.pageSegmentation
        )
    }
}

/// Batch runner to keep sequencing and per-item progress out of the facade.
final class SimpleOCRBatchRunner {
    private let recognizer: SimpleOCRRecognizer

    init(recognizer: SimpleOCRRecognizer) {
        self.recognizer = recognizer
    }

    func recognize(
        urls: [URL],
        config: OCRConfig,
        progress: ((OCRProgress) -> Void)?
    ) async throws -> [OCRResultPayload] {
        guard !urls.isEmpty else { throw OCRClientError.emptyBatch }

        var results: [OCRResultPayload] = []
        let total = urls.count
        for (index, url) in urls.enumerated() {
            progress?(OCRProgress(completed: index, total: total, itemProgress: 0, currentIndex: index, currentURL: url))
            guard let pix = PixImage(path: url.path) else { throw OCRClientError.invalidImage }
            let context = OCRBatchContext(completed: index, total: total, currentIndex: index, origin: url)
            let item = try await recognizer.recognize(
                pix: pix,
                config: config,
                context: context,
                progress: progress
            )
            results.append(item)
        }
        return results
    }
}
