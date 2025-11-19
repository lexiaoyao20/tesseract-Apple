# Tesseract OCR for Apple Platforms (Build & Release)

本项目提供适用于 macOS（Apple Silicon）和 iOS（真机 & 模拟器）的预编译 [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) 库。

---

## 核心特性

- 🚀 自动化：每天定时检测上游 Tesseract Release，发现新版本后自动编译、打包、发布。
- 📦 XCFramework 支持：提供包含 arm64 架构的 `Tesseract.xcframework`，同时支持 iOS 和 macOS。
- ⚡️ 二进制分发：通过 GitHub Releases 托管 Zip 产物，避免 Git 仓库体积膨胀，下载更快。
- 🛠 包管理支持：开箱即用的 Swift Package Manager (SPM) 和 CocoaPods。

---

## 📥 安装指南

### 1. Swift Package Manager（推荐）

在你的 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/lexiaoyao20/tesseract-Apple.git", from: "5.5.1")
]
```

或者在 Xcode 中：

1. 选择 `File > Add Packages...`
2. 输入仓库地址：`https://github.com/lexiaoyao20/tesseract-Apple.git`
3. 选择最新版本或指定的 Tag。

原理：CI 构建完成后，会自动更新本仓库的 `Package.swift`，填入最新 Release 的下载地址（`url`）和对应的 SHA256 校验值（`checksum`），客户端只需声明依赖即可。

### 2. CocoaPods

在你的 `Podfile` 中添加（使用 git 源，CocoaPods 会自动读取根目录的 podspec）：

```ruby
pod 'Tesseract', :git => 'https://github.com/lexiaoyao20/tesseract-Apple.git'
```

原理：CI 构建完成后，会自动更新 `Tesseract.podspec` 的 `s.source` 字段，将其指向 GitHub Release 的 HTTP 下载链接，确保用户拉取到的是预编译好的二进制包。

### 3. 手动下载

你也可以在 [GitHub Releases](https://github.com/lexiaoyao20/tesseract-Apple/releases) 页面下载最新的 `Tesseract.xcframework.zip`，解压后将 `Tesseract.xcframework` 直接拖入你的 Xcode 项目中，并设置为 **Embed & Sign**。

---

## ⚠️ 关于语言包（Tessdata）

本库仅包含 Tesseract 的二进制引擎，不包含语言训练数据（`.traineddata` 文件）。为了让 OCR 正常工作，你需要：

1. 从官方仓库下载所需语言数据（例如 `eng.traineddata`、`chi_sim.traineddata`），常用源：
   - [tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast)（推荐，速度快）
   - [tessdata_best](https://github.com/tesseract-ocr/tessdata_best)（精度高，速度慢）
2. 将这些文件放入你的 App 资源目录（例如 Bundle 内的 `tessdata` 文件夹）。
3. 在初始化 Tesseract API 时，指定 `datapath`。

Objective‑C / C++ 示例：

```objc
// 假设你已将 eng.traineddata 放入了 App Bundle 的 "tessdata" 文件夹中
NSString *datapath = [[NSBundle mainBundle] resourcePath];
// 或者直接指定包含 tessdata 文件夹的父目录路径

TessBaseAPI *api = TessBaseAPICreate();
// 初始化：指定数据路径和语言
if (TessBaseAPIInit3(api, [datapath UTF8String], "eng") != 0) {
    NSLog(@"Could not initialize tesseract.");
    return;
}
```

---

## 🏗 自动化构建流程

本项目使用 GitHub Actions 实现全自动维护（`.github/workflows/auto-build-tesseract.yml`）：

- **Check**：每天定时运行，或手动触发；脚本比对 [tesseract-ocr/tesseract](https://github.com/tesseract-ocr/tesseract) 的最新 Release Tag 与本仓库已存在的 Tag。
- **Build**：若发现新版本（且本仓库尚未构建过），在 `macos-latest` 环境下运行 `build.sh`：
  - 自动下载并编译依赖：zlib、libpng、libjpeg‑turbo、libtiff、leptonica；
  - 编译 Tesseract（macOS arm64 + iOS arm64 / Simulator）；
  - 生成 `Tesseract.xcframework`。
- **Release**：将生成的 `Tesseract.xcframework` 压缩为 Zip，上传到 GitHub Releases。
- **Update**：
  - 计算 Zip 包的 SHA256 校验值；
  - 修改 `Package.swift`：更新 `binaryTarget` 的 `url` 和 `checksum`；
  - 修改 `Tesseract.podspec`：更新 `version` 和 `source`（HTTP URL）。
- **Commit**：将上述配置文件的变更提交到仓库，完成版本更新。

---

## 🛠 手动构建

如果你需要自己手动编译（例如修改编译选项），需要在 macOS（Apple Silicon）环境下操作。

前置要求：

- Xcode & Command Line Tools
- `cmake`、`ninja`、`automake`、`autoconf`、`libtool`、`pkg-config`、`wget` 或 `curl`

### 步骤

1. 克隆仓库：

   ```bash
   git clone https://github.com/lexiaoyao20/tesseract-Apple.git
   cd tesseract-Apple
   ```

2. 运行构建脚本：

   ```bash
   chmod +x build.sh
   ./build.sh
   ```

构建过程中会生成：

- `tesseract-macos-arm64/`（macOS 静态库与头文件，主要用于构建过程和高级用法）
- `lib/Tesseract.xcframework`（最终推荐使用的产物）

你可以通过环境变量自定义构建，例如只构建 macOS 版本：

```bash
ENABLE_IOS=0 ./build.sh
```

更多可选参数（如最低系统版本等），可以直接查看 `build.sh` 顶部注释与环境变量说明。

---

## 📄 许可证

- 本仓库中的构建脚本和辅助代码：[Apache License 2.0](./LICENSE)。
- Tesseract OCR 及依赖库（Leptonica 等）：请遵循其各自的上游许可证（通常为 Apache 2.0 或类似开源协议）。

在使用本库发布商业产品前，请务必确认已符合 Tesseract 及其依赖的开源许可要求。
