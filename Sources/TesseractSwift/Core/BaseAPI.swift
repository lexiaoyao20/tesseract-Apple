/// Core building blocks for the public API. This file is not meant to be consumed directly.
import Tesseract
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Errors surfaced by the Swift wrapper.
public enum TesseractError: Error {
    case createFailed
    case apiClosed
    case allocationFailed(String)
    case initializationFailed(Int32)
    case recognitionFailed(Int32)
    case processFailed(String)
    case invalidImageData
    case invalidTrainedData
    case invalidPointer(String)
}

enum TesseractMemory {
    /// Convert a C string returned by Tesseract into Swift while freeing it.
    static func takeString(_ pointer: UnsafeMutablePointer<Int8>?) -> String? {
        guard let raw = pointer else { return nil }
        defer { TessDeleteText(raw) }
        return String(cString: raw)
    }

    /// Convert a NULL-terminated C string array into Swift and clean up.
    static func takeCStringArray(_ pointer: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> [String] {
        guard let base = pointer else { return [] }
        var result: [String] = []
        var index = 0
        while let current = base.advanced(by: index).pointee {
            result.append(String(cString: current))
            index += 1
        }
        TessDeleteTextArray(base)
        return result
    }

    /// Convert an int array terminated by -1 into Swift and free it.
    static func takeIntArray(_ pointer: UnsafePointer<Int32>?) -> [Int]? {
        guard let base = pointer else { return nil }
        var values: [Int] = []
        var offset = 0
        while true {
            let value = base.advanced(by: offset).pointee
            if value == -1 { break }
            values.append(Int(value))
            offset += 1
        }
        TessDeleteIntArray(base)
        return values
    }

    static func string(fromConst pointer: UnsafePointer<Int8>?) -> String? {
        guard let ptr = pointer else { return nil }
        return String(cString: ptr)
    }
}

func withOptionalCString<R>(_ string: String?, _ body: (UnsafePointer<Int8>?) throws -> R) rethrows -> R {
    if let string {
        return try string.withCString { try body($0) }
    } else {
        return try body(nil)
    }
}

func withCStringArray<R>(
    _ strings: [String],
    addNullTerminator: Bool = false,
    _ body: (UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?, Int) throws -> R
) throws -> R {
    var cStrings: [UnsafeMutablePointer<Int8>?] = []
    cStrings.reserveCapacity(strings.count + (addNullTerminator ? 1 : 0))
    for string in strings {
        guard let duplicated = strdup(string) else {
            cStrings.forEach { if let ptr = $0 { free(ptr) } }
            throw TesseractError.allocationFailed("strdup")
        }
        cStrings.append(duplicated)
    }
    if addNullTerminator {
        cStrings.append(nil)
    }
    defer {
        for ptr in cStrings {
            if let raw = ptr {
                free(raw)
            }
        }
    }
    return try cStrings.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress, strings.count)
    }
}

/// Swift-native enum for OCR engine modes.
public enum OCREngineMode: Int32 {
    case tesseractOnly = 0
    case lstmOnly = 1
    case combined = 2
    case `default` = 3

    var cValue: TessOcrEngineMode { TessOcrEngineMode(rawValue: UInt32(rawValue)) }
    init(_ cValue: TessOcrEngineMode) { self = OCREngineMode(rawValue: Int32(cValue.rawValue)) ?? .default }
}

/// Swift-native enum for page segmentation modes.
public enum PageSegmentationMode: Int32 {
    case osdOnly = 0
    case autoOsd = 1
    case autoOnly = 2
    case auto = 3
    case singleColumn = 4
    case singleBlockVertText = 5
    case singleBlock = 6
    case singleLine = 7
    case singleWord = 8
    case circleWord = 9
    case singleChar = 10
    case sparseText = 11
    case sparseTextOsd = 12
    case rawLine = 13
    case count = 14

    var cValue: TessPageSegMode { TessPageSegMode(rawValue: UInt32(rawValue)) }
    init(_ cValue: TessPageSegMode) { self = PageSegmentationMode(rawValue: Int32(cValue.rawValue)) ?? .auto }
}

/// Lightweight owner for Leptonica PIX that auto-destroys when released.
public final class PixImage {
    public let pointer: OpaquePointer
    private var ownsMemory: Bool

