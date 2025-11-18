# Repository Guidelines

This document describes how to work in this repository and serves as guidance for both human contributors and automated agents.

## Project Structure & Module Organization
- Root: build entrypoint `build.sh`, output directory `tesseract-macos-arm64` (headers and libraries), and `lib/Tesseract.xcframework`.
- Demos: `demo/macos` contains a minimal C console demo (`main.c`, `build_demo.sh`); `demo/ios` contains an Objective‑C integration example (`TesseractIOSDemo.m`, `README.md`).
- Do not commit large generated artifacts beyond the xcframework and minimal binaries needed for demos.

## Build, Test, and Development Commands
- Build macOS/iOS libraries and xcframework: `./build.sh` from the repo root (requires recent Xcode and command line tools).
- Build macOS C demo: `./demo/macos/build_demo.sh` (assumes `./tesseract-macos-arm64` exists).
- iOS demo: follow `demo/ios/README.md` to integrate `Tesseract.xcframework` into an Xcode project; there is no standalone build script.

## Distribution (CocoaPods & Swift Package)
- CocoaPods: the root `Tesseract.podspec` wraps `lib/Tesseract.xcframework` as a binary pod. To publish, push this repo to a Git remote, create a tag matching `s.version`, then run `pod spec lint` and push to your private or public spec repo.
- Swift Package: the root `Package.swift` exposes `lib/Tesseract.xcframework` as a binary target. To use it, point Xcode/SwiftPM to the Git URL of this repo and a tagged version; consumers can depend on the `Tesseract` library product.

## Coding Style & Naming Conventions
- C / Objective‑C: 4‑space indentation, no tabs; keep includes minimal (`<tesseract/capi.h>` for public API).
- Functions: use descriptive CamelCase for demo helpers (e.g., `RunTesseractDemo`); avoid abbreviations in new public APIs.
- Shell scripts: `bash`, `set -euo pipefail`, uppercase environment variables, and small, composable functions.

## Testing Guidelines
- There is no formal automated test suite; use the demos as smoke tests.
- After changes that affect the build, run `./build.sh`, then `./demo/macos/build_demo.sh` and execute `./demo/macos/tesseract-demo`.
- For iOS-related changes, rebuild the xcframework and run the iOS demo app on a device or simulator.

## Commit & Pull Request Guidelines
- Commits: use short, imperative summaries, optionally prefixed by area, e.g., `build: speed up tiff step` or `demo: add iOS usage note`.
- Pull requests: describe motivation, key changes, affected platforms (macOS/iOS), and manual test steps (commands run, OS/Xcode versions).

## Agent-Specific Instructions
- When modifying build scripts or demo sources, keep behavior backward compatible where possible and avoid changing default output paths.
- Prefer small, focused changes and update this document if you introduce new top‑level directories, commands, or workflows.
