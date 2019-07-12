# XcodeArchiveCache

Native targets cache for Xcode archive builds.

# Warning

**⚠️ Alpha software ⚠️**

- This tool is intended to be used in CI workflows.
- To reuse cached build products, it changes project files.
- Remote caching is planned but not implemented yet.
- Current implementation supports native targets only. Targets should have framework or static library products.

# Installation

- Without Bundler: `gem install xcode-archive-cache`
- With Bundler: add `gem 'xcode-archive-cache'` to Gemfile

# Setup

XcodeArchiveCache has a simple DSL similar to Cocoapods DSL. Configuration is stored in a file called `Cachefile`. Place `Cachefile` in project's root directory.

Example configuration:

```
workspace "Workspace" do
  configuration "release" do
    build_configuration "Release"
    xcodebuild_args "SOME_FLAG='1' -UseModernBuildSystem=NO"
  end

  derived_data_path "build"

  target "Target" do
    cache "Pods_Target.framework"
    cache "libStaticLibrary.a"
  end
end
```

Example command:

```
xcode-archive-cache inject --configuration=release --storage="$HOME/build_cache"
```

# Usage

- Run `xcode-archive-cache` **before building app**. This will update cache and inject cached products into project.
- Build app as usual (Xcode, xcodebuild, Fastlane)
