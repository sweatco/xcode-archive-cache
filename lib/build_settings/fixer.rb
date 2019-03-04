require 'xcodeproj'

module XcodeArchiveCache
  module BuildSettings
    class Fixer

      # @param [String] configuration_name
      # @param [XcodeArchiveCache::ArtifactCache::ArtifactExtractor] artifact_extractor
      # @param [Logger] logger
      #
      def initialize(configuration_name, artifact_extractor, logger)
        @configuration_name = configuration_name
        @artifact_extractor = artifact_extractor
        @logger = logger
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def fix(graph)
        graph.nodes.each do |node|
          propagate_node(node)
        end
      end

      private

      FRAMEWORK_SEARCH_PATHS_KEY = "FRAMEWORK_SEARCH_PATHS"
      INHERITED_SETTINGS_VALUE = "$(inherited)"

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def propagate_node(node)
        @logger.debug("propagating #{node.name}")

        if node.rebuild
          # node should be rebuilt, so we shouldn't point dependants to the cached artifact
          # because there's no such artifact
          #
          @logger.debug("#{node.name} should be rebuilt, skipping")
          return
        end

        if node.native_target.product_type == Xcodeproj::Constants::PRODUCT_TYPE_UTI[:framework]
          @logger.debug("product is a framework")

          # add to framework search paths of dependents
          propagate_framework(node, node)

          # remove headers so they don't cause non-module includes
          delete_headers(node)
        elsif node.native_target.product_type == Xcodeproj::Constants::PRODUCT_TYPE_UTI[:static_library]
          @logger.debug("product is a static library")

          # TODO: add to library search paths of dependents
          raise StandardError.new, "Static libraries not supported yet"
        else
          raise ArgumentError.new, "Unsupported cached product type for #{node.name}: #{node.native_target.product_type}"
        end

        @logger.debug("done propagating #{node.name}")
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [XcodeArchiveCache::BuildGraph::Node] dependent_node
      #
      def propagate_framework(prebuilt_node, dependent_node)
        dependent_node.dependent.each do |node|
          add_as_prebuilt_framework(prebuilt_node, node)
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def add_as_prebuilt_framework(prebuilt_node, node)
        if node.rebuild
          build_configuration = node.native_target.build_configurations.select {|configuration| configuration.name == @configuration_name}.first
          unless build_configuration
            raise ArgumentError.new, "#{@configuration_name} build configuration not found on target #{node.name}"
          end

          artifact_location = @artifact_extractor.unpacked_artifact_location(prebuilt_node)
          search_path = path_to_search_path(artifact_location)
          @logger.debug("using search path #{search_path}")

          add_framework_search_path(build_configuration, search_path)
          remove_framework_dependency(prebuilt_node, node)

          @logger.debug("added prebuilt framework at #{search_path} to #{@configuration_name} configuration of #{node.name}")
        end

        # add to upper level dependencies too
        propagate_framework(prebuilt_node, node)
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] search_path
      #
      def add_framework_search_path(build_configuration, search_path)
        framework_search_paths = build_configuration.build_settings[FRAMEWORK_SEARCH_PATHS_KEY]
        if framework_search_paths && framework_search_paths.length > 0
          framework_search_paths += [search_path]
        else
          framework_search_paths = [INHERITED_SETTINGS_VALUE, search_path]
        end

        build_configuration.build_settings[FRAMEWORK_SEARCH_PATHS_KEY] = framework_search_paths
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def remove_framework_dependency(prebuilt_node, node)
        # remove from "Link binary with libraries"
        frameworks = node.native_target.frameworks_build_phase.files.select do |file|
          file.display_name == prebuilt_node.native_target.product_reference.name
        end

        if frameworks.length > 0
          frameworks.each do |framework|
            node.native_target.frameworks_build_phase.remove_file_reference(framework.file_ref)
          end
        end

        # remove from "Target dependencies"
        node.native_target.dependencies.delete_if {|dependency| dependency.target.uuid == prebuilt_node.native_target.uuid}
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def delete_headers(node)
        @logger.debug("deleting headers of #{node.name}")
        node.native_target.headers_build_phase.files.clear
      end

      def path_to_search_path(path)
        "\"#{path}\""
      end
    end
  end
end
