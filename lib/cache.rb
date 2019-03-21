module XcodeArchiveCache
  ;
end

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
require 'build_graph/native_target_finder'
require 'build_settings/loader'
require 'build_graph/sha_calculator'
require 'build_graph/rebuild_evaluator'

require 'artifact_cache/abstract_storage'
require 'artifact_cache/local_storage'
require 'artifact_cache/artifact_extractor'
require 'artifact_cache/archiver'

require 'build/performer'
require 'build/product_extractor'

require 'build_settings/filter'
require 'build_settings/loader'
require 'build_settings/extractor'

require 'logs/logs'

require 'pods/fixer'

require 'injection/injector'
require 'injection/build_flags_changer'
require 'injection/dependency_remover'
require 'injection/headers_mover'
require 'injection/storage'

require 'runner/runner'

require 'shell/executor'

require 'xcodebuild/executor'

config = {
    :workspace => "swc.xcworkspace",
    :configuration => "Internal",
    :cache_storage => {
        :local_dir => "build_cache"
    },
    :derived_data_path => "build",
    :targets => [{
                     :name => "swc",
                     :cached_dependencies => [{:name => "libSweatcoinReact.a"},
                                              {:name => "Pods_swc.framework", :embed_frameworks_script => "Pods/Target Support Files/Pods-swc/Pods-swc-frameworks.sh"}]
                 },
                 {
                     :name => "watch-extension",
                     :cached_dependencies => [{:name => "Pods_watch_extension.framework", :embed_frameworks_script => "Pods/Target Support Files/Pods-watch-extension/Pods-watch-extension-frameworks.sh"}]
                 }]
}

runner = XcodeArchiveCache::Runner.new(config)
runner.run
