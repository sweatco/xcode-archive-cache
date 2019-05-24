module XcodeArchiveCache
  class Runner

    include XcodeArchiveCache::Logs

    # @param [XcodeArchiveCache::Config::Entry] config
    #
    def initialize(config)
      @config = config

      workspace_path = File.absolute_path(config.file_path)
      workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
      workspace_dir = File.expand_path("..", workspace_path)

      projects = workspace.file_references.map {|file_reference| Xcodeproj::Project.open(file_reference.absolute_path(workspace_dir))}
      @native_target_finder = XcodeArchiveCache::BuildGraph::NativeTargetFinder.new(projects)

      storage_path = File.absolute_path(config.storage.path)
      @cache_storage = XcodeArchiveCache::ArtifactCache::LocalStorage.new(storage_path)
      @rebuild_evaluator = XcodeArchiveCache::BuildGraph::RebuildEvaluator.new(@cache_storage)

      @artifact_extractor = XcodeArchiveCache::ArtifactCache::ArtifactExtractor.new(@cache_storage)

      derived_data_path = File.absolute_path(config.settings.derived_data_path)
      @product_extractor = XcodeArchiveCache::Build::ProductExtractor.new(config.active_configuration.build_configuration, derived_data_path)

      unpacked_artifacts_dir = File.absolute_path(File.join(derived_data_path, "cached"))
      @injection_storage = XcodeArchiveCache::Injection::Storage.new(unpacked_artifacts_dir)
      @injector = XcodeArchiveCache::Injection::Injector.new(config.active_configuration.build_configuration, @injection_storage)
    end

    def run
      perform_cleanup

      config.targets.each do |target_config|
        handle_target(target_config)
      end
    end

    def perform_cleanup
      if File.exist?(config.settings.derived_data_path)
        FileUtils.rm_rf(config.settings.derived_data_path)
      end
    end

    private

    # @return [XcodeArchiveCache::Config::Entry]
    #
    attr_reader :config

    # @param [XcodeArchiveCache::Config::Target] target_config
    #
    def handle_target(target_config)
      target = @native_target_finder.find_for_product_name(target_config.name)
      unless target
        raise Informative, "Target not found for #{target_config.name}"
      end

      target_config.dependencies.each do |dependency_name|
        handle_dependency(target, dependency_name)
      end
    end

    # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
    # @param [String] dependency_name
    #
    def handle_dependency(target, dependency_name)
      info("checking #{dependency_name}")

      dependency_target = @native_target_finder.find_for_product_name(dependency_name)
      unless dependency_target
        raise Informative, "Target not found for #{dependency_name} of #{target.display_name}"
      end

      xcodebuild_executor = XcodeArchiveCache::Xcodebuild::Executor.new(config.active_configuration.build_configuration,
                                                                        dependency_target.platform_name,
                                                                        config.settings.destination,
                                                                        config.active_configuration.action,
                                                                        config.active_configuration.xcodebuild_args)
      graph_builder = XcodeArchiveCache::BuildGraph::Builder.new(@native_target_finder, xcodebuild_executor)
      graph = graph_builder.build_graph(target, dependency_target)

      evaluate_for_rebuild(graph)
      extract_cached_artifacts(graph)
      rebuild_if_needed(xcodebuild_executor, dependency_target, graph)
      @injector.perform_outgoing_injection(graph, target)
    end

    # @param [XcodeArchiveCache::BuildGraph::Graph] graph
    #
    def evaluate_for_rebuild(graph)
      graph.nodes.each do |node|
        @rebuild_evaluator.evaluate(node)
      end
    end

    # @param [XcodeArchiveCache::BuildGraph::Graph] graph
    #
    def extract_cached_artifacts(graph)
      graph.nodes.each do |node|
        next if node.rebuild

        destination = @injection_storage.prepare_storage(node)
        @artifact_extractor.unpack(node, destination)
      end
    end

    # @param [Xcodeproj::Project::Object::PBXNativeTarget] root_target
    # @param [XcodeArchiveCache::BuildGraph::Graph] graph
    #
    def rebuild_if_needed(xcodebuild_executor, root_target, graph)
      rebuild_performer = XcodeArchiveCache::Build::Performer.new(xcodebuild_executor, config.settings.derived_data_path)
      return unless rebuild_performer.should_rebuild?(graph)

      @injector.perform_internal_injection(graph)
      rebuild_performer.rebuild_missing(root_target, graph)

      graph.nodes.each do |node|
        next unless node.rebuild

        file_paths = @product_extractor.list_product_contents(root_target.name, node)
        @injection_storage.store_products(node, file_paths)
        @cache_storage.store(node, @injection_storage.get_storage_path(node))
      end
    end
  end
end
