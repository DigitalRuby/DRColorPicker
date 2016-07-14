Pod::Spec.new do |s|
s.name = 'DRColorPicker'
s.version = '1.1.0'
s.summary = 'Digital Ruby Color Picker'
s.homepage = 'http://www.digitalruby.com/introducing-drcolorpicker-ios/'
s.license  = 'MIT'
s.author = 'jjxtra'
s.source = {
:git => 'https://github.com/jjxtra/DRColorPicker.git',
:tag => s.version.to_s
}
s.platform = :ios, '6.0'
s.source_files =  'Pod/Classes/*'
#s.resources    = 'DRColorPickerExample/DRColorPicker/DRColorPicker.bundle'
s.resource_bundles = {
  'DRColorPicker' => ['Pod/Assets/**/*']
}
s.frameworks = 'UIKit', 'QuartzCore', 'ImageIO'
s.requires_arc = true
end
