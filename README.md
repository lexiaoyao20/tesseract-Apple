# Tesseract OCR for macOS & iOS (Apple Silicon)

Prebuilt [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) libraries and an XCFramework for macOS (Apple Silicon) and iOS, plus minimal C and Objective‑C demos.

This repository is intended as a convenient one‑key build and distribution wrapper around upstream Tesseract. It:

- Downloads and builds Tesseract and its core dependencies for Apple Silicon.
- Produces a unified installation directory for C projects on macOS.
- Optionally builds iOS libraries and a reusable `Tesseract.xcframework`.
- Provides small demos for macOS (C) and iOS (Objective‑C).
- Packages the XCFramework as a binary target for Swift Package Manager and CocoaPods.

> Note: This repo does **not** modify Tesseract itself; it only contains build scripts, packaging metadata, and prebuilt binaries for convenience. Please review the upstream project and license before shipping products.

---

## 1. Repository Layout

- `build.sh` – One‑key build script for macOS (arm64) and optional iOS.
- `tesseract-macos-arm64/` – Unified installation prefix for macOS (headers + libraries).
- `lib/Tesseract.xcframework` – Prebuilt XCFramework for macOS + iOS (if generated).
- `demo/macos/` – Minimal macOS C demo:
  - `build_demo.sh` – Builds the console demo binary `tesseract-demo`.
  - `main.c` – Prints the Tesseract version via the C API.
- `demo/ios/` – Minimal iOS integration example:
  - `TesseractIOSDemo.m` – Objective‑C demo code that calls Tesseract.
  - `README.md` – Step‑by‑step iOS integration guide.
- `Package.swift` – Swift Package manifest exposing `Tesseract.xcframework` as a binary target.
- `Tesseract.podspec` – CocoaPods spec wrapping `Tesseract.xcframework` as a binary pod.

Generated directories such as `build-macos-arm64`, `build-ios`, and intermediate `tesseract-ios-*` folders are created during the build and may be removed automatically depending on configuration.

---

## 2. Requirements

Build and usage have been tested primarily on recent macOS with Apple Silicon.

- macOS 11.0+ (Big Sur or later).
- Apple Silicon (arm64) machine.
- Xcode + Command Line Tools (for `clang`, SDKs, and `xcodebuild`).
- Common build tooling:
  - `git`, `curl`
  - `cmake`, `ninja`
  - Autotools: `autoconf`, `automake`, `libtool`, `pkg-config`

Most dependencies are downloaded and built automatically by `build.sh`. Ensure the above tools are installed (e.g. via Xcode and package managers such as Homebrew).

---

## 3. Building Tesseract Libraries

From the repository root:

```bash
chmod +x build.sh
./build.sh
```

The script will:

- Check your macOS version and required tools.
- Download and build:
  - `zlib`
  - `libpng`
  - `libjpeg-turbo`
  - `libtiff`
  - `Leptonica`
  - `Tesseract`
- Install everything into:
  - `./tesseract-macos-arm64` (macOS headers + static libraries)
- Optionally build iOS variants and create:
  - `./lib/Tesseract.xcframework`

### 3.1 Output Layout (macOS)

After a successful build, the primary macOS output is:

```text
tesseract-macos-arm64/
  include/          # Tesseract + Leptonica headers
  lib/
    libtesseract.a
    libtesseract_all.a
    # Other dependency static libraries
```

Key points:

- `libtesseract.a` – Core Tesseract static library.
- `libtesseract_all.a` – Convenience static library that bundles Tesseract and major dependencies, intended for direct linking from C projects.

### 3.2 iOS Build and XCFramework

By default, the script attempts to build both macOS and iOS (device + simulator) variants and then generate `lib/Tesseract.xcframework` via `xcodebuild`.

You can control behaviour with environment variables, for example:

```bash
# Build macOS only (skip iOS)
ENABLE_IOS=0 ./build.sh

# Customize minimum deployment targets
MACOS_MIN_VERSION=12.0 IOS_MIN_VERSION=14.0 ./build.sh
```

If `xcodebuild` is not available, the XCFramework creation step will be skipped, but the macOS libraries will still be produced.

---

## 4. Using Tesseract from C on macOS

Once `./build.sh` has completed:

```bash
export TESS_ROOT="$(pwd)/tesseract-macos-arm64"

clang -std=c11 main.c \
  -I"$TESS_ROOT/include" \
  -L"$TESS_ROOT/lib" \
  -ltesseract_all \
  -framework CoreFoundation \
  -framework CoreGraphics \
  -framework ImageIO \
  -framework Accelerate
```

Where your `main.c` might include the C API header:

```c
#include <tesseract/capi.h>
```

You can also use the provided macOS demo as a smoke test (see below).

---

## 5. Demos

### 5.1 macOS C Demo

The macOS demo lives in `demo/macos` and simply prints the Tesseract version using the C API.

Steps:

```bash
# 1) Build libraries and headers
./build.sh

# 2) Build the demo
./demo/macos/build_demo.sh

# 3) Run the demo
./demo/macos/tesseract-demo
```

You should see the Tesseract version and a confirmation message if linking succeeded.

### 5.2 iOS Objective‑C Demo

The iOS example in `demo/ios` shows how to integrate `Tesseract.xcframework` into an iOS 13+ app using Objective‑C.

High‑level steps (see `demo/ios/README.md` for details):

1. Run `./build.sh` to generate `Tesseract.xcframework` in the repo root.
2. Create a new iOS App project in Xcode (iOS 13+).
3. Drag `Tesseract.xcframework` into the Xcode project navigator:
   - Check “Copy items if needed”.
   - Add it to your app target.
