import Foundation
import AppKit
import Combine
import Darwin
import OSLog
import TesseractSwift

@MainActor
final class OCRViewModel: ObservableObject {
    @Published var currentImage: NSImage? = nil
    @Published var status: String = "Select an image to begin"
    @Published var progress: Int = 0
    @Published var isRunning: Bool = false
    @Published var language: String = "eng"
    @Published var dataPath: String = OCRViewModel.defaultTessdataPath()
    @Published var engineMode: OCREngineMode = .lstmOnly
    @Published var pageSegMode: PageSegmentationMode = .singleBlock
    @Published var outputOptions = OutputOptions()
    @Published var variables: [KeyValue] = []
    @Published var crop = Crop()
    @Published var result: OCRResult? = nil
    @Published var errorMessage: String? = nil

    private static let logger = Logger(subsystem: "com.tesseractswift.demo", category: "OCRViewModel")
    private let logger = OCRViewModel.logger
    private var task: Task<Void, Never>? = nil

    struct KeyValue: Identifiable, Hashable {
        let id = UUID()
        var key: String
        var value: String
    }

    struct Crop {
        var x: String = ""
        var y: String = ""
        var width: String = ""
        var height: String = ""

        var rect: CGRect? {
            guard let x = Double(x), let y = Double(y), let w = Double(width), let h = Double(height), w > 0, h > 0 else {
                return nil
            }
            return CGRect(x: x, y: y, width: w, height: h)
        }
    }

    func loadImage(_ image: NSImage?) {
        guard let image else { return }
        currentImage = image
        status = "Image loaded"
    }

    func loadImage(from url: URL) {
        guard let image = ImageUtilities.image(from: url) else { return }
        currentImage = image
        status = "Image loaded"
    }

    func loadSampleImage() {
        loadImage(ImageUtilities.sampleImage())
    }

    func addVariable(key: String, value: String) {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let index = variables.firstIndex(where: { $0.key == key }) {
            variables[index].value = value
        } else {
            variables.append(KeyValue(key: key, value: value))
        }
    }

    func removeVariable(_ pair: KeyValue) {
        variables.removeAll { $0.id == pair.id }
    }

    func recognize() {
        startRecognition(using: engineMode)
    }

    @MainActor
    private func startRecognition(using engine: OCREngineMode) {
        guard let image = currentImage else {
            reportError("Please load an image first")
            return
        }

        let resolvedPath = resolvedTessdataPath()
        if resolvedPath == nil {
            errorMessage = "No tessdata found. Add traineddata to the bundle or specify a tessdata path."
            status = "Missing tessdata"
            return
        }

        task?.cancel()
        isRunning = true
        progress = 0
        status = "Running (\(engine.label))"
        let config = OCRConfig(
            language: language,
            dataPath: resolvedPath,
            engineMode: engine,
            pageSegmentation: pageSegMode,
            variables: Dictionary(uniqueKeysWithValues: variables.map { ($0.key, $0.value) }),
            disableBlockSeparators: true
        )

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let simpleResult = try await TesseractSwiftClient.recognize(
                    image: image,
                    config: config
                ) { [weak self] p in
                    Task { @MainActor in
                        self?.progress = min(100, max(0, p.itemProgress))
                    }
                }

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.result = self.convert(simple: simpleResult)
                    self.status = "Done (\(engine.label))"
                    self.isRunning = false
                    self.errorMessage = nil
                }
            } catch {
                guard !Task.isCancelled else { return }

                let message = describe(error: error, dataPath: resolvedPath)
                logger.error("OCR failed: \(message, privacy: .public)")
                await MainActor.run {
                    self.errorMessage = message
                    self.status = "Failed"
                    self.isRunning = false
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
        status = "Cancelled"
    }

    private static func ensureOutputDirectory() -> URL {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("TesseractSwiftDemo", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func defaultTessdataPath() -> String {
        // Prefer bundled resources; if missing, return empty and let the user point to a path.
        return Bundle.main.resourcePath ?? ""
    }

    func reportError(_ message: String) {
        logger.error("\(message, privacy: .public)")
        errorMessage = message
    }

    private func resolvedTessdataPath() -> String? {
        let fallbackPath = Self.defaultTessdataPath()
        let candidate = dataPath.isEmpty ? fallbackPath : dataPath
        return candidate.isEmpty ? nil : candidate
    }

    private func convert(simple: OCRResultPayload) -> OCRResult {
        OCRResult(
            utf8Text: simple.text,
            hocr: nil,
            alto: nil,
            pageXML: nil,
            tsv: nil,
            pdfURL: nil,
            rendererOutputs: [],
            boxText: nil,
            lstmBoxText: nil,
            wordStrBoxText: nil,
            unlv: nil,
            meanConfidence: simple.meanConfidence,
            wordConfidences: [],
            tokens: [],
            orientation: nil,
            blockCount: nil,
            engineUsed: simple.engineUsed,
            dataPathUsed: simple.dataPathUsed
        )
    }

    private func describe(error: Error, dataPath: String?) -> String {
        guard let tessError = error as? TesseractError else { return error.localizedDescription }
        switch tessError {
        case .initializationFailed(let code):
            let path = dataPath ?? "(none)"
            return "Initialization failed (code \(code)). Verify tessdata at \(path) contains required traineddata."
        case .recognitionFailed(let code):
            return "Recognition failed (code \(code))."
        case .createFailed: return "Failed to create Tesseract API instance."
        case .apiClosed: return "Tesseract API is closed."
        case .allocationFailed(let label): return "Allocation failed: \(label)."
        case .processFailed(let reason): return "Processing failed: \(reason)."
        case .invalidImageData: return "Invalid image data."
        case .invalidTrainedData: return "Invalid traineddata payload."
        case .invalidPointer(let reason): return "Invalid pointer: \(reason)."
        }
    }
}
