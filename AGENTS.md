# Repository Guidelines

This document describes how to work in this repository and serves as guidance for both human contributors and automated agents.

## Project Structure & Module Organization
- Root: build entrypoint `build.sh`; local outputs land in `tesseract-macos-arm64/` (headers + libs), `tesseract-ios-arm64/`, `tesseract-ios-simulator/`, and `lib/Tesseract.xcframework` when iOS is enabled.
- Package managers: `Package.swift` exposes the binary target `Tesseract` and Swift overlay `TesseractSwift`.
- Swift overlay: `Sources/TesseractSwift` re-exports the C API and adds async wrappers (`TesseractSwiftClient`, helpers, iterators, renderers). See `SwiftWrapper.md` for usage notes.
- Demos: `Examples/TesseractSwiftDemo` (SwiftPM macOS SwiftUI app showcasing the overlay with progress, variables, and renderers) and `Examples/OCRTest` (macOS SwiftUI sample using a minimal C-API wrapper `TesseractWrapper`). Both embed `eng.traineddata` under `Resources/`.
- Do not commit large generated artifacts beyond the xcframework zip referenced by releases and the small traineddata files already in `Examples/**/Resources`.

## Build, Test, and Development Commands
- Build macOS/iOS libraries and xcframework: `./build.sh` (requires recent Xcode and command line tools). Outputs to `tesseract-*` and `lib/Tesseract.xcframework`.
- Swift overlay development: open `Package.swift` in Xcode or use SwiftPM; the binary target is downloaded from GitHub Releases.
- Demos: open `Examples/TesseractSwiftDemo/TesseractSwiftDemo.xcodeproj` (overlay demo) or `Examples/OCRTest/OCRTest.xcodeproj` (minimal C API) in Xcode and run on macOS. Both demos rely on the bundled `eng.traineddata`.

## Distribution (Swift Package)
- Swift Package: `Package.swift` points the `Tesseract` binary target at the GitHub Release zip and exposes `TesseractSwift` as a Swift target. Consumers add the repo URL and depend on either `Tesseract` or `TesseractSwift`.

## Coding Style & Naming Conventions
- Swift: follow existing style (4 spaces, explicit `self` where needed, prefer small helpers, async APIs in `TesseractSwift` stay thin over the C API). Keep demo code readable.
- Shell scripts: `bash`, `set -euo pipefail`, uppercase environment variables, and small, composable functions.

## Testing Guidelines
- There is no formal automated test suite; use the demos as smoke tests.
- After changes that affect the build, run `./build.sh` and ensure the binary target still resolves in SwiftPM/Xcode.
- For Swift overlay updates, open and run `Examples/TesseractSwiftDemo` on macOS; for low-level API changes, run `Examples/OCRTest`.

## Commit & Pull Request Guidelines
- Commits: use short, imperative summaries, optionally prefixed by area, e.g., `build: speed up tiff step` or `demo: add iOS usage note`.
- Pull requests: describe motivation, key changes, affected platforms (macOS/iOS), and manual test steps (commands run, OS/Xcode versions).

## Agent-Specific Instructions
- Keep `build.sh` output locations stable (`tesseract-*`, `lib/Tesseract.xcframework`) to avoid breaking consumers and release packaging.
- Prefer small, focused changes and update this document if you introduce new top-level directories, commands, or workflows.
