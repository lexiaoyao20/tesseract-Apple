import AppKit
import CoreGraphics
import TesseractSwift

enum ImageUtilities {
    static func pixImage(from image: NSImage) -> PixImage? {
        PixImage(nsImage: image)
    }

    static func pixImage(fromFileURL url: URL) -> PixImage? {
        PixImage(path: url.path)
    }

    /// Best-effort DPI estimate from the first bitmap representation.
    static func estimatedPPI(for image: NSImage) -> Int? {
        guard let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else { return nil }
        let inchesWide = rep.size.width / 72.0
        guard inchesWide > 0 else { return nil }
        let ppi = Int(round(Double(rep.pixelsWide) / Double(inchesWide)))
        return ppi > 0 ? ppi : nil
    }

    static func image(from url: URL) -> NSImage? {
        NSImage(contentsOf: url)
    }

    /// Generate a sample image at runtime so we don't need to ship assets.
    static func sampleImage() -> NSImage {
        let size = NSSize(width: 640, height: 320)
        let image = NSImage(size: size)
        image.lockFocus()
        let bounds = NSRect(origin: .zero, size: size)
        let gradient = NSGradient(colors: [NSColor.systemTeal, NSColor.systemIndigo])
        gradient?.draw(in: bounds, angle: 90)

        let text = "Tesseract Swift Demo\n1234567890 ABC xyz"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 26, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textRect = bounds.insetBy(dx: 24, dy: 60)
        attributed.draw(in: textRect)

        let badge = "PSM_AUTO | OEM_DEFAULT"
        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.systemYellow
        ]
        let badgePoint = NSPoint(x: 20, y: 16)
        badge.draw(at: badgePoint, withAttributes: badgeAttributes)

        image.unlockFocus()
        return image
    }
}
