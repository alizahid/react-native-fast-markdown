require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "FastMarkdown"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/alizahid/react-native-fast-markdown.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}",
                   "cpp/core/**/*.{h,cpp}",
                   "cpp/react/**/*.{h,cpp}",
                   "cpp/md4c/*.{h,c}"
  s.private_header_files = "ios/**/*.h", "cpp/**/*.h"

  s.pod_target_xcconfig = {
    # The override directory must precede generated headers so the custom
    # component descriptor shadows the codegen default.
    "HEADER_SEARCH_PATHS" => '"$(PODS_TARGET_SRCROOT)/cpp/react/override" "$(PODS_TARGET_SRCROOT)/cpp"',
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
  }

  # Image pipeline (same core expo-image uses): animated GIF/APNG with lazy
  # frame decoding, memory + disk caches, request dedupe and cancellation.
  s.dependency "SDWebImage", "~> 5.21"

  install_modules_dependencies(s)
end
