# Tesseract OCR for Apple Platforms (Build & Release)

Prebuilt [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) libraries for macOS (Apple Silicon) and iOS (device & simulator), plus a Swift overlay (`TesseractSwift`) and two macOS SwiftUI demos.

- 中文文档请查看: [README_cn.md](README_cn.md)

What's included:

- `Package.swift` points to the published `Tesseract.xcframework.zip` (v5.5.1) hosted on GitHub Releases.
- `Sources/TesseractSwift`: async, memory-safe Swift wrappers that re-export the C API.
- Demos under `Examples/`: `TesseractSwiftDemo` (overlay showcase) and `OCRTest` (minimal C API wrapper). Each ships `eng.traineddata` under `Resources` for out-of-the-box runs.
- `build.sh`: local one-key build for macOS + optional iOS, producing `tesseract-macos-arm64/` and `lib/Tesseract.xcframework`.

---

## 📥 Installation

### 1. Swift Package Manager (recommended)

Add this repository as a package dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/lexiaoyao20/tesseract-Apple.git", from: "5.5.1")
]
```

Targets can depend on either product:

- `Tesseract` – the binary XCFramework (C API).
- `TesseractSwift` – the Swift overlay built atop the binary target.

In Xcode:

1. Choose `File > Add Packages...`.
2. Enter `https://github.com/lexiaoyao20/tesseract-Apple.git`.
3. Pick the latest tag.

### 2. Manual download

Grab the latest `Tesseract.xcframework.zip` from [GitHub Releases](https://github.com/lexiaoyao20/tesseract-Apple/releases), unzip, and drag `Tesseract.xcframework` into Xcode (set to **Embed & Sign** for app targets).

---

## ⚠️ Tessdata (Language Packs)

The repository does **not** bundle language training data beyond the demo `eng.traineddata`. To use other languages:

1. Download `.traineddata` files you need from official sources such as:
   - [tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast) (recommended – faster)
   - [tessdata_best](https://github.com/tesseract-ocr/tessdata_best) (higher accuracy, slower)
2. Add them to your app bundle (for example `Resources/tessdata`).
3. Point `datapath` to the parent directory when initialising the API.

Objective-C / C++ example:

```objc
// Assume eng.traineddata is inside the "tessdata" folder in the app bundle
NSString *datapath = [[NSBundle mainBundle] resourcePath];
// Or explicitly point to the parent directory that contains "tessdata"

TessBaseAPI *api = TessBaseAPICreate();
// Initialise with data path and language
if (TessBaseAPIInit3(api, [datapath UTF8String], "eng") != 0) {
    NSLog(@"Could not initialize tesseract.");
    return;
}
```

---

## 🛠 Manual Build (macOS + optional iOS)

For custom builds, run the one-key script on Apple Silicon macOS (Xcode required):

```bash
chmod +x build.sh
./build.sh           # macOS + iOS (arm64 + simulator)
ENABLE_IOS=0 ./build.sh  # macOS only
```

Outputs:

- `tesseract-macos-arm64/` – headers and static libs for macOS.
- `tesseract-ios-arm64/` and `tesseract-ios-simulator/` – intermediate iOS builds (kept if `KEEP_INTERMEDIATE=1`).
- `lib/Tesseract.xcframework` – XCFramework combining macOS/iOS arm64 slices.

Additional options (deployment targets, versions) are documented at the top of `build.sh`.

---

## 🚀 Swift Usage (Overlay Facade)

High-level async facade with optional logging:

```swift
import TesseractSwift

// Enable verbose logs (on by default in DEBUG)
TesseractSwiftLog.isEnabled = true

// Single image
let result = try await TesseractSwiftClient.recognize(url: imageURL)
print(result.text)

// Batch with progress
let cfg = OCRConfig(language: "eng", pageSegmentation: .singleBlock)
let results = try await TesseractSwiftClient.recognize(urls: imageURLs, config: cfg) { p in
    print("item \(p.currentIndex + 1)/\(p.total) \(p.itemProgress)%")
}
```

`OCRConfig` covers language, optional tessdata path, engine/PSM, variables (use `OCRVariable.*`), and a flag to suppress block separators. `OCRResultPayload` returns text plus confidence and the modes used. For lower-level control (HOCR/PDF/iterators), see `SwiftWrapper.md` or use the exported C API directly.

---

## 🧪 Demos

- `Examples/TesseractSwiftDemo`: SwiftPM-driven macOS SwiftUI app showcasing the overlay (progress, custom variables, rendered tokens). Open the `.xcodeproj` and run.
- `Examples/OCRTest`: minimal macOS SwiftUI sample using `TesseractWrapper` over the C API. Open the `.xcodeproj` and run.

Both include `Resources/eng.traineddata` so they run offline.

---

## 📄 Licensing

- Build scripts and helper code in this repository: [Apache License 2.0](./LICENSE).
- Tesseract OCR and its dependencies (such as Leptonica) are licensed under their respective upstream licenses.

Before shipping commercial products using this library, ensure you comply with the Tesseract and dependency licenses.
