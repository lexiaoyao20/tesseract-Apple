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
            path: "lib/Tesseract.xcframework"
        ),
    ]
)
