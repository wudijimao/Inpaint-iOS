# Uncomment the next line to define a global platform for your project
 platform :ios, '15.0'

target 'Inpaint' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks! :linkage => :dynamic

  pod 'SnapKit'
  pod 'Toast-Swift'
  pod 'UMCommon'
  pod 'UMDevice'
  pod 'UMAPM'
  
  pod 'Inpainting', :path => 'LocalPods/Inpainting'
  pod 'CoreMLImage', :path => 'LocalPods/CoreMLImage'

  # Pods for Inpaint
  target 'InpaintEditor' do
  end


  target 'InpaintTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'InpaintUITests' do
    # Pods for testing
  end

end


post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
        config.build_settings['DEVELOPMENT_TEAM'] = '26NS455T8K'
      end
    end
  end
end
