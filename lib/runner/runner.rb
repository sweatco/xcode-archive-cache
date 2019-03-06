module XcodeArchiveCache
  class Runner

    # @param [Hash{String => Hash}] config
    #
    def initialize(config)
      @config = config

      workspace_path = File.absolute_path(config[:workspace])
      @workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)

      workspace_dir = File.expand_path("..", workspace_path)
      @projects = @workspace.file_references.map {|file_reference| Xcodeproj::Project.open(file_reference.absolute_path(workspace_dir))}

      @logger = Logger.new(STDOUT)

      @cache_storage = XcodeArchiveCache::ArtifactCache::LocalStorage.new(config[:cache_storage][:local_dir])
      @rebuild_evaluator = XcodeArchiveCache::BuildGraph::RebuildEvaluator.new(@cache_storage)

      @unpacked_artifacts_dir = File.absolute_path(File.join(config[:derived_data_path], "cached"))
      @artifact_extractor = XcodeArchiveCache::ArtifactCache::ArtifactExtractor.new(@cache_storage, @unpacked_artifacts_dir)
      @product_extractor = XcodeArchiveCache::BuildProduct::Extractor.new(config[:configuration], config[:derived_data_path])

      @build_settings_fixer = XcodeArchiveCache::BuildSettings::Fixer.new(config[:configuration], @artifact_extractor, @logger)
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
      dependency_target = find_target(dependency_name)
      unless dependency_target
        puts "target not found for #{dependency_name} of #{target.display_name}"
        exit 1
      end

      xcodebuild_executor = XcodeArchiveCache::Xcodebuild::Executor.new(dependency_target.project.path, @config[:configuration], dependency_target.platform_name)
      graph_builder = XcodeArchiveCache::BuildGraph::Builder.new(xcodebuild_executor, @logger)
      graph = graph_builder.build_graph(dependency_target)
      evaluate_for_rebuild(graph)

      @artifact_extractor.unpack_available(graph)
      rebuild_missing(dependency_target, graph)

      fix_target_settings(target, graph)

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

    # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
    # @param [XcodeArchiveCache::BuildGraph::Graph] graph
    #
    def rebuild_missing(target, graph)
      should_rebuild_anything = graph.nodes.reduce(false) {|rebuild, node| rebuild || node.rebuild}
      if should_rebuild_anything
        @build_settings_fixer.fix(graph)
        target.project.save

        xcodebuild_executor = XcodeArchiveCache::Xcodebuild::Executor.new(target.project.path, @config[:configuration], target.platform_name)
        build_result = xcodebuild_executor.build(target.name, @config[:derived_data_path])
        unless build_result
          puts "failed to build dependencies"
          exit 1
        end

        copy_and_cache_products(target, graph)
      else
        puts "no need to rebuild anything here"
      end
    end

    # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
    # @param [XcodeArchiveCache::BuildGraph::Graph] graph
    #
    def copy_and_cache_products(target, graph)
      graph.nodes.each do |node|
        next unless node.rebuild

        unpacked_product_dir = File.join(@unpacked_artifacts_dir, node.name)
        if File.exist?(unpacked_product_dir)
          FileUtils.rm_rf(unpacked_product_dir)
        end

        FileUtils.mkdir_p(unpacked_product_dir)
        @product_extractor.copy_product(target.name, node, unpacked_product_dir)
        @cache_storage.store(node, unpacked_product_dir)
      end
    end

    # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
    # @param [XcodeArchiveCache::BuildGraph::Graph] graph
    #
    def fix_target_settings(target, graph)
      graph.nodes.each do |node|
        @build_settings_fixer.add_as_prebuilt_framework(node, target)
      end

      target.project.save
    end
  end
end
