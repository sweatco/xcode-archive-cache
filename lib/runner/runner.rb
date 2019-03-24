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

      @projects = workspace.file_references.map {|file_reference| Xcodeproj::Project.open(file_reference.absolute_path(workspace_dir))}

      storage_path = File.absolute_path(config.storage.path)
      @cache_storage = XcodeArchiveCache::ArtifactCache::LocalStorage.new(storage_path)
      @rebuild_evaluator = XcodeArchiveCache::BuildGraph::RebuildEvaluator.new(@cache_storage)

      @artifact_extractor = XcodeArchiveCache::ArtifactCache::ArtifactExtractor.new(@cache_storage)

      derived_data_path = File.absolute_path(config.build_settings.derived_data_path)
      @product_extractor = XcodeArchiveCache::Build::ProductExtractor.new(config.build_settings.configuration, derived_data_path)

      unpacked_artifacts_dir = File.absolute_path(File.join(derived_data_path, "cached"))
      @injection_storage = XcodeArchiveCache::Injection::Storage.new(unpacked_artifacts_dir)
      @injector = XcodeArchiveCache::Injection::Injector.new(config.build_settings.configuration, @injection_storage)
    end

    def run
      config.targets.each do |target_config|
        handle_target(target_config)
      end
    end

    private

    # @return [XcodeArchiveCache::Config::Entry]
    #
    attr_reader :config

    # @param [XcodeArchiveCache::Config::Target] target_config
    #
    def handle_target(target_config)
      target = find_target(target_config.name)
      unless target
        error("target not found for #{target_config.name}")
        exit 1
      end

      target_config.dependencies.each do |dependency_name|
        handle_dependency(target, dependency_name)
      end
    end

    # @param [String] product_name
    #
    def find_target(product_name)
      @projects.each do |project|
        target = project.native_targets
                     .select {|native_target| native_target.name == product_name || native_target.product_reference.display_name == product_name}
                     .first
        return target if target
      end
    end

    # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
    # @param [String] dependency_name
    #
    def handle_dependency(target, dependency_name)
      info("checking #{dependency_name}")

      dependency_target = find_target(dependency_name)
      unless dependency_target
        error("target not found for #{dependency_name} of #{target.display_name}")
        exit 1
      end

      xcodebuild_executor = XcodeArchiveCache::Xcodebuild::Executor.new(config.build_settings.configuration, dependency_target.platform_name)
      graph_builder = XcodeArchiveCache::BuildGraph::Builder.new(@projects, xcodebuild_executor)
      graph = graph_builder.build_graph(dependency_target)

      evaluate_for_rebuild(graph)
      extract_cached_artifacts(graph)
      rebuild_if_needed(dependency_target, graph)
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
    def rebuild_if_needed(root_target, graph)
      rebuild_performer = XcodeArchiveCache::Build::Performer.new(config.build_settings.derived_data_path)
      return unless rebuild_performer.should_rebuild?(graph)

      @injector.perform_internal_injection(graph)
      rebuild_performer.rebuild_missing(config.build_settings.configuration, root_target, graph)

      graph.nodes.each do |node|
        next unless node.rebuild

        file_paths = @product_extractor.list_product_contents(root_target.name, node)
        @injection_storage.store_products(node, file_paths)
        @cache_storage.store(node, @injection_storage.get_storage_path(node))
      end
    end
  end
end
