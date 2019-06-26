module XcodeArchiveCache
  module Injection
    class Injector

      include XcodeArchiveCache::Logs

      # @param [String] configuration_name
      # @param [XcodeArchiveCache::Injection::Storage] storage
      #
      def initialize(configuration_name, storage)
        @configuration_name = configuration_name
        @storage = storage
        @headers_mover = HeadersMover.new(storage)
        @dependency_remover = DependencyRemover.new
        @build_flags_changer = BuildFlagsChanger.new
        @pods_fixer = PodsScriptFixer.new
        @framework_embedder = FrameworkEmbedder.new
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def perform_internal_injection(graph)
        graph.nodes.each {|node| add_as_prebuilt_to_dependents(node)}
        save_graph_projects(graph)
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def perform_outgoing_injection(graph, target)
        graph.nodes.each {|node| add_as_prebuilt_dependency(node, target, node.is_root)}

        # pretty dummy but should work in most cases;
        # here we assume that if graph has a pods target
        # then all graph nodes are built as pods and therefore
        # are covered by "Embed Pods Frameworks" script
        #
        if graph.node_by_name(get_pods_target_name(target))
          pods_fixer.fix_embed_frameworks_script(target, graph.dependent_build_settings, storage.container_dir_path)
        else
          framework_nodes = graph.nodes.select {|node| node.has_framework_product?}
          framework_file_paths = framework_nodes.map {|node| File.join(storage.get_storage_path(node), node.product_file_name)}
          framework_embedder.embed(framework_file_paths, target)
        end

        save_graph_projects(graph)
        target.project.save
      end

      private

      # @return [String]
      #
      attr_reader :configuration_name

      # @return [Storage]
      # 
      attr_reader :storage

      # @return [HeadersMover]
      #
      attr_reader :headers_mover

      # @return [DependencyRemover]
      #
      attr_reader :dependency_remover

      # @return [BuildFlagsChanger]
      #
      attr_reader :build_flags_changer

      # @return [PodsScriptFixer]
      #
      attr_reader :pods_fixer

      # @return [FrameworkEmbedder]
      #
      attr_reader :framework_embedder

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      #
      def add_as_prebuilt_to_dependents(prebuilt_node)
        prebuilt_node.all_dependent_nodes.each do |dependent_node|
          next if prebuilt_node.rebuild

          should_link = prebuilt_node.dependent.include?(dependent_node)
          add_as_prebuilt_dependency(prebuilt_node, dependent_node.native_target, should_link)
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def add_as_prebuilt_dependency(prebuilt_node, dependent_target, should_link)
        debug("adding #{prebuilt_node.name} as prebuilt to #{dependent_target.display_name}")


        if prebuilt_node.has_framework_product?
          add_as_prebuilt_framework(prebuilt_node, dependent_target, should_link)
        elsif prebuilt_node.has_static_library_product?
          add_as_prebuilt_static_lib(prebuilt_node, dependent_target, should_link)
        else
          raise ArgumentError.new, "#{prebuilt_node.name} has unsupported product type: #{prebuilt_node.native_target.product_type}"
        end

        debug("done with #{prebuilt_node.name} for #{dependent_target.display_name}")
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      # @param [Boolean] should_link
      #
      def add_as_prebuilt_framework(prebuilt_node, dependent_target, should_link)
        build_configuration = find_build_configuration(dependent_target)

        artifact_location = storage.get_storage_path(prebuilt_node)
        build_flags_changer.add_framework_search_path(build_configuration, artifact_location)
        build_flags_changer.add_framework_headers_iquote(build_configuration, artifact_location, prebuilt_node)

        if should_link
          build_flags_changer.add_framework_linker_flag(build_configuration, prebuilt_node)
        end

        # remove headers so they don't cause non-module includes
        headers_mover.delete_headers(prebuilt_node)

        dependency_remover.remove_dependency(prebuilt_node, dependent_target)
        remove_native_target_from_project(prebuilt_node)
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      # @param [Boolean] should_link
      #
      def add_as_prebuilt_static_lib(prebuilt_node, dependent_target, should_link)
        build_configuration = find_build_configuration(dependent_target)

        if should_link
          artifact_location = storage.get_storage_path(prebuilt_node)
          build_flags_changer.add_library_search_path(build_configuration, artifact_location)
          build_flags_changer.add_library_linker_flag(build_configuration, prebuilt_node)
        end

        headers_mover.prepare_headers_for_injection(prebuilt_node)

        storage.get_all_headers_storage_paths(prebuilt_node)&.each do |path|
          build_flags_changer.add_headers_search_path(build_configuration, path)
          build_flags_changer.add_iquote_path(build_configuration, path)
          build_flags_changer.add_capital_i_path(build_configuration, path)
        end

        dependency_remover.remove_dependency(prebuilt_node, dependent_target)
        remove_native_target_from_project(prebuilt_node)
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def find_build_configuration(target)
        build_configuration = target.build_configurations.select {|configuration| configuration.name == configuration_name}.first
        unless build_configuration
          raise ArgumentError.new, "#{configuration_name} build configuration not found on target #{node.name}"
        end

        build_configuration
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def get_pods_target_name(target)
        "Pods-#{target.display_name}"
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # since 10.2 Xcode looks for implicit dependencies
      # in -l and -framework linker flags, so we need to delete
      # dependency target to make sure Xcode has no way to build it
      # as implicit dependency
      #
      def remove_native_target_from_project(node)
        node.native_target.project.targets.delete(node.native_target)
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def save_graph_projects(graph)
        projects = graph.nodes.map(&:native_target).map(&:project).uniq
        debug("updating #{projects.length} projects")
        projects.each {|project| project.save}
      end
    end
  end
end
