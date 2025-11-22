import Foundation
import Tesseract
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Swift struct for font attributes reported by result iterator.
public struct TessFontAttributes {
    public let name: String?
    public let isBold: Bool
    public let isItalic: Bool
    public let isUnderlined: Bool
    public let isMonospace: Bool
    public let isSerif: Bool
    public let isSmallCaps: Bool
    public let pointSize: Int32
    public let fontId: Int32
}

/// Wrapper over TessPageIterator that cleans up when released.
public final class TessPageIteratorWrapper {
    public let pointer: OpaquePointer
    private let ownsPointer: Bool

    init?(pointer: OpaquePointer?, ownsPointer: Bool) {
        guard let pointer else { return nil }
        self.pointer = pointer
        self.ownsPointer = ownsPointer
    }

    deinit {
        if ownsPointer {
            TessPageIteratorDelete(pointer)
        }
    }

    /// Deep copy of iterator.
    public func copy() -> TessPageIteratorWrapper? {
        TessPageIteratorWrapper(pointer: TessPageIteratorCopy(pointer), ownsPointer: true)
    }

    /// Move to the first element.
    public func begin() {
        TessPageIteratorBegin(pointer)
    }

    @discardableResult
    public func next(level: TessPageIteratorLevel = RIL_BLOCK) -> Bool {
        TessPageIteratorNext(pointer, level) != 0
    }

    public func isAtBeginning(of level: TessPageIteratorLevel) -> Bool {
        TessPageIteratorIsAtBeginningOf(pointer, level) != 0
    }

    public func isAtFinalElement(level: TessPageIteratorLevel, element: TessPageIteratorLevel) -> Bool {
        TessPageIteratorIsAtFinalElement(pointer, level, element) != 0
    }

    public func boundingBox(level: TessPageIteratorLevel) -> (left: Int32, top: Int32, right: Int32, bottom: Int32)? {
        var left: Int32 = 0
        var top: Int32 = 0
        var right: Int32 = 0
        var bottom: Int32 = 0
        let success = TessPageIteratorBoundingBox(pointer, level, &left, &top, &right, &bottom) != 0
        return success ? (left, top, right, bottom) : nil
    }

#if canImport(CoreGraphics)
    public func boundingBoxRect(level: TessPageIteratorLevel) -> CGRect? {
        guard let box = boundingBox(level: level) else { return nil }
        let width = CGFloat(box.right - box.left)
        let height = CGFloat(box.bottom - box.top)
        return CGRect(x: CGFloat(box.left), y: CGFloat(box.top), width: width, height: height)
    }
#endif

    public func blockType() -> TessPolyBlockType {
        TessPageIteratorBlockType(pointer)
    }

    public func binaryImage(level: TessPageIteratorLevel) -> PixImage? {
        PixImage(existing: TessPageIteratorGetBinaryImage(pointer, level), takeOwnership: true)
    }

    public func image(level: TessPageIteratorLevel, padding: Int = 0, originalImage: PixImage? = nil) -> (pix: PixImage, left: Int32, top: Int32)? {
        var left: Int32 = 0
        var top: Int32 = 0
        let pixPointer = TessPageIteratorGetImage(pointer, level, Int32(padding), originalImage?.pointer, &left, &top)
        guard let pixPointer, let pix = PixImage(existing: pixPointer, takeOwnership: true) else { return nil }
        return (pix, left, top)
    }

    public func baseline(level: TessPageIteratorLevel) -> (x1: Int32, y1: Int32, x2: Int32, y2: Int32)? {
        var x1: Int32 = 0
        var y1: Int32 = 0
        var x2: Int32 = 0
        var y2: Int32 = 0
        let success = TessPageIteratorBaseline(pointer, level, &x1, &y1, &x2, &y2) != 0
        return success ? (x1, y1, x2, y2) : nil
    }

    public func orientation() -> (orientation: TessOrientation, writingDirection: TessWritingDirection, textlineOrder: TessTextlineOrder, deskewAngle: Float) {
        var orientation = ORIENTATION_PAGE_UP
        var writingDirection = WRITING_DIRECTION_LEFT_TO_RIGHT
        var order = TEXTLINE_ORDER_LEFT_TO_RIGHT
        var angle: Float = 0
        TessPageIteratorOrientation(pointer, &orientation, &writingDirection, &order, &angle)
        return (orientation, writingDirection, order, angle)
    }

    public func paragraphInfo() -> (justification: TessParagraphJustification, isListItem: Bool, isCrown: Bool, firstLineIndent: Int32) {
        var justification = JUSTIFICATION_UNKNOWN
        var isListItem: Int32 = 0
        var isCrown: Int32 = 0
        var firstLineIndent: Int32 = 0
        TessPageIteratorParagraphInfo(pointer, &justification, &isListItem, &isCrown, &firstLineIndent)
        return (justification, isListItem != 0, isCrown != 0, firstLineIndent)
    }
}

