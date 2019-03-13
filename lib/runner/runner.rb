module XcodeArchiveCache
  class Runner

    # @param [Hash{String => Hash}] config
    #
    def initialize(config)
      @config = config
      @logger = Logger.new(STDOUT)

      workspace_path = File.absolute_path(config[:workspace])
      workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
      workspace_dir = File.expand_path("..", workspace_path)

      @projects = workspace.file_references.map {|file_reference| Xcodeproj::Project.open(file_reference.absolute_path(workspace_dir))}

      @cache_storage = XcodeArchiveCache::ArtifactCache::LocalStorage.new(config[:cache_storage][:local_dir])
      @rebuild_evaluator = XcodeArchiveCache::BuildGraph::RebuildEvaluator.new(@cache_storage)

      @unpacked_artifacts_dir = File.absolute_path(File.join(config[:derived_data_path], "cached"))
      @artifact_extractor = XcodeArchiveCache::ArtifactCache::ArtifactExtractor.new(@cache_storage)
      @product_extractor = XcodeArchiveCache::Build::ProductExtractor.new(config[:configuration], config[:derived_data_path])

      @injection_storage = XcodeArchiveCache::Injection::Storage.new(@unpacked_artifacts_dir)
      @injector = XcodeArchiveCache::Injection::Injector.new(config[:configuration], @injection_storage, @logger)
    end

    def run
      @config[:targets].each do |target_config|
        handle_target(target_config)
      end
    end

    private

    # @param [Hash{String => Hash}] target_config
    #
    def handle_target(target_config)
      target = find_target(target_config[:name])
      unless target
        puts "target not found for #{target_config[:name]}"
        exit 1
      end

      target_config[:cached_dependencies].each do |dependency_config|
        handle_dependency(target, dependency_config)
      end
    end

    # @param [String] product_name
    #
    def find_target(product_name)
      @projects.each do |project|
        target = project.native_targets.select {|native_target| native_target.name == product_name || native_target.product_reference.display_name == product_name}.first
        return target if target
      end
    end

    # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
    # @param [Hash] dependency_config
    #
    def handle_dependency(target, dependency_config)
      dependency_name = dependency_config[:name]
      @logger.info("checking #{dependency_name}")

      dependency_target = find_target(dependency_name)
      unless dependency_target
        @logger.error("target not found for #{dependency_name} of #{target.display_name}")
        exit 1
      end

      xcodebuild_executor = XcodeArchiveCache::Xcodebuild::Executor.new(dependency_target.project.path, @config[:configuration], dependency_target.platform_name)
      graph_builder = XcodeArchiveCache::BuildGraph::Builder.new(xcodebuild_executor, @logger)
      graph = graph_builder.build_graph(dependency_target)
      evaluate_for_rebuild(graph)
      extract_cached_artifacts(graph)
      perform_rebuild(dependency_target, graph)
      @injector.inject_in_dependent(graph, target)

      if dependency_config[:embed_frameworks_script]
        pods_fixer = XcodeArchiveCache::Pods::Fixer.new
        pods_fixer.fix_embed_frameworks_script(dependency_config[:embed_frameworks_script], @unpacked_artifacts_dir)
      end
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
    def perform_rebuild(root_target, graph)
      rebuild_performer = XcodeArchiveCache::Build::Performer.new(@logger)
      return unless rebuild_performer.should_rebuild?(graph)

      @injector.inject_in_graph(graph)
      rebuild_performer.rebuild_missing(root_target, graph)

      graph.nodes.each do |node|
        next unless node.rebuild

        file_paths = @product_extractor.list_product_contents(root_target.name, node)
        @injection_storage.store(node, file_paths)
        @cache_storage.store(node, @injection_storage.get_storage_path(node))
      end
    end
  end
end
