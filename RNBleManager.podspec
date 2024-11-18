require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name		      = "RNBleManager"
  s.summary		    = package['description']
  s.version		    = package['version']
  s.authors		    = package["author"]
  s.homepage    	= package["homepage"]
  s.license     	= package["license"]
  s.platform    	= :ios, "11.0"
  s.source      	= { :git => "https://github.com/innoveit/react-native-ble-manager.git" }
  s.source_files = "ios/**/*.{h,mm,swift}" 
  
  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
      
  install_modules_dependencies(s)
end
