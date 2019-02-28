require 'xcodeproj'
require 'logger'

require_relative 'lib/build_graph/builder'
require_relative 'lib/build_settings/loader'
require_relative 'lib/build_graph/sha_calculator'
require_relative 'lib/artifact_cache/local_storage'
require_relative 'lib/build_graph/rebuild_evaluator'

pods_project_path = ARGV[0]
pods_project = Xcodeproj::Project.open(pods_project_path)

target = pods_project.targets.select {|target| target.display_name == ARGV[1] }.first
graph_builder = XcodeArchiveCache::BuildGraph::Builder.new(Logger.new(STDOUT))
graph = graph_builder.build_graph(pods_project, target)

build_settings_loader = XcodeArchiveCache::BuildSettings::Loader.new
build_settings = build_settings_loader.load_settings(pods_project, ARGV[2])

graph.nodes.each do |node|
  node.build_settings = build_settings[node.name]
end

sha_calculator = XcodeArchiveCache::BuildGraph::NodeShaCalculator.new
graph.nodes.each do |node|
  sha_calculator.calculate(node)
end

cache_storage = XcodeArchiveCache::ArtifactCache::LocalStorage.new(ARGV[3])
rebuild_evaluator = XcodeArchiveCache::BuildGraph::RebuildEvaluator.new(cache_storage)
graph.nodes.each do |node|
  rebuild_evaluator.evaluate(node)
end
