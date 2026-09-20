require 'xcodeproj'
p = Xcodeproj::Project.open('pip_swift/pip_swift.xcodeproj')
app = p.targets.find { |t| t.name == 'pip_swift' }
unit = p.new_target(:unit_test_bundle, 'PowerLifecycleTests', :ios, '15.0')
ui = p.new_target(:ui_test_bundle, 'SimulatorUITests', :ios, '15.0')
[unit, ui].each do |target|
  target.add_dependency(app)
  group = p.main_group.new_group(target.name, target.name)
  target.add_file_references([group.new_file("#{target.name}.swift")])
  target.build_configurations.each do |config|
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.globalrefresh.tests.#{target.name}"
    config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    if target == unit
      config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/pip_swift.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/pip_swift'
      config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    else
      config.build_settings['TEST_TARGET_NAME'] = 'pip_swift'
    end
  end
end
p.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(unit)
scheme.add_test_target(ui)
scheme.set_launch_target(app)
scheme.test_action.build_configuration = 'Debug'
scheme.save_as('pip_swift/pip_swift.xcodeproj', 'SimulatorValidation', true)