    /// Create from an image file path supported by Leptonica.
    public init?(path: String) {
        guard let pix = path.withCString({ pixRead($0) }) else { return nil }
        pointer = pix
        ownsMemory = true
    }

    /// Create from an encoded image buffer (png/jpeg/webp/...).
    public init?(data: Data) {
        guard !data.isEmpty else { return nil }
        let pix = data.withUnsafeBytes { buffer -> OpaquePointer? in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            return pixReadMem(base, buffer.count)
        }
        guard let pix else { return nil }
        pointer = pix
        ownsMemory = true
    }

    /// Wrap an existing PIX pointer.
    public init?(existing pointer: OpaquePointer?, takeOwnership: Bool) {
        guard let pointer else { return nil }
        self.pointer = pointer
        self.ownsMemory = takeOwnership
    }

#if canImport(UIKit)
    /// Create from UIImage by serializing to PNG/JPEG then feeding Leptonica.
    public convenience init?(uiImage: UIImage, preferredCompression: CGFloat = 0.92) {
        let data = uiImage.pngData() ?? uiImage.jpegData(compressionQuality: preferredCompression)
        guard let data else { return nil }
        self.init(data: data)
    }
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Create from NSImage by converting to PNG.
    public convenience init?(nsImage: NSImage) {
        guard
            let tiff = nsImage.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let data = rep.representation(using: .png, properties: [:])
        else { return nil }
        self.init(data: data)
    }
#endif

    deinit {
        if ownsMemory {
            var ptr: OpaquePointer? = pointer
            pixDestroy(&ptr)
        }
    }

    @discardableResult
    public func detach() -> OpaquePointer {
        ownsMemory = false
        return pointer
    }
}

public enum TesseractSwift {
    /// Linked Tesseract version string.
    public static var version: String { String(cString: TessVersion()) }
}

/// High-level Swift wrapper for TessBaseAPI.
public final class TesseractSwiftAPI {
    public private(set) var handle: OpaquePointer?
    public var isClosed: Bool { handle == nil }

    /// Create an empty handle; call `initialize` before recognition.
    public init() throws {
        guard let created = TessBaseAPICreate() else {
            throw TesseractError.createFailed
        }
        handle = created
    }

    public convenience init(
        dataPath: String? = nil,
        language: String? = "eng",
        ocrEngineMode: OCREngineMode = .default,
        configs: [String] = [],
        variables: [String: String] = [:],
        setOnlyNonDebugParams: Bool = true,
        embeddedTrainedData: Data? = nil
    ) throws {
        try self.init()
        try initialize(
            dataPath: dataPath,
            language: language,
            ocrEngineMode: ocrEngineMode,
            configs: configs,
            variables: variables,
            setOnlyNonDebugParams: setOnlyNonDebugParams,
            embeddedTrainedData: embeddedTrainedData
        )
    }

    deinit {
        close()
    }

    @discardableResult
    public func close() -> Bool {
        guard let handle else { return false }
        TessBaseAPIDelete(handle)
        self.handle = nil
        return true
    }

    private func requireHandle() throws -> OpaquePointer {
        guard let handle else { throw TesseractError.apiClosed }
        return handle
    }