4. In your target’s **General → Frameworks, Libraries, and Embedded Content**, set `Tesseract.xcframework` to **Embed & Sign**.
5. Add `TesseractIOSDemo.m` to your project and call the demo function:

   ```objc
   #import "TesseractIOSDemo.h"

   - (void)viewDidLoad {
       [super viewDidLoad];
       RunTesseractDemo();
   }
   ```

`RunTesseractDemo()` uses `TessVersion()` to print the current Tesseract version and validate linkage.

> For real OCR usage you also need appropriate `*.traineddata` language files and must configure `TESSDATA_PREFIX` or pass the data path via `TessBaseAPIInit3`. This repository does not bundle language data.

---

## 6. Swift Package Manager Integration

This repository includes a `Package.swift` that exposes `Tesseract.xcframework` as a binary target for both iOS and macOS:

- Target name: `Tesseract`
- Library product: `Tesseract`

To consume it from another project:

1. Push this repository to a Git remote.
2. Create a Git tag (e.g. `0.1.0`) for the version you want to distribute.
3. In your Xcode project or `Package.swift`, add the package dependency pointing to that Git URL and version.

Example `Package.swift` snippet in a client project:

```swift
dependencies: [
    .package(url: "https://example.com/your/tesseract-release.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "Tesseract", package: "tesseract-release")
        ]
    )
]
```

Then import and link `Tesseract` as a binary framework in your Swift or Objective‑C code as usual.

---

## 7. CocoaPods Integration

The root `Tesseract.podspec` wraps `lib/Tesseract.xcframework` as a binary pod.

To use it in your own projects:

1. Update the following fields in `Tesseract.podspec`:
   - `s.homepage`
   - `s.license`
   - `s.authors`
   - `s.source` (Git URL and tag)
2. Push this repository to the Git URL configured in the podspec.
3. Create a Git tag matching `s.version` (e.g. `0.1.0`).
4. Validate the spec:

   ```bash
   pod spec lint Tesseract.podspec
   ```

5. Push the spec to your private or public specs repo (e.g. `trunk`).

In a consuming project’s `Podfile`:

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'Tesseract', '~> 0.1'
end
```

Then run `pod install` and open the generated workspace.

---

## 8. Configuration & Environment Variables

`build.sh` supports several environment variables to customize the build:

- `MACOS_MIN_VERSION` – Minimum macOS deployment target (default `11.0`).
- `ARCH` – Target architecture (default `arm64`).
- `BUILD_TYPE` – CMake build type, e.g. `Release` (default) or `Debug`.
- `IOS_MIN_VERSION` – Minimum iOS deployment target (default `13.0`).
- `IOS_ARCH_DEVICE` – iOS device architecture (default `arm64`).
- `IOS_ARCH_SIMULATOR` – iOS simulator architecture (default `arm64`).
- `ENABLE_IOS` – `1` to build iOS libraries and XCFramework (default), `0` to build macOS only.
- `KEEP_INTERMEDIATE` – `0` to delete intermediate build directories (default), `1` to keep them.
- `TESSERACT_VERSION`, `LEPTONICA_VERSION`, `ZLIB_VERSION`, `LIBPNG_VERSION`, `LIBTIFF_VERSION`, `LIBJPEG_TURBO_VERSION` – Versions of upstream dependencies to build.

Example: build only macOS, keep intermediate artifacts, and use a custom macOS minimum version:

```bash
ENABLE_IOS=0 KEEP_INTERMEDIATE=1 MACOS_MIN_VERSION=12.0 ./build.sh
```

---

## 9. Testing & Troubleshooting

- After modifying the build script or dependency versions:
  - Re‑run `./build.sh`.
  - Rebuild and run the macOS demo: `./demo/macos/build_demo.sh` then `./demo/macos/tesseract-demo`.
- For iOS changes:
  - Regenerate the XCFramework via `./build.sh`.
  - Re‑run the iOS demo app on a device or simulator following `demo/ios/README.md`.

Common issues:

- **Missing build tools** – Make sure Xcode, Command Line Tools, and utilities like `cmake`, `ninja`, `pkg-config`, and autotools are installed.
- **XCFramework not generated** – If `xcodebuild` is not available or iOS libraries fail to build, the script will skip XCFramework creation; check the build log for warnings.
- **Link errors in your app** – Verify that you link against `libtesseract_all.a` on macOS and that the required system frameworks (`CoreFoundation`, `CoreGraphics`, `ImageIO`, `Accelerate`) are included.

---

## 10. Licensing

Tesseract OCR itself is licensed under the Apache License 2.0. This repository only provides build scripts, prebuilt binaries, and packaging metadata around the upstream project.

- Please review the upstream Tesseract repository and license to ensure your use complies with all terms.
- The default `Tesseract.podspec` is configured for Apache 2.0 but includes TODO comments; adjust it as needed to match your actual distribution.

If you redistribute the binaries produced by this repository, you are responsible for complying with all upstream licenses (Tesseract, Leptonica, and other dependencies).

---

## 11. Contributing

- Keep behaviour backward‑compatible where possible and avoid changing default output paths.
- Prefer small, focused changes.
- After any build‑related change, re‑run:
  - `./build.sh`
  - `./demo/macos/build_demo.sh`
  - `./demo/macos/tesseract-demo`

Pull requests should describe:

- Motivation and high‑level changes.
- Affected platforms (macOS and/or iOS).
- Manual test steps (commands run, macOS/Xcode versions).

