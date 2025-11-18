# Tesseract OCR for macOS & iOS（Apple Silicon 预编译版本）

本仓库提供预编译的 [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) 库以及适用于 macOS（Apple Silicon）和 iOS 的 `Tesseract.xcframework`，并附带最小化的 C / Objective‑C 演示示例。

它的目标是作为上游 Tesseract 的“一键构建与分发包装”，主要功能包括：

- 自动下载并构建 Tesseract 及核心依赖（zlib、libpng、libjpeg‑turbo、libtiff、Leptonica）。
- 为 macOS C 项目提供统一的安装目录（头文件 + 静态库）。
- 可选构建 iOS（真机 + 模拟器）版本并生成可复用的 `Tesseract.xcframework`。
- 提供 macOS（C）和 iOS（Objective‑C）两个最小 Demo。
- 通过 Swift Package Manager 和 CocoaPods 暴露为二进制依赖。

> 注意：本仓库**不修改** Tesseract 本身，只提供构建脚本、打包配置和预编译二进制。发布产品前请务必阅读上游项目及其许可证。

---

## 1. 仓库结构

- `build.sh` – 一键构建脚本，支持 macOS（arm64）和可选 iOS。
- `tesseract-macos-arm64/` – macOS 统一安装前缀（头文件 + 库文件）。
- `lib/Tesseract.xcframework` – 预编译的 XCFramework（若已成功生成）。
- `demo/macos/` – macOS C 控制台 Demo：
  - `build_demo.sh` – 构建 Demo 可执行文件 `tesseract-demo`。
  - `main.c` – 使用 C API 打印 Tesseract 版本。
- `demo/ios/` – iOS 集成示例：
  - `TesseractIOSDemo.m` – Objective‑C 示例代码。
  - `README.md` – iOS 集成步骤说明。
- `Package.swift` – Swift Package 描述文件，将 `Tesseract.xcframework` 暴露为二进制 Target。
- `Tesseract.podspec` – CocoaPods 规格文件，将 `Tesseract.xcframework` 封装为二进制 Pod。

构建过程中会生成 `build-macos-arm64`、`build-ios` 以及若干 `tesseract-ios-*` 中间目录，脚本可根据配置选择是否在结束时自动清理。

---

## 2. 环境要求

推荐并主要在如下环境下使用和测试：

- macOS 11.0 及以上（Big Sur+）。
- Apple Silicon（arm64）机器。
- 已安装 Xcode 及 Command Line Tools（提供 `clang`、SDK 和 `xcodebuild`）。
- 常用构建工具：
  - `git`、`curl`
  - `cmake`、`ninja`
  - Autotools：`autoconf`、`automake`、`libtool`、`pkg-config`

大部分第三方库会由 `build.sh` 自动下载并构建，但请确保上述工具已安装（可通过 Xcode 和 Homebrew 等方式安装）。

---

## 3. 构建 Tesseract 库

在仓库根目录执行：

```bash
chmod +x build.sh
./build.sh
```

脚本将：

- 检查当前 macOS 版本和必需工具；
- 下载并构建：
  - `zlib`
  - `libpng`
  - `libjpeg-turbo`
  - `libtiff`
  - `Leptonica`
  - `Tesseract`
- 安装到统一目录：
  - `./tesseract-macos-arm64`（macOS 头文件 + 静态库）
- 可选：构建 iOS 版本并生成：
  - `./lib/Tesseract.xcframework`

### 3.1 macOS 输出结构

构建成功后，主要的 macOS 输出目录如下：

```text
tesseract-macos-arm64/
  include/          # Tesseract + Leptonica 头文件
  lib/
    libtesseract.a
    libtesseract_all.a
    # 以及其他依赖静态库
```

重点说明：

- `libtesseract.a` – Tesseract 核心静态库。
- `libtesseract_all.a` – 打包了 Tesseract 及主要依赖的方便链接库，适合 C 项目直接使用。

### 3.2 iOS 构建与 XCFramework

默认情况下，脚本会尝试构建：

- macOS 版本；
- iOS 真机 + 模拟器版本；
- 并通过 `xcodebuild` 生成 `lib/Tesseract.xcframework`。