    @inline(__always)
    private func withHandle<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        try body(requireHandle())
    }

    public func initialize(
        dataPath: String? = nil,
        language: String? = "eng",
        ocrEngineMode: OCREngineMode = .default,
        configs: [String] = [],
        variables: [String: String] = [:],
        setOnlyNonDebugParams: Bool = true,
        embeddedTrainedData: Data? = nil
    ) throws {
        let handle = try requireHandle()
        if let embeddedTrainedData, embeddedTrainedData.isEmpty {
            throw TesseractError.invalidTrainedData
        }
        let variableKeys = Array(variables.keys)
        let variableValues = variableKeys.map { variables[$0]! }
        let nonDebugFlag: Int32 = setOnlyNonDebugParams ? 1 : 0
        let initResult: Int32 = try withCStringArray(configs) { configPointer, configCount in
            try withCStringArray(variableKeys) { varKeysPointer, variableCount in
                try withCStringArray(variableValues) { varValuesPointer, _ in
                    try withOptionalCString(language) { languagePointer in
                        if let embeddedTrainedData {
                            return embeddedTrainedData.withUnsafeBytes { buffer in
                                let dataPointer = buffer.bindMemory(to: Int8.self).baseAddress
                                return TessBaseAPIInit5(
                                    handle,
                                    dataPointer,
                                    Int32(buffer.count),
                                    languagePointer,
                                    ocrEngineMode.cValue,
                                    configPointer,
                                    Int32(configCount),
                                    varKeysPointer,
                                    varValuesPointer,
                                    variableCount,
                                    nonDebugFlag
                                )
                            }
                        } else {
                            return try withOptionalCString(dataPath) { datapathPointer in
                                TessBaseAPIInit4(
                                    handle,
                                    datapathPointer,
                                    languagePointer,
                                    ocrEngineMode.cValue,
                                    configPointer,
                                    Int32(configCount),
                                    varKeysPointer,
                                    varValuesPointer,
                                    variableCount,
                                    nonDebugFlag
                                )
                            }
                        }
                    }
                }
            }
        }

        if initResult != 0 {
            throw TesseractError.initializationFailed(initResult)
        }
    }

    public func initForAnalysePage() throws {
        try withHandle { TessBaseAPIInitForAnalysePage($0) }
    }

    public func setInputName(_ name: String) throws {
        try withHandle { handle in
            name.withCString { TessBaseAPISetInputName(handle, $0) }
        }
    }

    public var inputName: String? {
        guard let handle else { return nil }
        return TesseractMemory.string(fromConst: TessBaseAPIGetInputName(handle))
    }

    public func setImage(_ pix: PixImage) throws {
        try withHandle { TessBaseAPISetImage2($0, pix.pointer) }
    }

#if canImport(UIKit)
    /// Convenience: set image from UIImage (encoded into PNG/JPEG internally).
    public func setImage(_ image: UIImage, preferredCompression: CGFloat = 0.92) throws {
        guard let pix = PixImage(uiImage: image, preferredCompression: preferredCompression) else {
            throw TesseractError.invalidImageData
        }
        try setImage(pix)
    }
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Convenience: set image from NSImage (converted to PNG).
    public func setImage(_ image: NSImage) throws {
        guard let pix = PixImage(nsImage: image) else {
            throw TesseractError.invalidImageData
        }
        try setImage(pix)
    }
#endif

    public func setInputImage(_ pix: PixImage) throws {
        try withHandle { TessBaseAPISetInputImage($0, pix.pointer) }
    }

    public func inputImage() throws -> PixImage? {
        try withHandle { handle in
            PixImage(existing: TessBaseAPIGetInputImage(handle), takeOwnership: false)
        }
    }

    public func setImage(
        data: Data,
        width: Int,
        height: Int,
        bytesPerPixel: Int,
        bytesPerLine: Int
    ) throws {
        guard !data.isEmpty else { throw TesseractError.invalidImageData }
        try withHandle { handle in
            try data.withUnsafeBytes { buffer in
                guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else {
                    throw TesseractError.invalidPointer("image buffer")
                }
                TessBaseAPISetImage(
                    handle,
                    base,
                    Int32(width),
                    Int32(height),
                    Int32(bytesPerPixel),
                    Int32(bytesPerLine)
                )
            }
        }
    }

    public func setRectangle(x: Int, y: Int, width: Int, height: Int) throws {
        let handle = try requireHandle()
        TessBaseAPISetRectangle(handle, Int32(x), Int32(y), Int32(width), Int32(height))
    }

#if canImport(CoreGraphics)
    public func setRectangle(_ rect: CGRect) throws {
        try setRectangle(
            x: Int(rect.origin.x),
            y: Int(rect.origin.y),
            width: Int(rect.size.width),
            height: Int(rect.size.height)
        )
    }
