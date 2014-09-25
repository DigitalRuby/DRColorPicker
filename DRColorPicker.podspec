Pod::Spec.new do |s|
s.name = 'DRColorPicker'
s.version = '1.0.8'
s.summary = 'Digital Ruby Color Picker'
s.homepage = 'http://www.digitalruby.com/introducing-drcolorpicker-ios/'
s.license  = 'MIT'
s.author = 'jjxtra'
s.source = {
:git => 'https://github.com/jjxtra/DRColorPicker.git',
:tag => '1.0.8'
}
s.platform = :ios, '6.0'
s.source_files =  'DRColorPickerExample/DRColorPicker/'
s.resources    = 'DRColorPickerExample/DRColorPicker/DRColorPicker.bundle'
s.frameworks = 'UIKit', 'QuartzCore', 'ImageIO'
s.requires_arc = true
end