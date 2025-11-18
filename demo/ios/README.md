# Tesseract iOS Demo 使用说明

本目录提供一个最小化的 iOS 使用示例，演示如何在 iOS 13+ 工程中使用 `Tesseract.xcframework`。

## 1. 先构建 xcframework

在仓库根目录运行：

```bash
./build.sh
```

确保环境中已安装 Xcode，脚本会在成功构建后生成：

- `Tesseract.xcframework`

## 2. 创建 iOS 工程并集成 xcframework

1. 在 Xcode 中创建一个新的 iOS App 工程（iOS 13+）。
2. 将仓库根目录下的 `Tesseract.xcframework` 拖入工程导航栏：
   - 勾选 “Copy items if needed”
   - 勾选目标 Target（iOS App）
3. 确认在 Target → General → Frameworks, Libraries, and Embedded Content 中：
   - `Tesseract.xcframework` 的 Embed 选项为 “Embed & Sign”。

## 3. 在 Objective‑C 代码中调用 Tesseract

将本目录中的 `TesseractIOSDemo.m` 拷贝到你的工程中，并在需要的地方调用：

```objc
#import "TesseractIOSDemo.h"

- (void)viewDidLoad {
    [super viewDidLoad];
    RunTesseractDemo();
}
```

`TesseractIOSDemo.m` 内部示例通过 `TessVersion()` 打印当前 Tesseract 版本，验证链接是否成功。

> 注意：如果你需要实际进行 OCR 识别，还需要准备对应语言的 `*.traineddata` 文件，并通过 `TESSDATA_PREFIX` 或 `TessBaseAPIInit3` 的 `datapath` 参数指定语言数据路径。

