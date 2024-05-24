# Uncomment this line to define a global platform for your project
min_target = 15.6
platform :ios, min_target
# Uncomment this line if you're using Swift
use_frameworks!

target 'Home Movies' do
    pod 'JPSVolumeButtonHandler', '~> 1.0'
end


post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ENABLE_BITCODE'] = 'NO'
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = min_target
        end
    end
end





