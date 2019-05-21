$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

Gem::Specification.new do |spec|
  spec.name = "xcode-archive-cache"
  spec.version = "0.0.1"
  spec.summary = "Xcode archive cache"
  spec.files = Dir.glob("lib/**/*")
  spec.executables = "xcode-archive-cache"
  spec.authors = "Ilya Dyakonov"

  spec.add_runtime_dependency 'xcodeproj',  '~> 1.7'
  spec.add_runtime_dependency 'rubyzip',    '~> 1.2'
  spec.add_runtime_dependency 'xcpretty',   '~> 0.3'
  spec.add_runtime_dependency 'claide',     '~> 1.0'
end
