module XcodeArchiveCache
  class Runner

    include XcodeArchiveCache::Logs

    # @param [XcodeArchiveCache::Config::Entry] config
    #
    def initialize(config)
      @config = config

      projects = list_projects
      @native_target_finder = XcodeArchiveCache::BuildGraph::NativeTargetFinder.new(projects, config.active_configuration.build_configuration)

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

    def list_projects
      file_path = File.absolute_path(config.file_path)

      if config.is_a?(XcodeArchiveCache::Config::Project)
        return [Xcodeproj::Project.open(file_path)]
      elsif config.is_a?(XcodeArchiveCache::Config::Workspace)
        workspace = Xcodeproj::Workspace.new_from_xcworkspace(file_path)
        workspace_dir = File.expand_path("..", file_path)

        return workspace.file_references.map {|file_reference| Xcodeproj::Project.open(file_reference.absolute_path(workspace_dir))}
      end

      raise XcodeArchiveCache::Informative, "Configuration misses entry point -- must have either a project or a workspace"
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
        raise XcodeArchiveCache::Informative, "Target not found for #{target_config.name}"
      end

      xcodebuild_executor = XcodeArchiveCache::Xcodebuild::Executor.new(config.active_configuration.build_configuration,
                                                                        target.platform_name,
                                                                        config.settings.destination,
                                                                        config.active_configuration.action,
                                                                        config.active_configuration.xcodebuild_args)
      build_settings_loader = XcodeArchiveCache::BuildSettings::Loader.new(xcodebuild_executor)
      graph_builder = XcodeArchiveCache::BuildGraph::Builder.new(@native_target_finder, build_settings_loader)

      dependency_targets = Hash.new
      build_graphs = Hash.new

      target_config.dependencies.each do |dependency_name|
        info("creating build graph for #{dependency_name}")

        dependency_target = find_dependency_target(target, dependency_name)
        dependency_targets[dependency_name] = dependency_target
        build_graphs[dependency_name] = graph_builder.build_graph(target, dependency_target)
      end

      pods_xcframeworks_fixer = XcodeArchiveCache::Injection::PodsXCFrameworkFixer.new(@injection_storage, @native_target_finder, config.active_configuration.build_configuration)
      pods_xcframeworks_fixer.fix(target, build_settings_loader)

      target_config.dependencies.each do |dependency_name|
        info("processing #{dependency_name}")

        dependency_target = dependency_targets[dependency_name]
        build_graph = build_graphs[dependency_name]
        
        @rebuild_evaluator.evaluate_build_graph(build_graph)
        unpack_cached_artifacts(build_graph)
        rebuild_if_needed(xcodebuild_executor, dependency_target, build_graph)
        @injector.perform_outgoing_injection(build_graph, target)
      end
    end

    # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
    # @param [String] dependency_name
    #
    # @return [Xcodeproj::Project::Object::PBXNativeTarget]
    #
    def find_dependency_target(target, dependency_name)
      dependency_target = @native_target_finder.find_for_product_name(dependency_name)
      unless dependency_target
        raise XcodeArchiveCache::Informative, "Target not found for #{dependency_name} of #{target.display_name}"
      end

      dependency_target
    end

    # @param [XcodeArchiveCache::BuildGraph::Graph] graph
    #
    def unpack_cached_artifacts(graph)
      graph.nodes
          .select {|node| node.state == :exists_in_cache}
          .each do |node|
        destination = @injection_storage.prepare_storage(node)
        @artifact_extractor.unpack(node, destination)
        node.state = :unpacked
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

      graph.nodes
          .select(&:waiting_for_rebuild)
          .each do |node|
        file_paths = @product_extractor.list_product_contents(node)
        @injection_storage.store_products(node, file_paths)
        @cache_storage.store(node, @injection_storage.get_storage_path(node))
        node.state = :rebuilt_and_cached
      end
    end
  end
end
