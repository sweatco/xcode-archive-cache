Gem::Specification.new do |spec|
  spec.name = "xcode-archive-cache"
  spec.version = "0.0.10"
  spec.files = Dir.glob("lib/**/*")
  spec.executables = "xcode-archive-cache"
  spec.authors = "Ilya Dyakonov"
  spec.license  = "MIT"
  spec.homepage = "https://github.com/sweatco/xcode-archive-cache"
  spec.summary = "Native targets cache for Xcode archive builds."
  spec.date = Time.now

  spec.add_runtime_dependency "xcodeproj",  ">= 1.10", "< 2.0"
  spec.add_runtime_dependency "rubyzip",    ">= 2.0", "< 3.0"
  spec.add_runtime_dependency "xcpretty",   "~> 0.3"
  spec.add_runtime_dependency "claide",     "~> 1.0"

  spec.required_ruby_version = ">= 2.0.0"
end