#endif

    public var dataPath: String? {
        guard let handle else { return nil }
        return TesseractMemory.string(fromConst: TessBaseAPIGetDatapath(handle))
    }

    public func setOutputName(_ name: String) throws {
        let handle = try requireHandle()
        name.withCString { TessBaseAPISetOutputName(handle, $0) }
    }

    /// Page segmentation mode using Swift enum wrapper.
    public var pageSegmentationMode: PageSegmentationMode {
        get {
            guard let handle else { return .auto }
            return PageSegmentationMode(TessBaseAPIGetPageSegMode(handle))
        }
        set {
            guard let handle else { return }
            TessBaseAPISetPageSegMode(handle, newValue.cValue)
        }
    }

    public func setSourceResolution(ppi: Int) throws {
        let handle = try requireHandle()
        TessBaseAPISetSourceResolution(handle, Int32(ppi))
    }

    public var sourceYResolution: Int? {
        guard let handle else { return nil }
        return Int(TessBaseAPIGetSourceYResolution(handle))
    }

    @discardableResult
    public func setVariable(name: String, value: String) throws -> Bool {
        let handle = try requireHandle()
        return name.withCString { namePtr in
            value.withCString { valuePtr in
                TessBaseAPISetVariable(handle, namePtr, valuePtr) != 0
            }
        }
    }

    @discardableResult
    public func setVariable(name: String, bool value: Bool) throws -> Bool {
        try setVariable(name: name, value: value ? "1" : "0")
    }

    @discardableResult
    public func setVariable(name: String, integer value: Int) throws -> Bool {
        try setVariable(name: name, value: String(value))
    }

    @discardableResult
    public func setVariable(name: String, double value: Double) throws -> Bool {
        try setVariable(name: name, value: String(value))
    }

    @discardableResult
    public func setDebugVariable(name: String, value: String) throws -> Bool {
        let handle = try requireHandle()
        return name.withCString { namePtr in
            value.withCString { valuePtr in
                TessBaseAPISetDebugVariable(handle, namePtr, valuePtr) != 0
            }
        }
    }

    public func intVariable(named name: String) throws -> Int? {
        let handle = try requireHandle()
        var value: Int32 = 0
        let success = name.withCString { TessBaseAPIGetIntVariable(handle, $0, &value) } != 0
        return success ? Int(value) : nil
    }

    public func boolVariable(named name: String) throws -> Bool? {
        let handle = try requireHandle()
        var value: Int32 = 0
        let success = name.withCString { TessBaseAPIGetBoolVariable(handle, $0, &value) } != 0
        return success ? value != 0 : nil
    }

    public func doubleVariable(named name: String) throws -> Double? {
        let handle = try requireHandle()
        var value: Double = 0
        let success = name.withCString { TessBaseAPIGetDoubleVariable(handle, $0, &value) } != 0
        return success ? value : nil
    }

    public func stringVariable(named name: String) throws -> String? {
        let handle = try requireHandle()
        return name.withCString { cString in
            TesseractMemory.string(fromConst: TessBaseAPIGetStringVariable(handle, cString))
        }
    }

    public func readConfigFile(_ filename: String) throws {
        let handle = try requireHandle()
        filename.withCString { TessBaseAPIReadConfigFile(handle, $0) }
    }

    public func readDebugConfigFile(_ filename: String) throws {
        let handle = try requireHandle()
        filename.withCString { TessBaseAPIReadDebugConfigFile(handle, $0) }
    }

    public func initLanguages() throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.string(fromConst: TessBaseAPIGetInitLanguagesAsString(handle))
    }

    public func loadedLanguages() throws -> [String] {
        let handle = try requireHandle()
        return TesseractMemory.takeCStringArray(TessBaseAPIGetLoadedLanguagesAsVector(handle))
    }

    public func availableLanguages() throws -> [String] {
        let handle = try requireHandle()
        return TesseractMemory.takeCStringArray(TessBaseAPIGetAvailableLanguagesAsVector(handle))
    }

    public func recognize(monitor: TessMonitor? = nil) throws {
        let handle = try requireHandle()
        let result = TessBaseAPIRecognize(handle, monitor?.pointer)
        if result != 0 {
            throw TesseractError.recognitionFailed(result)
        }
    }

    public func recognizeText(monitor: TessMonitor? = nil) throws -> String? {
        try recognize(monitor: monitor)
        return try getUTF8Text()
    }

    /// Async recognition to keep UI threads responsive.
    public func recognizeAsync(monitor: TessMonitor? = nil) async throws {
        try await Task.detached(priority: .userInitiated) {
            try self.recognize(monitor: monitor)
        }.value
    }

    /// Async convenience that runs recognition and returns UTF-8 text.
    public func recognizeTextAsync(monitor: TessMonitor? = nil) async throws -> String? {
        try await Task.detached(priority: .userInitiated) {
            try self.recognizeText(monitor: monitor)
        }.value
    }

    public func processPages(
        filename: String,
        retryConfig: String? = nil,
        timeoutMillis: Int = 0,
        renderer: TessResultRendererWrapper
    ) throws {
        let handle = try requireHandle()
        let success = filename.withCString { filePtr in
            withOptionalCString(retryConfig) { retryPtr in
                TessBaseAPIProcessPages(
                    handle,
                    filePtr,
                    retryPtr,
                    Int32(timeoutMillis),
                    renderer.pointer
                )
            }
        } != 0
        if !success {
            throw TesseractError.processFailed(filename)
        }
    }

    /// Async wrapper to offload multi-page processing.
    public func processPagesAsync(
        filename: String,
        retryConfig: String? = nil,
        timeoutMillis: Int = 0,
        renderer: TessResultRendererWrapper
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            try self.processPages(
                filename: filename,
                retryConfig: retryConfig,
                timeoutMillis: timeoutMillis,
                renderer: renderer
            )
        }.value
    }

    public func processPage(
        pix: PixImage,
        pageIndex: Int = 0,
        filename: String,
        retryConfig: String? = nil,
        timeoutMillis: Int = 0,
        renderer: TessResultRendererWrapper
    ) throws {
        let handle = try requireHandle()
        let success = filename.withCString { filePtr in
            withOptionalCString(retryConfig) { retryPtr in
                TessBaseAPIProcessPage(
                    handle,
                    pix.pointer,
                    Int32(pageIndex),
                    filePtr,
                    retryPtr,
                    Int32(timeoutMillis),
                    renderer.pointer
                )
            }
        } != 0
        if !success {
            throw TesseractError.processFailed(filename)
        }
    }

    /// Async wrapper to offload single page processing.
    public func processPageAsync(
        pix: PixImage,
        pageIndex: Int = 0,
        filename: String,
        retryConfig: String? = nil,
        timeoutMillis: Int = 0,
        renderer: TessResultRendererWrapper
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            try self.processPage(
                pix: pix,
                pageIndex: pageIndex,
                filename: filename,
                retryConfig: retryConfig,
                timeoutMillis: timeoutMillis,
                renderer: renderer
            )
        }.value
    }

    public func getUTF8Text() throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.takeString(TessBaseAPIGetUTF8Text(handle))
    }

    public func getHOCRText(page: Int = 0) throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.takeString(TessBaseAPIGetHOCRText(handle, Int32(page)))
    }

    public func getAltoText(page: Int = 0) throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.takeString(TessBaseAPIGetAltoText(handle, Int32(page)))
    }

    public func getPAGEText(page: Int = 0) throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.takeString(TessBaseAPIGetPAGEText(handle, Int32(page)))
    }

    public func getTSVText(page: Int = 0) throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.takeString(TessBaseAPIGetTsvText(handle, Int32(page)))
    }

    public func getBoxText(page: Int = 0) throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.takeString(TessBaseAPIGetBoxText(handle, Int32(page)))
    }

    public func getLSTMBoxText(page: Int = 0) throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.takeString(TessBaseAPIGetLSTMBoxText(handle, Int32(page)))
    }

    public func getWordStringBoxText(page: Int = 0) throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.takeString(TessBaseAPIGetWordStrBoxText(handle, Int32(page)))
    }

    public func getUNLVText() throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.takeString(TessBaseAPIGetUNLVText(handle))
    }

    public func meanTextConfidence() throws -> Int {
        let handle = try requireHandle()
        return Int(TessBaseAPIMeanTextConf(handle))
    }

    public func allWordConfidences() throws -> [Int]? {
        let handle = try requireHandle()
        return TesseractMemory.takeIntArray(TessBaseAPIAllWordConfidences(handle))
    }

    public func clearAdaptiveClassifier() throws {
        let handle = try requireHandle()
        TessBaseAPIClearAdaptiveClassifier(handle)
    }

    public func clear() throws {
        let handle = try requireHandle()
        TessBaseAPIClear(handle)
    }

    public func end() throws {
        let handle = try requireHandle()
        TessBaseAPIEnd(handle)
    }

    public func rect(
        imageData: Data,
        bytesPerPixel: Int,
        bytesPerLine: Int,
        left: Int,
        top: Int,
        width: Int,
        height: Int
    ) throws -> String? {
        let handle = try requireHandle()
        return imageData.withUnsafeBytes { buffer in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            return TesseractMemory.takeString(
                TessBaseAPIRect(
                    handle,
                    base,
                    Int32(bytesPerPixel),
                    Int32(bytesPerLine),
                    Int32(left),
                    Int32(top),
                    Int32(width),
                    Int32(height)
                )
            )
        }
    }

    public func thresholdedImage() throws -> PixImage? {
        let handle = try requireHandle()
        return PixImage(existing: TessBaseAPIGetThresholdedImage(handle), takeOwnership: true)
    }

    public func thresholdedImageScaleFactor() throws -> Int {
        let handle = try requireHandle()
        return Int(TessBaseAPIGetThresholdedImageScaleFactor(handle))
    }

    public func gradient() throws -> Float {
        let handle = try requireHandle()
        return TessBaseAPIGetGradient(handle)
    }

    /// Layout analysis without full recognition.
    public func analyseLayout() throws -> TessPageIteratorWrapper? {
        let handle = try requireHandle()
        guard let iterator = TessBaseAPIAnalyseLayout(handle) else { return nil }
        return TessPageIteratorWrapper(pointer: iterator, ownsPointer: true)
    }

    /// Result iterator after calling `recognize`.
    public func iterator() throws -> TessResultIteratorWrapper? {
        let handle = try requireHandle()
        guard let iterator = TessBaseAPIGetIterator(handle) else { return nil }
        return TessResultIteratorWrapper(pointer: iterator, ownsPointer: true)
    }

    /// Mutable iterator variant.
    public func mutableIterator() throws -> TessResultIteratorWrapper? {
        let handle = try requireHandle()
        guard let iterator = TessBaseAPIGetMutableIterator(handle) else { return nil }
        return TessResultIteratorWrapper(pointer: iterator, ownsPointer: true)
    }

    public func isValid(word: String) throws -> Bool {
        let handle = try requireHandle()
        return word.withCString { TessBaseAPIIsValidWord(handle, $0) } != 0
    }

    public func textDirection() throws -> (offset: Int32, slope: Float)? {
        let handle = try requireHandle()
        var offset: Int32 = 0
        var slope: Float = 0
        let success = TessBaseAPIGetTextDirection(handle, &offset, &slope) != 0
        return success ? (offset, slope) : nil
    }

    public func unichar(for id: Int) throws -> String? {
        let handle = try requireHandle()
        return TesseractMemory.string(fromConst: TessBaseAPIGetUnichar(handle, Int32(id)))
    }

    public func clearPersistentCache() throws {
        let handle = try requireHandle()
        TessBaseAPIClearPersistentCache(handle)
    }

    public func detectOrientationScript() throws -> (degrees: Int32, confidence: Float, scriptName: String?, scriptConfidence: Float)? {
        let handle = try requireHandle()
        var orientation: Int32 = 0
        var orientationConfidence: Float = 0
        var scriptName: UnsafePointer<Int8>?
        var scriptConfidence: Float = 0

        let ok = TessBaseAPIDetectOrientationScript(
            handle,
            &orientation,
            &orientationConfidence,
            &scriptName,
            &scriptConfidence
        ) != 0
        guard ok else { return nil }
        let script = TesseractMemory.string(fromConst: scriptName)
        return (orientation, orientationConfidence, script, scriptConfidence)
    }

    public func setMinOrientationMargin(_ margin: Double) throws {
        let handle = try requireHandle()
        TessBaseAPISetMinOrientationMargin(handle, margin)
    }

    public func numDawgs() throws -> Int32 {
        let handle = try requireHandle()
        return TessBaseAPINumDawgs(handle)
    }

    public func engineMode() throws -> OCREngineMode {
        let handle = try requireHandle()
        return OCREngineMode(TessBaseAPIOem(handle))
    }
}
