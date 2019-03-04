require 'xcodeproj'
require 'logger'

require_relative 'lib/build_graph/builder'
require_relative 'lib/build_settings/loader'
require_relative 'lib/build_graph/sha_calculator'
require_relative 'lib/artifact_cache/local_storage'
require_relative 'lib/build_graph/rebuild_evaluator'
require_relative 'lib/artifact_cache/artifact_extractor'
require_relative 'lib/build_settings/fixer'
require_relative 'lib/build_product/extractor'

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

workspace_path = File.absolute_path(config[:workspace])
workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)

workspace_dir = File.expand_path("..", workspace_path)
projects = workspace.file_references.map {|file_reference| Xcodeproj::Project.open(file_reference.absolute_path(workspace_dir))}

def find_target(product_name, projects)
  projects.each do |project|
    target = project.native_targets.select {|native_target| native_target.product_reference.display_name == product_name}.first
    return project, target if target
  end
end

target = config[:targets].first
target[:cached_dependencies].each do |dependency_name|
  project, dependency_target = find_target(dependency_name, projects)
  unless project && dependency_target
    puts "target not found for #{dependency_name} of #{target[:name]}"
    exit 1
  end

  logger = Logger.new(STDOUT)
  graph_builder = XcodeArchiveCache::BuildGraph::Builder.new(logger)
  graph = graph_builder.build_graph(project, dependency_target)

  xcodebuild_executor = XcodeArchiveCache::Xcodebuild::Executor.new
  build_settings_loader = XcodeArchiveCache::BuildSettings::Loader.new(xcodebuild_executor)
  build_settings = build_settings_loader.load_settings(project, config[:configuration])

  graph.nodes.each do |node|
    node.build_settings = build_settings[node.name]
  end

  sha_calculator = XcodeArchiveCache::BuildGraph::NodeShaCalculator.new
  graph.nodes.each do |node|
    sha_calculator.calculate(node)
  end

  cache_storage = XcodeArchiveCache::ArtifactCache::LocalStorage.new(config[:cache_storage][:local_dir])
  rebuild_evaluator = XcodeArchiveCache::BuildGraph::RebuildEvaluator.new(cache_storage)
  graph.nodes.each do |node|
    rebuild_evaluator.evaluate(node)
  end

  unpacked_artifacts_dir = File.join(config[:derived_data_path], "cached")
  artifact_extractor = XcodeArchiveCache::ArtifactCache::ArtifactExtractor.new(cache_storage, unpacked_artifacts_dir)
  artifact_extractor.unpack_available(graph)

  should_rebuild_anything = graph.nodes.reduce(false) {|rebuild, node| rebuild || node.rebuild}

  if should_rebuild_anything
    build_settings_fixer = XcodeArchiveCache::BuildSettings::Fixer.new(config[:configuration], artifact_extractor, logger)
    build_settings_fixer.fix(graph)
    project.save

    build_result = xcodebuild_executor.build(project.path, config[:configuration], dependency_target.name, config[:derived_data_path])
    if build_result == nil
      puts "failed to build dependencies"
      exit 1
    end

    product_extractor = XcodeArchiveCache::BuildProduct::Extractor.new(config[:configuration], config[:derived_data_path])
    graph.nodes.each do |node|
      next unless node.rebuild

      unpacked_product_dir = File.join(unpacked_artifacts_dir, node.name)
      if File.exist?(unpacked_product_dir)
        FileUtils.rm_rf(unpacked_product_dir)
      end

      FileUtils.mkdir_p(unpacked_product_dir)
      product_extractor.copy_product(dependency_target.name, node, unpacked_product_dir)
      cache_storage.store(node, unpacked_product_dir)
    end
  else
    puts "no need to rebuild anything here"
  end

  # TODO: fix main target settings
end
