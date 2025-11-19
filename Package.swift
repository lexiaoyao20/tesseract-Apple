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
            url: "https://github.com/lexiaoyao20/tesseract-Apple/releases/download/5.5.1/Tesseract.xcframework.zip",
            checksum: "ae466a144c3793ea0284c5feab2116d8a1bc7833f4803bafd55235c49bfc9d9b"
        ),
    ]
)
