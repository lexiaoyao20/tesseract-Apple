import Foundation
import Tesseract

/// RAII wrapper for TessResultRenderer, covering text/HOCR/PDF/TSV outputs.
public final class TessResultRendererWrapper {
    public let pointer: OpaquePointer
    private var ownsPointer: Bool

    /// Supported renderer types.
    public enum Kind {
        case text
        case hocr(fontInfo: Bool)
        case alto
        case page
        case tsv
        case pdf(dataPath: String, textOnly: Bool)
        case unlv
        case boxText
        case lstmBox
        case wordStrBox
    }

    init?(pointer: OpaquePointer?, ownsPointer: Bool) {
        guard let pointer else { return nil }
        self.pointer = pointer
        self.ownsPointer = ownsPointer
    }

    deinit {
        if ownsPointer {
            TessDeleteResultRenderer(pointer)
        }
    }

    /// Factory to create the requested renderer.
    public static func create(outputBase: String, kind: Kind) -> TessResultRendererWrapper? {
        switch kind {
        case .text:
            return outputBase.withCString { TessResultRendererWrapper(pointer: TessTextRendererCreate($0), ownsPointer: true) }
        case .hocr(let fontInfo):
            return outputBase.withCString {
                TessResultRendererWrapper(pointer: TessHOcrRendererCreate2($0, fontInfo ? Int32(1) : Int32(0)), ownsPointer: true)
            }
        case .alto:
            return outputBase.withCString { TessResultRendererWrapper(pointer: TessAltoRendererCreate($0), ownsPointer: true) }
        case .page:
            return outputBase.withCString { TessResultRendererWrapper(pointer: TessPAGERendererCreate($0), ownsPointer: true) }
        case .tsv:
            return outputBase.withCString { TessResultRendererWrapper(pointer: TessTsvRendererCreate($0), ownsPointer: true) }
        case .pdf(let dataPath, let textOnly):
            return outputBase.withCString { basePtr in
                dataPath.withCString { dataPtr in
                    TessResultRendererWrapper(pointer: TessPDFRendererCreate(basePtr, dataPtr, textOnly ? Int32(1) : Int32(0)), ownsPointer: true)
                }
            }
        case .unlv:
            return outputBase.withCString { TessResultRendererWrapper(pointer: TessUnlvRendererCreate($0), ownsPointer: true) }
        case .boxText:
            return outputBase.withCString { TessResultRendererWrapper(pointer: TessBoxTextRendererCreate($0), ownsPointer: true) }
        case .lstmBox:
            return outputBase.withCString { TessResultRendererWrapper(pointer: TessLSTMBoxRendererCreate($0), ownsPointer: true) }
        case .wordStrBox:
            return outputBase.withCString { TessResultRendererWrapper(pointer: TessWordStrBoxRendererCreate($0), ownsPointer: true) }
        }
    }

    /// Insert another renderer for chained output (ownership transferred).
    @discardableResult
    public func insert(renderer: TessResultRendererWrapper) -> TessResultRendererWrapper {
        renderer.ownsPointer = false
        TessResultRendererInsert(pointer, renderer.pointer)
        return renderer
    }

    /// Convenience to build a linked renderer chain using the same output base.
    public static func createChain(outputBase: String, kinds: [Kind]) -> TessResultRendererWrapper? {
        guard let headKind = kinds.first else { return nil }
        guard let head = create(outputBase: outputBase, kind: headKind) else { return nil }
        var tail = head
        for kind in kinds.dropFirst() {
            guard let next = create(outputBase: outputBase, kind: kind) else { return nil }
            tail = tail.insert(renderer: next)
        }
        return head
    }

    public func next() -> TessResultRendererWrapper? {
        TessResultRendererWrapper(pointer: TessResultRendererNext(pointer), ownsPointer: false)
    }

    /// Begin a multi-page document.
    public func beginDocument(title: String) -> Bool {
        title.withCString { TessResultRendererBeginDocument(pointer, $0) } != 0
    }

    /// Add an already-recognized page.
    public func addImage(api: TesseractSwiftAPI) -> Bool {
        guard let handle = api.handle else { return false }
        return TessResultRendererAddImage(pointer, handle) != 0
    }

    /// Finalize and flush output.
    public func endDocument() -> Bool {
        TessResultRendererEndDocument(pointer) != 0
    }

    public var fileExtension: String? {
        TesseractMemory.string(fromConst: TessResultRendererExtention(pointer))
    }

    public var title: String? {
        TesseractMemory.string(fromConst: TessResultRendererTitle(pointer))
    }

    public var imageCount: Int {
        Int(TessResultRendererImageNum(pointer))
    }
}
