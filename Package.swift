// swift-tools-version:5.7
// Upstream Tesseract OCR version: 5.5.2

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
            url: "https://github.com/lexiaoyao20/tesseract-Apple/releases/download/5.5.2/Tesseract.xcframework.zip",
            checksum: "869192e6af23919fe67699fa678668de7199e2f6646d427bc92e14b8b005fce8"
        ),
        .target(
            name: "TesseractSwift",
            dependencies: ["Tesseract"],
            path: "Sources/TesseractSwift"
        ),
    ]
)
