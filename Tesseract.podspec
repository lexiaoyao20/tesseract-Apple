Pod::Spec.new do |s|
  s.name             = 'Tesseract'
  s.version          = '5.5.1'
  s.summary          = 'Prebuilt Tesseract OCR for iOS and macOS (arm64).'
  s.description      = <<-DESC
Prebuilt Tesseract OCR static library packaged as an XCFramework for iOS (device and simulator) and macOS on Apple Silicon.
  DESC
  s.homepage         = 'https://github.com/lexiaoyao20/tesseract-Apple'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.authors          = { 'Bob' => 'lexiaoyao20@gmail.com' }

  # Use GitHub Releases XCFramework Zip as the binary source (kept in sync with Package.swift)
  s.source           = { :http => 'https://github.com/lexiaoyao20/tesseract-Apple/releases/download/5.5.1/Tesseract.xcframework.zip' }

  s.ios.deployment_target  = '13.0'
  s.macos.deployment_target = '11.0'

  # Prebuilt XCFramework contained in the downloaded archive root
  s.vendored_frameworks = 'lib/Tesseract.xcframework'

  # Tesseract 链接依赖
  s.frameworks = %w[CoreFoundation CoreGraphics ImageIO Accelerate]
  s.libraries  = %w[c++ z iconv]

  # 不包含任何 ObjC / Swift 源码
  s.requires_arc = false
end
