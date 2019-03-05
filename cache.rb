require 'xcodeproj'
require 'logger'

require_relative 'lib/runner/runner'

config = {
    :workspace => "swc.xcworkspace",
    :configuration => "Internal",
    :cache_storage => {
        :local_dir => "build_cache"
    },
    :derived_data_path => "build",
    :targets => [{
                     :name => "swc",
                     :cached_dependencies => ["Pods_swc.framework"]
                 }]
}

runner = XcodeArchiveCache::Runner.new(config)
runner.run
