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
            checksum: "d272c98eecb64581a4f8a8d963d27cbdc956b9fbb2c3040777ea472cd8ac9d3c"
        ),
    ]
)
