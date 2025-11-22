import Foundation
import CoreGraphics
import AppKit
import TesseractSwift

/// User-configurable output options.
struct OutputOptions {
    var wantHOCR = false
    var wantAlto = false
    var wantPageXML = false
    var wantTSV = false
    var wantPDF = false
    var pdfTextOnly = false
    var wantBoxText = false
    var wantLSTMBox = false
    var wantWordBox = false
    var wantUNLV = false
}

/// Request sent to the OCR service.
struct OCRRequest {
    var image: NSImage
    var dataPath: String?
    var language: String
    var engineMode: OCREngineMode
    var pageSegMode: PageSegmentationMode
    var variables: [String: String]
}

/// Token-level info produced by the iterator.
struct OCRToken: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let box: CGRect?
}

/// Orientation metadata returned by Tesseract.
struct OrientationInfo {
    let degrees: Int32
    let confidence: Float
    let scriptName: String?
    let scriptConfidence: Float
}

/// Renderer outputs generated via TessResultRenderer.
struct RendererOutput: Identifiable {
    let id = UUID()
    let kind: String
    let url: URL
}

/// Full OCR result payload to feed the UI.
struct OCRResult {
    var utf8Text: String?
    var hocr: String?
    var alto: String?
    var pageXML: String?
    var tsv: String?
    var pdfURL: URL?
    var rendererOutputs: [RendererOutput]
    var boxText: String?
    var lstmBoxText: String?
    var wordStrBoxText: String?
    var unlv: String?
    var meanConfidence: Int?
    var wordConfidences: [Int]
    var tokens: [OCRToken]
    var orientation: OrientationInfo?
    var blockCount: Int?
    var engineUsed: OCREngineMode
    var dataPathUsed: String?
}