可以通过环境变量控制行为，例如：

```bash
# 仅构建 macOS（跳过 iOS）
ENABLE_IOS=0 ./build.sh

# 调整最低系统版本
MACOS_MIN_VERSION=12.0 IOS_MIN_VERSION=14.0 ./build.sh
```

如果系统中缺少 `xcodebuild`，则会跳过 XCFramework 生成步骤，但 macOS 库仍然会构建完成。

---

## 4. 在 macOS C 项目中使用

当 `./build.sh` 运行完成后，可以在 C 项目中按如下方式链接：

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

示例源文件中应包含 C API 头文件：

```c
#include <tesseract/capi.h>
```

你也可以直接使用仓库自带的 macOS Demo 进行冒烟测试（见下一节）。

---

## 5. 演示示例

### 5.1 macOS C Demo

macOS Demo 位于 `demo/macos`，通过 C API 打印 Tesseract 版本。

步骤如下：

```bash
# 1）先构建库和头文件
./build.sh

# 2）构建 Demo
./demo/macos/build_demo.sh

# 3）运行 Demo
./demo/macos/tesseract-demo
```

如果看到 Tesseract 版本号以及成功链接的提示信息，说明 macOS 构建和链接正常。

### 5.2 iOS Objective‑C Demo

iOS 示例位于 `demo/ios`，展示如何在 iOS 13+ App 中集成 `Tesseract.xcframework` 并使用 Objective‑C 调用。

高层步骤（详见 `demo/ios/README.md`）：

1. 在仓库根目录执行 `./build.sh` 生成 `Tesseract.xcframework`。
2. 在 Xcode 中创建新的 iOS App 工程（iOS 13+）。
3. 将仓库根目录下的 `Tesseract.xcframework` 拖入 Xcode 工程导航栏：
   - 勾选 “Copy items if needed”；
   - 勾选对应的 App Target。
4. 在 Target 的 **General → Frameworks, Libraries, and Embedded Content** 中，将 `Tesseract.xcframework` 的 Embed 选项设置为 **Embed & Sign**。
5. 将 `TesseractIOSDemo.m` 拷贝到工程中，在合适位置调用：

   ```objc
   #import "TesseractIOSDemo.h"

   - (void)viewDidLoad {
       [super viewDidLoad];
       RunTesseractDemo();
   }
   ```

`RunTesseractDemo()` 内部通过 `TessVersion()` 打印当前 Tesseract 版本，用于验证链接是否成功。

> 实际进行 OCR 识别时，你还需要准备对应语言的 `*.traineddata` 数据文件，并通过环境变量 `TESSDATA_PREFIX` 或 `TessBaseAPIInit3` 的 `datapath` 参数设置语言数据路径。本仓库不包含语言数据。

---

## 6. 通过 Swift Package Manager 使用

仓库根目录提供了一个 `Package.swift`，将 `Tesseract.xcframework` 暴露为二进制 Target：

- Target 名称：`Tesseract`
- Library 产品名称：`Tesseract`

在其他工程中使用时，可以按如下方式：

1. 将本仓库推送到一个 Git 远程仓库；
2. 为要分发的版本打上 Git Tag（如 `0.1.0`）；
3. 在 Xcode 或你的 `Package.swift` 中添加对应的包依赖。

在下游工程中的 `Package.swift` 示例：

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

之后即可像使用普通二进制框架一样在 Swift / Objective‑C 代码中引用 `Tesseract`。

---

## 7. 通过 CocoaPods 使用

根目录下的 `Tesseract.podspec` 将 `lib/Tesseract.xcframework` 封装为二进制 Pod。

在自己的项目中使用时，一般流程为：

1. 根据实际情况修改 `Tesseract.podspec` 中的字段：
   - `s.homepage`
   - `s.license`
   - `s.authors`
   - `s.source`（Git 地址和 Tag）
2. 将本仓库推送到上述 Git 地址；
3. 创建与 `s.version` 对应的 Tag（例如 `0.1.0`）；
4. 校验 Podspec：

   ```bash
   pod spec lint Tesseract.podspec
   ```

