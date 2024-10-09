require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))
folly_version = '2021.06.28.00-v2'
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'
Pod::Spec.new do |s|
  s.name		= "react-native-ble-manager"
  s.summary		= "A BLE module for react native."
  s.version		= package['version']
  s.authors		= { "Innove" => "https://github.com/innoveit" }
  s.homepage    	= "https://github.com/innoveit/react-native-ble-manager"
  s.license     	= "Apache-2.0"
  s.platform    	= :ios, "11.0"
  s.source      	= { :git => "https://github.com/innoveit/react-native-ble-manager.git" }
  s.source_files = "ios/**/*.{h,c,cc,cpp,m,mm,swift}"
  s.dependency 'React-Core'

  if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
      s.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"
      s.pod_target_xcconfig    = {
          "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\"",
          "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
      }

      s.dependency "React-Codegen"
      s.dependency "RCT-Folly", folly_version
      s.dependency "RCTRequired"
      s.dependency "RCTTypeSafety"
      s.dependency "ReactCommon/turbomodule/core"
  end
end
