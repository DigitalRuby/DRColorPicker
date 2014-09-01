Pod::Spec.new do |s|
s.name = 'DRColorPicker'
s.version = '1.0'
s.summary = 'Digital Ruby Color Picker'
s.homepage = 'http://www.digitalruby.com/introducing-drcolorpicker-ios/'
s.license  = 'MIT'
s.author = 'jjxtra'
s.source = {
:git => 'https://github.com/jjxtra/DRColorPicker.git',
:commit => '1f4f24bc2b8e729eee6f1cbfed7833b115676d08'
}
s.platform = :ios, '6.0'
s.source_files =  'DRColorPickerExample/DRColorPicker/'
s.resources    = 'DRColorPickerExample/DRColorPicker/DRColorPicker.bundle'
s.frameworks = 'UIKit', 'QuartzCore', 'ImageIO'
s.requires_arc = true
end