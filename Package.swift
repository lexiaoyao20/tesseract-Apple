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
        .library(
            name: "TesseractSwift",
            targets: ["TesseractSwift"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "Tesseract",
            url: "https://github.com/lexiaoyao20/tesseract-Apple/releases/download/5.5.1/Tesseract.xcframework.zip",
            checksum: "c7857a4b891314f3c67a20763dc50ed37a54f482458e7d67c04debce2025f572"
        ),
        .target(
            name: "TesseractSwift",
            dependencies: ["Tesseract"],
            path: "Sources/TesseractSwift"
        ),
    ]
)
