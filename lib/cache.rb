module XcodeArchiveCache; end

require 'zip'
require 'pathname'
require 'fileutils'
require 'logger'
require 'tempfile'
require 'find'
require 'digest'
require 'xcodeproj'
require 'open3'

require 'build_graph/graph'
require 'build_graph/node'
require 'build_graph/builder'
require 'build_settings/loader'
require 'build_graph/sha_calculator'
require 'build_graph/rebuild_evaluator'

require 'artifact_cache/abstract_storage'
require 'artifact_cache/local_storage'
require 'artifact_cache/artifact_extractor'
require 'artifact_cache/archiver'

require 'build_product/extractor'

require 'build_settings/fixer'
require 'build_settings/filter'
require 'build_settings/loader'
require 'build_settings/extractor'

require 'xcodebuild/executor'

require 'runner/runner'

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
                 },
                 {
                     :name => "watch-extension",
                     :cached_dependencies => ["Pods_watch_extension.framework"]
                 }]
}

runner = XcodeArchiveCache::Runner.new(config)
runner.run
