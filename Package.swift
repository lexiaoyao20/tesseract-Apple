// swift-tools-version:5.7
// Upstream Tesseract OCR version: 5.5.1

import PackageDescription

let package = Package(
    name: "Tesseract",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "Tesseract",
            targets: ["Tesseract"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "Tesseract",
            url: "https://github.com/lexiaoyao20/tesseract-release/releases/download/5.5.1/Tesseract.xcframework.zip",
            checksum: "91a73114c4c6eee083963534fdd47ac42021b5f1ef97a49c888f5913228fd8dc"
        ),
    ]
)
