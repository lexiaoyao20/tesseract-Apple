/// Public entrypoints for the TesseractSwift module.
/// - Re-exports the C API (`@_exported import Tesseract`) for advanced callers.
/// - Provides a concise async facade (`TesseractSwiftSimple`) with batch + progress.
/// - Exposes a runtime logging toggle (`TesseractSwiftLog`).
@_exported import Tesseract
import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Runtime logging gate for all public facades. DEBUG builds default to enabled.
public enum TesseractSwiftLog {
    public static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    public static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[TesseractSwift] \(message())")
    }
}

/// Errors surfaced by the high-level facade.
public enum OCRClientError: Error {
    case invalidImage
    case emptyBatch
}

/// Minimal configuration for the high-level API.
public struct OCRConfig {
    /// Language codes like "eng" or "chi_sim+eng".
    public var language: String = "eng"
    /// Optional tessdata directory; falls back to TESSDATA_PREFIX / bundle if nil.
    public var dataPath: String? = nil
    public var engineMode: OCREngineMode = .lstmOnly
    public var pageSegmentation: PageSegmentationMode = .singleBlock
    /// Key/value pairs forwarded to Tesseract variables.
    public var variables: [String: String] = [:]
    /// When true, suppresses block/line separators to avoid extra blank lines.
    public var disableBlockSeparators: Bool = true

    public init(
        language: String = "eng",
        dataPath: String? = nil,
        engineMode: OCREngineMode = .lstmOnly,
        pageSegmentation: PageSegmentationMode = .singleBlock,
        variables: [String: String] = [:],
        disableBlockSeparators: Bool = true
    ) {
        self.language = language
        self.dataPath = dataPath
        self.engineMode = engineMode
        self.pageSegmentation = pageSegmentation
        self.variables = variables
        self.disableBlockSeparators = disableBlockSeparators
    }
}

/// Common Tesseract variable keys for convenience (usable via `OCRConfig.variables[...]`).
public enum OCRVariable {
    public static let charWhitelist = "tessedit_char_whitelist"
    public static let charBlacklist = "tessedit_char_blacklist"
    public static let preserveInterwordSpaces = "preserve_interword_spaces"
    public static let detectStraightBlobs = "tessedit_detect_straight_blobs"
    public static let zeroRejection = "tessedit_zero_rejection"
    public static let zeroKelvinRejection = "tessedit_zero_kelvin_rejection"
}

/// Progress callback payload for single or batch recognition.
public struct OCRProgress {
    public let completed: Int
    public let total: Int
    public let itemProgress: Int
    public let currentIndex: Int
    public let currentURL: URL?
}

/// Simplified result payload.
public struct OCRResultPayload {
    public let text: String
    public let meanConfidence: Int?
    public let dataPathUsed: String?
    public let engineUsed: OCREngineMode
    public let pageSegModeUsed: PageSegmentationMode
}

/// High-level facade that mirrors the tiny macOS demo API while keeping async progress.
///
/// Usage:
/// ```swift
/// // Single image (URL)
/// let result = try await TesseractSwiftSimple.recognize(url: imageURL)
/// print(result.text)
///
/// // Batch
/// let results = try await TesseractSwiftSimple.recognize(urls: imageURLs) { progress in
///     print("overall \(progress.completed)/\(progress.total), item \(progress.itemProgress)%")
/// }
///
/// // Toggle logging
/// TesseractSwiftLog.isEnabled = true
/// ```
public enum TesseractSwiftClient {
    private static let recognizer = SimpleOCRRecognizer()
    private static let batchRunner = SimpleOCRBatchRunner(recognizer: recognizer)

    /// Recognize a single image from Data.
    public static func recognize(
        data: Data,
        config: OCRConfig = .init(),
        progress: ((OCRProgress) -> Void)? = nil
    ) async throws -> OCRResultPayload {
        guard let pix = PixImage(data: data) else { throw OCRClientError.invalidImage }
        return try await recognizer.recognize(
            pix: pix,
            config: config,
            context: .single(origin: nil),
            progress: progress
        )
    }

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Recognize a single NSImage.
    public static func recognize(
        image: NSImage,
        config: OCRConfig = .init(),
        progress: ((OCRProgress) -> Void)? = nil
    ) async throws -> OCRResultPayload {
        guard let pix = PixImage(nsImage: image) else { throw OCRClientError.invalidImage }
        return try await recognizer.recognize(
            pix: pix,
            config: config,
            context: .single(origin: nil),
            progress: progress
        )
    }
#endif

#if canImport(UIKit)
    /// Recognize a single UIImage.
    public static func recognize(
        image: UIImage,
        config: OCRConfig = .init(),
        progress: ((OCRProgress) -> Void)? = nil
    ) async throws -> OCRResultPayload {
        guard let pix = PixImage(uiImage: image) else { throw OCRClientError.invalidImage }
        return try await recognizer.recognize(
            pix: pix,
            config: config,
            context: .single(origin: nil),
            progress: progress
        )
    }
#endif

    /// Recognize a single image from a file URL.
    public static func recognize(
        url: URL,
        config: OCRConfig = .init(),
        progress: ((OCRProgress) -> Void)? = nil
    ) async throws -> OCRResultPayload {
        guard let pix = PixImage(path: url.path) else { throw OCRClientError.invalidImage }
        return try await recognizer.recognize(
            pix: pix,
            config: config,
            context: .single(origin: url),
            progress: progress
        )
    }

    /// Recognize a batch of file URLs sequentially with aggregated progress.
    public static func recognize(
        urls: [URL],
        config: OCRConfig = .init(),
        progress: ((OCRProgress) -> Void)? = nil
    ) async throws -> [OCRResultPayload] {
        return try await batchRunner.recognize(urls: urls, config: config, progress: progress)
    }
}
