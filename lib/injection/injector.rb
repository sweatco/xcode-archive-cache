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
        @modulemap_fixer = ModulemapFixer.new(storage)
        @framework_embedder = FrameworkEmbedder.new
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def perform_internal_injection(graph)
        inject_unpacked_and_rebuilt(graph.nodes)
        add_header_paths(graph.nodes)
        save_graph_projects(graph)
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def perform_outgoing_injection(graph, target)
        root_node = graph.root_node
        if root_node.native_target.project == target.project && root_node.native_target.uuid == target.uuid
          return
        end

        no_rebuild_performed = root_node.state == :unpacked

        graph.nodes.each do |node|
          if no_rebuild_performed || node.state == :rebuilt_and_cached
            headers_mover.prepare_headers_for_injection(node)
            modulemap_fixer.fix_modulemap(node)
          end

          add_as_prebuilt_dependency(node, target)
          remove_native_target_from_project(node)
        end

        add_header_paths_to_target(target, storage.get_all_headers_storage_paths)

        # pretty dummy but should work in most cases;
        # here we assume that if graph has a pods target
        # then all graph nodes are built as pods and therefore
        # are covered by "Embed Pods Frameworks" script
        #
        if graph.node_by_name(get_pods_target_name(target))
          pods_fixer.fix_embed_frameworks_script(target, graph, storage.container_dir_path)
          pods_fixer.fix_copy_resources_script(target, graph, storage.container_dir_path)
        else
          framework_nodes = graph.nodes.select { |node| node.has_framework_product? }
          framework_file_paths = framework_nodes.map { |node| File.join(storage.get_storage_path(node), node.product_file_name) }
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

      # @return [ModulemapFixer]
      #
      attr_reader :modulemap_fixer

      # @return [FrameworkEmbedder]
      #
      attr_reader :framework_embedder

      # @param [Array<XcodeArchiveCache::BuildGraph::Node>] nodes
      #
      def inject_unpacked_and_rebuilt(nodes)
        cached_nodes = nodes.select { |node| node.state == :unpacked }
        cached_nodes.each do |node|
          headers_mover.prepare_headers_for_injection(node)
          modulemap_fixer.fix_modulemap(node)
          add_as_prebuilt_to_dependents(node)
        end

        built_nodes = nodes.select { |node| node.state == :rebuilt_and_cached }
        built_nodes.each do |node|
          add_as_prebuilt_to_dependents(node)
        end
      end

      # @param [Array<XcodeArchiveCache::BuildGraph::Node>] nodes
      #
      def add_header_paths(nodes)
        header_storage_paths = storage.get_all_headers_storage_paths
        return if header_storage_paths.length == 0

        nodes
            .select(&:waiting_for_rebuild)
            .each { |node| add_header_paths_to_target(node.native_target, header_storage_paths) }
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [Array<String>] paths
      #
      def add_header_paths_to_target(target, paths)
        return if paths == nil

        debug("adding #{paths} to #{target.display_name}")

        build_configuration = find_build_configuration(target)
        paths.each do |path|
          build_flags_changer.add_headers_search_path(build_configuration, path)
          build_flags_changer.add_iquote_path(build_configuration, path)
          build_flags_changer.add_capital_i_path(build_configuration, path)
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      #
      def add_as_prebuilt_to_dependents(prebuilt_node)
        dependent_to_rebuild = prebuilt_node
                                   .all_dependent_nodes
                                   .select(&:waiting_for_rebuild)
        dependent_to_rebuild.each do |dependent_node|
          add_as_prebuilt_dependency(prebuilt_node, dependent_node.native_target)
        end

        remove_native_target_from_project(prebuilt_node)
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def save_graph_projects(graph)
        projects = graph.nodes.map(&:native_target).map(&:project).uniq
        debug("updating #{projects.length} projects")
        projects.each { |project| project.save }
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def add_as_prebuilt_dependency(prebuilt_node, dependent_target)
        debug("adding #{prebuilt_node.name} as prebuilt to #{dependent_target.display_name}")

        unless prebuilt_node.has_acceptable_product?
          raise Informative, "#{prebuilt_node.name} has unsupported product type: #{prebuilt_node.native_target.product_type}"
        end

        if prebuilt_node.has_framework_product?
          add_as_prebuilt_framework(prebuilt_node, dependent_target)
        elsif prebuilt_node.has_static_library_product?
          add_as_prebuilt_static_lib(prebuilt_node, dependent_target)
        end

        debug("done with #{prebuilt_node.name} for #{dependent_target.display_name}")
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def add_as_prebuilt_framework(prebuilt_node, dependent_target)
        build_configuration = find_build_configuration(dependent_target)

        artifact_location = storage.get_storage_path(prebuilt_node)
        build_flags_changer.add_framework_search_path(build_configuration, artifact_location)
        build_flags_changer.add_framework_headers_iquote(build_configuration, artifact_location, prebuilt_node)

        if dependency_remover.is_linked(prebuilt_node, dependent_target)
          build_flags_changer.add_framework_linker_flag(build_configuration, prebuilt_node)
        end

        dependency_remover.remove_dependency(prebuilt_node, dependent_target)
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def add_as_prebuilt_static_lib(prebuilt_node, dependent_target)
        build_configuration = find_build_configuration(dependent_target)

        injected_modulemap_file_path = storage.get_modulemap_path(prebuilt_node)
        if injected_modulemap_file_path
          modulemap_file_names = ["#{prebuilt_node.module_name}.modulemap", File.basename(prebuilt_node.modulemap_file_path)]
          build_flags_changer.fix_module_map_path(build_configuration, modulemap_file_names, injected_modulemap_file_path)
        end

        artifact_location = storage.get_storage_path(prebuilt_node)
        build_flags_changer.add_library_search_path(build_configuration, artifact_location)

        if dependency_remover.is_linked(prebuilt_node, dependent_target)
          if dependent_target.product_type == Xcodeproj::Constants::PRODUCT_TYPE_UTI[:static_library]
            build_flags_changer.add_static_lib_libtool_flag(build_configuration, prebuilt_node)
          else
            build_flags_changer.add_static_lib_linker_flag(build_configuration, prebuilt_node)
          end
        end

        dependency_remover.remove_dependency(prebuilt_node, dependent_target)
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def find_build_configuration(target)
        build_configuration = target.build_configurations.select { |configuration| configuration.name == configuration_name }.first
        unless build_configuration
          raise Informative, "#{configuration_name} build configuration not found on target #{node.name}"
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
        debug("deleting #{node.name} target")
        node.native_target.project.targets.delete(node.native_target)
      end
    end
  end
end
