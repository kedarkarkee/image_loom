#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint image_loom.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'image_loom'
  s.version          = '0.0.1'
  s.summary          = 'Fused crop, rotate and flip for images.'
  s.description      = <<-DESC
Single-pass native image geometry (crop, rotate, flip) for Flutter.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'image_loom/Sources/image_loom/**/*'

  # Uncomment if you keep a privacy manifest.
  # s.resource_bundles = {'image_loom_privacy' => ['image_loom/Sources/image_loom/PrivacyInfo.xcprivacy']}

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'

  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '10.15'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain an i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
