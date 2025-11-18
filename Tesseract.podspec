Pod::Spec.new do |s|
  s.name             = 'Tesseract'
  s.version          = '0.1.0'
  s.summary          = 'Prebuilt Tesseract OCR for iOS and macOS (arm64).'
  s.description      = <<-DESC
Prebuilt Tesseract OCR static library packaged as an XCFramework for iOS (device and simulator) and macOS on Apple Silicon.
  DESC
  s.homepage         = 'https://example.com/tesseract-release' # TODO: 替换为你的主页或仓库地址
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' } # TODO: 确认与实际库一致的 License
  s.authors          = { 'Your Name' => 'you@example.com' }        # TODO: 修改为你的姓名和邮箱

  # 使用当前仓库作为二进制源，发布时需要打 tag 与 s.version 对应
  s.source           = { :git => 'https://example.com/your/tesseract-release.git', :tag => s.version.to_s } # TODO: 修改为真实 Git 地址

  s.ios.deployment_target  = '13.0'
  s.macos.deployment_target = '11.0'

  # 预编译好的 XCFramework
  s.vendored_frameworks = 'lib/Tesseract.xcframework'

  # Tesseract 链接依赖
  s.frameworks = %w[CoreFoundation CoreGraphics ImageIO Accelerate]
  s.libraries  = %w[c++ z iconv]

  # 不包含任何 ObjC / Swift 源码
  s.requires_arc = false
end

