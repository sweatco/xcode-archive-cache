require 'zip'
require 'pathname'
require 'fileutils'
require 'logger'
require 'tempfile'
require 'find'
require 'digest'
require 'xcodeproj'
require 'open3'
require 'claide'

require 'logs/logs'

require 'command/command'
require 'command/inject'

require 'config/dsl'
require 'config/config'

require 'build_graph/graph'
require 'build_graph/node'
require 'build_graph/builder'
require 'build_graph/native_target_finder'
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
require 'build_settings/string_interpolator'
require 'build_settings/parser'

require 'injection/injector'
require 'injection/pods_script_fixer'
require 'injection/build_flags_changer'
require 'injection/dependency_remover'
require 'injection/headers_mover'
require 'injection/storage'

require 'runner/runner'

require 'shell/executor'

require 'xcodebuild/executor'

module XcodeArchiveCache
  class Informative < StandardError
    include CLAide::InformativeError
  end
end