5. 将校验通过的 Podspec 推送到你的私有或公共 Specs 仓库（例如 `trunk`）。

在下游工程的 `Podfile` 中：

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'Tesseract', '~> 0.1'
end
```

然后执行 `pod install`，打开生成的 Workspace 即可。

---

## 8. 配置项与环境变量

`build.sh` 支持通过环境变量定制构建行为，常用包括：

- `MACOS_MIN_VERSION` – 最低 macOS 部署版本（默认 `11.0`）。
- `ARCH` – 目标架构（默认 `arm64`）。
- `BUILD_TYPE` – CMake 构建类型，如 `Release`（默认）或 `Debug`。
- `IOS_MIN_VERSION` – 最低 iOS 部署版本（默认 `13.0`）。
- `IOS_ARCH_DEVICE` – iOS 真机架构（默认 `arm64`）。
- `IOS_ARCH_SIMULATOR` – iOS 模拟器架构（默认 `arm64`）。
- `ENABLE_IOS` – 是否构建 iOS 版本和 XCFramework，`1` 表示开启（默认），`0` 表示仅构建 macOS。
- `KEEP_INTERMEDIATE` – 是否保留中间构建目录，`0` 为构建结束后删除（默认），`1` 为保留。
- `TESSERACT_VERSION`、`LEPTONICA_VERSION`、`ZLIB_VERSION`、`LIBPNG_VERSION`、`LIBTIFF_VERSION`、`LIBJPEG_TURBO_VERSION` – 控制上游依赖的版本号。

示例：仅构建 macOS、保留中间目录并修改最低 macOS 版本：

```bash
ENABLE_IOS=0 KEEP_INTERMEDIATE=1 MACOS_MIN_VERSION=12.0 ./build.sh
```

---

## 9. 测试与故障排查

- 若修改了构建脚本或依赖版本，建议按以下顺序自检：
  - 重新运行 `./build.sh`；
  - 重新构建并运行 macOS Demo：`./demo/macos/build_demo.sh` 然后 `./demo/macos/tesseract-demo`。
- 若涉及 iOS 相关改动：
  - 重新生成 XCFramework：运行 `./build.sh`；
  - 按 `demo/ios/README.md` 中步骤在真机或模拟器上运行 iOS Demo。

常见问题示例：

- **缺少构建工具**：请确认已安装 Xcode、Command Line Tools，以及 `cmake`、`ninja`、`pkg-config` 和 Autotools 等工具。
- **未生成 XCFramework**：如果系统中没有 `xcodebuild`，或 iOS 库构建失败，脚本会跳过 XCFramework 生成；请查看构建日志中的错误或警告。
- **应用中链接错误**：在 macOS 上请确认链接的是 `libtesseract_all.a`，并且包含所需系统框架（`CoreFoundation`、`CoreGraphics`、`ImageIO`、`Accelerate` 等）。

---

## 10. 许可证说明

Tesseract OCR 本身采用 Apache License 2.0 许可。本仓库仅提供围绕上游项目的构建脚本、预编译二进制以及打包配置，并不改变上游许可。

- 请务必阅读并遵守上游 Tesseract 仓库及其依赖（Leptonica 等）的许可证条款。
- 根目录下的 `Tesseract.podspec` 默认按 Apache 2.0 配置，但其中包含 TODO 注释；在对外分发前请根据实际情况进行调整和补充。

如果你对本仓库产出的二进制进行再分发，需自行确保遵守所有上游项目的许可要求。

---

## 11. 参与贡献

- 修改构建脚本或 Demo 时，尽量保持向后兼容，避免随意更改默认输出路径。
- 以小而专注的改动为主，便于 Review 和回归。
- 对构建相关改动，建议完成后执行：
  - `./build.sh`
  - `./demo/macos/build_demo.sh`
  - `./demo/macos/tesseract-demo`

提交 PR 时，请简要说明：

- 变更动机与主要改动内容；
- 影响平台（macOS 和/或 iOS）；
- 手动测试步骤（运行命令、macOS / Xcode 版本等）。

