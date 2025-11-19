# Tesseract OCR for Apple Platforms (Build & Release)

Prebuilt [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) libraries for macOS (Apple Silicon) and iOS (device & simulator), delivered as a single XCFramework.

- Chinese docs: [README_cn.md](README_cn.md)

You can consume it in three ways:

1. **Recommended** – via Swift Package Manager (binary target).
2. Via CocoaPods as a binary pod.
3. Manually, by downloading or building `Tesseract.xcframework` yourself.

> This repo does **not** modify upstream Tesseract. It only contains build scripts, packaging metadata, and prebuilt binaries. Always review the upstream project and licenses before shipping products.

---

## Core Features

- 🚀 Automated updates: A GitHub Actions workflow checks upstream Tesseract releases daily and on manual trigger. When a new version appears, it automatically builds, packages, and publishes.
- 📦 XCFramework support: Ships `Tesseract.xcframework` with arm64 slices for iOS and macOS.
- ⚡️ Binary distribution: Uses GitHub Releases to host the zip artifact, avoiding Git repo bloat and speeding up downloads.
- 🛠 Package managers: First‑class support for Swift Package Manager (SPM) and CocoaPods.

---

## 📥 Installation

### 1. Swift Package Manager (recommended)

Add this repository as a package dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/lexiaoyao20/tesseract-Apple.git", from: "5.5.1")
]
```

Or in Xcode:

1. Choose `File > Add Packages...`.
2. Enter the repo URL: `https://github.com/lexiaoyao20/tesseract-Apple.git`.
3. Select the latest version or a specific tag.

How it works: after CI finishes a build, it automatically updates this repo’s `Package.swift` to point the `binaryTarget` at the latest GitHub Release URL and SHA256 `checksum`. Your app only needs to declare the dependency.

### 2. CocoaPods

In your `Podfile`, using the git source (CocoaPods will read the podspec at the repo root):

```ruby
pod 'Tesseract', :git => 'https://github.com/lexiaoyao20/tesseract-Apple.git'
```

If you have published this pod into a private Specs repo, you can instead use:

```ruby
pod 'Tesseract'
```

How it works: after CI builds a new XCFramework, it updates `Tesseract.podspec`’s `s.source` to point at the GitHub Release HTTP URL, so consumers always download the prebuilt binary zip.

### 3. Manual download

You can also download the latest `Tesseract.xcframework.zip` from the GitHub Releases page, unzip it, and drag `Tesseract.xcframework` directly into your Xcode project, setting it to **Embed & Sign** for your app target.

---

## ⚠️ Tessdata (Language Packs)

This repo only ships the Tesseract engine binaries. It does **not** include language training data (`.traineddata` files).

To make OCR work you must:

1. Download the language data you need (for example `eng.traineddata`, `chi_sim.traineddata`) from official sources such as:
   - `tessdata_fast` (recommended – faster)
   - `tessdata_best` (higher accuracy, slower)
2. Add those files to your app’s resources (for example, a `tessdata` folder in the app bundle).
3. Pass the correct `datapath` when initialising the Tesseract API.

Objective‑C / C++ example:

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

## 🏗 Automated Build & Release Pipeline

This repo uses GitHub Actions (`.github/workflows/auto-build-tesseract.yml`) to keep everything up to date:

- **Check**:
  - Runs daily on schedule or via manual dispatch.
  - Compares the latest numeric tag from `tesseract-ocr/tesseract` with local tags in this repo.
- **Build** (only if a new upstream version is found and not yet built here):
  - Runs `build.sh` on `macos-latest`.
  - Automatically downloads and builds dependencies: zlib, libpng, libjpeg‑turbo, libtiff, leptonica.
  - Builds Tesseract for macOS arm64 + iOS arm64 / simulator.
  - Produces `lib/Tesseract.xcframework`.
- **Release**:
  - Zips `lib/Tesseract.xcframework` as `Tesseract.xcframework.zip`.
  - Uploads it to a new GitHub Release for that version.
- **Update**:
  - Computes the SHA256 checksum of the zip.
  - Updates `Package.swift` (binary target `url` and `checksum`).
  - Updates `Tesseract.podspec` (`version` and HTTP `source`).
- **Commit**:
  - Commits and pushes changes to config files so the repo stays in sync with the latest upstream Tesseract.

As a consumer you normally just depend on a tagged version of this repo via SwiftPM or CocoaPods; CI guarantees that the tag corresponds to a valid prebuilt XCFramework.

---

## 🛠 Manual Build (Advanced)

If you want to build locally (for example to tweak build options), you need a macOS Apple Silicon environment.

Prerequisites:

- Xcode & Command Line Tools
- `cmake`, `ninja`, `automake`, `autoconf`, `libtool`, `pkg-config`, `wget` or `curl`

### Steps

1. Clone the repo:

   ```bash
   git clone https://github.com/lexiaoyao20/tesseract-Apple.git
   cd tesseract-Apple
   ```

2. Run the build script:

   ```bash
   chmod +x build.sh
   ./build.sh
   ```

Build outputs include:

- `tesseract-macos-arm64/` – macOS static libraries and headers (primarily for internal use and advanced C integrations).
- `lib/Tesseract.xcframework` – the main artifact recommended for app integration.

You can customise the build via environment variables, for example to build macOS only:

```bash
ENABLE_IOS=0 ./build.sh
```

Additional options (such as minimum deployment targets) are documented in comments and env vars at the top of `build.sh`.

---

## 📄 Licensing

- Build scripts and helper code in this repository: Apache License 2.0.
- Tesseract OCR and its dependencies (such as Leptonica) are licensed under their respective upstream licenses (commonly Apache 2.0 or similar).

Before shipping commercial products using this library, ensure you comply with the Tesseract and dependency licenses.
