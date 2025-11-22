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
            checksum: "d66dd118516292a5b2cf3aa5747941a205afc259d090e97ce5cd65f9b4ebcf0c"
        ),
        .target(
            name: "TesseractSwift",
            dependencies: ["Tesseract"],
            path: "Sources/TesseractSwift"
        ),
    ]
)
