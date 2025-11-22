# Tesseract OCR for Apple Platforms (Build & Release)

提供适用于 macOS（Apple Silicon）和 iOS（真机 & 模拟器）的预编译 [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) 库，包含 Swift 封装（`TesseractSwift`）和两个 macOS SwiftUI 示例。

- English version: [README.md](README.md)

仓库内容：

- `Package.swift`：指向 GitHub Releases 上已发布的 `Tesseract.xcframework.zip`（当前 5.5.1）。
- `Sources/TesseractSwift`：异步、安全的 Swift 封装，重新导出 C API。
- 示例在 `Examples/`：`TesseractSwiftDemo`（展示封装能力）和 `OCRTest`（最小 C API 包装）。两个示例均在 `Resources` 中内置 `eng.traineddata`。
- `build.sh`：本地一键构建脚本，生成 `tesseract-macos-arm64/` 和 `lib/Tesseract.xcframework`（可选包含 iOS）。

---

## 📥 安装

### 1. Swift Package Manager（推荐）

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/lexiaoyao20/tesseract-Apple.git", from: "5.5.1")
]
```

目标可选择产品：

- `Tesseract`：XCFramework 二进制（C API）。
- `TesseractSwift`：基于二进制目标的 Swift 封装。

Xcode 中：`File > Add Packages...`，填入 `https://github.com/lexiaoyao20/tesseract-Apple.git` 并选择最新 Tag。

### 2. 手动下载

在 [GitHub Releases](https://github.com/lexiaoyao20/tesseract-Apple/releases) 下载 `Tesseract.xcframework.zip`，解压后将 `Tesseract.xcframework` 拖入 Xcode，App 目标设置为 **Embed & Sign**。

---

## ⚠️ 语言包（Tessdata）

仓库未额外包含语言训练数据（示例仅带 `eng.traineddata`）。如需其他语言：

1. 从官方仓库下载 `.traineddata`，例如：
   - [tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast)（推荐，速度快）
   - [tessdata_best](https://github.com/tesseract-ocr/tessdata_best)（精度高）
2. 放入 App 资源目录（如 `Resources/tessdata`）。
3. 初始化 API 时将 `datapath` 指向包含 `tessdata` 的父目录。

Objective-C / C++ 示例：

```objc
// 假设 eng.traineddata 位于 App Bundle 的 "tessdata" 目录
NSString *datapath = [[NSBundle mainBundle] resourcePath];
// 或显式指定包含 tessdata 的父目录

TessBaseAPI *api = TessBaseAPICreate();
if (TessBaseAPIInit3(api, [datapath UTF8String], "eng") != 0) {
    NSLog(@"Could not initialize tesseract.");
    return;
}
```

---

## 🛠 手动构建（macOS + 可选 iOS）

在 Apple Silicon macOS 上运行（需 Xcode）：

```bash
chmod +x build.sh
./build.sh              # 同时构建 macOS + iOS（真机/模拟器）
ENABLE_IOS=0 ./build.sh # 仅 macOS
```

输出：

- `tesseract-macos-arm64/`：macOS 头文件和静态库。
- `tesseract-ios-arm64/`、`tesseract-ios-simulator/`：iOS 中间产物（若 `KEEP_INTERMEDIATE=1` 则保留）。
- `lib/Tesseract.xcframework`：包含 macOS/iOS arm64 的 XCFramework。

更多可配置项（部署版本、依赖版本）见 `build.sh` 顶部注释与环境变量。

---

## 🚀 Swift 封装用法

高阶异步接口，带可控日志：

```swift
import TesseractSwift

TesseractSwiftLog.isEnabled = true // DEBUG 默认开启

// 单图
let result = try await TesseractSwiftClient.recognize(url: imageURL)
print(result.text)

// 批量 + 进度
let cfg = OCRConfig(language: "eng", pageSegmentation: .singleBlock)
let results = try await TesseractSwiftClient.recognize(urls: imageURLs, config: cfg) { p in
    print("item \(p.currentIndex + 1)/\(p.total) \(p.itemProgress)%")
}
```

`OCRConfig` 覆盖语言、可选 tessdata 路径、引擎/PSM、变量（`OCRVariable.*` 常用 Key）、以及是否去除块分隔符。`OCRResultPayload` 返回文本、均值置信度及使用的模式。更底层的 HOCR/PDF/迭代器等能力可参考 `SwiftWrapper.md`，或直接使用导出的 C API。

---

## 🧪 示例

- `Examples/TesseractSwiftDemo`：SwiftPM 驱动的 macOS SwiftUI Demo，展示封装（进度、变量、自定义渲染）。打开 `.xcodeproj` 直接运行。
- `Examples/OCRTest`：基于 `TesseractWrapper` 的最小 C API 示例，macOS SwiftUI。打开 `.xcodeproj` 直接运行。

两个示例均内置 `Resources/eng.traineddata`，可离线运行。

---

## 📄 许可证

- 本仓库中的构建脚本和辅助代码：[Apache License 2.0](./LICENSE)。
- Tesseract OCR 及其依赖（如 Leptonica）：遵循各自上游许可。

在发布商业产品前，请确认已符合 Tesseract 及依赖的开源许可要求。