/// Wrapper over TessResultIterator with RAII cleanup.
public final class TessResultIteratorWrapper {
    public let pointer: OpaquePointer
    private let ownsPointer: Bool

    init?(pointer: OpaquePointer?, ownsPointer: Bool) {
        guard let pointer else { return nil }
        self.pointer = pointer
        self.ownsPointer = ownsPointer
    }

    deinit {
        if ownsPointer {
            TessResultIteratorDelete(pointer)
        }
    }

    /// Deep copy of iterator.
    public func copy() -> TessResultIteratorWrapper? {
        TessResultIteratorWrapper(pointer: TessResultIteratorCopy(pointer), ownsPointer: true)
    }

    public func pageIterator() -> TessPageIteratorWrapper? {
        TessPageIteratorWrapper(pointer: TessResultIteratorGetPageIterator(pointer), ownsPointer: false)
    }

    public func pageIteratorConst() -> TessPageIteratorWrapper? {
        guard let constIterator = TessResultIteratorGetPageIteratorConst(pointer) else { return nil }
        return TessPageIteratorWrapper(pointer: constIterator, ownsPointer: false)
    }

    public func choiceIterator() -> TessChoiceIteratorWrapper? {
        TessChoiceIteratorWrapper(pointer: TessResultIteratorGetChoiceIterator(pointer), ownsPointer: true)
    }

    @discardableResult
    public func next(level: TessPageIteratorLevel = RIL_SYMBOL) -> Bool {
        TessResultIteratorNext(pointer, level) != 0
    }

    public func utf8Text(level: TessPageIteratorLevel = RIL_SYMBOL) -> String? {
        TesseractMemory.takeString(TessResultIteratorGetUTF8Text(pointer, level))
    }

    public func confidence(level: TessPageIteratorLevel = RIL_SYMBOL) -> Float {
        TessResultIteratorConfidence(pointer, level)
    }

#if canImport(CoreGraphics)
    public func boundingBoxRect(level: TessPageIteratorLevel = RIL_SYMBOL) -> CGRect? {
        pageIteratorConst()?.boundingBoxRect(level: level)
    }
#endif

    public func wordRecognitionLanguage() -> String? {
        TesseractMemory.string(fromConst: TessResultIteratorWordRecognitionLanguage(pointer))
    }

    public func wordFontAttributes() -> TessFontAttributes {
        var isBold: Int32 = 0
        var isItalic: Int32 = 0
        var isUnderlined: Int32 = 0
        var isMonospace: Int32 = 0
        var isSerif: Int32 = 0
        var isSmallcaps: Int32 = 0
        var pointsize: Int32 = 0
        var fontId: Int32 = 0
        let name = TesseractMemory.string(fromConst: TessResultIteratorWordFontAttributes(
            pointer,
            &isBold,
            &isItalic,
            &isUnderlined,
            &isMonospace,
            &isSerif,
            &isSmallcaps,
            &pointsize,
            &fontId
        ))
        return TessFontAttributes(
            name: name,
            isBold: isBold != 0,
            isItalic: isItalic != 0,
            isUnderlined: isUnderlined != 0,
            isMonospace: isMonospace != 0,
            isSerif: isSerif != 0,
            isSmallCaps: isSmallcaps != 0,
            pointSize: pointsize,
            fontId: fontId
        )
    }

    public func wordIsFromDictionary() -> Bool {
        TessResultIteratorWordIsFromDictionary(pointer) != 0
    }

    public func wordIsNumeric() -> Bool {
        TessResultIteratorWordIsNumeric(pointer) != 0
    }

    public func symbolIsSuperscript() -> Bool {
        TessResultIteratorSymbolIsSuperscript(pointer) != 0
    }

    public func symbolIsSubscript() -> Bool {
        TessResultIteratorSymbolIsSubscript(pointer) != 0
    }

    public func symbolIsDropcap() -> Bool {
        TessResultIteratorSymbolIsDropcap(pointer) != 0
    }
}

/// Wrapper over TessChoiceIterator with automatic cleanup.
public final class TessChoiceIteratorWrapper {
    public let pointer: OpaquePointer
    private let ownsPointer: Bool

    init?(pointer: OpaquePointer?, ownsPointer: Bool) {
        guard let pointer else { return nil }
        self.pointer = pointer
        self.ownsPointer = ownsPointer
    }

    deinit {
        if ownsPointer {
            TessChoiceIteratorDelete(pointer)
        }
    }

    @discardableResult
    public func next() -> Bool {
        TessChoiceIteratorNext(pointer) != 0
    }

    public func utf8Text() -> String? {
        TesseractMemory.string(fromConst: TessChoiceIteratorGetUTF8Text(pointer))
    }

    public func confidence() -> Float {
        TessChoiceIteratorConfidence(pointer)
    }
}
