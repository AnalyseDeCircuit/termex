#
# Flutter FFI plugin podspec for termex_bridge (iOS).
# Builds the termex_flutter_bridge Rust crate via cargokit.
#
Pod::Spec.new do |s|
  s.name             = 'termex_bridge'
  s.version          = '0.53.7'
  s.summary          = 'FRB-generated bindings for termex-core (iOS).'
  s.description      = <<-DESC
Flutter FFI plugin that bundles the termex_flutter_bridge Rust crate.
                       DESC
  s.homepage         = 'https://github.com/onelaprince/termex'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Termex' => 'noreply@termex.dev' }
  s.module_name      = 'termex_flutter_bridge'

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" .. termex_flutter_bridge',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${PODS_CONFIGURATION_BUILD_DIR}/termex_flutter_bridge/libtermex_flutter_bridge.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${PODS_CONFIGURATION_BUILD_DIR}/termex_flutter_bridge/libtermex_flutter_bridge.a',
  }
end
