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
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def perform_internal_injection(graph)
        graph.nodes.each {|node| add_as_prebuilt_to_dependents(node)}

        projects = graph.nodes.map(&:native_target).map(&:project).uniq
        debug("updating #{projects.length} projects")
        projects.each {|project| project.save}
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def perform_outgoing_injection(graph, target)
        graph.nodes.each {|node| add_as_prebuilt_dependency(node, target)}

        if graph.node_by_name(get_pods_target_name(target))
          pods_fixer.fix_embed_frameworks_script(target, graph.dependent_build_settings, storage.container_dir_path)
        end

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

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      #
      def add_as_prebuilt_to_dependents(prebuilt_node)
        dependent_nodes = prebuilt_node.dependent + nodes_to_propagate_to(prebuilt_node)
        dependent_nodes.each do |dependent_node|
          add_as_prebuilt_dependency(prebuilt_node, dependent_node.native_target, true)
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def nodes_to_propagate_to(node)
        return [] unless node.has_static_library_product?

        # propagate static library to all dependent nodes
        # with targets from the same project
        node.all_dependent_nodes.select {|dependent_node| node.native_target.project == dependent_node.native_target.project}
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      # @param [Boolean] always_link
      #
      def add_as_prebuilt_dependency(prebuilt_node, dependent_target, always_link = false)
        return if prebuilt_node.rebuild

        debug("adding #{prebuilt_node.name} as prebuilt to #{dependent_target.display_name}")

        if prebuilt_node.has_framework_product?
          add_as_prebuilt_framework(prebuilt_node, dependent_target)
        elsif prebuilt_node.has_static_library_product?
          add_as_prebuilt_static_lib(prebuilt_node, dependent_target, always_link)
        else
          raise ArgumentError.new, "#{prebuilt_node.name} has unsupported product type: #{prebuilt_node.native_target.product_type}"
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
        build_flags_changer.add_framework_linker_flag(build_configuration, prebuilt_node)
        build_flags_changer.add_framework_headers_iquote(build_configuration, artifact_location, prebuilt_node)

        # remove headers so they don't cause non-module includes
        headers_mover.delete_headers(prebuilt_node)

        dependency_remover.remove_dependency(prebuilt_node, dependent_target)
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      # @param [Boolean] always_link
      #
      def add_as_prebuilt_static_lib(prebuilt_node, dependent_target, always_link)
        build_configuration = find_build_configuration(dependent_target)

        if always_link || prebuilt_node.is_root
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
    end
  end
end
