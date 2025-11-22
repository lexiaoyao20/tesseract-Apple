# TesseractSwift 简洁封装

面向应用的高阶客户端 `TesseractSwiftClient`，开箱即可完成“输入图片 → 输出文本”，支持批量与进度回调。日志可用 `TesseractSwiftLog.isEnabled` 控制（DEBUG 默认开启）。

## 安装（SwiftPM）

```swift
.package(url: "https://github.com/lexiaoyao20/tesseract-Apple.git", from: "5.5.1")
```

产品：`TesseractSwift`

## 快速上手

```swift
import TesseractSwift

// 日志开关
TesseractSwiftLog.isEnabled = true

// 单图：支持 Data / URL / NSImage / UIImage
let single = try await TesseractSwiftClient.recognize(url: imageURL)
print(single.text)

// 批量 + 进度
let cfg = OCRConfig(language: "eng", pageSegmentation: .singleBlock)
let results = try await TesseractSwiftClient.recognize(urls: images, config: cfg) { p in
    print("item \(p.currentIndex + 1)/\(p.total) \(p.itemProgress)%")
}
results.forEach { print($0.text) }
```

## 配置与返回

- `OCRConfig`: 语言、可选 `tessdata` 路径、引擎模式、PSM、变量（常用 key 可用 `OCRVariable.*`）、是否关闭块/行分隔符（避免多余空行）。
- `OCRResultPayload`: 文本、均值置信度、使用的引擎/PSM/数据路径。

需要 HOCR/PDF/迭代器等深度能力时，可直接使用导出的 C API 或自建 `TesseractSwiftAPI`。
