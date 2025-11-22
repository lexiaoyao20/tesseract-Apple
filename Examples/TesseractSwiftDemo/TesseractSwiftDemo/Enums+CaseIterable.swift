import Foundation
import TesseractSwift

extension OCREngineMode {
    // Demo focuses on LSTM-only for stability and accuracy.
    static var demoOptions: [OCREngineMode] { [.lstmOnly] }
    var label: String {
        switch self {
        case .tesseractOnly: return "Tesseract only (legacy)"
        case .lstmOnly: return "LSTM only"
        case .combined: return "Combined"
        case .default: return "Default"
        }
    }
}

extension PageSegmentationMode {
    static var demoOptions: [PageSegmentationMode] {
        [.osdOnly, .autoOsd, .autoOnly, .auto, .singleColumn, .singleBlockVertText, .singleBlock, .singleLine, .singleWord, .circleWord, .singleChar, .sparseText, .sparseTextOsd, .rawLine]
    }

    var label: String {
        switch self {
        case .osdOnly: return "OSD only"
        case .autoOsd: return "Auto + OSD"
        case .autoOnly: return "Auto (no OSD)"
        case .auto: return "Auto"
        case .singleColumn: return "Single column"
        case .singleBlockVertText: return "Single block vertical"
        case .singleBlock: return "Single block"
        case .singleLine: return "Single line"
        case .singleWord: return "Single word"
        case .circleWord: return "Circle word"
        case .singleChar: return "Single char"
        case .sparseText: return "Sparse text"
        case .sparseTextOsd: return "Sparse + OSD"
        case .rawLine: return "Raw line"
        case .count: return "Count"
        }
    }
}
